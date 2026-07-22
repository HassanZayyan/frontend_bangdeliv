import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('courier route saved prompt instruction uses readable text size', () {
    final source = File(
      'lib/features/chatbot/presentation/widgets/chatbot_message_content.dart',
    ).readAsStringSync();
    final promptContent = source.substring(
      source.indexOf('Widget buildChatbotSimplePromptContent({'),
      source.indexOf('Widget buildChatbotUserRouteCommandContent({'),
    );

    expect(promptContent, contains('fontSize: 14.5'));
    expect(promptContent, contains('fontWeight: FontWeight.w500'));
  });
}
