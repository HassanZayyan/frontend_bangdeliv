import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/chatbot_model.dart';
import '../../../models/chatbot_launch_args.dart';
import '../../../services/api_exception.dart';
import '../../../services/chatbot_api_service.dart';
import '../../../services/customer_order_api_service.dart';
import '../../../utils/address_readiness.dart';
import '../../../utils/order_formatters.dart';
import '../../auth/application/auth_session_provider.dart';
import '../../../core/di/app_providers.dart';
import 'chatbot_conversation_models.dart';

export 'chatbot_conversation_models.dart';

String _normalizeConversationServiceType(String serviceType) {
  switch (serviceType.trim().toLowerCase()) {
    case 'antar_jemput':
    case 'kurir':
    case 'nitip':
      return serviceType.trim().toLowerCase();
    default:
      return 'nitip';
  }
}

enum _MessageResultContext { general, mapPin }

class ChatbotConversationNotifier extends Notifier<ChatbotConversationState> {
  ChatbotConversationNotifier(this._initialServiceType);

  final String _initialServiceType;

  /// stop_id slot aktif dari draft belanja terbaru. Dipakai untuk menandai
  /// menu selector agar tombol "Ganti Toko/Resto" menyasar stop yang tepat.
  String? _activeStopId;

  @override
  ChatbotConversationState build() {
    final serviceType = _normalizeConversationServiceType(_initialServiceType);
    return ChatbotConversationState(
      serviceType: serviceType,
      sessionId: null,
      messages: const <ChatbotConversationMessage>[],
      isBootstrapping: false,
      isSending: false,
      isApplyingAction: false,
      hasInitialized: false,
      errorMessage: null,
      activeOrderId: null,
      menuSelectorDraft: null,
      menuSelectorNotice: null,
    );
  }

  void _ensureService(String serviceType) {
    final normalizedServiceType = _normalizeConversationServiceType(
      serviceType,
    );
    if (state.serviceType == normalizedServiceType) {
      return;
    }

    _activeStopId = null;
    state = ChatbotConversationState(
      serviceType: normalizedServiceType,
      sessionId: null,
      messages: const <ChatbotConversationMessage>[],
      isBootstrapping: false,
      isSending: false,
      isApplyingAction: false,
      hasInitialized: false,
      errorMessage: null,
      activeOrderId: null,
      menuSelectorDraft: null,
      menuSelectorNotice: null,
    );
  }

  Future<void> bootstrap({
    required String serviceType,
    required String welcomeMessage,
  }) async {
    _ensureService(serviceType);

    if (state.hasInitialized || state.isBootstrapping) {
      return;
    }

    state = state.copyWith(
      isBootstrapping: true,
      hasInitialized: true,
      clearErrorMessage: true,
    );

    final sessionId = _generateSessionId(serviceType);

    state = state.copyWith(
      serviceType: serviceType,
      sessionId: sessionId,
      messages: <ChatbotConversationMessage>[
        _botMessage(
          text: welcomeMessage,
          timestamp: _nowLabel(),
          actionHints: _bootstrapActionHints(serviceType),
        ),
      ],
      isBootstrapping: false,
      clearErrorMessage: true,
    );
  }

  Future<bool> sendMessage(
    String rawMessage, {
    required String serviceType,
    bool clearMenuSelectorOnStart = true,
  }) async {
    _ensureService(serviceType);

    final message = rawMessage.trim();
    if (message.isEmpty || state.isSending || state.isBootstrapping) {
      return false;
    }

    var sessionId = state.sessionId?.trim();
    if (sessionId == null || sessionId.isEmpty) {
      sessionId = _generateSessionId(serviceType);
    }

    state = state.copyWith(
      serviceType: serviceType,
      sessionId: sessionId,
      messages: <ChatbotConversationMessage>[
        ..._clearActionHints(state.messages),
        ChatbotConversationMessage(
          text: message,
          timestamp: _nowLabel(),
          isUser: true,
          actionHints: const <ChatbotMessageActionHint>[],
        ),
      ],
      isSending: true,
      clearErrorMessage: true,
      clearMenuSelectorSurface: clearMenuSelectorOnStart,
    );

    final api = ref.read(chatbotRepositoryProvider);
    try {
      final result = await api.sendMessage(
        message,
        serviceType: serviceType,
        sessionId: sessionId,
      );

      sessionId = await _sessionIdAfterResult(
        result,
        serviceType: serviceType,
        fallbackSessionId: sessionId,
      );

      state = state.copyWith(
        serviceType: serviceType,
        sessionId: sessionId,
        isSending: false,
        activeOrderId: _trackAndResolveActiveOrderId(result),
        messages: <ChatbotConversationMessage>[
          ...state.messages,
          _messageFromResult(result, serviceType),
        ],
        clearErrorMessage: true,
        clearMenuSelectorSurface: true,
        pendingMenuSelectorRequest: result.menuSelector,
        clearPendingMenuSelectorRequest: result.menuSelector == null,
      );
      return true;
    } on ApiException catch (error) {
      final message = error.message.trim().isEmpty
          ? 'Gagal mengirim pesan.'
          : error.message.trim();
      state = state.copyWith(
        isSending: false,
        messages: <ChatbotConversationMessage>[
          ...state.messages,
          _botMessage(text: message, timestamp: _nowLabel()),
        ],
        errorMessage: message,
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        isSending: false,
        messages: <ChatbotConversationMessage>[
          ...state.messages,
          _botMessage(
            text: 'Maaf, layanan chatbot belum bisa digunakan saat ini.',
            timestamp: _nowLabel(),
          ),
        ],
        errorMessage: 'Gagal mengirim pesan.',
      );
      return false;
    }
  }

  void addLocalGuardResponse({
    required String rawMessage,
    required String serviceType,
    required String assistantMessage,
    List<ChatbotMessageActionHint> actionHints =
        const <ChatbotMessageActionHint>[],
  }) {
    _ensureService(serviceType);

    final message = rawMessage.trim();
    if (message.isEmpty || state.isBootstrapping || state.isSending) {
      return;
    }

    var sessionId = state.sessionId?.trim();
    if (sessionId == null || sessionId.isEmpty) {
      sessionId = _generateSessionId(serviceType);
    }

    state = state.copyWith(
      serviceType: serviceType,
      sessionId: sessionId,
      messages: <ChatbotConversationMessage>[
        ..._clearActionHints(state.messages),
        ChatbotConversationMessage(
          text: message,
          timestamp: _nowLabel(),
          isUser: true,
          actionHints: const <ChatbotMessageActionHint>[],
        ),
        _botMessage(
          text: assistantMessage,
          timestamp: _nowLabel(),
          actionHints: actionHints,
        ),
      ],
      clearErrorMessage: true,
      clearMenuSelectorSurface: true,
    );
  }

