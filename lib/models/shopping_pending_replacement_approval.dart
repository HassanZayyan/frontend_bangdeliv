/// Proposal penggantian toko/resto oleh customer ke lokasi jauh (> radius) yang
/// sedang menunggu persetujuan driver. Disurface di projection stop untuk kedua
/// sisi: customer melihat status "menunggu", driver melihat kartu Terima/Tolak.
class ShoppingPendingReplacementApproval {
  final int eventId;
  final String status;
  final double? distanceKm;
  final String? requestedBy;
  final String? newMerchantName;

  const ShoppingPendingReplacementApproval({
    required this.eventId,
    this.status = 'PENDING',
    this.distanceKm,
    this.requestedBy,
    this.newMerchantName,
  });

  bool get isPending => status.toUpperCase() == 'PENDING';

  static ShoppingPendingReplacementApproval? fromJson(dynamic json) {
    if (json is! Map) {
      return null;
    }
    final map = json.map((key, value) => MapEntry(key.toString(), value));
    final status = (map['status'] ?? 'PENDING').toString().toUpperCase();
    if (status != 'PENDING') {
      return null;
    }

    final merchant = map['new_merchant'];
    final merchantName = merchant is Map
        ? merchant['name']?.toString()
        : null;

    return ShoppingPendingReplacementApproval(
      eventId: _asInt(map['event_id']),
      status: status,
      distanceKm: _asDoubleOrNull(map['distance_km']),
      requestedBy: map['requested_by']?.toString(),
      newMerchantName: (merchantName ?? '').trim().isEmpty ? null : merchantName,
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double? _asDoubleOrNull(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}
