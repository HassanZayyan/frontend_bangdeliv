import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_routes.dart';
import '../../../../config/app_text_scaling.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../models/address_location_picker_result.dart';
import '../../../../models/chatbot_launch_args.dart';
import '../../../../models/customer_order_model.dart';
import '../../../../models/route_location_picker_result.dart';
import '../../../../models/user_profile_model.dart';
import '../../../../services/customer_order_api_service.dart';
import '../../../../utils/currency_formatter.dart';
import '../../../../widgets/bang_chat_bubble.dart';
import '../../../auth/application/auth_session_provider.dart';
import '../../../orders/application/customer_order_providers.dart';
import '../../application/chatbot_conversation_provider.dart';
import '../../../../utils/address_readiness.dart';
import '../../../shopping/presentation/screens/shopping_merchant_map_picker_screen.dart';
import '../widgets/chatbot_menu_selector.dart';

const double _chatbotButtonRadius = 10;
const double _chatbotBubbleTailWidth = 10;
const List<String> _chatbotOrderingServiceTypes = <String>[
  'antar_jemput',
  'kurir',
  'nitip',
];

class ChatbotScreen extends ConsumerStatefulWidget {
  const ChatbotScreen({super.key, this.launchArgs});

  final ChatbotLaunchArgs? launchArgs;

  @override
  ConsumerState<ChatbotScreen> createState() => _ChatbotScreenState();
}

enum _ChatbotMenuAction { restart }

