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

enum ChatbotMessageActionType {
  openAddresses,
  openMapPicker,
  openMerchantPicker,
  openRoutePicker,
  sendPresetMessage,
  openTrackOrder,
  openActivity,
}

class ChatbotCommandParser {
  const ChatbotCommandParser._();

  static bool isRestartCommand(String rawMessage) {
    final normalized = rawMessage.trim().toLowerCase();

    return normalized == 'refresh' || normalized == '/refresh';
  }
}

class ChatbotRoutePointHint {
  const ChatbotRoutePointHint({
    required this.target,
    required this.label,
    this.initialLatitude,
    this.initialLongitude,
    this.address,
  });

  final String target;
  final String label;
  final double? initialLatitude;
  final double? initialLongitude;
  final String? address;
}

class ChatbotLocationPatch {
  const ChatbotLocationPatch({
    required this.target,
    required this.latitude,
    required this.longitude,
    this.address,
  });

  final String target;
  final double latitude;
  final double longitude;
  final String? address;
}

class ChatbotMessageActionHint {
  const ChatbotMessageActionHint({
    required this.type,
    required this.label,
    this.target,
    this.presetMessage,
    this.orderId,
    this.merchantMode,
    this.initialLatitude,
    this.initialLongitude,
    this.routePoints = const <ChatbotRoutePointHint>[],
  });

  final ChatbotMessageActionType type;
  final String label;
  final String? target;
  final String? presetMessage;
  final int? orderId;
  final String? merchantMode;
  final double? initialLatitude;
  final double? initialLongitude;
  final List<ChatbotRoutePointHint> routePoints;
}

class ChatbotConversationMessage {
  const ChatbotConversationMessage({
    required this.text,
    required this.timestamp,
    required this.isUser,
    this.meta,
    this.actionHints = const <ChatbotMessageActionHint>[],
  });

  final String text;
  final String timestamp;
  final bool isUser;
  final String? meta;
  final List<ChatbotMessageActionHint> actionHints;
}

class ChatbotConversationState {
  const ChatbotConversationState({
    required this.serviceType,
    required this.sessionId,
    required this.messages,
    required this.isBootstrapping,
    required this.isSending,
    required this.isApplyingAction,
    required this.hasInitialized,
    required this.errorMessage,
  });

  final String serviceType;
  final String? sessionId;
  final List<ChatbotConversationMessage> messages;
  final bool isBootstrapping;
  final bool isSending;
  final bool isApplyingAction;
  final bool hasInitialized;
  final String? errorMessage;

  bool get isBusy => isBootstrapping || isSending || isApplyingAction;

  ChatbotConversationState copyWith({
    String? serviceType,
    String? sessionId,
    List<ChatbotConversationMessage>? messages,
    bool? isBootstrapping,
    bool? isSending,
    bool? isApplyingAction,
    bool? hasInitialized,
    String? errorMessage,
    bool clearSessionId = false,
    bool clearErrorMessage = false,
  }) {
    return ChatbotConversationState(
      serviceType: serviceType ?? this.serviceType,
      sessionId: clearSessionId ? null : (sessionId ?? this.sessionId),
      messages: messages ?? this.messages,
      isBootstrapping: isBootstrapping ?? this.isBootstrapping,
      isSending: isSending ?? this.isSending,
      isApplyingAction: isApplyingAction ?? this.isApplyingAction,
      hasInitialized: hasInitialized ?? this.hasInitialized,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }
}

class ChatbotConversationNotifier extends Notifier<ChatbotConversationState> {
  @override
  ChatbotConversationState build() {
    return const ChatbotConversationState(
      serviceType: 'nitip',
      sessionId: null,
      messages: <ChatbotConversationMessage>[],
      isBootstrapping: false,
      isSending: false,
      isApplyingAction: false,
      hasInitialized: false,
      errorMessage: null,
    );
  }

  void _ensureService(String serviceType) {
    if (state.serviceType == serviceType) {
      return;
    }

    state = ChatbotConversationState(
      serviceType: serviceType,
      sessionId: null,
      messages: const <ChatbotConversationMessage>[],
      isBootstrapping: false,
      isSending: false,
      isApplyingAction: false,
      hasInitialized: false,
      errorMessage: null,
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

  Future<void> sendMessage(
    String rawMessage, {
    required String serviceType,
  }) async {
    _ensureService(serviceType);

    final message = rawMessage.trim();
    if (message.isEmpty || state.isSending || state.isBootstrapping) {
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
      ],
      isSending: true,
      clearErrorMessage: true,
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
        messages: <ChatbotConversationMessage>[
          ...state.messages,
          _messageFromResult(result, serviceType),
        ],
        clearErrorMessage: true,
      );
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
    }
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
        messages: <ChatbotConversationMessage>[
          ...state.messages,
          _messageFromResult(result, serviceType),
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
    );

    final api = ref.read(chatbotRepositoryProvider);
    try {
      final result = await api.patchSessionMerchant(
        sessionId,
        serviceType: serviceType,
        merchantId: merchantId,
        merchantPlace: merchantPlace,
        mode: mode,
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
    );
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
    );
  }

