import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/chatbot_model.dart';
import '../services/api_exception.dart';
import '../services/chatbot_api_service.dart';
import '../utils/address_readiness.dart';
import '../utils/order_formatters.dart';
import 'auth_session_provider.dart';
import 'api_providers.dart';

enum ChatbotMessageActionType {
  openAddresses,
  openMapPicker,
  openRoutePicker,
  sendPresetMessage,
  openTrackOrder,
  openActivity,
}

class ChatbotRoutePointHint {
  const ChatbotRoutePointHint({
    required this.target,
    required this.label,
    this.initialLatitude,
    this.initialLongitude,
  });

  final String target;
  final String label;
  final double? initialLatitude;
  final double? initialLongitude;
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
    this.initialLatitude,
    this.initialLongitude,
    this.routePoints = const <ChatbotRoutePointHint>[],
  });

  final ChatbotMessageActionType type;
  final String label;
  final String? target;
  final String? presetMessage;
  final int? orderId;
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
    required this.sessions,
    required this.isBootstrapping,
    required this.isSending,
    required this.isApplyingAction,
    required this.hasInitialized,
    required this.errorMessage,
  });

  final String serviceType;
  final String? sessionId;
  final List<ChatbotConversationMessage> messages;
  final List<ChatbotSessionSummary> sessions;
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
    List<ChatbotSessionSummary>? sessions,
    bool? isBootstrapping,
    bool? isSending,
    bool? isApplyingAction,
    bool? hasInitialized,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return ChatbotConversationState(
      serviceType: serviceType ?? this.serviceType,
      sessionId: sessionId ?? this.sessionId,
      messages: messages ?? this.messages,
      sessions: sessions ?? this.sessions,
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
      sessions: <ChatbotSessionSummary>[],
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
      sessions: const <ChatbotSessionSummary>[],
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

    final api = ref.read(chatbotApiServiceProvider);
    final fallbackSessionId = _generateSessionId(serviceType);

    try {
      final prefs = await SharedPreferences.getInstance();
      final storageKey = _sessionStorageKey(serviceType);
      final storedSessionId = prefs.getString(storageKey)?.trim();

      final sessions = await api.fetchSessions(serviceType: serviceType);
      var sessionId = (storedSessionId == null || storedSessionId.isEmpty)
          ? (sessions.isNotEmpty ? sessions.first.sessionId : fallbackSessionId)
          : storedSessionId;

      var messages = <ChatbotConversationMessage>[];
      if (sessionId.isNotEmpty) {
        try {
          final history = await api.fetchSessionHistory(sessionId, limit: 100);
          if (history.sessionId.isNotEmpty) {
            sessionId = history.sessionId;
          }

          messages = history.messages
              .map((entry) => _messageFromHistoryEntry(entry, serviceType))
              .toList(growable: false);
        } catch (_) {
          sessionId = fallbackSessionId;
          messages = const <ChatbotConversationMessage>[];
        }
      }

      if (messages.isEmpty) {
        messages = <ChatbotConversationMessage>[
          _botMessage(
            text: welcomeMessage,
            timestamp: _nowLabel(),
            actionHints: _bootstrapActionHints(serviceType),
          ),
        ];
      }

      await prefs.setString(storageKey, sessionId);

      state = state.copyWith(
        serviceType: serviceType,
        sessionId: sessionId,
        sessions: sessions,
        messages: messages,
        isBootstrapping: false,
        clearErrorMessage: true,
      );
    } catch (_) {
      state = state.copyWith(
        serviceType: serviceType,
        sessionId: fallbackSessionId,
        messages: <ChatbotConversationMessage>[
          _botMessage(
            text: welcomeMessage,
            timestamp: _nowLabel(),
            actionHints: _bootstrapActionHints(serviceType),
          ),
        ],
        isBootstrapping: false,
        errorMessage: 'Gagal memuat histori chat. Sesi baru dibuat.',
      );

      await _persistSessionId(serviceType, fallbackSessionId);
    }
  }

  Future<void> refreshSessions({required String serviceType}) async {
    _ensureService(serviceType);

    final api = ref.read(chatbotApiServiceProvider);
    try {
      final sessions = await api.fetchSessions(serviceType: serviceType);
      state = state.copyWith(sessions: sessions, clearErrorMessage: true);
    } catch (_) {
      // Silent refresh failure.
    }
  }

  Future<void> selectSession(
    String sessionId, {
    required String serviceType,
    required String welcomeMessage,
  }) async {
    _ensureService(serviceType);

    final normalized = sessionId.trim();
    if (normalized.isEmpty || state.isBootstrapping) {
      return;
    }

    state = state.copyWith(isBootstrapping: true, clearErrorMessage: true);

    final api = ref.read(chatbotApiServiceProvider);
    try {
      final history = await api.fetchSessionHistory(normalized, limit: 100);
      final resolvedSessionId = history.sessionId.isNotEmpty
          ? history.sessionId
          : normalized;

      var messages = history.messages
          .map((entry) => _messageFromHistoryEntry(entry, serviceType))
          .toList(growable: false);

      if (messages.isEmpty) {
        messages = <ChatbotConversationMessage>[
          _botMessage(
            text: welcomeMessage,
            timestamp: _nowLabel(),
            actionHints: _bootstrapActionHints(serviceType),
          ),
        ];
      }

      await _persistSessionId(serviceType, resolvedSessionId);

      state = state.copyWith(
        serviceType: serviceType,
        sessionId: resolvedSessionId,
        messages: messages,
        isBootstrapping: false,
        clearErrorMessage: true,
      );

      await refreshSessions(serviceType: serviceType);
    } catch (_) {
      state = state.copyWith(
        isBootstrapping: false,
        errorMessage: 'Gagal membuka sesi chat terpilih.',
      );
    }
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
      await _persistSessionId(serviceType, sessionId);
    }

    state = state.copyWith(
      serviceType: serviceType,
      sessionId: sessionId,
      messages: <ChatbotConversationMessage>[
        ...state.messages,
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

    final api = ref.read(chatbotApiServiceProvider);
    try {
      final result = await api.sendMessage(
        message,
        serviceType: serviceType,
        sessionId: sessionId,
      );

      final canonicalSessionId = result.sessionId?.trim();
      if (canonicalSessionId != null && canonicalSessionId.isNotEmpty) {
        sessionId = canonicalSessionId;
      }

      await _persistSessionId(serviceType, sessionId);

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

      await refreshSessions(serviceType: serviceType);
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

    state = state.copyWith(isApplyingAction: true, clearErrorMessage: true);

    final api = ref.read(chatbotApiServiceProvider);
    try {
      final result = await api.patchSessionLocation(
        sessionId,
        serviceType: serviceType,
        target: target,
        latitude: latitude,
        longitude: longitude,
        address: address,
      );

      final canonicalSessionId = result.sessionId?.trim();
      final resolvedSessionId =
          canonicalSessionId != null && canonicalSessionId.isNotEmpty
          ? canonicalSessionId
          : sessionId;

      await _persistSessionId(serviceType, resolvedSessionId);

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

      await refreshSessions(serviceType: serviceType);
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

    state = state.copyWith(isApplyingAction: true, clearErrorMessage: true);

    final api = ref.read(chatbotApiServiceProvider);
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

      final canonicalSessionId = result.sessionId?.trim();
      final resolvedSessionId =
          canonicalSessionId != null && canonicalSessionId.isNotEmpty
          ? canonicalSessionId
          : sessionId;

      await _persistSessionId(serviceType, resolvedSessionId);

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

      await refreshSessions(serviceType: serviceType);
    } catch (_) {
      state = state.copyWith(
        isApplyingAction: false,
        errorMessage: 'Gagal memperbarui titik rute.',
      );
    }
  }

  void onAddressBookUpdated({required String serviceType}) {
    _ensureService(serviceType);

    if (serviceType != 'antar_jemput' && serviceType != 'kurir') {
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
          text: serviceType == 'kurir'
              ? 'Alamat ambil kamu sudah tersimpan. Atur titik ambil dan tujuan lewat tombol di bawah, atau tetap kirim lewat chat.'
              : 'Alamat jemput kamu sudah tersimpan. Atur titik jemput dan tujuan lewat tombol di bawah, atau tetap kirim lewat chat.',
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

  ChatbotConversationMessage _messageFromHistoryEntry(
    ChatbotHistoryMessage entry,
    String serviceType,
  ) {
    if (entry.isUser) {
      return ChatbotConversationMessage(
        text: entry.message,
        timestamp: _labelFromDateTime(entry.createdAt),
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
      text: entry.message,
      timestamp: _labelFromDateTime(entry.createdAt),
      isUser: false,
      meta: metaParts.join(' • '),
      actionHints: entry.aiResponse == null
          ? const <ChatbotMessageActionHint>[]
          : _resolveActionHintsFromPayload(
              entry.aiResponse!,
              serviceType: effectiveServiceType,
            ),
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

    return _resolveActionHints(
      nextActions: nextActions,
      actionPayloads: result.actionPayloads,
      serviceType: result.serviceType ?? state.serviceType,
    );
  }

  List<ChatbotMessageActionHint> _resolveActionHintsFromPayload(
    Map<String, dynamic> payload, {
    required String serviceType,
  }) {
    final validation = (payload['validation'] is Map<String, dynamic>)
        ? payload['validation'] as Map<String, dynamic>
        : null;
    final nextActionsRaw = (validation?['next_actions'] is List<dynamic>)
        ? validation!['next_actions'] as List<dynamic>
        : const <dynamic>[];

    final nextActions = nextActionsRaw
        .map((item) => item.toString().trim().toUpperCase())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);

    final actionPayloads = (payload['action_payloads'] is Map<String, dynamic>)
        ? payload['action_payloads'] as Map<String, dynamic>
        : null;

    return _resolveActionHints(
      nextActions: nextActions,
      actionPayloads: actionPayloads,
      serviceType: serviceType,
    );
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
          fallbackLabel: 'Pilih Titik Jemput',
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
          fallbackLabel: 'Pilih Titik Tujuan',
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
          fallbackLabel: 'Pilih Titik Tujuan',
        ),
      );
    }

    if (nextActions.contains('OPEN_MAP_PICKER_DELIVERY')) {
      add(
        _mapPickerHintFromPayload(
          actionPayloads,
          'OPEN_MAP_PICKER_DELIVERY',
          fallbackTarget: 'delivery',
          fallbackLabel: 'Pilih Titik Antar',
        ),
      );
    }

    if (nextActions.contains('CONFIRM_DRAFT')) {
      add(
        _presetMessageHintFromPayload(
          actionPayloads,
          'CONFIRM_DRAFT',
          fallbackLabel: 'Konfirmasi',
          fallbackMessage: 'Konfirmasi',
        ),
      );
    }

    if (nextActions.contains('RESET_DESTINATION')) {
      add(
        _presetMessageHintFromPayload(
          actionPayloads,
          'RESET_DESTINATION',
          fallbackLabel: 'Ubah Tujuan',
          fallbackMessage: 'Ubah Tujuan',
        ),
      );
    }

    // Optional — shown on completed draft so user can swap pickup without
    // being forced to; backend sends this when pickup is already set.
    if (nextActions.contains('CHANGE_PICKUP')) {
      add(
        _mapPickerHintFromPayload(
          actionPayloads,
          'CHANGE_PICKUP',
          fallbackTarget: 'pickup',
          fallbackLabel: 'Ubah Titik Jemput',
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
      label: label,
      presetMessage: message,
    );
  }

  ChatbotMessageActionHint _mapPickerHintFromPayload(
    Map<String, dynamic>? actionPayloads,
    String actionKey, {
    required String fallbackTarget,
    required String fallbackLabel,
  }) {
    final payload = actionPayloads?[actionKey];
    final payloadMap = payload is Map<String, dynamic>
        ? payload
        : <String, dynamic>{};

    final initialLatitude = _toDouble(payloadMap['initial_latitude']);
    final initialLongitude = _toDouble(payloadMap['initial_longitude']);

    return ChatbotMessageActionHint(
      type: ChatbotMessageActionType.openMapPicker,
      label: (payloadMap['label']?.toString().trim() ?? '').isEmpty
          ? fallbackLabel
          : payloadMap['label'].toString().trim(),
      target: (payloadMap['target']?.toString().trim() ?? '').isEmpty
          ? fallbackTarget
          : payloadMap['target'].toString().trim(),
      initialLatitude: initialLatitude,
      initialLongitude: initialLongitude,
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
        ? (isCourier
              ? 'Atur Titik Ambil & Tujuan'
              : 'Atur Titik Jemput & Tujuan')
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

    if (serviceType == 'nitip') {
      return const <ChatbotMessageActionHint>[];
    }

    if (serviceType != 'antar_jemput' && serviceType != 'kurir') {
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
          label: 'Atur Titik Ambil & Tujuan',
          routePoints: <ChatbotRoutePointHint>[
            ChatbotRoutePointHint(target: 'pickup', label: 'Titik Ambil'),
            ChatbotRoutePointHint(target: 'dropoff', label: 'Titik Tujuan'),
          ],
        ),
      ];
    }

    return const <ChatbotMessageActionHint>[
      ChatbotMessageActionHint(
        type: ChatbotMessageActionType.openRoutePicker,
        label: 'Atur Titik Jemput & Tujuan',
        routePoints: <ChatbotRoutePointHint>[
          ChatbotRoutePointHint(target: 'pickup', label: 'Titik Jemput'),
          ChatbotRoutePointHint(target: 'destination', label: 'Titik Tujuan'),
        ],
      ),
    ];
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
              '${item.type.name}:${item.target ?? '-'}:${item.presetMessage ?? '-'}:${item.orderId ?? '-'}:${item.label}',
        )
        .toSet();
    final incomingKeys = incoming
        .map(
          (item) =>
              '${item.type.name}:${item.target ?? '-'}:${item.presetMessage ?? '-'}:${item.orderId ?? '-'}:${item.label}',
        )
        .toSet();

    return currentKeys.length == incomingKeys.length &&
        currentKeys.containsAll(incomingKeys);
  }

  String _sessionStorageKey(String serviceType) {
    return 'chatbot_session_id_$serviceType';
  }

  Future<void> _persistSessionId(String serviceType, String sessionId) async {
    final normalized = sessionId.trim();
    if (normalized.isEmpty) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionStorageKey(serviceType), normalized);
    } catch (_) {
      // Best effort cache write.
    }
  }

  String _generateSessionId(String serviceType) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return 'chat-$serviceType-$now-${identityHashCode(this)}';
  }

  String _nowLabel() {
    return currentWibHourMinute();
  }

  String _labelFromDateTime(DateTime? value) {
    if (value == null) {
      return _nowLabel();
    }

    return formatTime(value, includeZone: false);
  }
}

final chatbotConversationProvider =
    NotifierProvider<ChatbotConversationNotifier, ChatbotConversationState>(
      ChatbotConversationNotifier.new,
    );