class _ChatbotScreenState extends ConsumerState<ChatbotScreen> {
  static const TextStyle _assistantNoticeLabelStyle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );
  static const TextStyle _assistantNoticeAmountStyle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    height: 1.35,
  );
  static const TextStyle _assistantNoticeNoteStyle = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 10.5,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  late final TextEditingController _inputController;
  late final ScrollController _scrollController;
  String? _bootstrappedServiceType;
  String? _appliedLaunchSignature;
  bool _isLoadingMenuSelector = false;
  int _menuSelectorRequestId = 0;
  int? _scheduledResolvedResetOrderId;
  bool _didAutoOpenAddressBook = false;
  bool _isAddressBookRouteOpen = false;
  bool _isRefreshingAddressContext = false;
  Timer? _pendingScrollTimer;
  final GlobalKey _menuSelectorSurfaceKey = GlobalKey(
    debugLabel: 'chatbot_menu_selector_surface',
  );
  final Map<int, GlobalKey> _messageKeys = <int, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController();
    _scrollController = ScrollController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final serviceType = _serviceContext.serviceType;
    if (_bootstrappedServiceType == serviceType) {
      // Already bootstrapped for this service type — just scroll to the
      // bottom so the user lands at the latest message on re-entry.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        unawaited(_refreshAndSyncAddressReadiness());
        _maybeResolveDriverVerificationGuard();
        _scrollToBottom();
      });
      return;
    }

    _bootstrappedServiceType = serviceType;
    _appliedLaunchSignature = null;
    _isLoadingMenuSelector = false;
    _menuSelectorRequestId += 1;
    _didAutoOpenAddressBook = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _bootstrapConversation();
    });
  }

  @override
  void dispose() {
    _pendingScrollTimer?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  _ServiceContext get _serviceContext {
    final rawServiceType =
        widget.launchArgs?.serviceType ??
        GoRouterState.of(context).uri.queryParameters['service_type'] ??
        'nitip';

    switch (rawServiceType) {
      case 'antar_jemput':
        return const _ServiceContext(
          serviceType: 'antar_jemput',
          title: 'BangBot AI - Antar Jemput',
          iconAsset: 'assets/images/services/service_ride_motor_simplified.png',
          welcomeMessage:
              'Halo! Saya BangBot untuk layanan Antar Jemput. Kamu bisa kirim tujuan lewat chat atau atur titik jemput dan tujuan di map.',
          addressRequiredMessage:
              'Sebelum pesan Antar Jemput, isi Alamat Saya dulu supaya titik jemput utama kamu siap dipakai.',
          suggestions: [],
        );
      case 'kurir':
        return const _ServiceContext(
          serviceType: 'kurir',
          title: 'BangBot AI - Kurir',
          iconAsset:
              'assets/images/services/service_courier_box_simplified.png',
          welcomeMessage:
              'Halo! Saya BangBot untuk layanan Kurir. Kirim barang seperti laundry, dokumen, skincare, atau paket kecil. Tulis tujuan dan isi paket lewat chat, atau atur titik ambil dan tujuan di map.',
          addressRequiredMessage:
              'Sebelum pesan Kurir, isi Alamat Saya dulu supaya titik ambil utama kamu siap dipakai.',
          suggestions: [],
        );
      default:
        return const _ServiceContext(
          serviceType: 'nitip',
          title: 'BangBot AI - Nitip',
          iconAsset:
              'assets/images/services/service_shopping_basket_simplified.png',
          welcomeMessage:
              'Halo! Saya BangBot untuk layanan Nitip. Tulis nama toko/resto dan barang yang ingin dibeli, atau pilih toko/resto dari daftar.\n\nContoh:\nBeli di Nasgor Gajah:\n- Nasi Goreng 1\n- Es Teh 1\n\nKamu bisa tambah sampai 3 toko/resto dalam satu pesanan.',
          addressRequiredMessage:
              'Sebelum pesan Nitip, pilih alamat antar dulu supaya ongkir bisa dihitung. Setelah itu kamu bisa pilih toko/resto atau tulis pesanan lewat chat.',
          suggestions: [],
        );
    }
  }

  ChatbotConversationNotifier _conversationNotifier([String? serviceType]) {
    return ref.read(
      chatbotConversationProvider(
        serviceType ?? _serviceContext.serviceType,
      ).notifier,
    );
  }

  ChatbotConversationState _readConversation([String? serviceType]) {
    return ref.read(
      chatbotConversationProvider(serviceType ?? _serviceContext.serviceType),
    );
  }

  Future<void> _bootstrapConversation() async {
    final wasInitialized = _readConversation().hasInitialized;
    final hasSavedAddress = _hasSavedAddressInProfile();
    final welcomeMessage = _serviceContext.welcomeMessageFor(hasSavedAddress);

    await _conversationNotifier().bootstrap(
      serviceType: _serviceContext.serviceType,
      welcomeMessage: welcomeMessage,
    );

    _maybeResolveDriverVerificationGuard();

    if (!_isCustomerOrderingBlocked() && !hasSavedAddress) {
      _conversationNotifier().ensureAddressGuardMessage(
        serviceType: _serviceContext.serviceType,
        message: _serviceContext.addressRequiredMessage,
      );
    }

    _scrollToBottom();

    if (wasInitialized) {
      await _refreshAndSyncAddressReadiness();
    }
    if (!mounted) {
      return;
    }

    if (!_isCustomerOrderingBlocked() &&
        !_didAutoOpenAddressBook &&
        !_hasSavedAddressInProfile()) {
      _didAutoOpenAddressBook = true;
      await _handleOpenAddressesAction();
    }

    await _maybeApplyLaunchArgs();
  }

  bool get _isOrderingService =>
      _chatbotOrderingServiceTypes.contains(_serviceContext.serviceType);

  Future<void> _refreshAddressContextIfNeeded() async {
    if (!_isOrderingService || _isRefreshingAddressContext) {
      return;
    }

    _isRefreshingAddressContext = true;
    try {
      await ref.read(authSessionProvider.notifier).refreshSession();
    } finally {
      _isRefreshingAddressContext = false;
    }
  }

  Future<void> _refreshAndSyncAddressReadiness({
    bool allowFollowUpMessage = false,
  }) async {
    if (_isAddressBookRouteOpen) {
      return;
    }

    await _refreshAddressContextIfNeeded();
    if (!mounted) {
      return;
    }

    final changed = _conversationNotifier().syncSavedAddressReadiness(
      serviceType: _serviceContext.serviceType,
      readyWelcomeMessage: _serviceContext.welcomeMessage,
      allowFollowUpMessage: allowFollowUpMessage,
    );

    if (!changed) {
      return;
    }

    await _maybeApplyLaunchArgs();
    _scrollToBottom();
  }

  Future<void> _maybeApplyLaunchArgs() async {
    final launchArgs = widget.launchArgs;
    if (launchArgs == null ||
        launchArgs.serviceType != _serviceContext.serviceType) {
      return;
    }

    final merchantId = launchArgs.merchantId;
    if (_serviceContext.serviceType != 'nitip' ||
        merchantId == null ||
        merchantId <= 0) {
      return;
    }

    if (!_hasSavedAddressInProfile()) {
      return;
    }

    final signature =
        '${launchArgs.serviceType}:$merchantId:${launchArgs.menuSuggestions.map((item) => item.name).join('|')}';
    if (_appliedLaunchSignature == signature) {
      return;
    }

    final state = _readConversation();
    if (state.isBusy || (state.sessionId ?? '').trim().isEmpty) {
      return;
    }

    _appliedLaunchSignature = signature;
    final applied = await _conversationNotifier().applyMerchantPickerAction(
      serviceType: _serviceContext.serviceType,
      merchantId: merchantId,
      mode: 'select',
      appendAssistantMessage: false,
    );

    if (!mounted || !applied) {
      return;
    }

    _showMenuSelector(
      merchantName: launchArgs.merchantName,
      menus: launchArgs.menuSuggestions,
      merchantMode: 'select',
    );

    _scrollToMenuSelectorSurface();
  }

  Future<void> _sendMessage([String? presetText]) async {
    final raw = (presetText ?? _inputController.text).trim();
    if (raw.isEmpty) {
      return;
    }

    if (ChatbotCommandParser.isRestartCommand(raw)) {
      _inputController.clear();
      _clearMenuSelector();
      await _handleRestartConversation();
      return;
    }

    final orderingBlockMessage = _customerOrderingBlockMessage();
    if (orderingBlockMessage != null) {
      _inputController.clear();
      _clearMenuSelector();
      _conversationNotifier().addLocalGuardResponse(
        rawMessage: raw,
        serviceType: _serviceContext.serviceType,
        assistantMessage: orderingBlockMessage,
        actionHints: _customerOrderingBlockActionHints(),
      );
      _scrollToBottom();
      return;
    }

    if (!_hasSavedAddressInProfile()) {
      await _handleOpenAddressesAction();
      return;
    }

    _inputController.clear();
    _clearMenuSelector();

    await _conversationNotifier().sendMessage(
      raw,
      serviceType: _serviceContext.serviceType,
    );
  }

  Future<void> _handleMenuAction(_ChatbotMenuAction action) async {
    switch (action) {
      case _ChatbotMenuAction.restart:
        await _handleRestartConversation();
        return;
    }
  }

  Future<void> _handleRestartConversation() async {
    _clearMenuSelector();
    await _conversationNotifier().restartActiveSession(
      serviceType: _serviceContext.serviceType,
      welcomeMessage: _currentWelcomeMessage(),
    );

    _scrollToBottom();
  }

  bool _isNearBottom({double threshold = 160}) {
    if (!_scrollController.hasClients) {
      return true;
    }

    final position = _scrollController.position;
    return position.maxScrollExtent - position.pixels <= threshold;
  }

  GlobalKey _messageKeyFor(int index) {
    return _messageKeys.putIfAbsent(
      index,
      () => GlobalKey(debugLabel: 'chatbot_message_$index'),
    );
  }

  void _pruneMessageKeys(int messageCount) {
    _messageKeys.removeWhere((index, _) => index >= messageCount);
  }

  void _scrollToBottom({bool force = true}) {
    if (!force && !_isNearBottom()) {
      return;
    }

    _pendingScrollTimer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingScrollTimer?.cancel();
      _pendingScrollTimer = Timer(const Duration(milliseconds: 40), () {
        if (!mounted || !_scrollController.hasClients) {
          return;
        }

        final target = _scrollController.position.maxScrollExtent;
        if ((_scrollController.position.pixels - target).abs() < 1) {
          return;
        }

        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        );
      });
    });
  }

  void _scrollToMessage(int index, {bool force = true}) {
    if (!force && !_isNearBottom()) {
      return;
    }

    _pendingScrollTimer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingScrollTimer?.cancel();
      _pendingScrollTimer = Timer(const Duration(milliseconds: 60), () {
        if (!mounted) {
          return;
        }

        final targetContext = _messageKeys[index]?.currentContext;
        if (targetContext == null) {
          _scrollToBottom(force: force);
          return;
        }

        Scrollable.ensureVisible(
          targetContext,
          alignment: 0.06,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      });
    });
  }

  void _scrollToMenuSelectorSurface() {
    _pendingScrollTimer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingScrollTimer?.cancel();
      _pendingScrollTimer = Timer(const Duration(milliseconds: 80), () {
        if (!mounted) {
          return;
        }

        final targetContext = _menuSelectorSurfaceKey.currentContext;
        if (targetContext == null) {
          return;
        }

        Scrollable.ensureVisible(
          targetContext,
          alignment: 0.06,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      });
    });
  }

  String _currentWelcomeMessage() {
    final addresses =
        ref.read(authSessionProvider).profile?.addresses ??
        const <SavedAddressModel>[];

    return _serviceContext.welcomeMessageFor(hasUsableSavedAddress(addresses));
  }

  bool _hasMenuSelectorSurface(ChatbotConversationState state) {
    return state.hasMenuSelectorSurface || _isLoadingMenuSelector;
  }

  void _showMenuSelector({
    required String? merchantName,
    required List<ChatbotMenuSuggestion> menus,
    String merchantMode = 'select',
  }) {
    _menuSelectorRequestId += 1;
    final normalizedMenus = menus
        .where((menu) => menu.name.trim().isNotEmpty)
        .toList(growable: false);
    if (normalizedMenus.isEmpty) {
      _clearMenuSelector();
      return;
    }

    _conversationNotifier().showMenuSelector(
      serviceType: _serviceContext.serviceType,
      merchantName: merchantName,
      menus: normalizedMenus,
      merchantMode: merchantMode,
    );

    setState(() {
      _isLoadingMenuSelector = false;
    });
  }

  void _showMenuSelectorNotice(String message) {
    _menuSelectorRequestId += 1;
    _conversationNotifier().showMenuSelectorNotice(
      serviceType: _serviceContext.serviceType,
      message: message,
    );

    setState(() {
      _isLoadingMenuSelector = false;
    });
  }

  void _clearMenuSelector() {
    if (!_isLoadingMenuSelector &&
        !_readConversation().hasMenuSelectorSurface) {
      return;
    }

    _menuSelectorRequestId += 1;
    _conversationNotifier().clearMenuSelectorSurface(
      serviceType: _serviceContext.serviceType,
    );

    setState(() {
      _isLoadingMenuSelector = false;
    });
  }

  Future<void> _handleMenuSelectorConfirm(String message) async {
    _clearMenuSelector();
    await _sendMessage(message);
  }

  Future<void> _handleChangeMenuSelectorMerchant(
    ChatbotMenuSelectorDraft selector,
  ) async {
    final mode = selector.merchantMode == 'add' ? 'add' : 'select';
    await _handleOpenMerchantPickerAction(
      ChatbotMessageActionHint(
        type: ChatbotMessageActionType.openMerchantPicker,
        label: mode == 'add' ? 'Tambah Toko/Resto' : 'Ganti Toko/Resto',
        merchantMode: mode,
      ),
    );
  }

  Future<void> _handleBack() async {
    if (!mounted) {
      return;
    }

    if (context.canPop()) {
      context.pop();
      return;
    }

    final session = ref.read(authSessionProvider);
    if (session.role == SessionUserRole.driver) {
      context.go(AppRoutes.driverHome);
      return;
    }

    context.go(AppRoutes.home);
  }

  void _resetConversationIfOrderResolved(
    ChatbotConversationState conversation,
    AsyncValue<List<CustomerOrderSummaryModel>> ordersAsync,
  ) {
    final orderId = conversation.activeOrderId;
    if (orderId == null || orderId <= 0) {
      return;
    }

    final orders = ordersAsync.asData?.value;
    if (orders == null || orders.isEmpty) {
      return;
    }

    CustomerOrderSummaryModel? matchedOrder;
    for (final order in orders) {
      if (order.id == orderId) {
        matchedOrder = order;
        break;
      }
    }

    if (matchedOrder == null || !matchedOrder.isResolvedForCustomer) {
      return;
    }

    if (_scheduledResolvedResetOrderId == orderId) {
      return;
    }

    _scheduledResolvedResetOrderId = orderId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final latestConversation = _readConversation(conversation.serviceType);
      if (latestConversation.activeOrderId != orderId) {
        _scheduledResolvedResetOrderId = null;
        return;
      }

      _clearMenuSelector();
      _conversationNotifier(conversation.serviceType).resetAfterResolvedOrder(
        serviceType: conversation.serviceType,
        orderId: orderId,
        welcomeMessage: _currentWelcomeMessage(),
      );
      _scheduledResolvedResetOrderId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final conversationProvider = chatbotConversationProvider(
      _serviceContext.serviceType,
    );
    final state = ref.watch(conversationProvider);
    final isServiceMismatch = state.serviceType != _serviceContext.serviceType;
    final effectiveBusy = state.isBusy || isServiceMismatch;
    final inputEnabled = !effectiveBusy;
    final latestActionMessageIndex = state.messages.lastIndexWhere(
      (message) => !message.isUser && message.actionHints.isNotEmpty,
    );
    final showStaticSuggestions = _shouldShowStaticSuggestions(state);

    // Auto-scroll whenever the message list grows (new send / map-pin response)
    ref.listen<ChatbotConversationState>(conversationProvider, (
      previous,
      next,
    ) {
      final previousMessageCount = previous?.messages.length ?? 0;
      if (previousMessageCount < next.messages.length) {
        final latestMessageIndex = next.messages.length - 1;
        final latestMessage = next.messages[latestMessageIndex];
        final latestMessageIsFromUser = latestMessage.isUser;
        final wasWaitingForBotReply = previous?.isSending ?? false;
        final wasApplyingAction = previous?.isApplyingAction ?? false;
        final shouldFollowNewMessage =
            latestMessageIsFromUser ||
            wasWaitingForBotReply ||
            wasApplyingAction ||
            _isNearBottom();

        if (latestMessageIsFromUser) {
          _scrollToBottom(force: shouldFollowNewMessage);
        } else {
          _scrollToMessage(latestMessageIndex, force: shouldFollowNewMessage);
        }
      }
      if ((previous?.activeOrderId ?? 0) != (next.activeOrderId ?? 0) &&
          next.hasActiveOrder) {
        unawaited(
          ref.read(customerOrdersProvider.notifier).refresh(showLoading: false),
        );
      }
    });
    ref.listen<AuthSessionState>(authSessionProvider, (previous, next) {
      if (previous != null &&
          previous.driverAccessState != next.driverAccessState) {
        _maybeResolveDriverVerificationGuard(next);
      }

      final previousHasAddress = hasUsableSavedAddress(
        previous?.profile?.addresses ?? const <SavedAddressModel>[],
      );
      final nextHasAddress = hasUsableSavedAddress(
        next.profile?.addresses ?? const <SavedAddressModel>[],
      );
      if (_isOrderingService &&
          !_isRefreshingAddressContext &&
          !previousHasAddress &&
          nextHasAddress) {
        final changed = _conversationNotifier().syncSavedAddressReadiness(
          serviceType: _serviceContext.serviceType,
          readyWelcomeMessage: _serviceContext.welcomeMessage,
        );
        if (changed) {
          unawaited(_maybeApplyLaunchArgs());
          _scrollToBottom();
        }
      }
    });
    if (state.hasActiveOrder) {
      ref.watch(customerOrdersAutoRefreshProvider);
      final ordersAsync = ref.watch(customerOrdersProvider);
      _resetConversationIfOrderResolved(state, ordersAsync);
    }
    _pruneMessageKeys(state.messages.length);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        toolbarHeight: 64,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
          onPressed: _handleBack,
        ),
        title: Row(
          children: [
            Image.asset(
              _serviceContext.iconAsset,
              width: 28,
              height: 28,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  _serviceContext.title,
                  maxLines: 1,
                  softWrap: false,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<_ChatbotMenuAction>(
            tooltip: 'Opsi chat',
            enabled: !effectiveBusy,
            icon: Icon(
              Icons.more_vert,
              color: !effectiveBusy
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
            ),
            color: AppColors.white,
            constraints: const BoxConstraints(minWidth: 220),
            offset: const Offset(0, 12),
            position: PopupMenuPosition.under,
            onSelected: _handleMenuAction,
            itemBuilder: (context) {
              return const [
                PopupMenuItem<_ChatbotMenuAction>(
                  value: _ChatbotMenuAction.restart,
                  child: Row(
                    children: [
                      Icon(
                        Icons.restart_alt,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          'Mulai Ulang Pesanan',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if ((state.errorMessage ?? '').isNotEmpty)
            Container(
              width: double.infinity,
              color: AppColors.cardYellow,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                state.errorMessage!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Expanded(
            child:
                (state.isBootstrapping && state.messages.isEmpty) ||
                    isServiceMismatch
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(20),
                    children: [
                      ...List.generate(state.messages.length, (index) {
                        final message = state.messages[index];
                        return KeyedSubtree(
                          key: _messageKeyFor(index),
                          child: _buildMessageItem(
                            message,
                            actionsEnabled:
                                !effectiveBusy &&
                                index == latestActionMessageIndex,
                          ),
                        );
                      }),
                      if (_hasMenuSelectorSurface(state))
                        KeyedSubtree(
                          key: _menuSelectorSurfaceKey,
                          child: _buildMenuSelectorSurface(state),
                        ),
                    ],
                  ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: const BoxDecoration(
              color: AppColors.white,
              border: Border(top: BorderSide(color: AppColors.border)),
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showStaticSuggestions) ...[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final suggestion
                              in _serviceContext.suggestions) ...[
                            _buildSuggestionChip(
                              suggestion,
                              enabled: inputEnabled,
                            ),
                            const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          enabled: inputEnabled,
                          minLines: 1,
                          maxLines: 3,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: AppTextScaling.adaptive(
                              context,
                              normal: 14,
                              large: 13.4,
                            ),
                          ),
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.white,
                            hintText: 'Ketik kebutuhan layanan...',
                            hintStyle: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: AppTextScaling.adaptive(
                                context,
                                normal: 14,
                                large: 13.4,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                                width: 1.2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: inputEnabled ? _sendMessage : null,
                        child: Container(
                          width: AppTextScaling.adaptive(
                            context,
                            normal: 50,
                            large: 54,
                          ),
                          height: AppTextScaling.adaptive(
                            context,
                            normal: 50,
                            large: 54,
                          ),
                          decoration: BoxDecoration(
                            color: inputEnabled
                                ? AppColors.primary
                                : AppColors.primary.withValues(alpha: 0.55),
                            shape: BoxShape.circle,
                          ),
                          child: effectiveBusy
                              ? const Padding(
                                  padding: EdgeInsets.all(14),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String label, {required bool enabled}) {
    return AppTextScaling.clampForCompactComponent(
      context: context,
      maxScaleFactor: AppTextScaling.compactComponentMaxScaleFactor,
      child: InkWell(
        borderRadius: BorderRadius.circular(_chatbotButtonRadius),
        onTap: enabled ? () => _sendMessage(label) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(_chatbotButtonRadius),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.24),
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  bool _shouldShowStaticSuggestions(ChatbotConversationState state) {
    if (_serviceContext.suggestions.isEmpty) {
      return false;
    }

    if (state.isBootstrapping ||
        state.isSending ||
        state.isApplyingAction ||
        _hasMenuSelectorSurface(state)) {
      return false;
    }

    return !state.messages.any((message) => message.isUser);
  }

  Widget _buildMenuSelectorSurface(ChatbotConversationState state) {
    final selectorData = state.menuSelectorDraft;
    if (selectorData != null) {
      return ChatbotMenuSelector(
        merchantName: selectorData.merchantName,
        menus: selectorData.menus,
        quantities: selectorData.quantities,
        onQuantityDelta: (index, delta) {
          _conversationNotifier().adjustMenuSelectorQuantity(
            serviceType: _serviceContext.serviceType,
            index: index,
            delta: delta,
          );
        },
        onChangeMerchant: () => _handleChangeMenuSelectorMerchant(selectorData),
        onConfirm: _handleMenuSelectorConfirm,
      );
    }

    if (_isLoadingMenuSelector) {
      return _buildMenuSelectorInfoBubble(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                'Memuat menu tempat...',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: AppTextScaling.adaptive(
                    context,
                    normal: 13,
                    large: 12.4,
                  ),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final notice = (state.menuSelectorNotice ?? '').trim();
    if (notice.isNotEmpty) {
      return _buildMenuSelectorInfoBubble(
        child: Text(
          notice,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: AppTextScaling.adaptive(context, normal: 13, large: 12.4),
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildMenuSelectorInfoBubble({required Widget child}) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildMessageItem(
    ChatbotConversationMessage message, {
    required bool actionsEnabled,
  }) {
    final isUser = message.isUser;
    final bubbleColor = isUser ? AppColors.primary : AppColors.white;
    final textColor = isUser ? Colors.white : AppColors.textPrimary;
    final metaColor = isUser
        ? Colors.white.withValues(alpha: 0.8)
        : AppColors.textSecondary;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          BangChatBubble(
            side: isUser ? BangChatBubbleSide.right : BangChatBubbleSide.left,
            color: bubbleColor,
            borderColor: isUser ? null : AppColors.border,
            margin: EdgeInsets.only(
              left: isUser ? 50 : 0,
              right: isUser ? 0 : 50,
              bottom: 6,
            ),
            padding: const EdgeInsets.all(16),
            borderRadius: BorderRadius.circular(10).copyWith(
              topLeft: isUser
                  ? const Radius.circular(10)
                  : const Radius.circular(4),
              topRight: isUser
                  ? const Radius.circular(4)
                  : const Radius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMessageTextContent(
                  message: message,
                  textColor: textColor,
                ),
                if (message.meta != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    message.meta!,
                    style: TextStyle(color: metaColor, fontSize: 11),
                  ),
                ],
                if (message.actionHints.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildActionHintSection(
                    actionHints: message.actionHints,
                    actionsEnabled: actionsEnabled,
                    isUser: isUser,
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              left: isUser ? 0 : _chatbotBubbleTailWidth,
              right: isUser ? _chatbotBubbleTailWidth : 0,
              bottom: 8,
            ),
            child: Text(
              message.timestamp,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageTextContent({
    required ChatbotConversationMessage message,
    required Color textColor,
  }) {
    if (message.isUser) {
      final routeCommandParts = _tryParseUserRouteCommand(message.text);
      if (routeCommandParts != null) {
        return _buildUserRouteCommandContent(
          parts: routeCommandParts,
          textColor: textColor,
        );
      }

      return Text(
        message.text,
        style: TextStyle(color: textColor, height: 1.5),
      );
    }

    final parts = _tryParseDraftMessage(message.text);
    if (parts == null) {
      final shoppingParts = _tryParseShoppingDraftMessage(message.text);
      if (shoppingParts != null) {
        return _buildShoppingDraftContent(
          parts: shoppingParts,
          textColor: textColor,
        );
      }

      final incompleteShoppingParts = _tryParseIncompleteShoppingDraftMessage(
        message.text,
      );
      if (incompleteShoppingParts != null) {
        return _buildIncompleteShoppingDraftContent(
          parts: incompleteShoppingParts,
          textColor: textColor,
        );
      }

      final resetParts = _tryParseResetDestinationMessage(message.text);
      if (resetParts != null) {
        return _buildResetDestinationContent(
          parts: resetParts,
          textColor: textColor,
        );
      }

      final inlineResetParts = _tryParseInlineCourierResetMessage(message.text);
      if (inlineResetParts != null) {
        return _buildResetDestinationContent(
          parts: inlineResetParts,
          textColor: textColor,
        );
      }

      final shoppingSuccessParts = _tryParseShoppingSuccessMessage(
        message.text,
      );
      if (shoppingSuccessParts != null) {
        return _buildShoppingSuccessContent(
          parts: shoppingSuccessParts,
          textColor: textColor,
        );
      }

      final promptParts = _tryParseCourierRouteSavedPrompt(message.text);
      if (promptParts != null) {
        return _buildSimplePromptContent(
          parts: promptParts,
          textColor: textColor,
        );
      }

      return Text(
        message.text,
        style: TextStyle(color: textColor, height: 1.5),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          parts.headline,
          style: TextStyle(
            color: textColor,
            height: 1.45,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        _buildDraftField(
          label: parts.pickupLabel,
          value: parts.pickupAddress,
          textColor: textColor,
        ),
        const SizedBox(height: 8),
        _buildDraftField(
          label: 'Tujuan',
          value: parts.destinationAddress,
          textColor: textColor,
        ),
        if (parts.packageDescription != null &&
            parts.packageDescription!.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildDraftField(
            label: 'Barang',
            value: parts.packageDescription!,
            textColor: textColor,
          ),
        ],
        if (parts.feeLine.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildAssistantNotice(parts.feeLine),
        ],
        if (parts.instructionLine.isNotEmpty &&
            !_hasPaymentActionHints(message.actionHints)) ...[
          const SizedBox(height: 10),
          _buildAssistantInstructionText(
            parts.instructionLine,
            fontSize: 12,
            height: 1.4,
          ),
        ],
      ],
    );
  }

  Widget _buildActionHintSection({
    required List<ChatbotMessageActionHint> actionHints,
    required bool actionsEnabled,
    required bool isUser,
  }) {
    final paymentActions = actionHints
        .where(_isPaymentActionHint)
        .toList(growable: false);
    final destinationResetActions = actionHints
        .where(_isDestinationResetActionHint)
        .toList(growable: false);
    final routeEditActions = actionHints
        .where(
          (actionHint) =>
              _isRouteEditActionHint(actionHint) &&
              !_isDestinationResetActionHint(actionHint),
        )
        .toList(growable: false);
    final locationSetupActions = actionHints
        .where(
          (actionHint) =>
              _isLocationSetupActionHint(actionHint) &&
              !_isDestinationResetActionHint(actionHint) &&
              !_isRouteEditActionHint(actionHint) &&
              !_isAddMerchantActionHint(actionHint),
        )
        .toList(growable: false);
    final confirmationActions = actionHints
        .where(_isConfirmationActionHint)
        .toList(growable: false);
    final addMerchantActions = actionHints
        .where(_isAddMerchantActionHint)
        .toList(growable: false);
    final otherActions = actionHints
        .where(
          (actionHint) =>
              !_isPaymentActionHint(actionHint) &&
              !_isDestinationResetActionHint(actionHint) &&
              !_isRouteEditActionHint(actionHint) &&
              !_isLocationSetupActionHint(actionHint) &&
              !_isConfirmationActionHint(actionHint) &&
              !_isAddMerchantActionHint(actionHint),
        )
        .toList(growable: false);

    if (paymentActions.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildActionHintGroup(
            title: _locationSetupActionTitle(),
            actions: locationSetupActions,
            actionsEnabled: actionsEnabled,
            isUser: isUser,
            isPrimaryChoice: true,
          ),
          if (destinationResetActions.isNotEmpty) ...[
            if (locationSetupActions.isNotEmpty) const SizedBox(height: 14),
            _buildActionGroupTitle('Tujuan baru'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final actionHint in destinationResetActions)
                  _buildActionHintButton(
                    actionHint: actionHint,
                    actionsEnabled: actionsEnabled,
                    isUser: isUser,
                    isPrimaryChoice: true,
                  ),
              ],
            ),
          ],
          if (routeEditActions.isNotEmpty) ...[
            if (locationSetupActions.isNotEmpty ||
                destinationResetActions.isNotEmpty)
              const SizedBox(height: 14),
            _buildActionGroupTitle('Ubah lokasi'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final actionHint in routeEditActions)
                  _buildActionHintButton(
                    actionHint: actionHint,
                    actionsEnabled: actionsEnabled,
                    isUser: isUser,
                  ),
              ],
            ),
          ],
          _buildActionHintGroup(
            title: 'Selesaikan pesanan',
            actions: confirmationActions,
            actionsEnabled: actionsEnabled,
            isUser: isUser,
            isPrimaryChoice: true,
            hasPreviousGroup:
                locationSetupActions.isNotEmpty ||
                destinationResetActions.isNotEmpty ||
                routeEditActions.isNotEmpty,
          ),
          _buildAddMerchantActionGroup(
            actions: addMerchantActions,
            actionsEnabled: actionsEnabled,
            isUser: isUser,
            hasPreviousGroup:
                locationSetupActions.isNotEmpty ||
                destinationResetActions.isNotEmpty ||
                routeEditActions.isNotEmpty ||
                confirmationActions.isNotEmpty,
          ),
          if (otherActions.isNotEmpty) ...[
            if (locationSetupActions.isNotEmpty ||
                destinationResetActions.isNotEmpty ||
                routeEditActions.isNotEmpty ||
                confirmationActions.isNotEmpty ||
                addMerchantActions.isNotEmpty)
              const SizedBox(height: 14),
            _buildActionGroupTitle('Lanjutkan'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final actionHint in otherActions)
                  _buildActionHintButton(
                    actionHint: actionHint,
                    actionsEnabled: actionsEnabled,
                    isUser: isUser,
                  ),
              ],
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildActionGroupTitle('Pilih metode pembayaran'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final actionHint in paymentActions)
              _buildActionHintButton(
                actionHint: actionHint,
                actionsEnabled: actionsEnabled,
                isUser: isUser,
                isPrimaryChoice: true,
              ),
          ],
        ),
        _buildActionHintGroup(
          title: _locationSetupActionTitle(),
          actions: locationSetupActions,
          actionsEnabled: actionsEnabled,
          isUser: isUser,
          isPrimaryChoice: true,
          hasPreviousGroup: true,
        ),
        if (routeEditActions.isNotEmpty) ...[
          const SizedBox(height: 14),
          _buildActionGroupTitle('Ubah lokasi'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final actionHint in routeEditActions)
                _buildActionHintButton(
                  actionHint: actionHint,
                  actionsEnabled: actionsEnabled,
                  isUser: isUser,
                ),
            ],
          ),
        ],
        if (destinationResetActions.isNotEmpty) ...[
          const SizedBox(height: 14),
          _buildActionGroupTitle('Tujuan baru'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final actionHint in destinationResetActions)
                _buildActionHintButton(
                  actionHint: actionHint,
                  actionsEnabled: actionsEnabled,
                  isUser: isUser,
                  isPrimaryChoice: true,
                ),
            ],
          ),
        ],
        _buildActionHintGroup(
          title: 'Selesaikan pesanan',
          actions: confirmationActions,
          actionsEnabled: actionsEnabled,
          isUser: isUser,
          isPrimaryChoice: true,
          hasPreviousGroup: true,
        ),
        _buildAddMerchantActionGroup(
          actions: addMerchantActions,
          actionsEnabled: actionsEnabled,
          isUser: isUser,
          hasPreviousGroup: true,
        ),
        if (otherActions.isNotEmpty) ...[
          const SizedBox(height: 14),
          _buildActionGroupTitle('Lanjutkan'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final actionHint in otherActions)
                _buildActionHintButton(
                  actionHint: actionHint,
                  actionsEnabled: actionsEnabled,
                  isUser: isUser,
                ),
            ],
          ),
        ],
      ],
    );
  }

  String _locationSetupActionTitle() {
    return _serviceContext.serviceType == 'nitip'
        ? 'Atur pesanan'
        : 'Atur lokasi';
  }

  Widget _buildAddMerchantActionGroup({
    required List<ChatbotMessageActionHint> actions,
    required bool actionsEnabled,
    required bool isUser,
    bool hasPreviousGroup = false,
  }) {
    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasPreviousGroup) const SizedBox(height: 14),
        _buildActionGroupTitle('Tambah toko/resto lain'),
        const SizedBox(height: 6),
        _buildAssistantInstructionLines(
          const [
            'Pilih toko/resto dari daftar atau peta agar lokasinya tepat.',
            'Setelah toko dipilih, menu akan muncul di chat.',
          ],
          fontSize: 12.5,
          height: 1.4,
          fontWeight: FontWeight.w600,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final actionHint in actions)
              _buildActionHintButton(
                actionHint: actionHint,
                actionsEnabled: actionsEnabled,
                isUser: isUser,
                isPrimaryChoice: true,
              ),
          ],
        ),
        const SizedBox(height: 8),
        _buildAssistantInstructionLines(
          const [
            'Kalau menu tidak ada, ketik barangnya saja.',
            'Contoh:',
            '- susu 1',
            '- roti tawar 2',
          ],
          fontSize: 12.5,
          height: 1.4,
          fontWeight: FontWeight.w600,
        ),
      ],
    );
  }

  Widget _buildActionHintGroup({
    required String title,
    required List<ChatbotMessageActionHint> actions,
    required bool actionsEnabled,
    required bool isUser,
    bool isPrimaryChoice = false,
    bool hasPreviousGroup = false,
  }) {
    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasPreviousGroup) const SizedBox(height: 14),
        _buildActionGroupTitle(title),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final actionHint in actions)
              _buildActionHintButton(
                actionHint: actionHint,
                actionsEnabled: actionsEnabled,
                isUser: isUser,
                isPrimaryChoice: isPrimaryChoice,
              ),
          ],
        ),
      ],
    );
  }

  bool _isDestinationResetActionHint(ChatbotMessageActionHint actionHint) {
    final label = actionHint.label.trim().toLowerCase();
    return actionHint.type == ChatbotMessageActionType.openRoutePicker &&
        label == 'pilih tujuan baru';
  }

  Widget _buildActionGroupTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        height: 1.35,
      ),
    );
  }

  Widget _buildActionHintButton({
    required ChatbotMessageActionHint actionHint,
    required bool actionsEnabled,
    required bool isUser,
    bool isPrimaryChoice = false,
  }) {
    final isConfirmationAction = _isConfirmationActionHint(actionHint);
    final foregroundColor = isUser
        ? Colors.white
        : (isConfirmationAction ? AppColors.success : AppColors.primaryDark);
    final borderColor = isUser
        ? Colors.white.withValues(alpha: 0.35)
        : (isConfirmationAction ? AppColors.success : AppColors.primary);

    return OutlinedButton.icon(
      onPressed: actionsEnabled ? () => _handleActionHint(actionHint) : null,
      icon: Icon(_iconForActionHint(actionHint), size: 16),
      label: Text(_displayLabelForActionHint(actionHint)),
      style: OutlinedButton.styleFrom(
        foregroundColor: foregroundColor,
        side: BorderSide(color: borderColor, width: 1.2),
        padding: EdgeInsets.symmetric(
          horizontal: isPrimaryChoice ? 14 : 12,
          vertical: isPrimaryChoice ? 9 : 8,
        ),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_chatbotButtonRadius),
        ),
      ),
    );
  }

  IconData _iconForActionHint(ChatbotMessageActionHint actionHint) {
    if (_isPaymentActionHint(actionHint)) {
      return Icons.payments_outlined;
    }

    if (_isConfirmationActionHint(actionHint)) {
      return Icons.check_circle_outline_rounded;
    }

    if (_isRouteEditActionHint(actionHint)) {
      return Icons.edit_location_alt_outlined;
    }

    if (_isMerchantMapPickerActionHint(actionHint)) {
      return Icons.map_outlined;
    }

    return switch (actionHint.type) {
      ChatbotMessageActionType.openAddresses => Icons.home_outlined,
      ChatbotMessageActionType.openMapPicker => Icons.location_on_outlined,
      ChatbotMessageActionType.openMerchantPicker => Icons.storefront_outlined,
      ChatbotMessageActionType.openRoutePicker => Icons.route_outlined,
      ChatbotMessageActionType.sendPresetMessage => Icons.bolt_rounded,
      ChatbotMessageActionType.openTrackOrder => Icons.map_outlined,
      ChatbotMessageActionType.openActivity => Icons.receipt_long_outlined,
      ChatbotMessageActionType.openDriverVerificationStatus =>
        Icons.badge_outlined,
    };
  }

  String _displayLabelForActionHint(ChatbotMessageActionHint actionHint) {
    if (_isConfirmationActionHint(actionHint)) {
      return 'Buat Pesanan';
    }

    final label = actionHint.label.trim();
    if (label.isEmpty) {
      return label;
    }

    return _friendlyLocationActionLabel(label);
  }

  String _friendlyLocationActionLabel(String label) {
    var text = label;
    const replacements = <String, String>{
      'Titik Jemput/Tujuan': 'Lokasi Jemput/Tujuan',
      'Titik Jemput & Tujuan': 'Lokasi Jemput/Tujuan',
      'Titik Ambil & Tujuan': 'Lokasi Ambil/Tujuan',
      'Titik Ambil/Tujuan': 'Lokasi Ambil/Tujuan',
      'Titik Jemput': 'Lokasi Jemput',
      'Titik Ambil': 'Lokasi Ambil',
      'Titik Tujuan': 'Lokasi Tujuan',
      'Titik Antar': 'Lokasi Antar',
      'Titik di Peta': 'Lokasi di Peta',
      'Pilih Tempat di Map': 'Pilih Toko/Resto',
      'Pilih Tempat': 'Pilih Toko/Resto',
      'Tambah Tempat': 'Tambah Toko/Resto',
      'Lokasi Antar': 'Alamat Antar',
    };

    for (final entry in replacements.entries) {
      text = text.replaceAll(entry.key, entry.value);
    }

    return text;
  }

  bool _hasPaymentActionHints(List<ChatbotMessageActionHint> actionHints) {
    return actionHints.any(_isPaymentActionHint);
  }

  bool _isPaymentActionHint(ChatbotMessageActionHint actionHint) {
    final label = actionHint.label.trim().toLowerCase();
    final message = (actionHint.presetMessage ?? '').trim().toLowerCase();
    const paymentKeywords = <String>{
      'cod',
      'cash',
      'tunai',
      'transfer',
      'qris',
    };
    return actionHint.type == ChatbotMessageActionType.sendPresetMessage &&
        (paymentKeywords.contains(label) || paymentKeywords.contains(message));
  }

  bool _isRouteEditActionHint(ChatbotMessageActionHint actionHint) {
    final label = actionHint.label.trim().toLowerCase();
    final message = (actionHint.presetMessage ?? '').trim().toLowerCase();

    return (label.contains('ubah') || label.contains('ganti')) &&
        (label.contains('tujuan') ||
            label.contains('jemput') ||
            label.contains('antar') ||
            label.contains('ambil') ||
            label.contains('lokasi') ||
            message.contains('tujuan'));
  }

  bool _isLocationSetupActionHint(ChatbotMessageActionHint actionHint) {
    final label = actionHint.label.trim().toLowerCase();
    return (actionHint.type == ChatbotMessageActionType.openMapPicker ||
            actionHint.type == ChatbotMessageActionType.openMerchantPicker ||
            actionHint.type == ChatbotMessageActionType.openRoutePicker ||
            actionHint.type == ChatbotMessageActionType.openAddresses) &&
        (label.contains('atur') ||
            label.contains('pilih') ||
            label.contains('cari') ||
            label.contains('isi alamat'));
  }

  bool _isMerchantMapPickerActionHint(ChatbotMessageActionHint actionHint) {
    final mode = (actionHint.merchantMode ?? '').trim().toLowerCase();
    return actionHint.type == ChatbotMessageActionType.openMerchantPicker &&
        (mode == 'maps' || mode == 'maps_add');
  }

  bool _isAddMerchantActionHint(ChatbotMessageActionHint actionHint) {
    final mode = (actionHint.merchantMode ?? '').trim().toLowerCase();
    final label = actionHint.label.trim().toLowerCase();
    return actionHint.type == ChatbotMessageActionType.openMerchantPicker &&
        (mode == 'add' ||
            mode == 'maps_add' ||
            label.contains('tambah toko') ||
            label.contains('tambah resto'));
  }

  bool _isConfirmationActionHint(ChatbotMessageActionHint actionHint) {
    final label = actionHint.label.trim().toLowerCase();
    final message = (actionHint.presetMessage ?? '').trim().toLowerCase();
    return actionHint.type == ChatbotMessageActionType.sendPresetMessage &&
        (label.contains('konfirmasi') || message == 'konfirmasi');
  }

  Widget _buildResetDestinationContent({
    required _ResetDestinationMessageParts parts,
    required Color textColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          parts.headline,
          style: TextStyle(
            color: textColor,
            height: 1.45,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        _buildDraftField(
          label: parts.pickupLabel,
          value: parts.pickupAddress,
          textColor: textColor,
        ),
        if (parts.instructionLine.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildAssistantInstructionText(
            parts.instructionLine,
            fontSize: 12,
            height: 1.4,
          ),
        ],
      ],
    );
  }

  Widget _buildShoppingSuccessContent({
    required _ShoppingSuccessMessageParts parts,
    required Color textColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          parts.headline,
          style: TextStyle(
            color: textColor,
            height: 1.45,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (parts.deliveryFeeLine.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildAssistantNotice(parts.deliveryFeeLine),
        ],
        if (parts.instructionLine.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildAssistantInstructionText(
            parts.instructionLine,
            fontSize: 12.5,
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        ],
      ],
    );
  }

  Widget _buildIncompleteShoppingDraftContent({
    required _IncompleteShoppingDraftMessageParts parts,
    required Color textColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          parts.headline,
          style: TextStyle(
            color: textColor,
            height: 1.45,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        _buildDraftField(
          label: parts.merchantLabel,
          value: parts.merchantName,
          textColor: textColor,
        ),
        if (parts.instructionLines.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildAssistantInstructionLines(
            parts.instructionLines,
            fontSize: 13,
            height: 1.45,
            fontWeight: FontWeight.w600,
          ),
        ],
        if (parts.examples.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Contoh',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final example in parts.examples)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '-',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 13.5,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          example,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 13.5,
                            height: 1.45,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildSimplePromptContent({
    required _SimplePromptMessageParts parts,
    required Color textColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          parts.headline,
          style: TextStyle(
            color: textColor,
            height: 1.45,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (parts.instructionLine.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildSimplePromptInstruction(parts.instructionLine),
        ],
      ],
    );
  }

  Widget _buildSimplePromptInstruction(String text) {
    final lines = _splitSimplePromptInstruction(text);
    if (lines.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < lines.length; index += 1) ...[
          Text(
            lines[index],
            style: TextStyle(
              color: _isExampleInstructionLine(lines[index])
                  ? AppColors.textSecondary
                  : AppColors.textPrimary,
              fontSize: 14.5,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (index < lines.length - 1) const SizedBox(height: 4),
        ],
      ],
    );
  }

  List<String> _splitSimplePromptInstruction(String text) {
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    if (lines.length != 1) {
      return lines;
    }

    final line = lines.single;
    final exampleIndex = line.toLowerCase().indexOf(' contoh:');
    if (exampleIndex <= 0) {
      return lines;
    }

    return [
      line.substring(0, exampleIndex).trim(),
      line.substring(exampleIndex + 1).trim(),
    ].where((line) => line.isNotEmpty).toList(growable: false);
  }

  bool _isExampleInstructionLine(String line) {
    return line.trim().toLowerCase().startsWith('contoh:');
  }

  Widget _buildAssistantNotice(String text) {
    final rows = _parseAssistantNoticeRows(text);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardYellow.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: rows.isEmpty
          ? Text(
              text,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final textScaler = MediaQuery.textScalerOf(context);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final row in rows)
                      _buildAssistantNoticeRow(
                        row: row,
                        isLast: row == rows.last,
                        maxWidth: constraints.maxWidth,
                        textScaler: textScaler,
                      ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildAssistantNoticeRow({
    required _AssistantNoticeRow row,
    required bool isLast,
    required double maxWidth,
    required TextScaler textScaler,
  }) {
    final shouldStack = _shouldStackAssistantNoticeRow(
      row: row,
      maxWidth: maxWidth,
      textScaler: textScaler,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (shouldStack) ...[
            Text('${row.label}:', style: _assistantNoticeLabelStyle),
            const SizedBox(height: 2),
            Text(row.amount, style: _assistantNoticeAmountStyle),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '${row.label}:',
                    softWrap: false,
                    style: _assistantNoticeLabelStyle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(row.amount, style: _assistantNoticeAmountStyle),
              ],
            ),
          if (row.note.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(row.note, style: _assistantNoticeNoteStyle),
          ],
        ],
      ),
    );
  }

  bool _shouldStackAssistantNoticeRow({
    required _AssistantNoticeRow row,
    required double maxWidth,
    required TextScaler textScaler,
  }) {
    if (!maxWidth.isFinite || maxWidth <= 0) {
      return row.amount.length >= 18;
    }

    final labelWidth = _measureAssistantNoticeText(
      '${row.label}:',
      _assistantNoticeLabelStyle,
      textScaler,
    );
    final amountWidth = _measureAssistantNoticeText(
      row.amount,
      _assistantNoticeAmountStyle,
      textScaler,
    );

    return labelWidth + 8 + amountWidth > maxWidth;
  }

  double _measureAssistantNoticeText(
    String text,
    TextStyle style,
    TextScaler textScaler,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();

    return painter.width;
  }

  List<_AssistantNoticeRow> _parseAssistantNoticeRows(String text) {
    final rows = <_AssistantNoticeRow>[];
    final rowPattern = RegExp(
      r'^(.+?):\s*(Rp\s*[\d.]+(?:,\d+)?|Sesuai nota|Menunggu harga barang)(?:\s*(\(.+\)))?\.?$',
      caseSensitive: false,
    );

    for (final rawLine in text.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }

      final match = rowPattern.firstMatch(line);
      if (match == null) {
        return const [];
      }

      rows.add(
        _AssistantNoticeRow(
          label: _normalizeAssistantNoticeLabel(match.group(1)!.trim()),
          amount: match.group(2)!.trim().replaceFirst(RegExp(r'\.$'), ''),
          note: (match.group(3) ?? '').trim().replaceFirst(RegExp(r'\.$'), ''),
        ),
      );
    }

    return rows;
  }

  String _normalizeAssistantNoticeLabel(String label) {
    final normalized = label.replaceAll(RegExp(r'\s+'), ' ').trim();
    final lower = normalized.toLowerCase();

    if (lower == 'estimasi ongkir sementara' || lower == 'ongkir') {
      return 'Estimasi ongkir';
    }

    if (lower == 'harga barang') {
      return 'Harga barang';
    }

    if (lower == 'estimasi total sementara') {
      return 'Estimasi total';
    }

    return normalized;
  }

  Widget _buildUserRouteCommandContent({
    required _UserRouteCommandParts parts,
    required Color textColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rute dipilih',
          style: TextStyle(
            color: textColor,
            height: 1.35,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        for (final point in parts.points) ...[
          Text(
            point.label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            point.value,
            style: TextStyle(
              color: textColor,
              fontSize: 13.5,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (point != parts.points.last) const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildShoppingDraftContent({
    required _ShoppingDraftMessageParts parts,
    required Color textColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          parts.headline,
          style: TextStyle(
            color: textColor,
            height: 1.45,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        for (final stop in parts.stops) ...[
          _buildDraftField(
            label: stop.label,
            value: stop.merchant,
            textColor: textColor,
          ),
          const SizedBox(height: 8),
          Text(
            'Daftar belanja',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final item in stop.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.only(top: 9),
                        decoration: BoxDecoration(
                          color: textColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 13.5,
                            height: 1.45,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        _buildDraftField(
          label: 'Alamat antar',
          value: parts.deliveryAddress,
          textColor: textColor,
        ),
        if (parts.estimateLines.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildAssistantNotice(parts.estimateLines.join('\n')),
        ],
        if (parts.instructionLines.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildAssistantInstructionLines(
            parts.instructionLines,
            fontSize: 12.5,
            height: 1.45,
            fontWeight: FontWeight.w600,
          ),
        ],
      ],
    );
  }

  Widget _buildDraftField({
    required String label,
    required String value,
    required Color textColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            height: 1.45,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildAssistantInstructionText(
    String text, {
    required double fontSize,
    required double height,
    FontWeight? fontWeight,
  }) {
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    return _buildAssistantInstructionLines(
      lines,
      fontSize: fontSize,
      height: height,
      fontWeight: fontWeight,
    );
  }

  Widget _buildAssistantInstructionLines(
    List<String> lines, {
    required double fontSize,
    required double height,
    FontWeight? fontWeight,
  }) {
    if (lines.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < lines.length; index += 1) ...[
          _buildAssistantInstructionLine(
            lines[index],
            fontSize: fontSize,
            height: height,
            fontWeight: fontWeight,
          ),
          if (index < lines.length - 1) const SizedBox(height: 4),
        ],
      ],
    );
  }

  Widget _buildAssistantInstructionLine(
    String line, {
    required double fontSize,
    required double height,
    FontWeight? fontWeight,
  }) {
    final isPaymentMethodLine = line.toLowerCase().startsWith(
      'metode pembayaran:',
    );

    return Text(
      line,
      style: TextStyle(
        color: isPaymentMethodLine
            ? AppColors.textPrimary
            : AppColors.textSecondary,
        fontSize: isPaymentMethodLine ? 13.5 : fontSize,
        height: isPaymentMethodLine ? 1.35 : height,
        fontWeight: isPaymentMethodLine ? FontWeight.w800 : fontWeight,
      ),
    );
  }

  _ShoppingSuccessMessageParts? _tryParseShoppingSuccessMessage(String raw) {
    final normalized = raw.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty) {
      return null;
    }

    final lines = normalized
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (lines.isEmpty ||
        !lines.first.toLowerCase().startsWith('order nitip berhasil dibuat')) {
      return null;
    }

    var deliveryFeeLine = '';
    final instructionLines = <String>[];
    for (final line in lines.skip(1)) {
      if (line.toLowerCase().startsWith('estimasi ongkir sementara:')) {
        deliveryFeeLine = line;
      } else {
        instructionLines.add(line);
      }
    }

    return _ShoppingSuccessMessageParts(
      headline: lines.first,
      deliveryFeeLine: deliveryFeeLine,
      instructionLine: instructionLines.join(' ').trim(),
    );
  }

  _IncompleteShoppingDraftMessageParts? _tryParseIncompleteShoppingDraftMessage(
    String raw,
  ) {
    final normalized = raw.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty) {
      return null;
    }

    final lines = normalized
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (lines.length < 6) {
      return null;
    }

    final headline = lines.first;
    final lowerHeadline = headline.toLowerCase();
    if (!lowerHeadline.startsWith('draft nitip belum lengkap') ||
        !lowerHeadline.contains('items')) {
      return null;
    }

    final merchantLabelIndex = lines.indexWhere(
      (line) => line.toLowerCase() == 'tempat',
    );
    final exampleLabelIndex = lines.indexWhere(
      (line) => line.toLowerCase() == 'contoh:',
    );
    if (merchantLabelIndex < 0 ||
        exampleLabelIndex < 0 ||
        merchantLabelIndex + 1 >= exampleLabelIndex) {
      return null;
    }

    final instructionStartIndex = lines.indexWhere(
      (line) => line.toLowerCase().startsWith('tulis item'),
      merchantLabelIndex + 1,
    );
    if (instructionStartIndex < 0 ||
        instructionStartIndex >= exampleLabelIndex) {
      return null;
    }

    final merchantName = lines
        .sublist(merchantLabelIndex + 1, instructionStartIndex)
        .join(' ')
        .trim();
    if (merchantName.isEmpty) {
      return null;
    }

    final instructionLines = lines
        .sublist(instructionStartIndex, exampleLabelIndex)
        .where((line) => line.trim().isNotEmpty)
        .toList(growable: false);
    final examples = lines
        .skip(exampleLabelIndex + 1)
        .map((line) => line.replaceFirst(RegExp(r'^-\s*'), '').trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (instructionLines.isEmpty || examples.isEmpty) {
      return null;
    }

    return _IncompleteShoppingDraftMessageParts(
      headline: headline,
      merchantLabel: lines[merchantLabelIndex],
      merchantName: merchantName,
      instructionLines: instructionLines,
      examples: examples,
    );
  }

  _SimplePromptMessageParts? _tryParseCourierRouteSavedPrompt(String raw) {
    final normalized = raw.replaceAll('\r\n', '\n').trim();
    final compact = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
    const headline = 'Titik ambil dan tujuan sudah saya simpan.';
    if (!compact.toLowerCase().startsWith(headline.toLowerCase())) {
      return null;
    }

    return _SimplePromptMessageParts(
      headline: headline,
      instructionLine: normalized.substring(headline.length).trim(),
    );
  }

  _ResetDestinationMessageParts? _tryParseInlineCourierResetMessage(
    String raw,
  ) {
    final normalized = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) {
      return null;
    }

    final lower = normalized.toLowerCase();
    const pickupMarker = 'alamat ambil kamu di ';
    const instructionMarker = 'sekarang kirim tujuan baru';
    final pickupIndex = lower.indexOf(pickupMarker);
    final instructionIndex = lower.indexOf(instructionMarker);
    if (pickupIndex < 0 ||
        instructionIndex < 0 ||
        instructionIndex <= pickupIndex) {
      return null;
    }

    final headline = normalized.substring(0, pickupIndex).trim();
    if (!headline.toLowerCase().contains('tujuan sebelumnya') ||
        !headline.toLowerCase().contains('reset')) {
      return null;
    }

    final pickupAddress = normalized
        .substring(pickupIndex + pickupMarker.length, instructionIndex)
        .trim()
        .replaceFirst(RegExp(r'\.\s*$'), '');
    final instruction = normalized.substring(instructionIndex).trim();
    if (pickupAddress.isEmpty) {
      return null;
    }

    return _ResetDestinationMessageParts(
      headline: headline,
      pickupLabel: 'Ambil',
      pickupAddress: pickupAddress,
      instructionLine: instruction,
    );
  }

  _UserRouteCommandParts? _tryParseUserRouteCommand(String raw) {
    final normalized = raw.trim();
    if (!normalized.toLowerCase().startsWith('[map_route]')) {
      return null;
    }

    final body = normalized.replaceFirst(
      RegExp(r'^\[MAP_ROUTE\]\s*', caseSensitive: false),
      '',
    );
    final points = <_UserRouteCommandPoint>[];
    for (final segment in body.split(';')) {
      final arrowIndex = segment.indexOf('=>');
      if (arrowIndex < 0) {
        continue;
      }

      final rawTarget = segment.substring(0, arrowIndex).trim().toLowerCase();
      final value = segment.substring(arrowIndex + 2).trim();
      if (value.isEmpty) {
        continue;
      }

      final label = switch (rawTarget) {
        'pickup' => 'Ambil',
        'dropoff' => 'Tujuan',
        'destination' => 'Tujuan',
        _ => rawTarget.isEmpty ? 'Lokasi' : rawTarget,
      };
      points.add(_UserRouteCommandPoint(label: label, value: value));
    }

    if (points.isEmpty) {
      return null;
    }

    return _UserRouteCommandParts(points: points);
  }

  _ShoppingDraftMessageParts? _tryParseShoppingDraftMessage(String raw) {
    final normalized = raw.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty) {
      return null;
    }

    final lines = normalized
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    if (lines.length < 8) {
      return null;
    }

    final merchantIndexes = <int>[];
    for (var index = 0; index < lines.length; index += 1) {
      if (_isShoppingMerchantHeader(lines[index])) {
        merchantIndexes.add(index);
      }
    }
    final deliveryIndex = lines.indexWhere((line) {
      final lower = line.toLowerCase();
      return lower == 'alamat antar' || lower == 'alamat kirim';
    });
    final firstFeeIndex = lines.indexWhere(
      (line) => line.toLowerCase().startsWith('estimasi ongkir sementara:'),
    );

    if (merchantIndexes.isEmpty ||
        merchantIndexes.first <= 0 ||
        deliveryIndex < 0 ||
        firstFeeIndex <= deliveryIndex) {
      return null;
    }

    final headline = lines.take(merchantIndexes.first).join(' ').trim();
    final lowerHeadline = headline.toLowerCase();
    if (!lowerHeadline.contains('titip belanja') &&
        !lowerHeadline.contains('nitip')) {
      return null;
    }

    final firstItemHeaderAfterDelivery = lines.indexWhere(
      (line) => line.toLowerCase() == 'daftar belanja',
      deliveryIndex + 1,
    );
    final deliveryEndCandidates = <int>[
      firstFeeIndex,
      if (firstItemHeaderAfterDelivery > deliveryIndex)
        firstItemHeaderAfterDelivery,
      ...merchantIndexes.where((index) => index > deliveryIndex),
    ]..sort();
    final deliveryEndIndex = deliveryEndCandidates.first;
    final deliveryAddress = lines
        .sublist(deliveryIndex + 1, deliveryEndIndex)
        .join(' ')
        .trim();
    final stops = <_ShoppingDraftStopParts>[];
    for (var index = 0; index < merchantIndexes.length; index += 1) {
      final merchantIndex = merchantIndexes[index];
      final nextMerchantIndex = index + 1 < merchantIndexes.length
          ? merchantIndexes[index + 1]
          : lines.length;
      final segmentEndCandidates = <int>[
        nextMerchantIndex,
        if (deliveryIndex > merchantIndex) deliveryIndex,
        firstFeeIndex,
      ]..sort();
      final segmentEnd = segmentEndCandidates
          .where((candidate) => candidate > merchantIndex)
          .first;
      if (merchantIndex + 1 >= segmentEnd) {
        continue;
      }

      final itemHeaderIndex = lines.indexWhere(
        (line) => line.toLowerCase() == 'daftar belanja',
        merchantIndex + 1,
      );
      if (itemHeaderIndex < 0 || itemHeaderIndex >= segmentEnd) {
        continue;
      }

      final merchant = lines
          .sublist(merchantIndex + 1, itemHeaderIndex)
          .join(' ')
          .trim();
      final itemLines = lines.sublist(itemHeaderIndex + 1, segmentEnd);
      final items = _normalizeShoppingItemLines(itemLines);
      if (merchant.isEmpty || items.isEmpty) {
        continue;
      }

      stops.add(
        _ShoppingDraftStopParts(
          label: lines[merchantIndex],
          merchant: merchant,
          items: items,
        ),
      );
    }

    if (stops.isEmpty) {
      final oldItemsIndex = lines.indexWhere(
        (line) => line.toLowerCase() == 'daftar belanja',
      );
      if (deliveryIndex <= merchantIndexes.first ||
          oldItemsIndex <= deliveryIndex ||
          firstFeeIndex <= oldItemsIndex) {
        return null;
      }

      final merchant = lines
          .sublist(merchantIndexes.first + 1, deliveryIndex)
          .join(' ')
          .trim();
      final items = _normalizeShoppingItemLines(
        lines.sublist(oldItemsIndex + 1, firstFeeIndex),
      );
      if (merchant.isNotEmpty && items.isNotEmpty) {
        stops.add(
          _ShoppingDraftStopParts(
            label: lines[merchantIndexes.first],
            merchant: merchant,
            items: items,
          ),
        );
      }
    }

    final estimateLines = _normalizeShoppingEstimateLines(lines, firstFeeIndex);
    final instructionLines = _normalizeShoppingInstructionLines(
      lines,
      firstFeeIndex,
    );

    if (deliveryAddress.isEmpty || stops.isEmpty) {
      return null;
    }

    return _ShoppingDraftMessageParts(
      headline: headline,
      stops: stops,
      deliveryAddress: deliveryAddress,
      estimateLines: estimateLines,
      instructionLines: instructionLines,
    );
  }

  bool _isShoppingMerchantHeader(String line) {
    return RegExp(
      r'^(?:merchant|tempat)(?:\s+\d+)?$',
      caseSensitive: false,
    ).hasMatch(line.trim());
  }

  bool _isShoppingEstimateLine(String line) {
    final lower = line.toLowerCase();
    return lower.startsWith('estimasi ongkir sementara:') ||
        lower.startsWith('harga barang:') ||
        lower.startsWith('estimasi total sementara:');
  }

  List<String> _normalizeShoppingItemLines(List<String> lines) {
    final items = <String>[];
    final current = StringBuffer();
    final itemStartPattern = RegExp(r'^\d+\.\s*');

    void flush() {
      final value = current.toString().trim();
      if (value.isNotEmpty) {
        items.add(value);
      }
      current.clear();
    }

    for (final line in lines) {
      final cleaned = line.replaceFirst(itemStartPattern, '').trim();
      if (cleaned.isEmpty) {
        continue;
      }

      if (itemStartPattern.hasMatch(line)) {
        flush();
        current.write(cleaned);
      } else if (current.isNotEmpty) {
        current.write(' $cleaned');
      }
    }

    flush();
    return items;
  }

  List<String> _normalizeShoppingEstimateLines(
    List<String> lines,
    int startIndex,
  ) {
    final estimateLines = <String>[];
    var index = startIndex;

    while (index < lines.length) {
      final line = lines[index].trim();
      final isEstimateLine = _isShoppingEstimateLine(line);

      if (!isEstimateLine) {
        index += 1;
        continue;
      }

      if (line.toLowerCase().endsWith('rp') && index + 1 < lines.length) {
        estimateLines.add('$line ${lines[index + 1].trim()}');
        index += 2;
      } else {
        estimateLines.add(line);
        index += 1;
      }
    }

    return estimateLines;
  }

  List<String> _normalizeShoppingInstructionLines(
    List<String> lines,
    int startIndex,
  ) {
    final instructions = <String>[];
    var hasSeenFee = false;
    var skippingAddMerchantExample = false;

    for (final line in lines.skip(startIndex)) {
      if (_isShoppingEstimateLine(line)) {
        hasSeenFee = true;
        continue;
      }
      if (!hasSeenFee) {
        continue;
      }

      final lower = line.toLowerCase();
      final isAddMerchantPrompt =
          lower.contains('mau tambah tempat') ||
          lower.contains('mau tambah toko') ||
          lower.contains('mau tambah resto') ||
          lower.contains('tambah pesanan dari toko') ||
          lower.contains('tambah pesanan dari resto') ||
          lower.contains('contoh setelah tempat berikutnya') ||
          lower.contains('contoh isi pesan') ||
          lower.contains('contoh:');

      if (isAddMerchantPrompt) {
        skippingAddMerchantExample = true;
        continue;
      }

      if (skippingAddMerchantExample) {
        final looksLikeExampleItem = RegExp(r'^[-•]\s*').hasMatch(line);
        if (looksLikeExampleItem) {
          continue;
        }
        skippingAddMerchantExample = false;
      }

      instructions.add(line);
    }

    return instructions;
  }

  _DraftMessageParts? _tryParseDraftMessage(String raw) {
    final normalized = raw.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty) {
      return null;
    }

    final lines = normalized
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    if (lines.length < 4) {
      return null;
    }

    final pickupIndex = lines.indexWhere(
      (line) =>
          line.toLowerCase().startsWith('jemput:') ||
          line.toLowerCase().startsWith('ambil:'),
    );
    final destinationIndex = lines.indexWhere(
      (line) => line.toLowerCase().startsWith('tujuan:'),
    );
    final packageIndex = lines.indexWhere(
      (line) => line.toLowerCase().startsWith('barang:'),
    );
    final feeIndex = lines.indexWhere((line) {
      final lower = line.toLowerCase();
      return lower.startsWith('estimasi ongkir sementara:') ||
          lower.startsWith('ongkir:');
    });

    if (pickupIndex < 0 || destinationIndex < 0 || feeIndex < 0) {
      return null;
    }

    final introText = lines.take(pickupIndex).join('\n').trim();
    if (introText.isEmpty ||
        (!introText.toLowerCase().contains('antar jemput') &&
            !introText.toLowerCase().contains('kurir'))) {
      return null;
    }

    final pickupAddress = lines[pickupIndex].replaceFirst(
      RegExp(r'^(Jemput|Ambil):\s*', caseSensitive: false),
      '',
    );
    final destinationAddress = lines[destinationIndex].replaceFirst(
      RegExp(r'^Tujuan:\s*', caseSensitive: false),
      '',
    );

    final packageDescription = packageIndex >= 0
        ? lines[packageIndex].replaceFirst(
            RegExp(r'^Barang:\s*', caseSensitive: false),
            '',
          )
        : null;
    if (pickupAddress.isEmpty || destinationAddress.isEmpty) {
      return null;
    }

    final instructionLine = feeIndex + 1 < lines.length
        ? lines.skip(feeIndex + 1).join(' ').trim()
        : '';

    return _DraftMessageParts(
      headline: introText,
      pickupLabel: lines[pickupIndex].toLowerCase().startsWith('ambil:')
          ? 'Ambil'
          : 'Jemput',
      pickupAddress: pickupAddress,
      destinationAddress: destinationAddress,
      packageDescription: packageDescription,
      feeLine: lines[feeIndex],
      instructionLine: instructionLine,
    );
  }

  _ResetDestinationMessageParts? _tryParseResetDestinationMessage(String raw) {
    final normalized = raw.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty) {
      return null;
    }

    final lines = normalized
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (lines.length < 3) {
      return null;
    }

    final pickupIndex = lines.indexWhere(
      (line) =>
          line.toLowerCase().startsWith('jemput:') ||
          line.toLowerCase().startsWith('ambil:'),
    );
    if (pickupIndex < 0) {
      return null;
    }

    final headline = lines.take(pickupIndex).join('\n').trim();
    if (headline.isEmpty || !headline.toLowerCase().contains('tujuan')) {
      return null;
    }

    final pickupLabel = lines[pickupIndex].toLowerCase().startsWith('ambil:')
        ? 'Ambil'
        : 'Jemput';
    final pickupFirstLine = lines[pickupIndex].replaceFirst(
      RegExp(r'^(Jemput|Ambil):\s*', caseSensitive: false),
      '',
    );

    int instructionStartIndex = lines.length;
    for (int i = pickupIndex + 1; i < lines.length; i++) {
      final lower = lines[i].toLowerCase();
      if (lower.startsWith('silakan klik tombol') ||
          lower.startsWith('setelah itu,')) {
        instructionStartIndex = i;
        break;
      }
    }

    final pickupLines = <String>[
      if (pickupFirstLine.isNotEmpty) pickupFirstLine,
      ...lines.sublist(pickupIndex + 1, instructionStartIndex),
    ].where((line) => line.trim().isNotEmpty).toList(growable: false);
    if (pickupLines.isEmpty) {
      return null;
    }

    final instructionLine = instructionStartIndex < lines.length
        ? lines.sublist(instructionStartIndex).join(' ').trim()
        : '';

    return _ResetDestinationMessageParts(
      headline: headline,
      pickupLabel: pickupLabel,
      pickupAddress: pickupLines.join('\n'),
      instructionLine: instructionLine,
    );
  }

  bool _hasSavedAddressInProfile() {
    final authState = ref.read(authSessionProvider);
    final addresses = authState.profile?.addresses ?? const [];

    return hasUsableSavedAddress(addresses);
  }

  bool _isCustomerOrderingBlocked() {
    return _customerOrderingBlockMessage() != null;
  }

  String? _customerOrderingBlockMessage() {
    final session = ref.read(authSessionProvider);
    if (session.role != SessionUserRole.driver) {
      return null;
    }

    switch (session.driverAccessState) {
      case DriverAccessState.pending:
      case DriverAccessState.rejected:
      case DriverAccessState.suspended:
      case DriverAccessState.unknown:
        return 'Pengajuan driver Anda masih berlangsung. Selesaikan verifikasi atau batalkan pengajuan terlebih dahulu untuk kembali membuat pesanan sebagai customer.';
      case DriverAccessState.active:
        return 'Akun Anda sedang aktif sebagai driver. Gunakan akun customer untuk membuat pesanan.';
      case DriverAccessState.none:
        return null;
    }
  }

  List<ChatbotMessageActionHint> _customerOrderingBlockActionHints() {
    final session = ref.read(authSessionProvider);
    if (session.role != SessionUserRole.driver ||
        session.driverAccessState == DriverAccessState.active) {
      return const <ChatbotMessageActionHint>[];
    }

    return const <ChatbotMessageActionHint>[
      ChatbotMessageActionHint(
        type: ChatbotMessageActionType.openDriverVerificationStatus,
        label: 'Lihat Status Verifikasi',
      ),
    ];
  }

  void _maybeResolveDriverVerificationGuard([AuthSessionState? session]) {
    final AuthSessionState effectiveSession =
        session ?? ref.read(authSessionProvider);
    if (effectiveSession.role == SessionUserRole.driver &&
        effectiveSession.driverAccessState != DriverAccessState.none) {
      return;
    }

    var resolvedCurrentService = false;
    for (final serviceType in _chatbotOrderingServiceTypes) {
      final didResolve = _conversationNotifier(serviceType)
          .resolveDriverVerificationGuard(
            serviceType: serviceType,
            assistantMessage:
                'Pengajuan driver Anda sudah dibatalkan. Sekarang Anda bisa kembali membuat pesanan sebagai customer.',
          );
      if (didResolve && serviceType == _serviceContext.serviceType) {
        resolvedCurrentService = true;
      }
    }

    if (resolvedCurrentService) {
      _scrollToBottom();
    }
  }

  Future<void> _handleActionHint(ChatbotMessageActionHint actionHint) async {
    switch (actionHint.type) {
      case ChatbotMessageActionType.openAddresses:
        if (_handleBlockedOrderingAction(actionHint)) {
          return;
        }
        await _handleOpenAddressesAction();
        return;
      case ChatbotMessageActionType.openMapPicker:
        if (_handleBlockedOrderingAction(actionHint)) {
          return;
        }
        await _handleOpenMapPickerAction(actionHint);
        return;
      case ChatbotMessageActionType.openMerchantPicker:
        if (_handleBlockedOrderingAction(actionHint)) {
          return;
        }
        await _handleOpenMerchantPickerAction(actionHint);
        return;
      case ChatbotMessageActionType.openRoutePicker:
        if (_handleBlockedOrderingAction(actionHint)) {
          return;
        }
        await _handleOpenRoutePickerAction(actionHint);
        return;
      case ChatbotMessageActionType.sendPresetMessage:
        await _handleSendPresetMessageAction(actionHint);
        return;
      case ChatbotMessageActionType.openTrackOrder:
        await _handleOpenTrackOrderAction(actionHint);
        return;
      case ChatbotMessageActionType.openActivity:
        await _handleOpenActivityAction();
        return;
      case ChatbotMessageActionType.openDriverVerificationStatus:
        await _handleOpenDriverVerificationStatusAction();
        return;
    }
  }

  bool _handleBlockedOrderingAction(ChatbotMessageActionHint actionHint) {
    final orderingBlockMessage = _customerOrderingBlockMessage();
    if (orderingBlockMessage == null) {
      return false;
    }

    _inputController.clear();
    _clearMenuSelector();
    _conversationNotifier().addLocalGuardResponse(
      rawMessage: _displayLabelForActionHint(actionHint),
      serviceType: _serviceContext.serviceType,
      assistantMessage: orderingBlockMessage,
      actionHints: _customerOrderingBlockActionHints(),
    );
    _scrollToBottom();

    return true;
  }

  Future<void> _handleOpenDriverVerificationStatusAction() async {
    await context.push(AppRoutes.driverVerificationStatus);
    if (!mounted) {
      return;
    }

    await ref.read(authSessionProvider.notifier).refreshSession();
    _maybeResolveDriverVerificationGuard();
  }

  Future<void> _handleSendPresetMessageAction(
    ChatbotMessageActionHint actionHint,
  ) async {
    final presetMessage = (actionHint.presetMessage ?? actionHint.label).trim();
    if (presetMessage.isEmpty) {
      return;
    }

    await _sendMessage(presetMessage);
  }

  Future<void> _handleOpenAddressesAction() async {
    _isAddressBookRouteOpen = true;
    try {
      await context.push(AppRoutes.addressesForOrder());
      if (!mounted) {
        return;
      }

      await _refreshAddressContextIfNeeded();

      _conversationNotifier().syncSavedAddressReadiness(
        serviceType: _serviceContext.serviceType,
        readyWelcomeMessage: null,
      );

      await _maybeApplyLaunchArgs();

      _scrollToBottom();
    } finally {
      _isAddressBookRouteOpen = false;
    }
  }

  Future<void> _handleOpenMapPickerAction(
    ChatbotMessageActionHint actionHint,
  ) async {
    if ((_serviceContext.serviceType == 'antar_jemput' ||
            _serviceContext.serviceType == 'kurir' ||
            _serviceContext.serviceType == 'nitip') &&
        !_hasSavedAddressInProfile()) {
      await _handleOpenAddressesAction();
      return;
    }

    final pickerExtra = <String, dynamic>{
      ...?(actionHint.initialLatitude == null
          ? null
          : <String, dynamic>{'latitude': actionHint.initialLatitude}),
      ...?(actionHint.initialLongitude == null
          ? null
          : <String, dynamic>{'longitude': actionHint.initialLongitude}),
    };

    final result = await context.push(
      AppRoutes.addressLocationPicker,
      extra: pickerExtra,
    );

    if (!mounted || result is! AddressLocationPickerResult) {
      return;
    }

    final target = (actionHint.target ?? '').trim();
    if (target.isEmpty) {
      return;
    }

    await _conversationNotifier().applyMapPinAction(
      serviceType: _serviceContext.serviceType,
      target: target,
      latitude: result.latitude,
      longitude: result.longitude,
      address: result.address,
    );
  }

  Future<void> _handleOpenMerchantPickerAction(
    ChatbotMessageActionHint actionHint,
  ) async {
    if (_serviceContext.serviceType != 'nitip') {
      return;
    }

    final openMapsDirectly = _isMerchantMapPickerActionHint(actionHint);
    final result = await context.push<ShoppingMerchantPickerResult>(
      openMapsDirectly
          ? AppRoutes.chatbotShoppingMerchantMapPickerPath()
          : AppRoutes.chatbotShoppingMerchantPickerPath(),
      extra: ShoppingMerchantMapPickerArgs(
        initialLatitude: actionHint.initialLatitude,
        initialLongitude: actionHint.initialLongitude,
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    _clearMenuSelector();

    final appliedMode =
        actionHint.merchantMode == 'add' ||
            actionHint.merchantMode == 'maps_add'
        ? 'add'
        : 'select';
    final applied = await _conversationNotifier().applyMerchantPickerAction(
      serviceType: _serviceContext.serviceType,
      merchantId: result.merchantId,
      merchantPlace: result.isOfficial ? null : result.place,
      mode: appliedMode,
      appendAssistantMessage: !result.isOfficial,
    );

    if (!mounted || !applied) {
      return;
    }

    if (result.isOfficial) {
      await _loadOfficialMerchantMenus(
        merchantId: result.merchantId!,
        merchantName: result.place.name,
        merchantMode: appliedMode,
      );
      return;
    }
  }

  Future<void> _loadOfficialMerchantMenus({
    required int merchantId,
    required String merchantName,
    required String merchantMode,
  }) async {
    final requestId = ++_menuSelectorRequestId;
    _conversationNotifier().clearMenuSelectorSurface(
      serviceType: _serviceContext.serviceType,
    );
    setState(() {
      _isLoadingMenuSelector = true;
    });
    _scrollToMenuSelectorSurface();

    try {
      final menus = await ref
          .read(customerOrderRepositoryProvider)
          .searchMerchantMenus(merchantId, '');
      if (!mounted || requestId != _menuSelectorRequestId) {
        return;
      }

      final suggestions = menus
          .where((menu) => menu.name.trim().isNotEmpty)
          .map(
            (menu) => ChatbotMenuSuggestion(
              name: menu.name.trim(),
              presetMessage: '${menu.name.trim()} 1',
              priceLabel: formatMenuPriceOrPending(menu.price),
              imageUrl: menu.imageUrl,
            ),
          )
          .toList(growable: false);

      if (suggestions.isEmpty) {
        _showMenuSelectorNotice(
          'Menu resmi tempat ini belum tersedia. Kamu tetap bisa tulis item manual.',
        );
      } else {
        _showMenuSelector(
          merchantName: merchantName,
          menus: suggestions,
          merchantMode: merchantMode,
        );
      }
    } catch (_) {
      if (!mounted || requestId != _menuSelectorRequestId) {
        return;
      }
      _showMenuSelectorNotice(
        'Menu belum bisa dimuat. Kamu tetap bisa tulis item manual.',
      );
    }

    _scrollToMenuSelectorSurface();
  }

  Future<void> _handleOpenRoutePickerAction(
    ChatbotMessageActionHint actionHint,
  ) async {
    if (!_hasSavedAddressInProfile()) {
      await _handleOpenAddressesAction();
      return;
    }

    final serviceType = _serviceContext.serviceType;
    if (serviceType != 'antar_jemput' && serviceType != 'kurir') {
      return;
    }

    final defaultPickup = _defaultSavedAddress();
    if (defaultPickup == null || !_hasValidCoordinate(defaultPickup)) {
      await _handleOpenAddressesAction();
      return;
    }

    ChatbotRoutePointHint? pointFor(String target) {
      for (final point in actionHint.routePoints) {
        if (point.target == target) {
          return point;
        }
      }
      return null;
    }

    final pickupPoint = pointFor('pickup');
    final destinationTarget = serviceType == 'kurir'
        ? 'dropoff'
        : 'destination';
    final destinationPoint = pointFor(destinationTarget);
    final isCourier = serviceType == 'kurir';

    final result = await context.push(
      AppRoutes.routeLocationPicker,
      extra: RouteLocationPickerArgs(
        serviceType: serviceType,
        pickupTarget: 'pickup',
        destinationTarget: destinationTarget,
        pickupLabel: isCourier ? 'Ambil' : 'Jemput',
        destinationLabel: 'Tujuan',
        title: isCourier ? 'Atur Rute Kurir' : 'Atur Rute Antar Jemput',
        confirmLabel: isCourier ? 'Simpan Rute Kurir' : 'Simpan Rute',
        defaultPickupAddress: defaultPickup.fullAddress,
        defaultPickupLatitude: defaultPickup.latitude,
        defaultPickupLongitude: defaultPickup.longitude,
        pickupInitialLatitude: pickupPoint?.initialLatitude,
        pickupInitialLongitude: pickupPoint?.initialLongitude,
        pickupInitialAddress: pickupPoint?.address,
        destinationInitialLatitude: destinationPoint?.initialLatitude,
        destinationInitialLongitude: destinationPoint?.initialLongitude,
        destinationInitialAddress: destinationPoint?.address,
      ),
    );

    if (!mounted || result is! RouteLocationPickerResult) {
      return;
    }

    final locations = result.locations
        .map(
          (location) => ChatbotLocationPatch(
            target: location.target,
            latitude: location.latitude,
            longitude: location.longitude,
            address: (location.address ?? '').trim().isEmpty
                ? null
                : location.address!.trim(),
          ),
        )
        .toList(growable: false);

    await _conversationNotifier(
      serviceType,
    ).applyRoutePickerAction(serviceType: serviceType, locations: locations);
  }

  Future<void> _handleOpenTrackOrderAction(
    ChatbotMessageActionHint actionHint,
  ) async {
    final orderId = actionHint.orderId;
    final routeFuture = orderId != null && orderId > 0
        ? context.push(AppRoutes.track, extra: orderId)
        : context.push(AppRoutes.track);

    await routeFuture;
  }

  Future<void> _handleOpenActivityAction() async {
    context.go(AppRoutes.activity);
  }

  SavedAddressModel? _defaultSavedAddress() {
    final addresses =
        ref.read(authSessionProvider).profile?.addresses ??
        const <SavedAddressModel>[];
    return defaultUsableSavedAddress(addresses);
  }

  bool _hasValidCoordinate(SavedAddressModel address) {
    return isUsableSavedAddress(address);
  }
}

class _DraftMessageParts {
  const _DraftMessageParts({
    required this.headline,
    required this.pickupLabel,
    required this.pickupAddress,
    required this.destinationAddress,
    this.packageDescription,
    required this.feeLine,
    required this.instructionLine,
  });

  final String headline;
  final String pickupLabel;
  final String pickupAddress;
  final String destinationAddress;
  final String? packageDescription;
  final String feeLine;
  final String instructionLine;
}

class _ShoppingDraftMessageParts {
  const _ShoppingDraftMessageParts({
    required this.headline,
    required this.stops,
    required this.deliveryAddress,
    required this.estimateLines,
    required this.instructionLines,
  });

  final String headline;
  final List<_ShoppingDraftStopParts> stops;
  final String deliveryAddress;
  final List<String> estimateLines;
  final List<String> instructionLines;
}

class _ShoppingDraftStopParts {
  const _ShoppingDraftStopParts({
    required this.label,
    required this.merchant,
    required this.items,
  });

  final String label;
  final String merchant;
  final List<String> items;
}

class _ResetDestinationMessageParts {
  const _ResetDestinationMessageParts({
    required this.headline,
    required this.pickupLabel,
    required this.pickupAddress,
    required this.instructionLine,
  });

  final String headline;
  final String pickupLabel;
  final String pickupAddress;
  final String instructionLine;
}

class _ShoppingSuccessMessageParts {
  const _ShoppingSuccessMessageParts({
    required this.headline,
    required this.deliveryFeeLine,
    required this.instructionLine,
  });

  final String headline;
  final String deliveryFeeLine;
  final String instructionLine;
}

class _IncompleteShoppingDraftMessageParts {
  const _IncompleteShoppingDraftMessageParts({
    required this.headline,
    required this.merchantLabel,
    required this.merchantName,
    required this.instructionLines,
    required this.examples,
  });

  final String headline;
  final String merchantLabel;
  final String merchantName;
  final List<String> instructionLines;
  final List<String> examples;
}

class _SimplePromptMessageParts {
  const _SimplePromptMessageParts({
    required this.headline,
    required this.instructionLine,
  });

  final String headline;
  final String instructionLine;
}

class _UserRouteCommandParts {
  const _UserRouteCommandParts({required this.points});

  final List<_UserRouteCommandPoint> points;
}

class _UserRouteCommandPoint {
  const _UserRouteCommandPoint({required this.label, required this.value});

  final String label;
  final String value;
}

class _AssistantNoticeRow {
  const _AssistantNoticeRow({
    required this.label,
    required this.amount,
    required this.note,
  });

  final String label;
  final String amount;
  final String note;
}

class _ServiceContext {
  final String serviceType;
  final String title;
  final String iconAsset;
  final String welcomeMessage;
  final String addressRequiredMessage;
  final List<String> suggestions;

  const _ServiceContext({
    required this.serviceType,
    required this.title,
    required this.iconAsset,
    required this.welcomeMessage,
    required this.addressRequiredMessage,
    required this.suggestions,
  });

  String welcomeMessageFor(bool hasSavedAddress) {
    return hasSavedAddress ? welcomeMessage : addressRequiredMessage;
  }
}
