import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../config/app_colors.dart';
import '../../../../core/widgets/bang_action_button.dart';
import '../../../../models/driver_order_model.dart';
import '../../../../utils/service_type.dart';
import 'driver_active_order_widget_helpers.dart';

class DriverOrderProofChecklistCard extends StatelessWidget {
  const DriverOrderProofChecklistCard({
    super.key,
    required this.order,
    required this.isOrderBusy,
    required this.isProofUploading,
    required this.onUploadProof,
  });

  final DriverOrderModel order;
  final bool isOrderBusy;
  final bool Function(String type) isProofUploading;
  final Future<String?> Function({
    required String type,
    required XFile photo,
    String? note,
    int? pickupLocationId,
  })
  onUploadProof;

  @override
  Widget build(BuildContext context) {
    final requirements = _requirements();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Bukti Foto Order',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...() {
            final widgets = <Widget>[];
            for (var i = 0; i < requirements.length; i++) {
              widgets.add(_proofRow(context, requirements[i]));
              if (i < requirements.length - 1) {
                widgets.add(
                  const Divider(
                    height: 1,
                    thickness: 0.5,
                    color: Color(0xFFEEEEEE),
                  ),
                );
              }
            }
            return widgets;
          }(),
        ],
      ),
    );
  }

  List<_ProofRequirement> _requirements() {
    final serviceType = normalizeServiceTypeCode(order.serviceTypeCode);
    final hasStoreClosedProof = order.hasProof('store_closed');

    return <_ProofRequirement>[
      if (serviceType == ServiceTypeCodes.courier) ...[
        const _ProofRequirement(type: 'pickup', title: 'Pengambilan'),
        const _ProofRequirement(type: 'delivery', title: 'Diterima'),
      ],
      if (serviceType == ServiceTypeCodes.shopping)
        const _ProofRequirement(type: 'receipt', title: 'Struk belanja'),
      if (hasStoreClosedProof)
        const _ProofRequirement(type: 'store_closed', title: 'Toko tutup'),
    ];
  }

  Widget _proofRow(BuildContext context, _ProofRequirement requirement) {
    final uploaded = order.hasProof(requirement.type);
    final proof = _proofFor(requirement.type);
    final proofPhotoUrl = proof?.photoUrl;
    final isUploading = isProofUploading(requirement.type);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            uploaded ? Icons.check_circle : Icons.radio_button_unchecked,
            color: uploaded ? AppColors.success : AppColors.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              requirement.title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (proofPhotoUrl != null) ...[
            InkWell(
              onTap: () => _showProofPreview(context, proof!),
              borderRadius: BorderRadius.circular(10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  proofPhotoUrl,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 44,
                    height: 44,
                    color: AppColors.white,
                    child: const Icon(
                      Icons.image_not_supported_outlined,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          BangActionButton(
            label: uploaded ? 'Ganti' : 'Upload',
            icon: Icons.upload_file,
            variant: BangActionButtonVariant.outlined,
            isLoading: isUploading,
            isEnabled: !isOrderBusy || isUploading,
            onPressed: () => _handleUpload(context, requirement),
          ),
        ],
      ),
    );
  }

  DriverOrderProofModel? _proofFor(String type) {
    final normalized = type.trim().toLowerCase();
    for (final proof in order.proofs) {
      if (proof.type == normalized) {
        return proof;
      }
    }

    return null;
  }

  void _showProofPreview(BuildContext context, DriverOrderProofModel proof) {
    final url = proof.photoUrl;
    if (url == null || url.isEmpty) {
      return;
    }

    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(18),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: InteractiveViewer(
            child: Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Gambar bukti belum bisa dimuat.'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleUpload(
    BuildContext context,
    _ProofRequirement requirement,
  ) async {
    final photo = await pickDriverOrderImage(context);
    if (photo == null) {
      return;
    }

    final error = await onUploadProof(
      type: requirement.type,
      photo: photo,
      note: requirement.title,
    );

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? '${requirement.title} berhasil diupload.'),
        backgroundColor: error == null ? null : AppColors.error,
      ),
    );
  }
}

class _ProofRequirement {
  const _ProofRequirement({required this.type, required this.title});

  final String type;
  final String title;
}