  void onAddressBookUpdated({required String serviceType}) {
    _ensureService(serviceType);

    if (serviceType != 'antar_jemput' &&
        serviceType != 'kurir' &&
        serviceType != 'nitip') {
      return;
    }

    if (!_hasSavedAddressInProfile()) {
      return;
    }

    final mapHints = _serviceMapActionHints(serviceType);
    final lastAssistant = state.messages.isEmpty ? null : state.messages.last;
    if (lastAssistant != null &&
        !lastAssistant.isUser &&
        _isSameActionSet(lastAssistant.actionHints, mapHints)) {
      return;
    }

    state = state.copyWith(
      messages: <ChatbotConversationMessage>[
        ...state.messages,
        _botMessage(
          text: _addressBookUpdatedMessage(serviceType),
          timestamp: _nowLabel(),
          actionHints: mapHints,
        ),
      ],
      clearErrorMessage: true,
    );
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
    String serviceType,
  ) {
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

    return ChatbotConversationMessage(
      text: result.toAssistantText(),
      timestamp: _nowLabel(),
      isUser: false,
      meta: metaParts.join(' • '),
      actionHints: _resolveActionHintsFromResult(result),
    );
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
    ChatbotResult result,
  ) {
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

    return _resolveActionHints(
      nextActions: effectiveNextActions,
      actionPayloads: result.actionPayloads,
      serviceType: serviceType,
    );
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
          fallbackLabel: 'Pilih Tempat di Map',
          fallbackMode: 'select',
        ),
      );
    }

    if (nextActions.contains('OPEN_ADD_MERCHANT_PICKER')) {
      add(
        _merchantPickerHintFromPayload(
          actionPayloads,
          actionKey: 'OPEN_ADD_MERCHANT_PICKER',
          fallbackLabel: 'Tambah Tempat',
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
      final deliveryFallbackLabel =
          serviceType == 'nitip' && nextActions.contains('CONFIRM_DRAFT')
          ? 'Ganti Lokasi Antar'
          : 'Pilih Lokasi Antar';
      add(
        _mapPickerHintFromPayload(
          actionPayloads,
          'OPEN_MAP_PICKER_DELIVERY',
          fallbackTarget: 'delivery',
          fallbackLabel: deliveryFallbackLabel,
          labelOverride: deliveryFallbackLabel == 'Ganti Lokasi Antar'
              ? deliveryFallbackLabel
              : null,
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

    final shouldUseCourierRouteEditPicker =
        serviceType == 'kurir' &&
        nextActions.contains('RESET_DESTINATION') &&
        nextActions.contains('CHANGE_PICKUP');

    if (shouldUseCourierRouteEditPicker) {
      add(_courierRouteEditHintFromPayload(actionPayloads));
    }

    if (!shouldUseCourierRouteEditPicker &&
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
    if (!shouldUseCourierRouteEditPicker &&
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
    final hints = <ChatbotMessageActionHint>[
      ChatbotMessageActionHint(
        type: ChatbotMessageActionType.openTrackOrder,
        label: 'Lacak Pesanan',
        orderId: result.createdOrderId,
      ),
      const ChatbotMessageActionHint(
        type: ChatbotMessageActionType.openActivity,
        label: 'Lihat Aktivitas',
      ),
    ];

    return hints;
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

  ChatbotMessageActionHint _courierRouteEditHintFromPayload(
    Map<String, dynamic>? actionPayloads,
  ) {
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
      label: 'Ubah Lokasi Ambil/Tujuan',
      routePoints: <ChatbotRoutePointHint>[
        pointFrom(
          'CHANGE_PICKUP',
          fallbackTarget: 'pickup',
          fallbackLabel: 'Titik Ambil',
        ),
        pointFrom(
          'RESET_DESTINATION',
          fallbackTarget: 'dropoff',
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
      label: (payloadMap['label']?.toString().trim() ?? '').isEmpty
          ? fallbackLabel
          : payloadMap['label'].toString().trim(),
      merchantMode: mode == 'add' ? 'add' : 'select',
      initialLatitude: _toDouble(payloadMap['initial_latitude']),
      initialLongitude: _toDouble(payloadMap['initial_longitude']),
    );
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
          label: 'Pilih Tempat di Map',
        ),
        ChatbotMessageActionHint(
          type: ChatbotMessageActionType.openMapPicker,
          label: 'Pilih Lokasi Antar',
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
      return 'Alamat antar pesanan kamu sudah tersimpan. Pilih titik antar lewat tombol di bawah, atau tetap kirim lewat chat.';
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
    NotifierProvider<ChatbotConversationNotifier, ChatbotConversationState>(
      ChatbotConversationNotifier.new,
    );
