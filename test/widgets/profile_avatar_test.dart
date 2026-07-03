import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/widgets/profile_avatar.dart';

void main() {
  testWidgets('ProfileAvatar clips image with a true oval mask', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: ProfileAvatar(
            name: 'Hassan',
            imageProvider: MemoryImage(_transparentPng),
            size: 42,
            borderWidth: 1,
            imageScale: 1.12,
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(ProfileAvatar)), const Size(42, 42));

    final clip = tester.widget<ClipOval>(find.byType(ClipOval));
    expect(clip.clipBehavior, Clip.antiAlias);

    final transform = tester.widget<Transform>(find.byType(Transform));
    expect(transform.transform.entry(0, 0), moreOrLessEquals(1.12));
    expect(transform.transform.entry(1, 1), moreOrLessEquals(1.12));
  });

  testWidgets('ProfileAvatar does not scale image by default', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: ProfileAvatar(
            name: 'Hassan',
            imageProvider: MemoryImage(_transparentPng),
          ),
        ),
      ),
    );

    expect(find.byType(ClipOval), findsOneWidget);
    expect(find.byType(Transform), findsNothing);
  });
}

final Uint8List _transparentPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAFgwJ/lH3Y2wAAAABJRU5ErkJggg==',
);
