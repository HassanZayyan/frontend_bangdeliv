import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_bangdeliv/utils/currency_input_parser.dart';
import 'package:frontend_bangdeliv/utils/rupiah_input_formatter.dart';

void main() {
  const formatter = RupiahInputFormatter();

  test('formats digits with Indonesian thousand separators', () {
    final result = formatter.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(
        text: '50000',
        selection: TextSelection.collapsed(offset: 5),
      ),
    );

    expect(result.text, '50.000');
    expect(result.selection, const TextSelection.collapsed(offset: 6));
    expect(parseCurrencyInput(result.text), 50000);
  });

  test('accepts pasted currency text and normalizes leading zeros', () {
    final result = formatter.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(
        text: 'Rp 001500000',
        selection: TextSelection.collapsed(offset: 12),
      ),
    );

    expect(result.text, '1.500.000');
    expect(parseCurrencyInput(result.text), 1500000);
  });

  test('keeps cursor near edited digits in the middle', () {
    final result = formatter.formatEditUpdate(
      const TextEditingValue(
        text: '50.000',
        selection: TextSelection.collapsed(offset: 2),
      ),
      const TextEditingValue(
        text: '510.000',
        selection: TextSelection.collapsed(offset: 2),
      ),
    );

    expect(result.text, '510.000');
    expect(result.selection, const TextSelection.collapsed(offset: 2));
  });

  test('formats initial amounts without the field prefix', () {
    expect(formatRupiahInputAmount(50000), '50.000');
    expect(formatRupiahInputAmount(0), isEmpty);
  });
}
