import 'package:flutter/services.dart';

final RegExp _nonDigitPattern = RegExp(r'[^0-9]');
final RegExp _leadingZeroPattern = RegExp(r'^0+(?=\d)');

String formatRupiahInputText(String raw) {
  final digits = raw.replaceAll(_nonDigitPattern, '');
  if (digits.isEmpty) {
    return '';
  }

  final normalized = digits.replaceFirst(_leadingZeroPattern, '');
  final buffer = StringBuffer();
  for (var index = 0; index < normalized.length; index++) {
    final remaining = normalized.length - index;
    buffer.write(normalized[index]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write('.');
    }
  }

  return buffer.toString();
}

String formatRupiahInputAmount(num amount) {
  if (amount <= 0) {
    return '';
  }

  return formatRupiahInputText(amount.round().toString());
}

class RupiahInputFormatter extends TextInputFormatter {
  const RupiahInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = formatRupiahInputText(newValue.text);
    if (formatted.isEmpty) {
      return const TextEditingValue(
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final normalizedDigits = formatted.replaceAll(_nonDigitPattern, '');
    final selectionEnd = newValue.selection.isValid
        ? newValue.selection.end.clamp(0, newValue.text.length)
        : newValue.text.length;
    final digitsToRight = newValue.text
        .substring(selectionEnd)
        .replaceAll(_nonDigitPattern, '')
        .length
        .clamp(0, normalizedDigits.length);
    final digitsToLeft = normalizedDigits.length - digitsToRight;
    final cursorOffset = _offsetAfterDigits(formatted, digitsToLeft);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursorOffset),
    );
  }
}

int _offsetAfterDigits(String text, int digitCount) {
  if (digitCount <= 0) {
    return 0;
  }

  var seenDigits = 0;
  for (var index = 0; index < text.length; index++) {
    if (_isDigit(text.codeUnitAt(index))) {
      seenDigits++;
      if (seenDigits == digitCount) {
        return index + 1;
      }
    }
  }

  return text.length;
}

bool _isDigit(int codeUnit) => codeUnit >= 48 && codeUnit <= 57;
