double parseCurrencyInput(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (cleaned.isEmpty) {
    return 0;
  }

  return double.tryParse(cleaned) ?? 0;
}
