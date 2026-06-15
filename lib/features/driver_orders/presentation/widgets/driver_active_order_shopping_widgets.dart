import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../config/app_colors.dart';
import '../../../../models/driver_order_model.dart';
import 'driver_active_order_widget_helpers.dart';

class DriverShoppingItemsCard extends StatefulWidget {
  final DriverOrderModel order;
  final bool isProcessing;
  final Future<String?> Function(XFile photo, String? note) onUploadReceipt;
  final Future<String?> Function(
    List<Map<String, dynamic>> items,
    double shoppingTotalAmount,
    double? deliveryFeeOverride,
    String? receiptNote,
    XFile? receiptPhoto,
  )
  onSave;

  const DriverShoppingItemsCard({
    super.key,
    required this.order,
    required this.isProcessing,
    required this.onUploadReceipt,
    required this.onSave,
  });

  @override
  State<DriverShoppingItemsCard> createState() =>
      DriverShoppingItemsCardState();
}

class DriverShoppingItemsCardState extends State<DriverShoppingItemsCard> {
  final TextEditingController _shoppingTotalController =
      TextEditingController();
  final TextEditingController _deliveryFeeOverrideController =
      TextEditingController();
  final TextEditingController _receiptNoteController = TextEditingController();
  final Map<int, bool> _availability = {};
  final Map<int, bool> _heavy = {};
  final Set<int> _dirtyAvailabilityIds = {};
  final Set<int> _dirtyHeavyIds = {};
  bool _isUploadingReceipt = false;

  @override
  void initState() {
    super.initState();
    _syncControllers();
  }

