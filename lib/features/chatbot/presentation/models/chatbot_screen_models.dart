/// Value class murni untuk parsing/render pesan chatbot.
///
/// Dipindah dari ekor chatbot_screen.dart (dulu privat `_X`) agar bisa
/// dipakai widget dan util parser yang diekstrak dari layar.
library;

class ChatbotDraftMessageParts {
  const ChatbotDraftMessageParts({
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

class ChatbotShoppingDraftMessageParts {
  const ChatbotShoppingDraftMessageParts({
    required this.headline,
    required this.stops,
    required this.deliveryAddress,
    required this.estimateLines,
    required this.instructionLines,
  });

  final String headline;
  final List<ChatbotShoppingDraftStopParts> stops;
  final String deliveryAddress;
  final List<String> estimateLines;
  final List<String> instructionLines;
}

class ChatbotShoppingDraftStopParts {
  const ChatbotShoppingDraftStopParts({
    required this.label,
    required this.merchant,
    required this.items,
  });

  final String label;
  final String merchant;
  final List<String> items;
}

class ChatbotResetDestinationMessageParts {
  const ChatbotResetDestinationMessageParts({
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

class ChatbotShoppingSuccessMessageParts {
  const ChatbotShoppingSuccessMessageParts({
    required this.headline,
    required this.deliveryFeeLine,
    required this.instructionLine,
  });

  final String headline;
  final String deliveryFeeLine;
  final String instructionLine;
}

class ChatbotIncompleteShoppingDraftMessageParts {
  const ChatbotIncompleteShoppingDraftMessageParts({
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

class ChatbotSimplePromptMessageParts {
  const ChatbotSimplePromptMessageParts({
    required this.headline,
    required this.instructionLine,
  });

  final String headline;
  final String instructionLine;
}

class ChatbotUserRouteCommandParts {
  const ChatbotUserRouteCommandParts({required this.points});

  final List<ChatbotUserRouteCommandPoint> points;
}

class ChatbotUserRouteCommandPoint {
  const ChatbotUserRouteCommandPoint({required this.label, required this.value});

  final String label;
  final String value;
}

class ChatbotAssistantNoticeRow {
  const ChatbotAssistantNoticeRow({
    required this.label,
    required this.amount,
    required this.note,
  });

  final String label;
  final String amount;
  final String note;
}

class ChatbotServiceContext {
  final String serviceType;
  final String title;
  final String iconAsset;
  final String welcomeMessage;
  final String addressRequiredMessage;
  final List<ChatbotQuickTemplate> suggestions;

  const ChatbotServiceContext({
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

class ChatbotQuickTemplate {
  const ChatbotQuickTemplate(this.label, {this.chipLabel});

  /// Teks lengkap yang dimasukkan ke input (boleh multi-baris).
  final String label;

  /// Label ringkas untuk chip. Bila null, chip memakai [label].
  /// Diperlukan untuk template multi-baris karena chip hanya muat 1 baris.
  final String? chipLabel;

  static final RegExp placeholderPattern = RegExp(r'\[[^\]]+\]');

  bool get sendsImmediately => !placeholderPattern.hasMatch(label);
}

/// Segmen teks inline untuk render bold sederhana (penanda `**teks**`).
class ChatbotBoldSegment {
  const ChatbotBoldSegment(this.text, {required this.isBold});

  final String text;
  final bool isBold;
}
