/// Parser teks murni untuk pesan chatbot.
///
/// Dipindah dari method privat `_ChatbotScreenState` (move-only, tanpa
/// perubahan perilaku).
library;

import '../models/chatbot_screen_models.dart';

List<String> splitSimplePromptInstruction(String text) {
  final lines = text
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);

  if (lines.length != 1) {
    return lines;
  }

  final line = lines.single;
  final exampleIndex = line.toLowerCase().indexOf(' contoh:');
  if (exampleIndex <= 0) {
    return lines;
  }

  return [
    line.substring(0, exampleIndex).trim(),
    line.substring(exampleIndex + 1).trim(),
  ].where((line) => line.isNotEmpty).toList(growable: false);
}

bool isExampleInstructionLine(String line) {
  return line.trim().toLowerCase().startsWith('contoh:');
}

/// Memecah [text] menjadi segmen normal/bold berdasarkan penanda `**...**`.
///
/// Penanda `**` yang tidak berpasangan diperlakukan sebagai teks biasa.
List<ChatbotBoldSegment> parseInlineBoldSegments(String text) {
  final segments = <ChatbotBoldSegment>[];
  final pattern = RegExp(r'\*\*(.+?)\*\*', dotAll: true);
  var lastEnd = 0;
  for (final match in pattern.allMatches(text)) {
    if (match.start > lastEnd) {
      segments.add(
        ChatbotBoldSegment(text.substring(lastEnd, match.start), isBold: false),
      );
    }
    segments.add(ChatbotBoldSegment(match.group(1)!, isBold: true));
    lastEnd = match.end;
  }
  if (lastEnd < text.length) {
    segments.add(ChatbotBoldSegment(text.substring(lastEnd), isBold: false));
  }
  if (segments.isEmpty) {
    segments.add(ChatbotBoldSegment(text, isBold: false));
  }
  return segments;
}

List<ChatbotAssistantNoticeRow> parseAssistantNoticeRows(String text) {
  final rows = <ChatbotAssistantNoticeRow>[];
  final rowPattern = RegExp(
    r'^(.+?):\s*(Rp\s*[\d.]+(?:,\d+)?|Sesuai nota|Menunggu harga barang)(?:\s*(\(.+\)))?\.?$',
    caseSensitive: false,
  );

  for (final rawLine in text.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) {
      continue;
    }

    final match = rowPattern.firstMatch(line);
    if (match == null) {
      return const [];
    }

    rows.add(
      ChatbotAssistantNoticeRow(
        label: normalizeAssistantNoticeLabel(match.group(1)!.trim()),
        amount: match.group(2)!.trim().replaceFirst(RegExp(r'\.$'), ''),
        note: (match.group(3) ?? '').trim().replaceFirst(RegExp(r'\.$'), ''),
      ),
    );
  }

  return rows;
}

String normalizeAssistantNoticeLabel(String label) {
  final normalized = label.replaceAll(RegExp(r'\s+'), ' ').trim();
  final lower = normalized.toLowerCase();

  if (lower == 'estimasi ongkir sementara' || lower == 'ongkir') {
    return 'Estimasi ongkir';
  }

  if (lower == 'harga barang') {
    return 'Harga barang';
  }

  if (lower == 'estimasi total sementara') {
    return 'Estimasi total';
  }

  return normalized;
}

ChatbotShoppingSuccessMessageParts? tryParseShoppingSuccessMessage(String raw) {
  final normalized = raw.replaceAll('\r\n', '\n').trim();
  if (normalized.isEmpty) {
    return null;
  }

  final lines = normalized
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
  if (lines.isEmpty ||
      !lines.first.toLowerCase().startsWith('order nitip berhasil dibuat')) {
    return null;
  }

  var deliveryFeeLine = '';
  final instructionLines = <String>[];
  for (final line in lines.skip(1)) {
    if (line.toLowerCase().startsWith('estimasi ongkir sementara:')) {
      deliveryFeeLine = line;
    } else {
      instructionLines.add(line);
    }
  }

  return ChatbotShoppingSuccessMessageParts(
    headline: lines.first,
    deliveryFeeLine: deliveryFeeLine,
    instructionLine: instructionLines.join(' ').trim(),
  );
}

