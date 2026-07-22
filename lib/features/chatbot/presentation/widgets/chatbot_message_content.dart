/// Builder konten bubble pesan chatbot yang murni berbasis parts + warna.
///
/// Dipindah dari method privat `_ChatbotScreenState` (move-only, tanpa
/// perubahan perilaku).
library;

import 'package:flutter/material.dart';

import '../../../../config/app_colors.dart';
import '../models/chatbot_screen_models.dart';
import '../utils/chatbot_message_text.dart';

/// Merender teks bubble polos dengan dukungan penanda bold inline `**teks**`.
///
/// Bila tak ada penanda, mengembalikan [Text] biasa (tanpa overhead RichText).
Widget buildChatbotInlineText(
  String text, {
  required Color color,
  double height = 1.5,
}) {
  final segments = parseInlineBoldSegments(text);
  if (segments.length == 1 && !segments.first.isBold) {
    return Text(text, style: TextStyle(color: color, height: height));
  }

  return Text.rich(
    TextSpan(
      children: [
        for (final segment in segments)
          TextSpan(
            text: segment.text,
            style: segment.isBold
                ? const TextStyle(fontWeight: FontWeight.w700)
                : null,
          ),
      ],
    ),
    style: TextStyle(color: color, height: height),
  );
}

Widget buildChatbotDraftField({
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

Widget buildChatbotSimplePromptContent({
  required ChatbotSimplePromptMessageParts parts,
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
        buildChatbotSimplePromptInstruction(parts.instructionLine),
      ],
    ],
  );
}

Widget buildChatbotSimplePromptInstruction(String text) {
  final lines = splitSimplePromptInstruction(text);
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
            color: isExampleInstructionLine(lines[index])
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

Widget buildChatbotUserRouteCommandContent({
  required ChatbotUserRouteCommandParts parts,
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
