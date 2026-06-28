import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _orderChatSourcePath =
    'lib/features/orders/presentation/screens/order_chat_screen.dart';

void main() {
  test('chat title keeps participant identity compact', () {
    final source = File(_orderChatSourcePath).readAsStringSync();
    final titleSource = source.substring(
      source.indexOf('class _ChatParticipantTitle'),
      source.indexOf('class _MessageBubble'),
    );

    expect(titleSource, contains('size: 30'));
    expect(titleSource, contains('fontSize: 13.5'));
    expect(titleSource, contains('fontSize: 11'));
    expect(titleSource, isNot(contains('size: 36')));
    expect(titleSource, isNot(contains('fontSize: 15.5')));
    expect(titleSource, isNot(contains('fontSize: 17')));
  });

  test('message bubble keeps sender label compact', () {
    final source = File(_orderChatSourcePath).readAsStringSync();
    final bubbleSource = source.substring(
      source.indexOf('class _MessageBubble'),
      source.indexOf('class _MessageTextWithAdaptiveMeta'),
    );

    expect(bubbleSource, contains('fontSize: 10'));
    expect(bubbleSource, isNot(contains('fontSize: 11')));
  });

  test('message bubble uses inline timestamp with bottom-right fallback', () {
    final source = File(_orderChatSourcePath).readAsStringSync();
    final bubbleSource = source.substring(
      source.indexOf('class _MessageBubble'),
      source.indexOf('class _MessageMeta'),
    );

    expect(bubbleSource, contains('IntrinsicWidth('));
    expect(bubbleSource, contains('_MessageTextWithAdaptiveMeta'));
    expect(bubbleSource, contains('WidgetSpan'));
    expect(bubbleSource, contains('Transform.translate'));
    expect(bubbleSource, contains('computeLineMetrics'));
    expect(bubbleSource, contains('alignment: Alignment.centerRight'));
  });

  test('opponent bubble nudges inline timestamp without stretching bubble', () {
    final source = File(_orderChatSourcePath).readAsStringSync();
    final bubbleSource = source.substring(
      source.indexOf('class _MessageBubble'),
      source.indexOf('class _MessageMeta'),
    );

    expect(bubbleSource, contains('alignInlineMetaToEnd: !isMine'));
    expect(bubbleSource, contains('_opponentMetaSpacing = 20'));
    expect(bubbleSource, contains('lastLineWidth + metaSpacing + metaWidth'));
    expect(bubbleSource, isNot(contains('_inlineMetaLeadingGap')));
    expect(bubbleSource, isNot(contains('maxInlineWidth - lines.last.width')));
  });

  test('photo message pins timestamp to attachment width', () {
    final source = File(_orderChatSourcePath).readAsStringSync();
    final bubbleSource = source.substring(
      source.indexOf('class _MessageBubble'),
      source.indexOf('class _MessageMeta'),
    );

    expect(bubbleSource, contains('_MessageAttachmentCaptionWithMeta'));
    expect(bubbleSource, contains('attachmentContentWidth'));
    expect(bubbleSource, contains('width: attachmentContentWidth'));
    expect(bubbleSource, contains('SizedBox('));
    expect(bubbleSource, contains('Expanded(child: Text(body'));
    expect(bubbleSource, contains('const SizedBox(width: 10)'));
  });
}