ChatbotIncompleteShoppingDraftMessageParts? tryParseIncompleteShoppingDraftMessage(
  String raw,
) {
  final normalized = raw.replaceAll('\r\n', '\n').trim();
  if (normalized.isEmpty) {
    return null;
  }

  final lines = normalized
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
  if (lines.length < 6) {
    return null;
  }

  final headline = lines.first;
  final lowerHeadline = headline.toLowerCase();
  if (!lowerHeadline.startsWith('draft nitip belum lengkap') ||
      !lowerHeadline.contains('items')) {
    return null;
  }

  final merchantLabelIndex = lines.indexWhere(
    (line) => line.toLowerCase() == 'tempat',
  );
  final exampleLabelIndex = lines.indexWhere(
    (line) => line.toLowerCase() == 'contoh:',
  );
  if (merchantLabelIndex < 0 ||
      exampleLabelIndex < 0 ||
      merchantLabelIndex + 1 >= exampleLabelIndex) {
    return null;
  }

  final instructionStartIndex = lines.indexWhere(
    (line) => line.toLowerCase().startsWith('tulis item'),
    merchantLabelIndex + 1,
  );
  if (instructionStartIndex < 0 ||
      instructionStartIndex >= exampleLabelIndex) {
    return null;
  }

  final merchantName = lines
      .sublist(merchantLabelIndex + 1, instructionStartIndex)
      .join(' ')
      .trim();
  if (merchantName.isEmpty) {
    return null;
  }

  final instructionLines = lines
      .sublist(instructionStartIndex, exampleLabelIndex)
      .where((line) => line.trim().isNotEmpty)
      .toList(growable: false);
  final examples = lines
      .skip(exampleLabelIndex + 1)
      .map((line) => line.replaceFirst(RegExp(r'^-\s*'), '').trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
  if (instructionLines.isEmpty || examples.isEmpty) {
    return null;
  }

  return ChatbotIncompleteShoppingDraftMessageParts(
    headline: headline,
    merchantLabel: lines[merchantLabelIndex],
    merchantName: merchantName,
    instructionLines: instructionLines,
    examples: examples,
  );
}

ChatbotSimplePromptMessageParts? tryParseCourierRouteSavedPrompt(String raw) {
  final normalized = raw.replaceAll('\r\n', '\n').trim();
  final compact = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
  const headline = 'Titik ambil dan tujuan sudah saya simpan.';
  if (!compact.toLowerCase().startsWith(headline.toLowerCase())) {
    return null;
  }

  return ChatbotSimplePromptMessageParts(
    headline: headline,
    instructionLine: normalized.substring(headline.length).trim(),
  );
}

ChatbotResetDestinationMessageParts? tryParseInlineCourierResetMessage(
  String raw,
) {
  final normalized = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.isEmpty) {
    return null;
  }

  final lower = normalized.toLowerCase();
  const pickupMarker = 'alamat ambil kamu di ';
  const instructionMarker = 'sekarang kirim tujuan baru';
  final pickupIndex = lower.indexOf(pickupMarker);
  final instructionIndex = lower.indexOf(instructionMarker);
  if (pickupIndex < 0 ||
      instructionIndex < 0 ||
      instructionIndex <= pickupIndex) {
    return null;
  }

  final headline = normalized.substring(0, pickupIndex).trim();
  if (!headline.toLowerCase().contains('tujuan sebelumnya') ||
      !headline.toLowerCase().contains('reset')) {
    return null;
  }

  final pickupAddress = normalized
      .substring(pickupIndex + pickupMarker.length, instructionIndex)
      .trim()
      .replaceFirst(RegExp(r'\.\s*$'), '');
  final instruction = normalized.substring(instructionIndex).trim();
  if (pickupAddress.isEmpty) {
    return null;
  }

  return ChatbotResetDestinationMessageParts(
    headline: headline,
    pickupLabel: 'Ambil',
    pickupAddress: pickupAddress,
    instructionLine: instruction,
  );
}

