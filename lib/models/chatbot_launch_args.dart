class ChatbotLaunchArgs {
  const ChatbotLaunchArgs({
    required this.serviceType,
    this.merchantId,
    this.merchantName,
    this.menuSuggestions = const <ChatbotMenuSuggestion>[],
  });

  final String serviceType;
  final int? merchantId;
  final String? merchantName;
  final List<ChatbotMenuSuggestion> menuSuggestions;
}

class ChatbotMenuSuggestion {
  const ChatbotMenuSuggestion({
    required this.name,
    required this.presetMessage,
    this.priceLabel,
    this.imageUrl,
  });

  final String name;
  final String presetMessage;
  final String? priceLabel;
  final String? imageUrl;

  String get label {
    final normalizedPrice = (priceLabel ?? '').trim();
    if (normalizedPrice.isEmpty) {
      return name;
    }

    return '$name - $normalizedPrice';
  }
}