  @override
  void didUpdateWidget(covariant DriverShoppingItemsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.shoppingItems != widget.order.shoppingItems) {
      _syncControllers();
    }
  }

  @override
  void dispose() {
    _shoppingTotalController.dispose();
    _deliveryFeeOverrideController.dispose();
    _receiptNoteController.dispose();
    super.dispose();
  }

  void _syncControllers() {
    final activeIds = widget.order.shoppingItems.map((item) => item.id).toSet();
    final staleIds = _availability.keys
        .where((id) => !activeIds.contains(id))
        .toList(growable: false);
    for (final id in staleIds) {
      _availability.remove(id);
      _heavy.remove(id);
      _dirtyAvailabilityIds.remove(id);
      _dirtyHeavyIds.remove(id);
    }

    for (final item in widget.order.shoppingItems) {
      if (!_availability.containsKey(item.id)) {
        _dirtyAvailabilityIds.remove(item.id);
        _availability[item.id] = item.isAvailable;
      } else if (_dirtyAvailabilityIds.contains(item.id)) {
        if (_availability[item.id] == item.isAvailable) {
          _dirtyAvailabilityIds.remove(item.id);
        }
      } else {
        _availability[item.id] = item.isAvailable;
      }

      if (!_heavy.containsKey(item.id)) {
        _dirtyHeavyIds.remove(item.id);
        _heavy[item.id] = item.isHeavy;
      } else if (_dirtyHeavyIds.contains(item.id)) {
        if (_heavy[item.id] == item.isHeavy) {
          _dirtyHeavyIds.remove(item.id);
        }
      } else {
        _heavy[item.id] = item.isHeavy;
      }
    }

    _primeCheckoutControllers();
  }

  void _primeCheckoutControllers() {
    if (_shoppingTotalController.text.trim().isEmpty) {
      final subtotal =
          widget.order.shoppingPricing?.subtotal ??
          widget.order.shoppingItems.fold<double>(
            0,
            (sum, item) => sum + item.subtotal,
          );
      if (subtotal > 0) {
        _shoppingTotalController.text = subtotal.round().toString();
      }
    }

    final deliveryFeeSource = (widget.order.deliveryFeeSource ?? '')
        .trim()
        .toLowerCase();
    if (_deliveryFeeOverrideController.text.trim().isEmpty &&
        deliveryFeeSource == 'driver_manual' &&
        widget.order.deliveryFee != null &&
        widget.order.deliveryFee! > 0) {
      _deliveryFeeOverrideController.text = widget.order.deliveryFee!
          .round()
          .toString();
    }
  }

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Checkout Belanja',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Text(
                'Total dari struk',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (widget.order.shoppingStops.isEmpty) ...[
            _buildHeavyToggleForItems(widget.order.shoppingItems),
            const SizedBox(height: 8),
            ...widget.order.shoppingItems.map(_buildItemEditor),
          ] else
            ...widget.order.shoppingStops
                .where((stop) => !stop.isSkipped && !stop.isReplaced)
                .map(_buildStopSection),
          if (_shoppingProofs().isNotEmpty) ...[
            const SizedBox(height: 4),
            _buildProofPreviewStrip(_shoppingProofs()),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: _shoppingTotalController,
            keyboardType: TextInputType.number,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            decoration: driverDialogInputDecoration(
              labelText: 'Total belanja di struk',
              prefixText: 'Rp ',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _deliveryFeeOverrideController,
            keyboardType: TextInputType.number,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            decoration: driverDialogInputDecoration(
              labelText: 'Edit ongkir nitip (opsional)',
              prefixText: 'Rp ',
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: widget.isProcessing || _isUploadingReceipt
                ? null
                : _uploadReceiptPhoto,
            icon: _isUploadingReceipt
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.photo_camera_outlined, size: 18),
            label: Text(
              _isUploadingReceipt
                  ? 'Mengupload Struk...'
                  : !widget.order.hasProof('receipt')
                  ? 'Upload Foto Struk'
                  : 'Foto Struk Siap',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _receiptNoteController,
            minLines: 1,
            maxLines: 3,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            decoration: driverDialogInputDecoration(
              labelText: 'Catatan nota',
              hintText: 'Contoh: satu item kosong, diganti ukuran lain',
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.isProcessing || _isUploadingReceipt
                  ? null
                  : _save,
              icon: widget.isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : const Icon(Icons.receipt_long, size: 18),
              label: const Text('Simpan Checkout Nitip'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemEditor(DriverShoppingItemModel item) {
    final isAvailable = _availability[item.id] ?? item.isAvailable;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  '${item.quantity}x ${item.name}',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    decoration: isAvailable
                        ? TextDecoration.none
                        : TextDecoration.lineThrough,
                  ),
                ),
              ),
              Checkbox(
                value: isAvailable,
                visualDensity: const VisualDensity(
                  horizontal: -4,
                  vertical: -4,
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (value) {
                  setState(() {
                    _dirtyAvailabilityIds.add(item.id);
                    _availability[item.id] = value ?? true;
                  });
                },
              ),
            ],
          ),
          if ((item.notes ?? '').trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 2),
              child: Text(
                item.notes!.trim(),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStopSection(DriverShoppingStopModel stop) {
    final activeItems = stop.items;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${stop.sequenceNo <= 0 ? 1 : stop.sequenceNo}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  stop.merchant.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (stop.isFailed || stop.isSkipped || stop.isReplaced)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    stop.isFailed
                        ? 'Gagal'
                        : stop.isReplaced
                        ? 'Diganti'
                        : 'Dilewati',
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          if ((stop.merchant.address ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Text(
                stop.merchant.address!.trim(),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ),
          ],
          if ((stop.failureReason ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Text(
                stop.failureReason!.trim(),
                style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          _buildHeavyToggleForItems(activeItems),
          const SizedBox(height: 8),
          ...activeItems.map(_buildItemEditor),
        ],
      ),
    );
  }

  Widget _buildHeavyToggleForItems(List<DriverShoppingItemModel> items) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final availableItems = items
        .where((item) => _availability[item.id] ?? item.isAvailable)
        .toList(growable: false);
    final targetItems = availableItems.isEmpty ? items : availableItems;
    final isHeavy = targetItems.any((item) => _heavy[item.id] ?? item.isHeavy);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
      ),
      child: CheckboxListTile(
        value: isHeavy,
        onChanged: (value) {
          final nextValue = value ?? false;
          setState(() {
            for (final item in items) {
              _dirtyHeavyIds.add(item.id);
              _heavy[item.id] = nextValue;
            }
          });
        },
        dense: true,
        visualDensity: const VisualDensity(horizontal: -2, vertical: -3),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        controlAffinity: ListTileControlAffinity.leading,
        title: const Text(
          'Item berat',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
        ),
        subtitle: const Text(
          'Tambahan biaya Rp6.000 sekali per order',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
        ),
      ),
    );
  }

  List<DriverOrderProofModel> _shoppingProofs() {
    return widget.order.proofs
        .where(
          (proof) =>
              (proof.type == 'receipt' || proof.type == 'store_closed') &&
              (proof.photoUrl ?? '').trim().isNotEmpty,
        )
        .toList(growable: false);
  }

  Widget _buildProofPreviewStrip(List<DriverOrderProofModel> proofs) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: proofs
          .map(
            (proof) => InkWell(
              onTap: () => _showProofPreview(proof),
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 96,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        proof.photoUrl!,
                        width: 96,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 96,
                          height: 72,
                          color: AppColors.background,
                          child: const Icon(
                            Icons.image_not_supported_outlined,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      proof.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  void _showProofPreview(DriverOrderProofModel proof) {
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

  Future<void> _uploadReceiptPhoto() async {
    final photo = await pickDriverOrderImage(context);
    if (photo == null || !mounted) {
      return;
    }

    setState(() => _isUploadingReceipt = true);
    final error = await widget.onUploadReceipt(
      photo,
      _receiptNoteController.text.trim(),
    );

    if (!mounted) {
      return;
    }

    setState(() => _isUploadingReceipt = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Foto struk berhasil diupload.'),
        backgroundColor: error == null ? null : AppColors.error,
      ),
    );
  }

  Future<void> _save() async {
    final shoppingTotalAmount = parseDriverCurrencyInput(
      _shoppingTotalController.text,
    );
    final deliveryFeeOverrideRaw = _deliveryFeeOverrideController.text.trim();
    final deliveryFeeOverride = deliveryFeeOverrideRaw.isEmpty
        ? null
        : parseDriverCurrencyInput(deliveryFeeOverrideRaw);

    if (shoppingTotalAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Total belanja di struk wajib diisi.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (!widget.order.hasProof('receipt')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upload foto struk dulu.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final payload = widget.order.shoppingItems
        .map(
          (item) => <String, dynamic>{
            'id': item.id,
            'quantity': item.quantity,
            'is_available': _availability[item.id] ?? item.isAvailable,
            'notes': item.notes,
            'is_heavy': _heavy[item.id] ?? item.isHeavy,
          },
        )
        .toList(growable: false);

    final error = await widget.onSave(
      payload,
      shoppingTotalAmount,
      deliveryFeeOverride == null || deliveryFeeOverride <= 0
          ? null
          : deliveryFeeOverride,
      _receiptNoteController.text.trim(),
      null,
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Checkout nitip berhasil disimpan.'),
        backgroundColor: error == null ? null : AppColors.error,
      ),
    );

    if (error == null) {
      setState(_syncControllers);
    }
  }
}