ChatbotUserRouteCommandParts? tryParseUserRouteCommand(String raw) {
  final normalized = raw.trim();
  if (!normalized.toLowerCase().startsWith('[map_route]')) {
    return null;
  }

  final body = normalized.replaceFirst(
    RegExp(r'^\[MAP_ROUTE\]\s*', caseSensitive: false),
    '',
  );
  final points = <ChatbotUserRouteCommandPoint>[];
  for (final segment in body.split(';')) {
    final arrowIndex = segment.indexOf('=>');
    if (arrowIndex < 0) {
      continue;
    }

    final rawTarget = segment.substring(0, arrowIndex).trim().toLowerCase();
    final value = segment.substring(arrowIndex + 2).trim();
    if (value.isEmpty) {
      continue;
    }

    final label = switch (rawTarget) {
      'pickup' => 'Ambil',
      'dropoff' => 'Tujuan',
      'destination' => 'Tujuan',
      _ => rawTarget.isEmpty ? 'Lokasi' : rawTarget,
    };
    points.add(ChatbotUserRouteCommandPoint(label: label, value: value));
  }

  if (points.isEmpty) {
    return null;
  }

  return ChatbotUserRouteCommandParts(points: points);
}

ChatbotShoppingDraftMessageParts? tryParseShoppingDraftMessage(String raw) {
  final normalized = raw.replaceAll('\r\n', '\n').trim();
  if (normalized.isEmpty) {
    return null;
  }

  final lines = normalized
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);

  if (lines.length < 8) {
    return null;
  }

  final merchantIndexes = <int>[];
  for (var index = 0; index < lines.length; index += 1) {
    if (isShoppingMerchantHeader(lines[index])) {
      merchantIndexes.add(index);
    }
  }
  final deliveryIndex = lines.indexWhere((line) {
    final lower = line.toLowerCase();
    return lower == 'alamat antar' || lower == 'alamat kirim';
  });
  final firstFeeIndex = lines.indexWhere(
    (line) => line.toLowerCase().startsWith('estimasi ongkir sementara:'),
  );

  if (merchantIndexes.isEmpty ||
      merchantIndexes.first <= 0 ||
      deliveryIndex < 0 ||
      firstFeeIndex <= deliveryIndex) {
    return null;
  }

  final headline = lines.take(merchantIndexes.first).join(' ').trim();
  final lowerHeadline = headline.toLowerCase();
  if (!lowerHeadline.contains('titip belanja') &&
      !lowerHeadline.contains('nitip')) {
    return null;
  }

  final firstItemHeaderAfterDelivery = lines.indexWhere(
    (line) => line.toLowerCase() == 'daftar belanja',
    deliveryIndex + 1,
  );
  final deliveryEndCandidates = <int>[
    firstFeeIndex,
    if (firstItemHeaderAfterDelivery > deliveryIndex)
      firstItemHeaderAfterDelivery,
    ...merchantIndexes.where((index) => index > deliveryIndex),
  ]..sort();
  final deliveryEndIndex = deliveryEndCandidates.first;
  final deliveryAddress = lines
      .sublist(deliveryIndex + 1, deliveryEndIndex)
      .join(' ')
      .trim();
  final stops = <ChatbotShoppingDraftStopParts>[];
  for (var index = 0; index < merchantIndexes.length; index += 1) {
    final merchantIndex = merchantIndexes[index];
    final nextMerchantIndex = index + 1 < merchantIndexes.length
        ? merchantIndexes[index + 1]
        : lines.length;
    final segmentEndCandidates = <int>[
      nextMerchantIndex,
      if (deliveryIndex > merchantIndex) deliveryIndex,
      firstFeeIndex,
    ]..sort();
    final segmentEnd = segmentEndCandidates
        .where((candidate) => candidate > merchantIndex)
        .first;
    if (merchantIndex + 1 >= segmentEnd) {
      continue;
    }

    final itemHeaderIndex = lines.indexWhere(
      (line) => line.toLowerCase() == 'daftar belanja',
      merchantIndex + 1,
    );
    if (itemHeaderIndex < 0 || itemHeaderIndex >= segmentEnd) {
      continue;
    }

    final merchant = lines
        .sublist(merchantIndex + 1, itemHeaderIndex)
        .join(' ')
        .trim();
    final itemLines = lines.sublist(itemHeaderIndex + 1, segmentEnd);
    final items = normalizeShoppingItemLines(itemLines);
    if (merchant.isEmpty || items.isEmpty) {
      continue;
    }

    stops.add(
      ChatbotShoppingDraftStopParts(
        label: lines[merchantIndex],
        merchant: merchant,
        items: items,
      ),
    );
  }

  if (stops.isEmpty) {
    final oldItemsIndex = lines.indexWhere(
      (line) => line.toLowerCase() == 'daftar belanja',
    );
    if (deliveryIndex <= merchantIndexes.first ||
        oldItemsIndex <= deliveryIndex ||
        firstFeeIndex <= oldItemsIndex) {
      return null;
    }

    final merchant = lines
        .sublist(merchantIndexes.first + 1, deliveryIndex)
        .join(' ')
        .trim();
    final items = normalizeShoppingItemLines(
      lines.sublist(oldItemsIndex + 1, firstFeeIndex),
    );
    if (merchant.isNotEmpty && items.isNotEmpty) {
      stops.add(
        ChatbotShoppingDraftStopParts(
          label: lines[merchantIndexes.first],
          merchant: merchant,
          items: items,
        ),
      );
    }
  }

  final estimateLines = normalizeShoppingEstimateLines(lines, firstFeeIndex);
  final instructionLines = normalizeShoppingInstructionLines(
    lines,
    firstFeeIndex,
  );

  if (deliveryAddress.isEmpty || stops.isEmpty) {
    return null;
  }

  return ChatbotShoppingDraftMessageParts(
    headline: headline,
    stops: stops,
    deliveryAddress: deliveryAddress,
    estimateLines: estimateLines,
    instructionLines: instructionLines,
  );
}

