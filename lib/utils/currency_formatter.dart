String formatRupiah(num amount) {
  final isNegative = amount < 0;
  final normalized = amount.abs().round();
  final raw = normalized.toString();
  final buffer = StringBuffer();

  for (int i = 0; i < raw.length; i++) {
    final reverseIndex = raw.length - i;
    buffer.write(raw[i]);
    if (reverseIndex > 1 && reverseIndex % 3 == 1) {
      buffer.write('.');
    }
  }

  final prefix = isNegative ? '-Rp' : 'Rp';
  return '$prefix$buffer';
}

const shoppingPendingPriceLabel = 'Harga sesuai nota';

bool hasMenuReferencePrice(num? amount) {
  return amount != null && amount > 0;
}

String formatMenuPriceOrPending(num? amount) {
  return hasMenuReferencePrice(amount)
      ? formatRupiah(amount!)
      : shoppingPendingPriceLabel;
}
