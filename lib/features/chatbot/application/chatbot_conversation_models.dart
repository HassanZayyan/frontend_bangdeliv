import '../../../models/chatbot_launch_args.dart';
import '../../../models/chatbot_model.dart';

enum ChatbotMessageActionType {
  openAddresses,
  openMapPicker,
  openMerchantPicker,
  openRoutePicker,
  sendPresetMessage,
  openTrackOrder,
  openActivity,
  openDriverVerificationStatus,
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
    this.replaceTargetStopId,
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

  /// Saat `merchantMode == 'replace'`, stop_id slot yang ingin diganti.
  final String? replaceTargetStopId;
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

class ChatbotMenuSelectorDraft {
  const ChatbotMenuSelectorDraft({
    required this.merchantName,
    required this.merchantMode,
    required this.menus,
    required this.quantities,
    this.targetStopId,
  });

  final String merchantName;
  final String merchantMode;
  final List<ChatbotMenuSuggestion> menus;
  final List<int> quantities;

  /// stop_id slot yang diwakili menu selector ini. Tombol "Ganti Toko/Resto"
  /// memakainya untuk mengganti persis stop tersebut, bukan menambah stop baru.
  final String? targetStopId;

  ChatbotMenuSelectorDraft copyWith({
    String? merchantName,
    String? merchantMode,
    List<ChatbotMenuSuggestion>? menus,
    List<int>? quantities,
    String? targetStopId,
  }) {
    return ChatbotMenuSelectorDraft(
      merchantName: merchantName ?? this.merchantName,
      merchantMode: merchantMode ?? this.merchantMode,
      menus: menus ?? this.menus,
      quantities: quantities ?? this.quantities,
      targetStopId: targetStopId ?? this.targetStopId,
    );
  }
}

extension ChatbotMenuSelectorDraftX on ChatbotMenuSelectorDraft {
  int get selectedCount {
    return quantities.fold<int>(
      0,
      (total, quantity) => total + quantity.clamp(0, 99).toInt(),
    );
  }

  String confirmationMessage() {
    final lines = <String>[];
    for (var index = 0; index < menus.length; index++) {
      final quantity = index < quantities.length
          ? quantities[index].clamp(0, 99).toInt()
          : 0;
      if (quantity <= 0) {
        continue;
      }

      lines.add('${menus[index].name.trim()} $quantity');
    }

    return lines.join('\n');
  }
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
    required this.activeOrderId,
    required this.menuSelectorDraft,
    required this.menuSelectorNotice,
    this.pendingMenuSelectorRequest,
  });

  final String serviceType;
  final String? sessionId;
  final List<ChatbotConversationMessage> messages;
  final bool isBootstrapping;
  final bool isSending;
  final bool isApplyingAction;
  final bool hasInitialized;
  final String? errorMessage;
  final int? activeOrderId;
  final ChatbotMenuSelectorDraft? menuSelectorDraft;
  final String? menuSelectorNotice;

  /// Sinyal transien: backend meminta membuka menu selector resto terdaftar
  /// (mis. balasan `Lihat menu [resto]`). Dikonsumsi sekali oleh layar.
  final ChatbotMenuSelectorRequest? pendingMenuSelectorRequest;

  bool get isBusy => isBootstrapping || isSending || isApplyingAction;
  bool get hasActiveOrder => (activeOrderId ?? 0) > 0;
  bool get hasMenuSelectorSurface =>
      menuSelectorDraft != null || (menuSelectorNotice ?? '').trim().isNotEmpty;

  ChatbotConversationState copyWith({
    String? serviceType,
    String? sessionId,
    List<ChatbotConversationMessage>? messages,
    bool? isBootstrapping,
    bool? isSending,
    bool? isApplyingAction,
    bool? hasInitialized,
    String? errorMessage,
    int? activeOrderId,
    ChatbotMenuSelectorDraft? menuSelectorDraft,
    String? menuSelectorNotice,
    ChatbotMenuSelectorRequest? pendingMenuSelectorRequest,
    bool clearSessionId = false,
    bool clearErrorMessage = false,
    bool clearActiveOrderId = false,
    bool clearMenuSelectorSurface = false,
    bool clearPendingMenuSelectorRequest = false,
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
      activeOrderId: clearActiveOrderId
          ? null
          : (activeOrderId ?? this.activeOrderId),
      menuSelectorDraft: clearMenuSelectorSurface
          ? null
          : (menuSelectorDraft ?? this.menuSelectorDraft),
      menuSelectorNotice: clearMenuSelectorSurface
          ? null
          : (menuSelectorNotice ?? this.menuSelectorNotice),
      pendingMenuSelectorRequest: clearPendingMenuSelectorRequest
          ? null
          : (pendingMenuSelectorRequest ?? this.pendingMenuSelectorRequest),
    );
  }
}
