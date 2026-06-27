import '../utils/order_formatters.dart';

class PaymentProofFeedbackModel {
  const PaymentProofFeedbackModel({
    required this.status,
    this.label,
    this.reason,
    this.note,
    this.proofId,
    this.decidedBy,
    this.decidedAt,
  });

  final String status;
  final String? label;
  final String? reason;
  final String? note;
  final int? proofId;
  final String? decidedBy;
  final DateTime? decidedAt;

  String get normalizedStatus => status.trim().toLowerCase();

  bool get isRejected => normalizedStatus == 'rejected';
  bool get isPending => normalizedStatus == 'pending';
  bool get isApproved => normalizedStatus == 'approved';

  String? get displayReason {
    final explicitReason = reason?.trim() ?? '';
    if (explicitReason.isNotEmpty) {
      return explicitReason;
    }

    final fallbackNote = note?.trim() ?? '';
    return fallbackNote.isEmpty ? null : fallbackNote;
  }

  static PaymentProofFeedbackModel? fromRaw(dynamic raw) {
    if (raw is! Map) {
      return null;
    }

    final json = raw.map((key, value) => MapEntry(key.toString(), value));
    final status = (json['status'] ?? '').toString().trim().toLowerCase();
    if (status.isEmpty) {
      return null;
    }

    return PaymentProofFeedbackModel(
      status: status,
      label: _optionalText(json['label']),
      reason: _optionalText(json['reason']),
      note: _optionalText(json['note']),
      proofId: _optionalInt(json['proof_id'] ?? json['proofId']),
      decidedBy: _optionalText(json['decided_by'] ?? json['decidedBy']),
      decidedAt: parseBackendDateTime(json['decided_at'] ?? json['decidedAt']),
    );
  }

  static int? _optionalInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString());
  }

  static String? _optionalText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text == '-' ? null : text;
  }
}
