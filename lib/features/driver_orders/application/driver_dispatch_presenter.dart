import '../../../models/driver_order_model.dart';

class DriverDispatchViewData {
  const DriverDispatchViewData({
    required this.label,
    required this.bucket,
    this.priorityRank,
  });

  final String label;
  final String bucket;
  final int? priorityRank;
}

class DriverDispatchPresenter {
  static DriverDispatchViewData present(DriverDispatchModel? dispatch) {
    if (dispatch == null) {
      return const DriverDispatchViewData(
        label: 'Jarak belum tersedia',
        bucket: 'UNKNOWN',
      );
    }

    final label = dispatch.distanceLabel.trim().isEmpty
        ? 'Jarak belum tersedia'
        : dispatch.distanceLabel.trim();
    final bucket = dispatch.distanceBucket.trim().toUpperCase();

    return DriverDispatchViewData(
      label: label,
      bucket: bucket.isEmpty ? 'UNKNOWN' : bucket,
      priorityRank: dispatch.priorityRank,
    );
  }
}