  bool resolveDriverVerificationGuard({
    required String serviceType,
    required String assistantMessage,
  }) {
    _ensureService(serviceType);

    if (state.isBootstrapping || state.isSending || state.isApplyingAction) {
      return false;
    }

    final hasDriverVerificationAction = state.messages.any(
      (message) => message.actionHints.any(
        (hint) =>
            hint.type == ChatbotMessageActionType.openDriverVerificationStatus,
      ),
    );
    if (!hasDriverVerificationAction) {
      return false;
    }

    var sessionId = state.sessionId?.trim();
    if (sessionId == null || sessionId.isEmpty) {
      sessionId = _generateSessionId(serviceType);
    }

    state = state.copyWith(
      serviceType: serviceType,
      sessionId: sessionId,
      messages: <ChatbotConversationMessage>[
        ..._clearActionHints(state.messages),
        _botMessage(
          text: assistantMessage,
          timestamp: _nowLabel(),
          actionHints: _bootstrapActionHints(serviceType),
        ),
      ],
      clearErrorMessage: true,
      clearMenuSelectorSurface: true,
    );

    return true;
  }

  Future<void> applyMapPinAction({
    required String serviceType,
    required String target,
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    _ensureService(serviceType);

    final sessionId = state.sessionId?.trim();
    if (sessionId == null || sessionId.isEmpty || state.isApplyingAction) {
      return;
    }

    state = state.copyWith(
      isApplyingAction: true,
      messages: _clearActionHints(state.messages),
      clearErrorMessage: true,
      clearMenuSelectorSurface: true,
    );

    final api = ref.read(chatbotRepositoryProvider);
    try {
      final result = await api.patchSessionLocation(
        sessionId,
        serviceType: serviceType,
        target: target,
        latitude: latitude,
        longitude: longitude,
        address: address,
      );

      final resolvedSessionId = await _sessionIdAfterResult(
        result,
        serviceType: serviceType,
        fallbackSessionId: sessionId,
      );

      state = state.copyWith(
        serviceType: serviceType,
        sessionId: resolvedSessionId,
        isApplyingAction: false,
        activeOrderId: _trackAndResolveActiveOrderId(result),
        messages: <ChatbotConversationMessage>[
          ...state.messages,
          _messageFromResult(
            result,
            serviceType,
            contextAction: _MessageResultContext.mapPin,
            contextTarget: target,
          ),
        ],
        clearErrorMessage: true,
      );
    } catch (_) {
      state = state.copyWith(
        isApplyingAction: false,
        errorMessage: 'Gagal memperbarui titik lokasi.',
      );
    }
  }

  Future<void> applyRoutePickerAction({
    required String serviceType,
    required List<ChatbotLocationPatch> locations,
  }) async {
    _ensureService(serviceType);

    final sessionId = state.sessionId?.trim();
    if (sessionId == null ||
        sessionId.isEmpty ||
        state.isApplyingAction ||
        locations.isEmpty) {
      return;
    }

    state = state.copyWith(
      isApplyingAction: true,
      messages: _clearActionHints(state.messages),
      clearErrorMessage: true,
      clearMenuSelectorSurface: true,
    );

    final api = ref.read(chatbotRepositoryProvider);
    try {
      final result = await api.patchSessionLocations(
        sessionId,
        serviceType: serviceType,
        locations: locations
            .map(
              (location) => ChatbotLocationPatchRequest(
                target: location.target,
                latitude: location.latitude,
                longitude: location.longitude,
                address: location.address,
              ),
            )
            .toList(growable: false),
      );

      final resolvedSessionId = await _sessionIdAfterResult(
        result,
        serviceType: serviceType,
        fallbackSessionId: sessionId,
      );

      state = state.copyWith(
        serviceType: serviceType,
        sessionId: resolvedSessionId,
        isApplyingAction: false,
        activeOrderId: _trackAndResolveActiveOrderId(result),
        messages: <ChatbotConversationMessage>[
          ...state.messages,
          _messageFromResult(result, serviceType),
        ],
        clearErrorMessage: true,
      );
    } catch (_) {
      state = state.copyWith(
        isApplyingAction: false,
        errorMessage: 'Gagal memperbarui titik rute.',
      );
    }
  }

  Future<bool> applyMerchantPickerAction({
    required String serviceType,
    int? merchantId,
    ShoppingMerchantPlacePayload? merchantPlace,
    String mode = 'select',
    String? replaceTargetStopId,
    bool appendAssistantMessage = true,
  }) async {
    _ensureService(serviceType);

    final sessionId = state.sessionId?.trim();
    if (sessionId == null ||
        sessionId.isEmpty ||
        state.isApplyingAction ||
        ((merchantId == null || merchantId <= 0) && merchantPlace == null)) {
      return false;
    }

    state = state.copyWith(
      isApplyingAction: true,
      messages: _clearActionHints(state.messages),
      clearErrorMessage: true,
      clearMenuSelectorSurface: true,
    );

    final api = ref.read(chatbotRepositoryProvider);
    try {
      final result = await api.patchSessionMerchant(
        sessionId,
        serviceType: serviceType,
        merchantId: merchantId,
        merchantPlace: merchantPlace,
        mode: mode,
        replaceTargetStopId: replaceTargetStopId,
      );

      final resolvedSessionId = await _sessionIdAfterResult(
        result,
        serviceType: serviceType,
        fallbackSessionId: sessionId,
      );

      state = state.copyWith(
        serviceType: serviceType,
        sessionId: resolvedSessionId,
        isApplyingAction: false,
        activeOrderId: _trackAndResolveActiveOrderId(result),
        messages: appendAssistantMessage
            ? <ChatbotConversationMessage>[
                ...state.messages,
                _messageFromResult(result, serviceType),
              ]
            : state.messages,
        clearErrorMessage: true,
      );
      return true;
    } catch (_) {
      state = state.copyWith(
        isApplyingAction: false,
        errorMessage: 'Gagal memperbarui tempat Nitip.',
      );
      return false;
    }
  }

  void appendMenuSuggestionActions({
    required String serviceType,
    required String? merchantName,
    required List<ChatbotMenuSuggestion> suggestions,
  }) {
    _ensureService(serviceType);

    if (serviceType != 'nitip' || suggestions.isEmpty) {
      return;
    }

    final normalizedMerchant = (merchantName ?? '').trim();
    final merchantLabel = normalizedMerchant.isEmpty
        ? 'tempat ini'
        : normalizedMerchant;
    final actionHints = suggestions
        .where((item) => item.name.trim().isNotEmpty)
        .take(10)
        .map(
          (item) => ChatbotMessageActionHint(
            type: ChatbotMessageActionType.sendPresetMessage,
            label: item.label,
            presetMessage: item.presetMessage,
          ),
        )
        .toList(growable: false);

    if (actionHints.isEmpty) {
      return;
    }

    state = state.copyWith(
      messages: <ChatbotConversationMessage>[
        ..._clearActionHints(state.messages),
        _botMessage(
          text:
              'Menu $merchantLabel tersedia. Pilih salah satu menu di bawah, atau tulis item dan jumlah sendiri.',
          timestamp: _nowLabel(),
          actionHints: actionHints,
        ),
      ],
      clearErrorMessage: true,
      clearMenuSelectorSurface: true,
    );
  }

  void showMenuSelector({
    required String serviceType,
    required String? merchantName,
    required List<ChatbotMenuSuggestion> menus,
    String merchantMode = 'select',
  }) {
    _ensureService(serviceType);

    final normalizedMenus = menus
        .where((menu) => menu.name.trim().isNotEmpty)
        .toList(growable: false);
    if (normalizedMenus.isEmpty) {
      clearMenuSelectorSurface(serviceType: serviceType);
      return;
    }

    final effectiveMerchantName = (merchantName ?? '').trim();
    final normalizedMode = merchantMode.trim().toLowerCase();
    final effectiveMerchantMode =
        normalizedMode == 'add' || normalizedMode == 'maps_add'
        ? 'add'
        : 'select';
    // stop_id slot aktif terbaru dari backend; menandai stop yang diwakili
    // menu selector ini agar "Ganti Toko/Resto" mengganti stop yang tepat.
    final activeStopId = (_activeStopId ?? '').trim();
    final effectiveTargetStopId = activeStopId.isEmpty ? null : activeStopId;
    final previous = state.menuSelectorDraft;
    final quantities =
        previous != null &&
            previous.merchantName == effectiveMerchantName &&
            previous.merchantMode == effectiveMerchantMode &&
            previous.targetStopId == effectiveTargetStopId &&
            _hasSameMenuSuggestions(previous.menus, normalizedMenus)
        ? previous.quantities
              .take(normalizedMenus.length)
              .map((quantity) => quantity.clamp(0, 99).toInt())
              .toList(growable: false)
        : List<int>.filled(normalizedMenus.length, 0);

    state = state.copyWith(
      menuSelectorDraft: ChatbotMenuSelectorDraft(
        merchantName: effectiveMerchantName,
        merchantMode: effectiveMerchantMode,
        menus: normalizedMenus,
        quantities: quantities.length == normalizedMenus.length
            ? quantities
            : List<int>.filled(normalizedMenus.length, 0),
        targetStopId: effectiveTargetStopId,
      ),
      menuSelectorNotice: '',
    );
  }

  void adjustMenuSelectorQuantity({
    required String serviceType,
    required int index,
    required int delta,
  }) {
    _ensureService(serviceType);

    final selector = state.menuSelectorDraft;
    if (selector == null || index < 0 || index >= selector.menus.length) {
      return;
    }

    final quantities = selector.quantities.length == selector.menus.length
        ? selector.quantities.toList(growable: true)
        : List<int>.filled(selector.menus.length, 0);
    quantities[index] = (quantities[index] + delta).clamp(0, 99).toInt();

    state = state.copyWith(
      menuSelectorDraft: selector.copyWith(
        quantities: quantities.toList(growable: false),
      ),
      menuSelectorNotice: '',
    );
  }

  void showMenuSelectorNotice({
    required String serviceType,
    required String message,
  }) {
    _ensureService(serviceType);

    final normalizedMessage = message.trim();
    state = state.copyWith(clearMenuSelectorSurface: true);
    if (normalizedMessage.isEmpty) {
      return;
    }

    state = state.copyWith(menuSelectorNotice: normalizedMessage);
  }

  void clearMenuSelectorSurface({required String serviceType}) {
    _ensureService(serviceType);

    if (!state.hasMenuSelectorSurface) {
      return;
    }

    state = state.copyWith(clearMenuSelectorSurface: true);
  }

  /// Konsumsi sinyal menu selector (sekali pakai) setelah layar menanganinya.
  void consumeMenuSelectorRequest() {
    if (state.pendingMenuSelectorRequest == null) {
      return;
    }

    state = state.copyWith(clearPendingMenuSelectorRequest: true);
  }

  bool _hasSameMenuSuggestions(
    List<ChatbotMenuSuggestion> current,
    List<ChatbotMenuSuggestion> incoming,
  ) {
    if (current.length != incoming.length) {
      return false;
    }

    for (var index = 0; index < current.length; index++) {
      if (current[index].name.trim() != incoming[index].name.trim()) {
        return false;
      }
    }

    return true;
  }

  /// Menyimpan stop_id slot aktif terbaru sekaligus mengembalikan id order
  /// aktif. Dipanggil di setiap titik hasil balasan backend agar `_activeStopId`
  /// selalu mengikuti kebenaran draft terakhir.
  int? _trackAndResolveActiveOrderId(ChatbotResult result) {
    _activeStopId = _activeStopIdFromResult(result);
    return _activeOrderIdFromResult(result);
  }

  String? _activeStopIdFromResult(ChatbotResult result) {
    final shopping = result.shopping;
    if (shopping == null) {
      return null;
    }

    for (final stop in shopping.stops) {
      if (stop.isActive) {
        final stopId = (stop.stopId ?? '').trim();
        return stopId.isEmpty ? null : stopId;
      }
    }

    return null;
  }

  int? _activeOrderIdFromResult(ChatbotResult result) {
    if (!result.isOrderCreated) {
      return null;
    }

    final orderId = result.createdOrderId;
    if (orderId == null || orderId <= 0) {
      return null;
    }

    return orderId;
  }

  Future<String> _sessionIdAfterResult(
    ChatbotResult result, {
    required String serviceType,
    required String fallbackSessionId,
  }) async {
    final canonicalSessionId = result.sessionId?.trim();
    final sessionId =
        canonicalSessionId != null && canonicalSessionId.isNotEmpty
        ? canonicalSessionId
        : fallbackSessionId;

    if (!result.isOrderCreated) {
      return sessionId;
    }

    try {
      await ref.read(chatbotRepositoryProvider).clearSession(sessionId);
    } catch (_) {
      // Best effort: backend already clears completed draft data.
    }

    return _generateSessionId(serviceType);
  }

  Future<void> restartActiveSession({
    required String serviceType,
    required String welcomeMessage,
  }) async {
    _ensureService(serviceType);

    if (state.isBusy) {
      return;
    }

    final oldSessionId = state.sessionId?.trim();
    final newSessionId = _generateSessionId(serviceType);
    final api = ref.read(chatbotRepositoryProvider);
    var clearFailed = false;

    state = state.copyWith(
      isApplyingAction: true,
      messages: _clearActionHints(state.messages),
      clearErrorMessage: true,
    );

    if (oldSessionId != null && oldSessionId.isNotEmpty) {
      try {
        await api.clearSession(oldSessionId);
      } catch (_) {
        clearFailed = true;
      }
    }

    final normalizedWelcome = welcomeMessage.trim();
    state = state.copyWith(
      serviceType: serviceType,
      sessionId: newSessionId,
      messages: normalizedWelcome.isEmpty
          ? const <ChatbotConversationMessage>[]
          : <ChatbotConversationMessage>[
              _botMessage(
                text: normalizedWelcome,
                timestamp: _nowLabel(),
                actionHints: _bootstrapActionHints(serviceType),
              ),
            ],
      isBootstrapping: false,
      isSending: false,
      isApplyingAction: false,
      hasInitialized: normalizedWelcome.isNotEmpty,
      errorMessage: clearFailed
          ? 'Pesanan dimulai ulang. Sesi lama mungkin belum terhapus di server.'
          : null,
      clearErrorMessage: !clearFailed,
      clearActiveOrderId: true,
      clearMenuSelectorSurface: true,
    );
  }

  void resetAfterResolvedOrder({
    required String serviceType,
    required int orderId,
    required String welcomeMessage,
  }) {
    _ensureService(serviceType);

    if (state.activeOrderId != orderId || state.isBusy) {
      return;
    }

    final normalizedWelcome = welcomeMessage.trim();
    state = state.copyWith(
      serviceType: serviceType,
      sessionId: _generateSessionId(serviceType),
      messages: normalizedWelcome.isEmpty
          ? const <ChatbotConversationMessage>[]
          : <ChatbotConversationMessage>[
              _botMessage(
                text: normalizedWelcome,
                timestamp: _nowLabel(),
                actionHints: _bootstrapActionHints(serviceType),
              ),
            ],
      isBootstrapping: false,
      isSending: false,
      isApplyingAction: false,
      hasInitialized: normalizedWelcome.isNotEmpty,
      clearErrorMessage: true,
      clearActiveOrderId: true,
      clearMenuSelectorSurface: true,
    );
  }

  void onAddressBookUpdated({required String serviceType}) {
    _ensureService(serviceType);

    syncSavedAddressReadiness(
      serviceType: serviceType,
      readyWelcomeMessage: null,
    );
  }

  bool syncSavedAddressReadiness({
    required String serviceType,
    required String? readyWelcomeMessage,
    bool allowFollowUpMessage = true,
  }) {
    _ensureService(serviceType);

    if (state.isBusy ||
        (serviceType != 'antar_jemput' &&
            serviceType != 'kurir' &&
            serviceType != 'nitip')) {
      return false;
    }

    if (!_hasSavedAddressInProfile()) {
      return false;
    }

    final mapHints = _serviceMapActionHints(serviceType);
    if (mapHints.isEmpty) {
      return false;
    }

    final lastAssistant = state.messages.isEmpty ? null : state.messages.last;
    if (lastAssistant != null &&
        !lastAssistant.isUser &&
        _isSameActionSet(lastAssistant.actionHints, mapHints)) {
      return false;
    }

    var sessionId = state.sessionId?.trim();
    if (sessionId == null || sessionId.isEmpty) {
      sessionId = _generateSessionId(serviceType);
    }

    final shouldReplaceGuard = _isAddressGuardOnlyConversation(state.messages);
    if (!shouldReplaceGuard && !allowFollowUpMessage) {
      return false;
    }

    final normalizedWelcome = (readyWelcomeMessage ?? '').trim();
    final messageText = shouldReplaceGuard && normalizedWelcome.isNotEmpty
        ? normalizedWelcome
        : _addressBookUpdatedMessage(serviceType);

    state = state.copyWith(
      serviceType: serviceType,
      sessionId: sessionId,
      messages: shouldReplaceGuard
          ? <ChatbotConversationMessage>[
              _botMessage(
                text: messageText,
                timestamp: _nowLabel(),
                actionHints: mapHints,
              ),
            ]
          : <ChatbotConversationMessage>[
              ..._clearActionHints(state.messages),
              _botMessage(
                text: messageText,
                timestamp: _nowLabel(),
                actionHints: mapHints,
              ),
            ],
      hasInitialized: true,
      clearErrorMessage: true,
      clearMenuSelectorSurface: true,
    );

    return true;
  }

  void ensureAddressGuardMessage({
    required String serviceType,
    required String message,
  }) {
    _ensureService(serviceType);

    if (_hasSavedAddressInProfile()) {
      return;
    }

    final hasAddressAction = state.messages.any(
      (item) => item.actionHints.any(
        (hint) => hint.type == ChatbotMessageActionType.openAddresses,
      ),
    );
    if (hasAddressAction) {
      return;
    }

    state = state.copyWith(
      messages: <ChatbotConversationMessage>[
        ...state.messages,
        _botMessage(
          text: message,
          timestamp: _nowLabel(),
          actionHints: const <ChatbotMessageActionHint>[
            ChatbotMessageActionHint(
              type: ChatbotMessageActionType.openAddresses,
              label: 'Isi Alamat Saya',
            ),
          ],
        ),
      ],
      clearErrorMessage: true,
    );
  }

  bool _isAddressGuardOnlyConversation(
    List<ChatbotConversationMessage> messages,
  ) {
    if (messages.isEmpty) {
      return true;
    }

    if (messages.any((message) => message.isUser)) {
      return false;
    }

    return messages.any(
      (message) => message.actionHints.any(
        (hint) => hint.type == ChatbotMessageActionType.openAddresses,
      ),
    );
  }

  // ignore: unused_element
  ChatbotConversationMessage _messageFromHistoryEntry(
    dynamic entry,
    String serviceType,
  ) {
    if (entry.isUser) {
      return ChatbotConversationMessage(
        text: entry.message,
        timestamp: _nowLabel(),
        isUser: true,
      );
    }

    final metaParts = <String>[];
    final effectiveServiceType = entry.serviceType.trim().isEmpty
        ? serviceType
        : entry.serviceType;
    metaParts.add('Layanan: $effectiveServiceType');
    if (entry.modelUsed != null && entry.modelUsed!.trim().isNotEmpty) {
      metaParts.add('Model: ${entry.modelUsed}');
    }
    if (entry.orderId != null) {
      metaParts.add('Order ID: ${entry.orderId}');
    }

    return ChatbotConversationMessage(
      text: ChatbotResult.normalizeAssistantCopy(
        entry.message,
        serviceType: effectiveServiceType,
      ),
      timestamp: _nowLabel(),
      isUser: false,
      meta: metaParts.join(' • '),
      actionHints: const <ChatbotMessageActionHint>[],
    );
  }

  ChatbotConversationMessage _messageFromResult(
    ChatbotResult result,
    String serviceType, {
    _MessageResultContext contextAction = _MessageResultContext.general,
    String? contextTarget,
  }) {
    final shouldUseDeliveryAddressResponse = _shouldUseDeliveryAddressResponse(
      serviceType: serviceType,
      contextAction: contextAction,
      contextTarget: contextTarget,
      result: result,
    );
    final shouldUseMerchantMapFallback =
        !shouldUseDeliveryAddressResponse &&
        _shouldUseMerchantMapFallback(result, serviceType);
    final metaParts = <String>['Layanan: $serviceType'];
    if (result.modelUsed != null && result.modelUsed!.trim().isNotEmpty) {
      metaParts.add('Model: ${result.modelUsed}');
    }
    if (result.isOrderCreated) {
      final orderRef = result.createdOrderNumber?.trim();
      if (orderRef != null && orderRef.isNotEmpty) {
        metaParts.add('Order: $orderRef');
      } else if (result.createdOrderId != null) {
        metaParts.add('Order ID: ${result.createdOrderId}');
      }
    }

    final assistantText = shouldUseMerchantMapFallback
        ? _merchantMapFallbackMessage
        : shouldUseDeliveryAddressResponse
        ? _deliveryAddressSelectedMessage
        : result.toAssistantText();

    return ChatbotConversationMessage(
      text: assistantText,
      timestamp: _nowLabel(),
      isUser: false,
      meta: metaParts.join(' • '),
      actionHints: _resolveActionHintsFromResult(
        result,
        preferMerchantMapPicker: shouldUseMerchantMapFallback,
        preferMerchantListPicker: shouldUseDeliveryAddressResponse,
      ),
    );
  }

  static const String _deliveryAddressSelectedMessage =
      'Alamat antar sudah dipilih. Sekarang pilih toko/resto agar driver tahu lokasi pembelian.';

  static const String _merchantMapFallbackMessage =
      'Nama toko/resto itu belum terdaftar di BangDeliv. Ketuk Cari lewat Maps agar driver mendapatkan titik yang tepat.';

  bool _shouldUseDeliveryAddressResponse({
    required String serviceType,
    required _MessageResultContext contextAction,
    required String? contextTarget,
    required ChatbotResult result,
  }) {
    final normalizedServiceType = (result.serviceType ?? serviceType)
        .trim()
        .toLowerCase();
    final normalizedTarget = (contextTarget ?? '').trim().toLowerCase();
    if (normalizedServiceType != 'nitip' ||
        contextAction != _MessageResultContext.mapPin ||
        normalizedTarget != 'delivery' ||
        result.isOrderCreated) {
      return false;
    }

    final validation = result.validation;
    if (validation == null) {
      return false;
    }

    if (_shoppingDraftHasProgress(result.shopping)) {
      return false;
    }

    return validation.nextActions.any((action) {
      final normalized = action.trim().toUpperCase();
      return normalized == 'OPEN_MERCHANT_PICKER' ||
          normalized == 'OPEN_ADD_MERCHANT_PICKER';
    });
  }

  bool _shoppingDraftHasProgress(ChatbotShoppingDraft? shopping) {
    if (shopping == null) {
      return false;
    }

    if (shopping.readyToConfirm || shopping.items.isNotEmpty) {
      return true;
    }

    if (_hasNamedMerchant(shopping.merchant)) {
      return true;
    }

    for (final stop in shopping.stops) {
      if (stop.ready ||
          stop.items.isNotEmpty ||
          _hasNamedMerchant(stop.merchant)) {
        return true;
      }
    }

    return false;
  }

  bool _hasNamedMerchant(Map<String, dynamic>? merchant) {
    if (merchant == null) {
      return false;
    }

    return (merchant['name']?.toString().trim() ?? '').isNotEmpty;
  }

  bool _shouldUseMerchantMapFallback(ChatbotResult result, String serviceType) {
    final normalizedServiceType = (result.serviceType ?? serviceType)
        .trim()
        .toLowerCase();
    if (normalizedServiceType != 'nitip' || result.isOrderCreated) {
      return false;
    }

    final validation = result.validation;
    if (validation == null) {
      return false;
    }

    final hasMerchantPickerAction = validation.nextActions.any((action) {
      final normalized = action.trim().toUpperCase();
      return normalized == 'OPEN_MERCHANT_PICKER' ||
          normalized == 'OPEN_ADD_MERCHANT_PICKER';
    });
    if (!hasMerchantPickerAction) {
      return false;
    }

    final hasMissingMerchantField = validation.missingFields.any((field) {
      final normalized = field.trim().toLowerCase();
      return normalized.contains('tempat') ||
          normalized.contains('toko') ||
          normalized.contains('resto') ||
          normalized.contains('merchant') ||
          normalized.contains('place');
    });
    final assistantText = (result.assistantText ?? '').trim().toLowerCase();
    if (assistantText.isEmpty) {
      return hasMissingMerchantField;
    }

    return assistantText.contains('lengkapi: tempat') ||
        assistantText.contains('lengkapi: merchant') ||
        (assistantText.contains('belum lengkap') &&
            assistantText.contains('tempat'));
  }

  ChatbotConversationMessage _botMessage({
    required String text,
    required String timestamp,
    List<ChatbotMessageActionHint> actionHints =
        const <ChatbotMessageActionHint>[],
  }) {
    return ChatbotConversationMessage(
      text: text,
      timestamp: timestamp,
      isUser: false,
      actionHints: actionHints,
    );
  }

  List<ChatbotConversationMessage> _clearActionHints(
    List<ChatbotConversationMessage> messages,
  ) {
    return messages
        .map((message) {
          if (message.actionHints.isEmpty) {
            return message;
          }

          return ChatbotConversationMessage(
            text: message.text,
            timestamp: message.timestamp,
            isUser: message.isUser,
            meta: message.meta,
          );
        })
        .toList(growable: false);
  }

  List<ChatbotMessageActionHint> _resolveActionHintsFromResult(
    ChatbotResult result, {
    bool preferMerchantMapPicker = false,
    bool preferMerchantListPicker = false,
  }) {
    if (result.isOrderCreated) {
      return _orderCreatedActionHints(result);
    }

    final validation = result.validation;
    if (validation == null) {
      return const <ChatbotMessageActionHint>[];
    }

    final nextActions = validation.nextActions
        .map((item) => item.trim().toUpperCase())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    final serviceType = result.serviceType ?? state.serviceType;
    final effectiveNextActions = _sanitizePaymentActionsForResolvedDraft(
      nextActions: nextActions,
      serviceType: serviceType,
      readyToConfirm: result.draftReadyToConfirm,
      paymentMethod: result.draftPaymentMethod,
    );

    final hints = _resolveActionHints(
      nextActions: effectiveNextActions,
      actionPayloads: result.actionPayloads,
      serviceType: serviceType,
    );
    if (preferMerchantMapPicker) {
      return _preferMerchantMapPickerHints(hints);
    }
    if (preferMerchantListPicker) {
      return _preferMerchantListPickerHints(hints);
    }

    return hints;
  }

  List<ChatbotMessageActionHint> _preferMerchantMapPickerHints(
    List<ChatbotMessageActionHint> hints,
  ) {
    var replacedMerchantHint = false;
    final mapped = hints
        .map((hint) {
          if (hint.type != ChatbotMessageActionType.openMerchantPicker) {
            return hint;
          }

          replacedMerchantHint = true;
          final normalizedMode = (hint.merchantMode ?? '').trim().toLowerCase();
          return ChatbotMessageActionHint(
            type: ChatbotMessageActionType.openMerchantPicker,
            label: 'Cari lewat Maps',
            merchantMode: normalizedMode == 'add' ? 'maps_add' : 'maps',
            initialLatitude: hint.initialLatitude,
            initialLongitude: hint.initialLongitude,
          );
        })
        .toList(growable: true);

    if (!replacedMerchantHint) {
      mapped.add(
        const ChatbotMessageActionHint(
          type: ChatbotMessageActionType.openMerchantPicker,
          label: 'Cari lewat Maps',
          merchantMode: 'maps',
        ),
      );
    }

    return mapped;
  }

  List<ChatbotMessageActionHint> _preferMerchantListPickerHints(
    List<ChatbotMessageActionHint> hints,
  ) {
    var replacedMerchantHint = false;
    final mapped = <ChatbotMessageActionHint>[];

    for (final hint in hints) {
      if (hint.type != ChatbotMessageActionType.openMerchantPicker) {
        continue;
      }

      replacedMerchantHint = true;
      final normalizedMode = (hint.merchantMode ?? '').trim().toLowerCase();
      final isAddMode = normalizedMode == 'add' || normalizedMode == 'maps_add';
      mapped.add(
        ChatbotMessageActionHint(
          type: ChatbotMessageActionType.openMerchantPicker,
          label: isAddMode ? 'Tambah Toko/Resto' : 'Pilih Toko/Resto',
          merchantMode: isAddMode ? 'add' : 'select',
          initialLatitude: hint.initialLatitude,
          initialLongitude: hint.initialLongitude,
        ),
      );
    }

    if (!replacedMerchantHint) {
      mapped.add(
        const ChatbotMessageActionHint(
          type: ChatbotMessageActionType.openMerchantPicker,
          label: 'Pilih Toko/Resto',
          merchantMode: 'select',
        ),
      );
    }

    return mapped;
  }

  List<String> _sanitizePaymentActionsForResolvedDraft({
    required List<String> nextActions,
    required String serviceType,
    required bool readyToConfirm,
    required String? paymentMethod,
  }) {
    final normalizedPayment = (paymentMethod ?? '').trim().toUpperCase();
    final normalizedServiceType = serviceType.trim().toLowerCase();
    final supportsPaymentConfirmation =
        normalizedServiceType == 'nitip' ||
        normalizedServiceType == 'antar_jemput' ||
        normalizedServiceType == 'kurir';
    if (!supportsPaymentConfirmation ||
        !readyToConfirm ||
        (normalizedPayment != 'COD' && normalizedPayment != 'TRANSFER')) {
      return nextActions;
    }

    final filtered = nextActions
        .where(
          (action) =>
              action != 'SET_PAYMENT_COD' && action != 'SET_PAYMENT_TRANSFER',
        )
        .toList(growable: true);

    if (!filtered.contains('CONFIRM_DRAFT')) {
      filtered.add('CONFIRM_DRAFT');
    }

    return filtered;
  }

  List<ChatbotMessageActionHint> _resolveActionHints({
    required List<String> nextActions,
    required Map<String, dynamic>? actionPayloads,
    required String serviceType,
  }) {
    final hasSavedAddress = _hasSavedAddressInProfile();
    final requireAddressFirst =
        nextActions.contains('OPEN_ADDRESSES') && !hasSavedAddress;

    final hints = <ChatbotMessageActionHint>[];
    final seen = <String>{};

    void add(ChatbotMessageActionHint hint) {
      final key = switch (hint.type) {
        ChatbotMessageActionType.openMapPicker =>
          '${hint.type.name}:${hint.target ?? '-'}',
        ChatbotMessageActionType.openMerchantPicker =>
          '${hint.type.name}:${hint.merchantMode ?? 'select'}:${hint.label}',
        ChatbotMessageActionType.openRoutePicker =>
          '${hint.type.name}:${hint.label}',
        ChatbotMessageActionType.sendPresetMessage =>
          '${hint.type.name}:${hint.presetMessage ?? hint.label}',
        ChatbotMessageActionType.openAddresses =>
          '${hint.type.name}:${hint.label}',
        ChatbotMessageActionType.openTrackOrder =>
          '${hint.type.name}:${hint.orderId ?? '-'}',
        ChatbotMessageActionType.openActivity =>
          '${hint.type.name}:${hint.label}',
        ChatbotMessageActionType.openDriverVerificationStatus =>
          '${hint.type.name}:${hint.label}',
      };
      if (seen.add(key)) {
        hints.add(hint);
      }
    }

    if (nextActions.contains('OPEN_ADDRESSES')) {
      add(
        const ChatbotMessageActionHint(
          type: ChatbotMessageActionType.openAddresses,
          label: 'Isi Alamat Saya',
        ),
      );
    }

    if (requireAddressFirst) {
      return hints;
    }

    if (nextActions.contains('OPEN_MERCHANT_PICKER')) {
      add(
        _merchantPickerHintFromPayload(
          actionPayloads,
          actionKey: 'OPEN_MERCHANT_PICKER',
          fallbackLabel: 'Pilih Toko/Resto',
          fallbackMode: 'select',
        ),
      );
    }

    if (nextActions.contains('OPEN_ADD_MERCHANT_PICKER')) {
      add(
        _merchantPickerHintFromPayload(
          actionPayloads,
          actionKey: 'OPEN_ADD_MERCHANT_PICKER',
          fallbackLabel: 'Tambah Toko/Resto',
          fallbackMode: 'add',
        ),
      );
    }

    final isTransport = serviceType == 'antar_jemput' || serviceType == 'kurir';
    final hasLegacyTransportMapAction =
        nextActions.contains('OPEN_MAP_PICKER_PICKUP') ||
        (serviceType == 'antar_jemput' &&
            nextActions.contains('OPEN_MAP_PICKER_DESTINATION')) ||
        (serviceType == 'kurir' &&
            nextActions.contains('OPEN_MAP_PICKER_DROPOFF'));
    final shouldUseRoutePicker =
        isTransport &&
        (nextActions.contains('OPEN_ROUTE_PICKER') ||
            hasLegacyTransportMapAction);

    if (shouldUseRoutePicker) {
      add(
        _routePickerHintFromPayload(actionPayloads, serviceType: serviceType),
      );
    }

    if (!shouldUseRoutePicker &&
        nextActions.contains('OPEN_MAP_PICKER_PICKUP')) {
      add(
        _mapPickerHintFromPayload(
          actionPayloads,
          'OPEN_MAP_PICKER_PICKUP',
          fallbackTarget: 'pickup',
          fallbackLabel: 'Pilih Lokasi Jemput',
        ),
      );
    }

    if (!shouldUseRoutePicker &&
        nextActions.contains('OPEN_MAP_PICKER_DESTINATION')) {
      add(
        _mapPickerHintFromPayload(
          actionPayloads,
          'OPEN_MAP_PICKER_DESTINATION',
          fallbackTarget: 'destination',
          fallbackLabel: 'Pilih Lokasi Tujuan',
        ),
      );
    }

    if (!shouldUseRoutePicker &&
        nextActions.contains('OPEN_MAP_PICKER_DROPOFF')) {
      add(
        _mapPickerHintFromPayload(
          actionPayloads,
          'OPEN_MAP_PICKER_DROPOFF',
          fallbackTarget: 'dropoff',
          fallbackLabel: 'Pilih Lokasi Tujuan',
        ),
      );
    }

    if (nextActions.contains('OPEN_MAP_PICKER_DELIVERY')) {
      add(
        _mapPickerHintFromPayload(
          actionPayloads,
          'OPEN_MAP_PICKER_DELIVERY',
          fallbackTarget: 'delivery',
          fallbackLabel: 'Pilih Alamat Antar',
        ),
      );
    }

    if (nextActions.contains('SET_PAYMENT_COD')) {
      add(
        _presetMessageHintFromPayload(
          actionPayloads,
          'SET_PAYMENT_COD',
          fallbackLabel: 'COD',
          fallbackMessage: 'COD',
        ),
      );
    }

    if (nextActions.contains('SET_PAYMENT_TRANSFER')) {
      add(
        _presetMessageHintFromPayload(
          actionPayloads,
          'SET_PAYMENT_TRANSFER',
          fallbackLabel: 'QRIS',
          fallbackMessage: 'QRIS',
        ),
      );
    }

    if (nextActions.contains('CONFIRM_DRAFT')) {
      add(
        _presetMessageHintFromPayload(
          actionPayloads,
          'CONFIRM_DRAFT',
          fallbackLabel: 'Buat Pesanan',
          fallbackMessage: 'Konfirmasi',
          labelOverride: 'Buat Pesanan',
        ),
      );
    }

    final shouldUseTransportRouteEditPicker =
        (serviceType == 'antar_jemput' || serviceType == 'kurir') &&
        nextActions.contains('RESET_DESTINATION') &&
        nextActions.contains('CHANGE_PICKUP');

    if (shouldUseTransportRouteEditPicker) {
      add(
        _transportRouteEditHintFromPayload(
          actionPayloads,
          serviceType: serviceType,
        ),
      );
    }

    if (!shouldUseTransportRouteEditPicker &&
        nextActions.contains('RESET_DESTINATION')) {
      add(
        _presetMessageHintFromPayload(
          actionPayloads,
          'RESET_DESTINATION',
          fallbackLabel: serviceType == 'antar_jemput'
              ? 'Ubah Lokasi Jemput/Tujuan'
              : 'Ubah Lokasi Tujuan',
          fallbackMessage: 'Ubah Tujuan',
          labelOverride: serviceType == 'antar_jemput'
              ? 'Ubah Lokasi Jemput/Tujuan'
              : 'Ubah Lokasi Tujuan',
        ),
      );
    }

    // Optional — shown on completed draft so user can swap pickup without
    // being forced to; backend sends this when pickup is already set.
    if (!shouldUseTransportRouteEditPicker &&
        nextActions.contains('CHANGE_PICKUP')) {
      add(
        _mapPickerHintFromPayload(
          actionPayloads,
          'CHANGE_PICKUP',
          fallbackTarget: 'pickup',
          fallbackLabel: serviceType == 'kurir'
              ? 'Ubah Lokasi Ambil'
              : 'Ubah Lokasi Jemput',
        ),
      );
    }

    return hints;
  }

  List<ChatbotMessageActionHint> _orderCreatedActionHints(
    ChatbotResult result,
  ) {
    return <ChatbotMessageActionHint>[
      ChatbotMessageActionHint(
        type: ChatbotMessageActionType.openTrackOrder,
        label: 'Lacak Pesanan',
        orderId: result.createdOrderId,
      ),
    ];
  }

  ChatbotMessageActionHint _presetMessageHintFromPayload(
    Map<String, dynamic>? actionPayloads,
    String actionKey, {
    required String fallbackLabel,
    required String fallbackMessage,
    String? labelOverride,
  }) {
    final payload = actionPayloads?[actionKey];
    final payloadMap = payload is Map<String, dynamic>
        ? payload
        : <String, dynamic>{};

    final label = (payloadMap['label']?.toString().trim() ?? '').isEmpty
        ? fallbackLabel
        : payloadMap['label'].toString().trim();
    final message = (payloadMap['message']?.toString().trim() ?? '').isEmpty
        ? fallbackMessage
        : payloadMap['message'].toString().trim();

    return ChatbotMessageActionHint(
      type: ChatbotMessageActionType.sendPresetMessage,
      label: labelOverride ?? label,
      presetMessage: message,
    );
  }

  ChatbotMessageActionHint _transportRouteEditHintFromPayload(
    Map<String, dynamic>? actionPayloads, {
    required String serviceType,
  }) {
    final isCourier = serviceType == 'kurir';

    ChatbotRoutePointHint pointFrom(
      String actionKey, {
      required String fallbackTarget,
      required String fallbackLabel,
    }) {
      final payload = actionPayloads?[actionKey];
      final payloadMap = payload is Map<String, dynamic>
          ? payload
          : <String, dynamic>{};
      final target = (payloadMap['target']?.toString().trim() ?? '').isEmpty
          ? fallbackTarget
          : payloadMap['target'].toString().trim();

      return ChatbotRoutePointHint(
        target: target,
        label: fallbackLabel,
        initialLatitude: _toDouble(payloadMap['initial_latitude']),
        initialLongitude: _toDouble(payloadMap['initial_longitude']),
        address: (payloadMap['address']?.toString().trim() ?? '').isEmpty
            ? (payloadMap['formatted_address']?.toString().trim() ?? '').isEmpty
                  ? null
                  : payloadMap['formatted_address']?.toString().trim()
            : payloadMap['address']?.toString().trim(),
      );
    }

    return ChatbotMessageActionHint(
      type: ChatbotMessageActionType.openRoutePicker,
      label: isCourier
          ? 'Ubah Lokasi Ambil/Tujuan'
          : 'Ubah Lokasi Jemput/Tujuan',
      routePoints: <ChatbotRoutePointHint>[
        pointFrom(
          'CHANGE_PICKUP',
          fallbackTarget: 'pickup',
          fallbackLabel: isCourier ? 'Titik Ambil' : 'Titik Jemput',
        ),
        pointFrom(
          'RESET_DESTINATION',
          fallbackTarget: isCourier ? 'dropoff' : 'destination',
          fallbackLabel: 'Titik Tujuan',
        ),
      ],
    );
  }

  ChatbotMessageActionHint _mapPickerHintFromPayload(
    Map<String, dynamic>? actionPayloads,
    String actionKey, {
    required String fallbackTarget,
    required String fallbackLabel,
    String? labelOverride,
  }) {
    final payload = actionPayloads?[actionKey];
    final payloadMap = payload is Map<String, dynamic>
        ? payload
        : <String, dynamic>{};

    final initialLatitude = _toDouble(payloadMap['initial_latitude']);
    final initialLongitude = _toDouble(payloadMap['initial_longitude']);

    return ChatbotMessageActionHint(
      type: ChatbotMessageActionType.openMapPicker,
      label:
          labelOverride ??
          ((payloadMap['label']?.toString().trim() ?? '').isEmpty
              ? fallbackLabel
              : payloadMap['label'].toString().trim()),
      target: (payloadMap['target']?.toString().trim() ?? '').isEmpty
          ? fallbackTarget
          : payloadMap['target'].toString().trim(),
      initialLatitude: initialLatitude,
      initialLongitude: initialLongitude,
    );
  }

  ChatbotMessageActionHint _merchantPickerHintFromPayload(
    Map<String, dynamic>? actionPayloads, {
    required String actionKey,
    required String fallbackLabel,
    required String fallbackMode,
  }) {
    final payload = actionPayloads?[actionKey];
    final payloadMap = payload is Map<String, dynamic>
        ? payload
        : <String, dynamic>{};
    final mode =
        (payloadMap['mode']?.toString().trim().toLowerCase() ?? '').isEmpty
        ? fallbackMode
        : payloadMap['mode'].toString().trim().toLowerCase();

    return ChatbotMessageActionHint(
      type: ChatbotMessageActionType.openMerchantPicker,
      label: _friendlyMerchantPickerLabel(
        (payloadMap['label']?.toString().trim() ?? '').isEmpty
            ? fallbackLabel
            : payloadMap['label'].toString().trim(),
      ),
      merchantMode: mode == 'add' ? 'add' : 'select',
      initialLatitude: _toDouble(payloadMap['initial_latitude']),
      initialLongitude: _toDouble(payloadMap['initial_longitude']),
    );
  }

  String _friendlyMerchantPickerLabel(String label) {
    final normalized = label.trim();
    if (normalized == 'Pilih Tempat di Map' || normalized == 'Pilih Tempat') {
      return 'Pilih Toko/Resto';
    }
    if (normalized == 'Tambah Tempat') {
      return 'Tambah Toko/Resto';
    }

    return label;
  }

  ChatbotMessageActionHint _routePickerHintFromPayload(
    Map<String, dynamic>? actionPayloads, {
    required String serviceType,
  }) {
    final payload = actionPayloads?['OPEN_ROUTE_PICKER'];
    final payloadMap = payload is Map<String, dynamic>
        ? payload
        : <String, dynamic>{};
    final points = payloadMap['points'] is Map<String, dynamic>
        ? payloadMap['points'] as Map<String, dynamic>
        : <String, dynamic>{};

    final isCourier = serviceType == 'kurir';
    final label = (payloadMap['label']?.toString().trim() ?? '').isEmpty
        ? (isCourier ? 'Atur Lokasi Ambil/Tujuan' : 'Atur Lokasi Jemput/Tujuan')
        : payloadMap['label'].toString().trim();

    ChatbotRoutePointHint pointFrom(
      String payloadKey, {
      required String fallbackTarget,
      required String fallbackLabel,
      String? legacyActionKey,
    }) {
      final rawPoint = points[payloadKey];
      final pointMap = rawPoint is Map<String, dynamic>
          ? rawPoint
          : <String, dynamic>{};
      final legacyPayload = legacyActionKey == null
          ? null
          : actionPayloads?[legacyActionKey];
      final legacyMap = legacyPayload is Map<String, dynamic>
          ? legacyPayload
          : <String, dynamic>{};
      final source = pointMap.isNotEmpty ? pointMap : legacyMap;

      final target = (source['target']?.toString().trim() ?? '').isEmpty
          ? fallbackTarget
          : source['target'].toString().trim();
      final pointLabel = (source['label']?.toString().trim() ?? '').isEmpty
          ? fallbackLabel
          : source['label'].toString().trim();

      return ChatbotRoutePointHint(
        target: target,
        label: pointLabel,
        initialLatitude: _toDouble(source['initial_latitude']),
        initialLongitude: _toDouble(source['initial_longitude']),
        address: (source['address']?.toString().trim() ?? '').isEmpty
            ? (source['formatted_address']?.toString().trim() ?? '').isEmpty
                  ? null
                  : source['formatted_address']?.toString().trim()
            : source['address']?.toString().trim(),
      );
    }

    return ChatbotMessageActionHint(
      type: ChatbotMessageActionType.openRoutePicker,
      label: label,
      routePoints: <ChatbotRoutePointHint>[
        pointFrom(
          'pickup',
          fallbackTarget: 'pickup',
          fallbackLabel: isCourier ? 'Titik Ambil' : 'Titik Jemput',
          legacyActionKey: 'OPEN_MAP_PICKER_PICKUP',
        ),
        pointFrom(
          isCourier ? 'dropoff' : 'destination',
          fallbackTarget: isCourier ? 'dropoff' : 'destination',
          fallbackLabel: 'Titik Tujuan',
          legacyActionKey: isCourier
              ? 'OPEN_MAP_PICKER_DROPOFF'
              : 'OPEN_MAP_PICKER_DESTINATION',
        ),
      ],
    );
  }

  double? _toDouble(dynamic raw) {
    if (raw is num) {
      return raw.toDouble();
    }
    if (raw is String) {
      return double.tryParse(raw);
    }

    return null;
  }

  List<ChatbotMessageActionHint> _bootstrapActionHints(String serviceType) {
    final hasSavedAddress = _hasSavedAddressInProfile();

    final hints = <ChatbotMessageActionHint>[];
    if (!hasSavedAddress) {
      hints.add(
        const ChatbotMessageActionHint(
          type: ChatbotMessageActionType.openAddresses,
          label: 'Isi Alamat Saya',
        ),
      );

      return hints;
    }

    if (serviceType != 'antar_jemput' &&
        serviceType != 'kurir' &&
        serviceType != 'nitip') {
      return const <ChatbotMessageActionHint>[];
    }

    hints.addAll(_serviceMapActionHints(serviceType));

    return hints;
  }

  bool _hasSavedAddressInProfile() {
    final authState = ref.read(authSessionProvider);
    final addresses = authState.profile?.addresses ?? const [];

    return hasUsableSavedAddress(addresses);
  }

  List<ChatbotMessageActionHint> _serviceMapActionHints(String serviceType) {
    if (serviceType == 'kurir') {
      return const <ChatbotMessageActionHint>[
        ChatbotMessageActionHint(
          type: ChatbotMessageActionType.openRoutePicker,
          label: 'Atur Lokasi Ambil/Tujuan',
          routePoints: <ChatbotRoutePointHint>[
            ChatbotRoutePointHint(target: 'pickup', label: 'Titik Ambil'),
            ChatbotRoutePointHint(target: 'dropoff', label: 'Titik Tujuan'),
          ],
        ),
      ];
    }

    if (serviceType == 'nitip') {
      return const <ChatbotMessageActionHint>[
        ChatbotMessageActionHint(
          type: ChatbotMessageActionType.openMerchantPicker,
          label: 'Pilih Toko/Resto',
        ),
        ChatbotMessageActionHint(
          type: ChatbotMessageActionType.openMapPicker,
          label: 'Pilih Alamat Antar',
          target: 'delivery',
        ),
      ];
    }

    if (serviceType != 'antar_jemput') {
      return const <ChatbotMessageActionHint>[];
    }

    return const <ChatbotMessageActionHint>[
      ChatbotMessageActionHint(
        type: ChatbotMessageActionType.openRoutePicker,
        label: 'Atur Lokasi Jemput/Tujuan',
        routePoints: <ChatbotRoutePointHint>[
          ChatbotRoutePointHint(target: 'pickup', label: 'Titik Jemput'),
          ChatbotRoutePointHint(target: 'destination', label: 'Titik Tujuan'),
        ],
      ),
    ];
  }

  String _addressBookUpdatedMessage(String serviceType) {
    if (serviceType == 'kurir') {
      return 'Alamat ambil kamu sudah tersimpan. Atur titik ambil dan tujuan lewat tombol di bawah, atau tetap kirim lewat chat.';
    }

    if (serviceType == 'nitip') {
      return 'Alamat antar utama kamu sudah tersimpan. Alamat ini dipakai untuk estimasi ongkir dan bisa diganti selama pesanan masih draft.';
    }

    return 'Alamat jemput kamu sudah tersimpan. Atur titik jemput dan tujuan lewat tombol di bawah, atau tetap kirim lewat chat.';
  }

  bool _isSameActionSet(
    List<ChatbotMessageActionHint> current,
    List<ChatbotMessageActionHint> incoming,
  ) {
    if (current.length != incoming.length) {
      return false;
    }

    final currentKeys = current
        .map(
          (item) =>
              '${item.type.name}:${item.target ?? '-'}:${item.presetMessage ?? '-'}:${item.orderId ?? '-'}:${item.merchantMode ?? '-'}:${item.label}',
        )
        .toSet();
    final incomingKeys = incoming
        .map(
          (item) =>
              '${item.type.name}:${item.target ?? '-'}:${item.presetMessage ?? '-'}:${item.orderId ?? '-'}:${item.merchantMode ?? '-'}:${item.label}',
        )
        .toSet();

    return currentKeys.length == incomingKeys.length &&
        currentKeys.containsAll(incomingKeys);
  }

  String _generateSessionId(String serviceType) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return 'chat-$serviceType-$now-${identityHashCode(this)}';
  }

  String _nowLabel() {
    return currentWibHourMinute();
  }
}

final chatbotConversationProvider =
    NotifierProvider.family<
      ChatbotConversationNotifier,
      ChatbotConversationState,
      String
    >(ChatbotConversationNotifier.new);
