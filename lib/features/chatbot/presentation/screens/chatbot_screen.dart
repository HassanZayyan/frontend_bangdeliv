import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_routes.dart';
import '../../../../config/app_text_scaling.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../core/widgets/bang_confirmation_dialog.dart';
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
import '../models/chatbot_screen_models.dart';
import '../utils/chatbot_action_hint_utils.dart';
import '../utils/chatbot_message_text.dart';
import '../widgets/chatbot_message_content.dart';
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
  late final FocusNode _inputFocusNode;
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
    _inputFocusNode = FocusNode();
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
    _inputFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  ChatbotServiceContext get _serviceContext {
    final rawServiceType =
        widget.launchArgs?.serviceType ??
        GoRouterState.of(context).uri.queryParameters['service_type'] ??
        'nitip';

    switch (rawServiceType) {
      case 'antar_jemput':
        return const ChatbotServiceContext(
          serviceType: 'antar_jemput',
          title: 'BangBot AI - Antar Jemput',
          iconAsset: 'assets/images/services/service_ride_motor_simplified.png',
          welcomeMessage:
              'Halo! Saya BangBot untuk layanan Antar Jemput. Kamu bisa menulis titik jemput dan tujuan lewat chat atau mengaturnya lewat tombol di bawah.\n\nJika menulis lokasi secara manual lewat chat, pastikan lokasi jemput dan tujuan dapat ditemukan di Google Maps agar titiknya dapat diproses dengan tepat.\n\nContoh:\nAntar ke Ramayana Salatiga\nJemput saya di Kopi Kenangan Tembalang, antar ke Alun-Alun Semarang\n\nUntuk mengatur lokasi lewat peta, ketuk tombol aksi di bawah ini.',
          addressRequiredMessage:
              'Halo! Saya BangBot untuk layanan Antar Jemput. Sebelum membuat pesanan, ketuk tombol Isi Alamat Saya di bawah untuk menyimpan alamat jemput utama. Pastikan alamat tersebut dapat ditemukan di Google Maps agar titiknya dapat diproses dengan tepat.',
          suggestions: [
            ChatbotQuickTemplate('Antar saya ke [tujuan]'),
            ChatbotQuickTemplate('Jemput saya di [lokasi], antar ke [tujuan]'),
          ],
        );
      case 'kurir':
        return const ChatbotServiceContext(
          serviceType: 'kurir',
          title: 'BangBot AI - Kurir',
          iconAsset:
              'assets/images/services/service_courier_box_simplified.png',
          welcomeMessage:
              'Halo! Saya BangBot untuk layanan Kurir. Kamu bisa menulis detail pengiriman lewat chat dengan format berikut atau mengatur titik ambil dan tujuan lewat tombol di bawah.\n\nJika menulis lokasi secara manual lewat chat, pastikan lokasi ambil dan tujuan dapat ditemukan di Google Maps agar titiknya dapat diproses dengan tepat.\n\nContoh:\nAmbil: Laundry Berkah Salatiga\nTujuan: Universitas Kristen Satya Wacana\nBarang: 1 tas laundry\n\nUntuk mengatur rute lewat peta, ketuk tombol aksi di bawah ini.',
          addressRequiredMessage:
              'Halo! Saya BangBot untuk layanan Kurir. Sebelum membuat pesanan, ketuk tombol Isi Alamat Saya di bawah untuk menyimpan alamat ambil utama. Pastikan alamat tersebut dapat ditemukan di Google Maps agar titiknya dapat diproses dengan tepat.',
          suggestions: [
            ChatbotQuickTemplate('Anter [barang] ke [tujuan]'),
            ChatbotQuickTemplate('Kirim [barang] dari [lokasi] ke [tujuan]'),
            ChatbotQuickTemplate(
              'Ambil: [lokasi ambil]\nTujuan: [lokasi tujuan]\nBarang: [nama barang]',
              chipLabel: 'Ambil / Tujuan / Barang',
            ),
          ],
        );
      default:
        return const ChatbotServiceContext(
          serviceType: 'nitip',
          title: 'BangBot AI - Nitip',
          iconAsset:
              'assets/images/services/service_shopping_basket_simplified.png',
          welcomeMessage:
              'Halo! Saya BangBot untuk layanan Nitip. Kamu bisa menulis nama toko/resto dan barang yang ingin dibeli lewat chat atau memilih toko/resto dan alamat antar melalui tombol di bawah.\n\nJika menulis nama toko/resto secara manual lewat chat, pastikan toko/resto tersebut **sudah terdaftar di BangDeliv**. Jika belum terdaftar, ketuk tombol **Pilih Toko/Resto** lalu ketuk **Cari lewat Maps** untuk memilih lokasi toko/resto agar driver mendapatkan titik yang tepat.\n\nContoh:\nBeli di Nasgor Gajah:\n- Nasi Goreng 1\n- Es Teh 1\n\nKamu bisa menambahkan maksimal 3 toko/resto dalam satu pesanan.\n\nUntuk memilih toko/resto dan alamat antar, ketuk tombol aksi di bawah ini.',
          addressRequiredMessage:
              'Halo! Saya BangBot untuk layanan Nitip. Sebelum membuat pesanan, ketuk tombol Isi Alamat Saya di bawah untuk menyimpan alamat antar agar ongkir dapat dihitung. Pastikan alamat tersebut dapat ditemukan di Google Maps agar titiknya dapat diproses dengan tepat.',
          suggestions: [
            ChatbotQuickTemplate(
              'Beli di [nama resto]:\n- [menu] [jumlah]\n- [menu] [jumlah]',
              chipLabel: 'Beli di resto + menu',
            ),
            ChatbotQuickTemplate('Lihat menu [resto]'),
            ChatbotQuickTemplate('Rekomendasi makanan dong'),
          ],
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

  Future<bool> _sendMessage([
    String? presetText,
    bool preserveMenuSelectorOnFailure = false,
  ]) async {
    final raw = (presetText ?? _inputController.text).trim();
    if (raw.isEmpty) {
      return false;
    }

    if (ChatbotCommandParser.isRestartCommand(raw)) {
      _inputController.clear();
      _clearMenuSelector();
      await _handleRestartConversation();
      return true;
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
      return true;
    }

    if (!_hasSavedAddressInProfile()) {
      await _handleOpenAddressesAction();
      return false;
    }

    _inputController.clear();
    if (!preserveMenuSelectorOnFailure) {
      _clearMenuSelector();
    }

    return await _conversationNotifier().sendMessage(
      raw,
      serviceType: _serviceContext.serviceType,
      clearMenuSelectorOnStart: !preserveMenuSelectorOnFailure,
    );
  }

  Future<void> _handleRefreshConversation() async {
    final confirmed = await showBangConfirmationDialog(
      context,
      title: 'Refresh chat?',
      message:
          'Percakapan dan draft pesanan saat ini akan dihapus. Kamu yakin ingin memulai chat dari awal?',
      confirmLabel: 'Refresh Chat',
      isDestructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }

    await _handleRestartConversation();
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

  Future<void> _handleMenuSelectorConfirm(
    ChatbotMenuSelectorDraft selector,
  ) async {
    final message = selector.confirmationMessage();
    if (message.isEmpty) {
      return;
    }

    await _sendMessage(message, true);
  }

  Future<void> _handleWriteManualItem(ChatbotMenuSelectorDraft selector) async {
    final selectedCount = selector.selectedCount;
    if (selectedCount > 0) {
      final confirmed = await showBangConfirmationDialog(
        context,
        title: 'Tulis item manual?',
        message:
            'Pilihan $selectedCount item dari menu akan dikosongkan sebelum kamu menulis item manual.',
        confirmLabel: 'Tulis manual',
      );
      if (!confirmed || !mounted) {
        return;
      }
    }

    _clearMenuSelector();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _inputFocusNode.requestFocus();
      }
    });
  }

  Future<void> _handleChangeMenuSelectorMerchant(
    ChatbotMenuSelectorDraft selector,
  ) async {
    // "Ganti Toko/Resto" selalu MENGGANTI stop yang diwakili menu selector ini,
    // bukan menambah stop baru. Saat stop_id diketahui, sasar stop itu spesifik
    // (mode 'replace'); jika tidak (draft lama/single-merchant), fallback aman
    // ke 'select' yang mengganti stop aktif.
    final targetStopId = (selector.targetStopId ?? '').trim();
    final useReplace = targetStopId.isNotEmpty;
    await _handleOpenMerchantPickerAction(
      ChatbotMessageActionHint(
        type: ChatbotMessageActionType.openMerchantPicker,
        label: 'Ganti Toko/Resto',
        merchantMode: useReplace ? 'replace' : 'select',
        replaceTargetStopId: useReplace ? targetStopId : null,
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

      final menuRequest = next.pendingMenuSelectorRequest;
      if (menuRequest != null &&
          !identical(menuRequest, previous?.pendingMenuSelectorRequest)) {
        _conversationNotifier().consumeMenuSelectorRequest();
        unawaited(
          _loadOfficialMerchantMenus(
            merchantId: menuRequest.merchantId,
            merchantName: menuRequest.merchantName,
            merchantMode: menuRequest.mode == 'add' ? 'add' : 'select',
          ),
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
          IconButton(
            tooltip: 'Refresh chat',
            onPressed: effectiveBusy ? null : _handleRefreshConversation,
            icon: const Icon(Icons.refresh_rounded),
            color: AppColors.textPrimary,
            disabledColor: AppColors.textSecondary,
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
          if (state.menuSelectorDraft != null)
            ChatbotMenuSelectionActionBar(
              selectedCount: state.menuSelectorDraft!.selectedCount,
              isSending: state.isSending,
              onWriteManual: () =>
                  _handleWriteManualItem(state.menuSelectorDraft!),
              onConfirm: () =>
                  _handleMenuSelectorConfirm(state.menuSelectorDraft!),
            )
          else if (_isLoadingMenuSelector)
            const ChatbotMenuSelectionLoadingBar()
          else
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
                            focusNode: _inputFocusNode,
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

  void _applyTemplateToInput(ChatbotQuickTemplate template) {
    final match = ChatbotQuickTemplate.placeholderPattern.firstMatch(template.label);
    _inputController.value = TextEditingValue(
      text: template.label,
      selection: match == null
          ? TextSelection.collapsed(offset: template.label.length)
          : TextSelection(baseOffset: match.start, extentOffset: match.end),
    );
    _inputFocusNode.requestFocus();
  }

  Widget _buildSuggestionChip(ChatbotQuickTemplate template, {required bool enabled}) {
    final label = template.label;
    return AppTextScaling.clampForCompactComponent(
      context: context,
      maxScaleFactor: AppTextScaling.compactComponentMaxScaleFactor,
      child: InkWell(
        borderRadius: BorderRadius.circular(_chatbotButtonRadius),
        onTap: !enabled
            ? null
            : template.sendsImmediately
                ? () => _sendMessage(label)
                : () => _applyTemplateToInput(template),
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
            template.chipLabel ?? label,
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
      );
    }

    if (_isLoadingMenuSelector) {
      return ChatbotMenuSelectorInfoBubble(
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
      return ChatbotMenuSelectorInfoBubble(
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
      final routeCommandParts = tryParseUserRouteCommand(message.text);
      if (routeCommandParts != null) {
        return buildChatbotUserRouteCommandContent(
          parts: routeCommandParts,
          textColor: textColor,
        );
      }

      return Text(
        message.text,
        style: TextStyle(color: textColor, height: 1.5),
      );
    }

    final parts = tryParseDraftMessage(message.text);
    if (parts == null) {
      final shoppingParts = tryParseShoppingDraftMessage(message.text);
      if (shoppingParts != null) {
        return _buildShoppingDraftContent(
          parts: shoppingParts,
          textColor: textColor,
        );
      }

      final incompleteShoppingParts = tryParseIncompleteShoppingDraftMessage(
        message.text,
      );
      if (incompleteShoppingParts != null) {
        return _buildIncompleteShoppingDraftContent(
          parts: incompleteShoppingParts,
          textColor: textColor,
        );
      }

      final resetParts = tryParseResetDestinationMessage(message.text);
      if (resetParts != null) {
        return _buildResetDestinationContent(
          parts: resetParts,
          textColor: textColor,
        );
      }

      final inlineResetParts = tryParseInlineCourierResetMessage(message.text);
      if (inlineResetParts != null) {
        return _buildResetDestinationContent(
          parts: inlineResetParts,
          textColor: textColor,
        );
      }

      final shoppingSuccessParts = tryParseShoppingSuccessMessage(
        message.text,
      );
      if (shoppingSuccessParts != null) {
        return _buildShoppingSuccessContent(
          parts: shoppingSuccessParts,
          textColor: textColor,
        );
      }

      final promptParts = tryParseCourierRouteSavedPrompt(message.text);
      if (promptParts != null) {
        return buildChatbotSimplePromptContent(
          parts: promptParts,
          textColor: textColor,
        );
      }

      return buildChatbotInlineText(message.text, color: textColor);
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
        buildChatbotDraftField(
          label: parts.pickupLabel,
          value: parts.pickupAddress,
          textColor: textColor,
        ),
        const SizedBox(height: 8),
        buildChatbotDraftField(
          label: 'Tujuan',
          value: parts.destinationAddress,
          textColor: textColor,
        ),
        if (parts.packageDescription != null &&
            parts.packageDescription!.isNotEmpty) ...[
          const SizedBox(height: 8),
          buildChatbotDraftField(
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
            !hasPaymentActionHints(message.actionHints)) ...[
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
        .where(isPaymentActionHint)
        .toList(growable: false);
    final destinationResetActions = actionHints
        .where(isDestinationResetActionHint)
        .toList(growable: false);
    final routeEditActions = actionHints
        .where(
          (actionHint) =>
              isRouteEditActionHint(actionHint) &&
              !isDestinationResetActionHint(actionHint),
        )
        .toList(growable: false);
    final locationSetupActions = actionHints
        .where(
          (actionHint) =>
              isLocationSetupActionHint(actionHint) &&
              !isDestinationResetActionHint(actionHint) &&
              !isRouteEditActionHint(actionHint) &&
              !isAddMerchantActionHint(actionHint),
        )
        .toList(growable: false);
    final confirmationActions = actionHints
        .where(isConfirmationActionHint)
        .toList(growable: false);
    final addMerchantActions = actionHints
        .where(isAddMerchantActionHint)
        .toList(growable: false);
    final otherActions = actionHints
        .where(
          (actionHint) =>
              !isPaymentActionHint(actionHint) &&
              !isDestinationResetActionHint(actionHint) &&
              !isRouteEditActionHint(actionHint) &&
              !isLocationSetupActionHint(actionHint) &&
              !isConfirmationActionHint(actionHint) &&
              !isAddMerchantActionHint(actionHint),
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
              ),
          ],
        ),
        _buildActionHintGroup(
          title: _locationSetupActionTitle(),
          actions: locationSetupActions,
          actionsEnabled: actionsEnabled,
          isUser: isUser,
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
                ),
            ],
          ),
        ],
        _buildActionHintGroup(
          title: 'Selesaikan pesanan',
          actions: confirmationActions,
          actionsEnabled: actionsEnabled,
          isUser: isUser,
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
        ? 'Ketuk tombol untuk atur pesanan'
        : 'Ketuk tombol untuk atur lokasi';
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
              ),
          ],
        ),
      ],
    );
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
  }) {
    final usesSuccessTone =
        isConfirmationActionHint(actionHint) ||
        isPaymentActionHint(actionHint);
    final semanticColor = usesSuccessTone
        ? AppColors.success
        : AppColors.primary;

    return FilledButton.icon(
      onPressed: actionsEnabled ? () => _handleActionHint(actionHint) : null,
      icon: Icon(_iconForActionHint(actionHint), size: 17),
      label: Text(_displayLabelForActionHint(actionHint)),
      style: FilledButton.styleFrom(
        backgroundColor: isUser ? AppColors.white : semanticColor,
        foregroundColor: isUser ? semanticColor : AppColors.white,
        disabledBackgroundColor: AppColors.surfaceAlt,
        disabledForegroundColor: AppColors.textMuted,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_chatbotButtonRadius),
        ),
      ),
    );
  }

  IconData _iconForActionHint(ChatbotMessageActionHint actionHint) {
    if (isPaymentActionHint(actionHint)) {
      return Icons.payments_outlined;
    }

    if (isConfirmationActionHint(actionHint)) {
      return Icons.check_circle_outline_rounded;
    }

    if (isRouteEditActionHint(actionHint)) {
      return Icons.edit_location_alt_outlined;
    }

    if (isMerchantMapPickerActionHint(actionHint)) {
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
    if (isConfirmationActionHint(actionHint)) {
      return 'Buat Pesanan';
    }

    final label = actionHint.label.trim();
    if (label.isEmpty) {
      return label;
    }

    return friendlyLocationActionLabel(label);
  }

  Widget _buildResetDestinationContent({
    required ChatbotResetDestinationMessageParts parts,
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
        buildChatbotDraftField(
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
    required ChatbotShoppingSuccessMessageParts parts,
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
    required ChatbotIncompleteShoppingDraftMessageParts parts,
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
        buildChatbotDraftField(
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

  Widget _buildAssistantNotice(String text) {
    final rows = parseAssistantNoticeRows(text);
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
    required ChatbotAssistantNoticeRow row,
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
    required ChatbotAssistantNoticeRow row,
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

  Widget _buildShoppingDraftContent({
    required ChatbotShoppingDraftMessageParts parts,
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
          buildChatbotDraftField(
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
        buildChatbotDraftField(
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

    final openMapsDirectly = isMerchantMapPickerActionHint(actionHint);
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

    final replaceTarget = (actionHint.replaceTargetStopId ?? '').trim();
    final String appliedMode;
    if (actionHint.merchantMode == 'replace' && replaceTarget.isNotEmpty) {
      appliedMode = 'replace';
    } else if (actionHint.merchantMode == 'add' ||
        actionHint.merchantMode == 'maps_add') {
      appliedMode = 'add';
    } else {
      appliedMode = 'select';
    }
    final applied = await _conversationNotifier().applyMerchantPickerAction(
      serviceType: _serviceContext.serviceType,
      merchantId: result.merchantId,
      merchantPlace: result.isOfficial ? null : result.place,
      mode: appliedMode,
      replaceTargetStopId: appliedMode == 'replace' ? replaceTarget : null,
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
        confirmLabel: 'Konfirmasi',
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