bool isShoppingMerchantHeader(String line) {
  return RegExp(
    r'^(?:merchant|tempat)(?:\s+\d+)?$',
    caseSensitive: false,
  ).hasMatch(line.trim());
}

bool isShoppingEstimateLine(String line) {
  final lower = line.toLowerCase();
  return lower.startsWith('estimasi ongkir sementara:') ||
      lower.startsWith('harga barang:') ||
      lower.startsWith('estimasi total sementara:');
}

List<String> normalizeShoppingItemLines(List<String> lines) {
  final items = <String>[];
  final current = StringBuffer();
  final itemStartPattern = RegExp(r'^\d+\.\s*');

  void flush() {
    final value = current.toString().trim();
    if (value.isNotEmpty) {
      items.add(value);
    }
    current.clear();
  }

  for (final line in lines) {
    final cleaned = line.replaceFirst(itemStartPattern, '').trim();
    if (cleaned.isEmpty) {
      continue;
    }

    if (itemStartPattern.hasMatch(line)) {
      flush();
      current.write(cleaned);
    } else if (current.isNotEmpty) {
      current.write(' $cleaned');
    }
  }

  flush();
  return items;
}

List<String> normalizeShoppingEstimateLines(
  List<String> lines,
  int startIndex,
) {
  final estimateLines = <String>[];
  var index = startIndex;

  while (index < lines.length) {
    final line = lines[index].trim();
    final isEstimateLine = isShoppingEstimateLine(line);

    if (!isEstimateLine) {
      index += 1;
      continue;
    }

    if (line.toLowerCase().endsWith('rp') && index + 1 < lines.length) {
      estimateLines.add('$line ${lines[index + 1].trim()}');
      index += 2;
    } else {
      estimateLines.add(line);
      index += 1;
    }
  }

  return estimateLines;
}

List<String> normalizeShoppingInstructionLines(
  List<String> lines,
  int startIndex,
) {
  final instructions = <String>[];
  var hasSeenFee = false;
  var skippingAddMerchantExample = false;

  for (final line in lines.skip(startIndex)) {
    if (isShoppingEstimateLine(line)) {
      hasSeenFee = true;
      continue;
    }
    if (!hasSeenFee) {
      continue;
    }

    final lower = line.toLowerCase();
    final isAddMerchantPrompt =
        lower.contains('mau tambah tempat') ||
        lower.contains('mau tambah toko') ||
        lower.contains('mau tambah resto') ||
        lower.contains('tambah pesanan dari toko') ||
        lower.contains('tambah pesanan dari resto') ||
        lower.contains('contoh setelah tempat berikutnya') ||
        lower.contains('contoh isi pesan') ||
        lower.contains('contoh:');

    if (isAddMerchantPrompt) {
      skippingAddMerchantExample = true;
      continue;
    }

    if (skippingAddMerchantExample) {
      final looksLikeExampleItem = RegExp(r'^[-•]\s*').hasMatch(line);
      if (looksLikeExampleItem) {
        continue;
      }
      skippingAddMerchantExample = false;
    }

    instructions.add(line);
  }

  return instructions;
}

