import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('courier route saved prompt instruction uses readable text size', () {
    final source = File('lib/screens/chatbot_screen.dart').readAsStringSync();
    final promptContent = source.substring(
      source.indexOf('Widget _buildSimplePromptContent({'),
      source.indexOf('Widget _buildAssistantNotice(String text)'),
    );

    expect(promptContent, contains('fontSize: 14.5'));
    expect(promptContent, contains('fontWeight: FontWeight.w500'));
  });
}
