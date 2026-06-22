import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_routes.dart';
import '../../../../config/app_text_scaling.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../models/address_location_picker_result.dart';
import '../../../../models/chatbot_launch_args.dart';
import '../../../../models/route_location_picker_result.dart';
import '../../../../models/user_profile_model.dart';
import '../../../../services/customer_order_api_service.dart';
import '../../../../utils/currency_formatter.dart';
import '../../../auth/application/auth_session_provider.dart';
import '../../application/chatbot_conversation_provider.dart';
import '../../../../utils/address_readiness.dart';
import '../../../shopping/presentation/screens/shopping_merchant_map_picker_screen.dart';
import '../widgets/chatbot_menu_selector.dart';

class ChatbotScreen extends ConsumerStatefulWidget {
  const ChatbotScreen({super.key, this.launchArgs});

  final ChatbotLaunchArgs? launchArgs;

  @override
  ConsumerState<ChatbotScreen> createState() => _ChatbotScreenState();
}

enum _ChatbotMenuAction { restart }

class _ChatbotMenuSelectorData {
  const _ChatbotMenuSelectorData({
    required this.merchantName,
    required this.menus,
  });

  final String merchantName;
  final List<ChatbotMenuSuggestion> menus;
}

class _ChatbotScreenState extends ConsumerState<ChatbotScreen> {
  late final TextEditingController _inputController;
  late final ScrollController _scrollController;
  String? _bootstrappedServiceType;
  String? _appliedLaunchSignature;
  _ChatbotMenuSelectorData? _menuSelectorData;
  bool _isLoadingMenuSelector = false;
  String? _menuSelectorNotice;
  int _menuSelectorRequestId = 0;
  bool _didAutoOpenAddressBook = false;

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
        if (mounted) _scrollToBottom();
      });
      return;
    }

    _bootstrappedServiceType = serviceType;
    _appliedLaunchSignature = null;
    _menuSelectorData = null;
    _isLoadingMenuSelector = false;
    _menuSelectorNotice = null;
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
          suggestions: [
            'Antar ke Ramayana Salatiga',
            'Saya mau ke Alun-Alun Salatiga',
          ],
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
          suggestions: ['Kirim laundry', 'Kirim skincare', 'Kirim dokumen'],
        );
      default:
        return const _ServiceContext(
          serviceType: 'nitip',
          title: 'BangBot AI - Nitip',
          iconAsset:
              'assets/images/services/service_shopping_basket_simplified.png',
          welcomeMessage:
              'Halo! Saya BangBot untuk layanan Nitip. Tulis merchant dan item lewat chat, atau pilih merchant di map. Kamu bisa tambah sampai 3 merchant dalam satu pesanan.',
          addressRequiredMessage:
              'Sebelum pesan Nitip, isi Alamat Saya dulu supaya titik antar pesanan kamu siap dipakai.',
          suggestions: [
            'Beli ayam geprek',
            'Beli sembako',
            'Belanja minimarket',
          ],
        );
    }
  }

  Future<void> _bootstrapConversation() async {
    final hasSavedAddress = _hasSavedAddressInProfile();
    final welcomeMessage = _serviceContext.welcomeMessageFor(hasSavedAddress);

    await ref
        .read(chatbotConversationProvider.notifier)
        .bootstrap(
          serviceType: _serviceContext.serviceType,
          welcomeMessage: welcomeMessage,
        );

    if (!hasSavedAddress) {
      ref
          .read(chatbotConversationProvider.notifier)
          .ensureAddressGuardMessage(
            serviceType: _serviceContext.serviceType,
            message: _serviceContext.addressRequiredMessage,
          );
    }

    _scrollToBottom();

    if (!_didAutoOpenAddressBook && !_hasSavedAddressInProfile()) {
      _didAutoOpenAddressBook = true;
      await _handleOpenAddressesAction();
    }

    await _maybeApplyLaunchArgs();
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

    final state = ref.read(chatbotConversationProvider);
    if (state.isBusy || (state.sessionId ?? '').trim().isEmpty) {
      return;
    }

    _appliedLaunchSignature = signature;
    final applied = await ref
        .read(chatbotConversationProvider.notifier)
        .applyMerchantPickerAction(
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
    );

    _scrollToBottom();
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

    if (!_hasSavedAddressInProfile()) {
      await _handleOpenAddressesAction();
      return;
    }

    _inputController.clear();
    _clearMenuSelector();

    await ref
        .read(chatbotConversationProvider.notifier)
        .sendMessage(raw, serviceType: _serviceContext.serviceType);

    _scrollToBottom();
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
    await ref
        .read(chatbotConversationProvider.notifier)
        .restartActiveSession(
          serviceType: _serviceContext.serviceType,
          welcomeMessage: _currentWelcomeMessage(),
        );

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  String _currentWelcomeMessage() {
    final addresses =
        ref.read(authSessionProvider).profile?.addresses ??
        const <SavedAddressModel>[];

    return _serviceContext.welcomeMessageFor(hasUsableSavedAddress(addresses));
  }

  bool get _hasMenuSelectorSurface {
    return _menuSelectorData != null ||
        _isLoadingMenuSelector ||
        (_menuSelectorNotice ?? '').trim().isNotEmpty;
  }

  void _showMenuSelector({
    required String? merchantName,
    required List<ChatbotMenuSuggestion> menus,
  }) {
    _menuSelectorRequestId += 1;
    final normalizedMenus = menus
        .where((menu) => menu.name.trim().isNotEmpty)
        .toList(growable: false);
    if (normalizedMenus.isEmpty) {
      _clearMenuSelector();
      return;
    }

    setState(() {
      _menuSelectorData = _ChatbotMenuSelectorData(
        merchantName: (merchantName ?? '').trim(),
        menus: normalizedMenus,
      );
      _isLoadingMenuSelector = false;
      _menuSelectorNotice = null;
    });
  }

  void _showMenuSelectorNotice(String message) {
    _menuSelectorRequestId += 1;
    setState(() {
      _menuSelectorData = null;
      _isLoadingMenuSelector = false;
      _menuSelectorNotice = message;
    });
  }

  void _clearMenuSelector() {
    if (!_hasMenuSelectorSurface) {
      return;
    }

    _menuSelectorRequestId += 1;
    setState(() {
      _menuSelectorData = null;
      _isLoadingMenuSelector = false;
      _menuSelectorNotice = null;
    });
  }

  Future<void> _handleMenuSelectorConfirm(String message) async {
    _clearMenuSelector();
    await _sendMessage(message);
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatbotConversationProvider);
    final isServiceMismatch = state.serviceType != _serviceContext.serviceType;
    final effectiveBusy = state.isBusy || isServiceMismatch;
    final inputEnabled = !effectiveBusy;
    final latestActionMessageIndex = state.messages.lastIndexWhere(
      (message) => !message.isUser && message.actionHints.isNotEmpty,
    );
    final showStaticSuggestions =
        latestActionMessageIndex < 0 && !_hasMenuSelectorSurface;

    // Auto-scroll whenever the message list grows (new send / map-pin response)
    ref.listen<ChatbotConversationState>(chatbotConversationProvider, (
      previous,
      next,
    ) {
      if ((previous?.messages.length ?? 0) < next.messages.length) {
        _scrollToBottom();
      }
    });
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
                    fontWeight: FontWeight.bold,
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
                        return _buildMessageItem(
                          message,
                          actionsEnabled:
                              !effectiveBusy &&
                              index == latestActionMessageIndex,
                        );
                      }),
                      if (_hasMenuSelectorSurface) _buildMenuSelectorSurface(),
                    ],
                  ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: const BoxDecoration(
              color: AppColors.white,
              border: Border(top: BorderSide(color: AppColors.border)),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                              borderRadius: BorderRadius.circular(24),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
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
                        borderRadius: BorderRadius.circular(25),
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
        borderRadius: BorderRadius.circular(30),
        onTap: enabled ? () => _sendMessage(label) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(30),
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

  Widget _buildMenuSelectorSurface() {
    final selectorData = _menuSelectorData;
    if (selectorData != null) {
      return ChatbotMenuSelector(
        merchantName: selectorData.merchantName,
        menus: selectorData.menus,
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
                'Memuat menu merchant...',
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

    final notice = (_menuSelectorNotice ?? '').trim();
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
            borderRadius: BorderRadius.circular(18),
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
          Container(
            margin: EdgeInsets.only(
              left: isUser ? 50 : 0,
              right: isUser ? 0 : 50,
              bottom: 6,
            ),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bubbleColor,
              border: isUser
                  ? null
                  : Border.all(color: AppColors.border, width: 1),
              borderRadius: BorderRadius.circular(16).copyWith(
                topLeft: isUser
                    ? const Radius.circular(16)
                    : const Radius.circular(4),
                topRight: isUser
                    ? const Radius.circular(4)
                    : const Radius.circular(16),
              ),
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
            padding: const EdgeInsets.only(bottom: 8),
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
          Text(
            parts.instructionLine,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
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
              !_isRouteEditActionHint(actionHint),
        )
        .toList(growable: false);
    final confirmationActions = actionHints
        .where(_isConfirmationActionHint)
        .toList(growable: false);
    final otherActions = actionHints
        .where(
          (actionHint) =>
              !_isPaymentActionHint(actionHint) &&
              !_isDestinationResetActionHint(actionHint) &&
              !_isRouteEditActionHint(actionHint) &&
              !_isLocationSetupActionHint(actionHint) &&
              !_isConfirmationActionHint(actionHint),
        )
        .toList(growable: false);

    if (paymentActions.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildActionHintGroup(
            title: 'Atur lokasi',
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
                    isSecondaryAction: true,
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
          if (otherActions.isNotEmpty) ...[
            if (locationSetupActions.isNotEmpty ||
                destinationResetActions.isNotEmpty ||
                routeEditActions.isNotEmpty ||
                confirmationActions.isNotEmpty)
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
          title: 'Atur lokasi',
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
                  isSecondaryAction: true,
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

  Widget _buildActionHintGroup({
    required String title,
    required List<ChatbotMessageActionHint> actions,
    required bool actionsEnabled,
    required bool isUser,
    bool isPrimaryChoice = false,
    bool isSecondaryAction = false,
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
                isSecondaryAction: isSecondaryAction,
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
    bool isSecondaryAction = false,
  }) {
    final foregroundColor = isUser ? Colors.white : AppColors.primaryDark;
    final borderColor = isUser
        ? Colors.white.withValues(alpha: 0.35)
        : AppColors.primary;

    return OutlinedButton.icon(
      onPressed: actionsEnabled ? () => _handleActionHint(actionHint) : null,
      icon: Icon(_iconForActionHint(actionHint), size: 16),
      label: Text(actionHint.label),
      style: OutlinedButton.styleFrom(
        foregroundColor: foregroundColor,
        side: BorderSide(color: borderColor),
        padding: EdgeInsets.symmetric(
          horizontal: isPrimaryChoice ? 14 : 12,
          vertical: isPrimaryChoice ? 9 : 8,
        ),
        textStyle: TextStyle(
          fontSize: isSecondaryAction ? 11.5 : 12,
          fontWeight: isPrimaryChoice ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
    );
  }

  IconData _iconForActionHint(ChatbotMessageActionHint actionHint) {
    if (_isPaymentActionHint(actionHint)) {
      return Icons.payments_outlined;
    }

    return switch (actionHint.type) {
      ChatbotMessageActionType.openAddresses => Icons.home_outlined,
      ChatbotMessageActionType.openMapPicker => Icons.location_on_outlined,
      ChatbotMessageActionType.openMerchantPicker => Icons.storefront_outlined,
      ChatbotMessageActionType.openRoutePicker => Icons.route_outlined,
      ChatbotMessageActionType.sendPresetMessage => Icons.bolt_rounded,
      ChatbotMessageActionType.openTrackOrder => Icons.map_outlined,
      ChatbotMessageActionType.openActivity => Icons.receipt_long_outlined,
    };
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
            label.contains('isi alamat'));
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
          Text(
            parts.instructionLine,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
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
          Text(
            parts.instructionLine,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
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
          Text(
            parts.instructionLine,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14.5,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
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
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final row in rows)
                  Padding(
                    padding: EdgeInsets.only(bottom: row == rows.last ? 0 : 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                '${row.label}:',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              row.amount,
                              maxLines: 1,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                        if (row.note.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            row.note,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  List<_AssistantNoticeRow> _parseAssistantNoticeRows(String text) {
    final rows = <_AssistantNoticeRow>[];
    final rowPattern = RegExp(
      r'^(.+?):\s*(Rp\s*[\d.]+(?:,\d+)?)(?:\s*(\(.+\)))?\.?$',
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
          Text(
            parts.instructionLines.join('\n'),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
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

  _SimplePromptMessageParts? _tryParseCourierRouteSavedPrompt(String raw) {
    final normalized = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    const headline = 'Titik ambil dan tujuan sudah saya simpan.';
    if (!normalized.toLowerCase().startsWith(headline.toLowerCase())) {
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
      r'^merchant(?:\s+\d+)?$',
      caseSensitive: false,
    ).hasMatch(line.trim());
  }

  bool _isShoppingEstimateLine(String line) {
    final lower = line.toLowerCase();
    return lower.startsWith('estimasi ongkir sementara:') ||
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

    for (final line in lines.skip(startIndex)) {
      if (_isShoppingEstimateLine(line)) {
        hasSeenFee = true;
        continue;
      }
      if (!hasSeenFee) {
        continue;
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

  Future<void> _handleActionHint(ChatbotMessageActionHint actionHint) async {
    switch (actionHint.type) {
      case ChatbotMessageActionType.openAddresses:
        await _handleOpenAddressesAction();
        return;
      case ChatbotMessageActionType.openMapPicker:
        await _handleOpenMapPickerAction(actionHint);
        return;
      case ChatbotMessageActionType.openMerchantPicker:
        await _handleOpenMerchantPickerAction(actionHint);
        return;
      case ChatbotMessageActionType.openRoutePicker:
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
    }
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
    await context.push(AppRoutes.addresses);
    if (!mounted) {
      return;
    }

    await ref.read(authSessionProvider.notifier).refreshSession();

    ref
        .read(chatbotConversationProvider.notifier)
        .onAddressBookUpdated(serviceType: _serviceContext.serviceType);

    await _maybeApplyLaunchArgs();

    _scrollToBottom();
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

    await ref
        .read(chatbotConversationProvider.notifier)
        .applyMapPinAction(
          serviceType: _serviceContext.serviceType,
          target: target,
          latitude: result.latitude,
          longitude: result.longitude,
          address: null,
        );

    _scrollToBottom();
  }

  Future<void> _handleOpenMerchantPickerAction(
    ChatbotMessageActionHint actionHint,
  ) async {
    if (_serviceContext.serviceType != 'nitip') {
      return;
    }

    final result = await context.push<ShoppingMerchantPickerResult>(
      AppRoutes.chatbotShoppingMerchantMapPickerPath(),
      extra: ShoppingMerchantMapPickerArgs(
        initialLatitude: actionHint.initialLatitude,
        initialLongitude: actionHint.initialLongitude,
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    _clearMenuSelector();

    final applied = await ref
        .read(chatbotConversationProvider.notifier)
        .applyMerchantPickerAction(
          serviceType: _serviceContext.serviceType,
          merchantId: result.merchantId,
          merchantPlace: result.isOfficial ? null : result.place,
          mode: actionHint.merchantMode == 'add' ? 'add' : 'select',
          appendAssistantMessage: !result.isOfficial,
        );

    if (!mounted || !applied) {
      return;
    }

    if (result.isOfficial) {
      await _loadOfficialMerchantMenus(
        merchantId: result.merchantId!,
        merchantName: result.place.name,
      );
      return;
    }

    _scrollToBottom();
  }

  Future<void> _loadOfficialMerchantMenus({
    required int merchantId,
    required String merchantName,
  }) async {
    final requestId = ++_menuSelectorRequestId;
    setState(() {
      _menuSelectorData = null;
      _isLoadingMenuSelector = true;
      _menuSelectorNotice = null;
    });
    _scrollToBottom();

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
              priceLabel: formatRupiah(menu.price),
              imageUrl: menu.imageUrl,
            ),
          )
          .toList(growable: false);

      if (suggestions.isEmpty) {
        _showMenuSelectorNotice(
          'Menu resmi merchant ini belum tersedia. Kamu tetap bisa tulis item manual.',
        );
      } else {
        _showMenuSelector(merchantName: merchantName, menus: suggestions);
      }
    } catch (_) {
      if (!mounted || requestId != _menuSelectorRequestId) {
        return;
      }
      _showMenuSelectorNotice(
        'Menu belum bisa dimuat. Kamu tetap bisa tulis item manual.',
      );
    }

    _scrollToBottom();
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

    await ref
        .read(chatbotConversationProvider.notifier)
        .applyRoutePickerAction(serviceType: serviceType, locations: locations);

    _scrollToBottom();
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