ChatbotDraftMessageParts? tryParseDraftMessage(String raw) {
  final normalized = raw.replaceAll('\r\n', '\n').trim();
  if (normalized.isEmpty) {
    return null;
  }

  final lines = normalized
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);

  if (lines.length < 4) {
    return null;
  }

  final pickupIndex = lines.indexWhere(
    (line) =>
        line.toLowerCase().startsWith('jemput:') ||
        line.toLowerCase().startsWith('ambil:'),
  );
  final destinationIndex = lines.indexWhere(
    (line) => line.toLowerCase().startsWith('tujuan:'),
  );
  final packageIndex = lines.indexWhere(
    (line) => line.toLowerCase().startsWith('barang:'),
  );
  final feeIndex = lines.indexWhere((line) {
    final lower = line.toLowerCase();
    return lower.startsWith('estimasi ongkir sementara:') ||
        lower.startsWith('ongkir:');
  });

  if (pickupIndex < 0 || destinationIndex < 0 || feeIndex < 0) {
    return null;
  }

  final introText = lines.take(pickupIndex).join('\n').trim();
  if (introText.isEmpty ||
      (!introText.toLowerCase().contains('antar jemput') &&
          !introText.toLowerCase().contains('kurir'))) {
    return null;
  }

  final pickupAddress = lines[pickupIndex].replaceFirst(
    RegExp(r'^(Jemput|Ambil):\s*', caseSensitive: false),
    '',
  );
  final destinationAddress = lines[destinationIndex].replaceFirst(
    RegExp(r'^Tujuan:\s*', caseSensitive: false),
    '',
  );

  final packageDescription = packageIndex >= 0
      ? lines[packageIndex].replaceFirst(
          RegExp(r'^Barang:\s*', caseSensitive: false),
          '',
        )
      : null;
  if (pickupAddress.isEmpty || destinationAddress.isEmpty) {
    return null;
  }

  final instructionLine = feeIndex + 1 < lines.length
      ? lines.skip(feeIndex + 1).join(' ').trim()
      : '';

  return ChatbotDraftMessageParts(
    headline: introText,
    pickupLabel: lines[pickupIndex].toLowerCase().startsWith('ambil:')
        ? 'Ambil'
        : 'Jemput',
    pickupAddress: pickupAddress,
    destinationAddress: destinationAddress,
    packageDescription: packageDescription,
    feeLine: lines[feeIndex],
    instructionLine: instructionLine,
  );
}

ChatbotResetDestinationMessageParts? tryParseResetDestinationMessage(String raw) {
  final normalized = raw.replaceAll('\r\n', '\n').trim();
  if (normalized.isEmpty) {
    return null;
  }

  final lines = normalized
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
  if (lines.length < 3) {
    return null;
  }

  final pickupIndex = lines.indexWhere(
    (line) =>
        line.toLowerCase().startsWith('jemput:') ||
        line.toLowerCase().startsWith('ambil:'),
  );
  if (pickupIndex < 0) {
    return null;
  }

  final headline = lines.take(pickupIndex).join('\n').trim();
  final normalizedHeadline = headline.toLowerCase();
  if (headline.isEmpty ||
      !normalizedHeadline.contains('tujuan sebelumnya') ||
      !normalizedHeadline.contains('reset')) {
    return null;
  }

  final pickupLabel = lines[pickupIndex].toLowerCase().startsWith('ambil:')
      ? 'Ambil'
      : 'Jemput';
  final pickupFirstLine = lines[pickupIndex].replaceFirst(
    RegExp(r'^(Jemput|Ambil):\s*', caseSensitive: false),
    '',
  );

  int instructionStartIndex = lines.length;
  for (int i = pickupIndex + 1; i < lines.length; i++) {
    final lower = lines[i].toLowerCase();
    if (lower.startsWith('silakan klik tombol') ||
        lower.startsWith('setelah itu,')) {
      instructionStartIndex = i;
      break;
    }
  }

  final pickupLines = <String>[
    if (pickupFirstLine.isNotEmpty) pickupFirstLine,
    ...lines.sublist(pickupIndex + 1, instructionStartIndex),
  ].where((line) => line.trim().isNotEmpty).toList(growable: false);
  if (pickupLines.isEmpty) {
    return null;
  }

  final instructionLine = instructionStartIndex < lines.length
      ? lines.sublist(instructionStartIndex).join(' ').trim()
      : '';

  return ChatbotResetDestinationMessageParts(
    headline: headline,
    pickupLabel: pickupLabel,
    pickupAddress: pickupLines.join('\n'),
    instructionLine: instructionLine,
  );
}
