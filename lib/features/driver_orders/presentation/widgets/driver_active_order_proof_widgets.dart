import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../config/app_colors.dart';
import '../../../../models/driver_order_model.dart';
import '../../../../utils/service_type.dart';
import 'driver_active_order_widget_helpers.dart';

class DriverOrderProofChecklistCard extends StatelessWidget {
  const DriverOrderProofChecklistCard({
    super.key,
    required this.order,
    required this.isProcessing,
    required this.onUploadProof,
  });

  final DriverOrderModel order;
  final bool isProcessing;
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.photo_camera_outlined, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Bukti Foto Order',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...requirements.map(
            (requirement) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _proofRow(context, requirement),
            ),
          ),
        ],
      ),
    );
  }

  List<_ProofRequirement> _requirements() {
    final serviceType = normalizeServiceTypeCode(order.serviceTypeCode);
    final hasStoreClosedProof = order.hasProof('store_closed');

    return <_ProofRequirement>[
      if (serviceType == ServiceTypeCodes.courier) ...[
        const _ProofRequirement(
          type: 'pickup',
          title: 'Pengambilan',
          description: 'Foto saat barang/order diambil.',
        ),
        const _ProofRequirement(
          type: 'delivery',
          title: 'Diterima',
          description: 'Foto saat order selesai diterima.',
        ),
      ],
      if (serviceType == ServiceTypeCodes.shopping)
        const _ProofRequirement(
          type: 'receipt',
          title: 'Struk belanja',
          description: 'Foto struk untuk total belanja nitip.',
        ),
      if (hasStoreClosedProof)
        const _ProofRequirement(
          type: 'store_closed',
          title: 'Toko tutup',
          description: 'Bukti toko tutup/gagal pickup.',
        ),
    ];
  }

  Widget _proofRow(BuildContext context, _ProofRequirement requirement) {
    final uploaded = order.hasProof(requirement.type);
    final proof = _proofFor(requirement.type);
    final proofPhotoUrl = proof?.photoUrl;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  requirement.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  requirement.description,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (proofPhotoUrl != null) ...[
            InkWell(
              onTap: () => _showProofPreview(context, proof!),
              borderRadius: BorderRadius.circular(8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
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
          OutlinedButton.icon(
            onPressed: isProcessing
                ? null
                : () => _handleUpload(context, requirement),
            icon: const Icon(Icons.upload_file, size: 16),
            label: Text(uploaded ? 'Ganti' : 'Upload'),
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
          borderRadius: BorderRadius.circular(12),
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
  const _ProofRequirement({
    required this.type,
    required this.title,
    required this.description,
  });

  final String type;
  final String title;
  final String description;
}
