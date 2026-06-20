import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../config/app_colors.dart';
import '../../../../core/widgets/bang_action_button.dart';
import '../../../../core/widgets/bang_negotiation_status_panel.dart';
import '../../../../core/widgets/bang_shopping_merchant_request_summary.dart';
import '../../../../models/driver_order_model.dart';
import '../../../../models/shopping_negotiation_model.dart';
import '../../../../models/shopping_order_capability_model.dart';
import '../../../../utils/order_formatters.dart';
import 'driver_active_order_widget_helpers.dart';

class DriverShoppingItemChangeRequestCard extends StatelessWidget {
  const DriverShoppingItemChangeRequestCard({
    super.key,
    required this.request,
    required this.isOrderBusy,
    required this.isApproving,
    required this.isRejecting,
    required this.onRespond,
  });

  final ShoppingItemChangeRequestModel request;
  final bool isOrderBusy;
  final bool isApproving;
  final bool isRejecting;
  final Future<String?> Function(String action) onRespond;

  static bool shouldShow(DriverOrderModel order) {
    return order.shoppingItemChangeRequest?.isApproveable == true;
  }

  @override
  Widget build(BuildContext context) {
    final action = (request.action ?? 'ADD').toUpperCase();
    final actionLabel = action == 'REMOVE'
        ? 'Hapus item'
        : action == 'UPDATE'
        ? 'Ubah item'
        : 'Tambah item';

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
              Icon(Icons.pending_actions_outlined, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Request Item Customer',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            actionLabel,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          BangShoppingMerchantRequestSummary(request: request),
          if ((request.note ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              request.note!.trim(),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: BangActionButton(
                  label: 'Tolak',
                  variant: BangActionButtonVariant.outlined,
                  icon: Icons.close_rounded,
                  isLoading: isRejecting,
                  isEnabled: !isOrderBusy || isRejecting,
                  onPressed: () => _respond(context, 'REJECT'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: BangActionButton(
                  label: 'Setujui',
                  icon: Icons.check_rounded,
                  isLoading: isApproving,
                  isEnabled: !isOrderBusy || isApproving,
                  onPressed: () => _respond(context, 'APPROVE'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _respond(BuildContext context, String action) async {
    final error = await onRespond(action);
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Request item diproses.'),
        backgroundColor: error == null ? null : AppColors.error,
      ),
    );
  }
}

class DriverShoppingMerchantQuotePanel extends StatefulWidget {
  const DriverShoppingMerchantQuotePanel({
    super.key,
    required this.pickupLocationId,
    required this.quote,
    required this.isOrderBusy,
    required this.isSubmittingQuote,
    required this.isBypassingPrice,
    required this.onSubmitQuote,
    required this.onBypassApproval,
  });

  final int pickupLocationId;
  final ShoppingMerchantQuoteModel? quote;
  final bool isOrderBusy;
  final bool isSubmittingQuote;
  final bool isBypassingPrice;
  final Future<String?> Function({
    required double amount,
    int? pickupLocationId,
  })
  onSubmitQuote;
  final Future<String?> Function({required int pickupLocationId})
  onBypassApproval;

  @override
  State<DriverShoppingMerchantQuotePanel> createState() =>
      _DriverShoppingMerchantQuotePanelState();
}

class _DriverShoppingMerchantQuotePanelState
    extends State<DriverShoppingMerchantQuotePanel> {
  final TextEditingController _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _primeAmount();
  }

  @override
  void didUpdateWidget(covariant DriverShoppingMerchantQuotePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quote?.displayAmount != widget.quote?.displayAmount &&
        _amountController.text.trim().isEmpty) {
      _primeAmount();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _primeAmount() {
    final amount = widget.quote?.displayAmount;
    if ((amount ?? 0) > 0) {
      _amountController.text = amount!.round().toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final quote = widget.quote;
    final canSubmitQuote = quote?.amount.canDriverSubmitQuote == true;
    final isPendingCustomer = quote?.isPendingCustomer == true;
    final isApproved = quote?.isApproved == true;
    final needsRequote = quote?.needsRequote == true;

    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.request_quote_outlined,
                color: AppColors.primary,
                size: 18,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Harga Nitip',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          if (isApproved)
            BangNegotiationStatusPanel(
              icon: Icons.verified_outlined,
              label: 'Disetujui',
              amountText: formatCurrency(quote?.approvedAmount ?? 0),
              color: AppColors.success,
            )
          else if (isPendingCustomer) ...[
            BangNegotiationStatusPanel(
              icon: Icons.schedule_outlined,
              label: 'Menunggu customer',
              amountText: formatCurrency(quote?.amount.quotedAmount ?? 0),
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 9),
            BangActionButton(
              label: 'Lanjutkan tanpa respon customer',
              variant: BangActionButtonVariant.outlined,
              icon: Icons.double_arrow_rounded,
              isLoading: widget.isBypassingPrice,
              isEnabled: !widget.isOrderBusy || widget.isBypassingPrice,
              onPressed: _bypassApproval,
            ),
          ] else ...[
            if (needsRequote) ...[
              const Text(
                'Perubahan item perlu harga baru.',
                style: TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
            ],
            _quoteForm(canSubmitQuote),
          ],
        ],
      ),
    );
  }

  Widget _quoteForm(bool canSubmitQuote) {
    return Column(
      children: [
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          enabled: canSubmitQuote && !widget.isOrderBusy,
          decoration: driverDialogInputDecoration(
            labelText: 'Harga merchant',
            prefixText: 'Rp ',
          ),
        ),
        const SizedBox(height: 8),
        BangActionButton(
          label: 'Kirim Harga',
          icon: Icons.send_outlined,
          isLoading: widget.isSubmittingQuote,
          isEnabled:
              canSubmitQuote &&
              (!widget.isOrderBusy || widget.isSubmittingQuote),
          onPressed: _submitQuote,
        ),
      ],
    );
  }

  Future<void> _submitQuote() async {
    final amount = parseDriverCurrencyInput(_amountController.text);
    if (amount <= 0) {
      _showSnack('Harga merchant harus lebih dari 0.', isError: true);
      return;
    }

    final error = await widget.onSubmitQuote(
      amount: amount,
      pickupLocationId: widget.pickupLocationId,
    );
    if (!mounted) {
      return;
    }

    _showSnack(error ?? 'Harga Nitip dikirim.');
  }

  Future<void> _bypassApproval() async {
    final error = await widget.onBypassApproval(
      pickupLocationId: widget.pickupLocationId,
    );
    if (!mounted) {
      return;
    }

    _showSnack(error ?? 'Harga dilanjutkan tanpa respons customer.');
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : null,
      ),
    );
  }
}

class DriverShoppingItemsCard extends StatefulWidget {
  final DriverOrderModel order;
  final bool isOrderBusy;
  final bool isSavingCheckout;
  final bool Function(int pickupLocationId) isSavingItems;
  final bool canEditAvailability;
  final bool canUploadReceipt;
  final bool canCheckout;
  final bool Function(int pickupLocationId) isSubmittingQuote;
  final bool Function(int pickupLocationId) isBypassingPrice;
  final bool Function(int pickupLocationId) isMarkingMerchantOpen;
  final bool Function(int pickupLocationId) isClosingMerchant;
  final Future<String?> Function(XFile photo) onUploadReceipt;
  final Future<String?> Function({
    required double amount,
    int? pickupLocationId,
  })
  onSubmitQuote;
  final Future<String?> Function({required int pickupLocationId}) onBypassPrice;
  final Future<String?> Function({required int pickupLocationId})
  onMarkMerchantOpen;
  final Future<String?> Function({
    required int pickupLocationId,
    required String reason,
  })
  onMarkMerchantClosed;
  final Future<String?> Function(
    List<Map<String, dynamic>> items,
    int? pickupLocationId,
  )
  onSaveItems;
  final Future<String?> Function(
    List<Map<String, dynamic>> items,
    XFile? receiptPhoto,
  )
  onSave;

  const DriverShoppingItemsCard({
    super.key,
    required this.order,
    required this.isOrderBusy,
    required this.isSavingCheckout,
    required this.isSavingItems,
    required this.canEditAvailability,
    required this.canUploadReceipt,
    required this.canCheckout,
    required this.isSubmittingQuote,
    required this.isBypassingPrice,
    required this.isMarkingMerchantOpen,
    required this.isClosingMerchant,
    required this.onUploadReceipt,
    required this.onSubmitQuote,
    required this.onBypassPrice,
    required this.onMarkMerchantOpen,
    required this.onMarkMerchantClosed,
    required this.onSaveItems,
    required this.onSave,
  });

  @override
  State<DriverShoppingItemsCard> createState() =>
      DriverShoppingItemsCardState();
}

class DriverShoppingItemsCardState extends State<DriverShoppingItemsCard> {
  final Map<int, bool> _availability = {};
  final Set<int> _dirtyAvailabilityIds = {};
  bool _isUploadingReceipt = false;
  bool _checkoutSavedLocally = false;

  @override
  void initState() {
    super.initState();
    _checkoutSavedLocally = widget.order.shoppingCapabilities.hasCheckoutSaved;
    _syncControllers();
  }

  @override
  void didUpdateWidget(covariant DriverShoppingItemsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.id != widget.order.id) {
      _checkoutSavedLocally =
          widget.order.shoppingCapabilities.hasCheckoutSaved;
    } else if (widget.order.shoppingCapabilities.hasCheckoutSaved) {
      _checkoutSavedLocally = true;
    }

    if (oldWidget.order.shoppingItems != widget.order.shoppingItems) {
      _syncControllers();
    }
  }

  void _syncControllers() {
    final activeIds = widget.order.shoppingItems.map((item) => item.id).toSet();
    final staleIds = _availability.keys
        .where((id) => !activeIds.contains(id))
        .toList(growable: false);
    for (final id in staleIds) {
      _availability.remove(id);
      _dirtyAvailabilityIds.remove(id);
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final checkoutAllowed =
        widget.canCheckout &&
        (widget.order.shoppingNegotiation?.checkoutAllowed ?? false);
    final checkoutSaved =
        widget.order.shoppingCapabilities.hasCheckoutSaved ||
        _checkoutSavedLocally;
    final showCheckoutFields =
        widget.canUploadReceipt && (checkoutAllowed || checkoutSaved);
    final canSaveCheckout = checkoutAllowed && !checkoutSaved;
    final canEditAvailability =
        widget.canEditAvailability &&
        !widget.order.shoppingCapabilities.hasPendingItemChangeRequest;

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
              if (showCheckoutFields)
                const Text(
                  'Struk belanja',
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
            ...widget.order.shoppingItems.map(
              (item) => _buildItemEditor(
                item,
                showAvailabilityControl: canEditAvailability,
                canToggleAvailability: canEditAvailability,
              ),
            ),
            if (canEditAvailability &&
                _hasItemChangesForItems(widget.order.shoppingItems)) ...[
              const SizedBox(height: 2),
              SizedBox(
                width: double.infinity,
                child: BangActionButton(
                  label: 'Simpan Ketersediaan Item',
                  icon: Icons.checklist_rtl_outlined,
                  isLoading: widget.isSavingItems(0),
                  isEnabled: !widget.isOrderBusy || widget.isSavingItems(0),
                  onPressed: () =>
                      _saveItemAvailability(widget.order.shoppingItems, null),
                ),
              ),
            ],
          ] else
            ...widget.order.shoppingStops
                .where((stop) => !stop.isSkipped && !stop.isReplaced)
                .map(_buildStopSection),
          if (showCheckoutFields && _shoppingProofs().isNotEmpty) ...[
            const SizedBox(height: 4),
            _buildProofPreviewStrip(_shoppingProofs()),
            const SizedBox(height: 10),
          ],
          if (showCheckoutFields) ...[
            const SizedBox(height: 8),
            BangActionButton(
              label: !widget.order.hasProof('receipt')
                  ? 'Upload Foto Struk Opsional'
                  : 'Foto Struk Siap',
              variant: BangActionButtonVariant.outlined,
              icon: Icons.photo_camera_outlined,
              isLoading: _isUploadingReceipt,
              isEnabled: !widget.isOrderBusy || _isUploadingReceipt,
              onPressed: _uploadReceiptPhoto,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: BangActionButton(
                label: checkoutSaved
                    ? 'Checkout Nitip Tersimpan'
                    : 'Simpan Checkout Nitip',
                icon: checkoutSaved
                    ? Icons.check_circle_outline
                    : Icons.receipt_long,
                isLoading: widget.isSavingCheckout,
                isEnabled:
                    canSaveCheckout &&
                    (!widget.isOrderBusy || widget.isSavingCheckout),
                onPressed: _save,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemEditor(
    DriverShoppingItemModel item, {
    required bool showAvailabilityControl,
    required bool canToggleAvailability,
  }) {
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
              if (showAvailabilityControl)
                Checkbox(
                  value: isAvailable,
                  visualDensity: const VisualDensity(
                    horizontal: -4,
                    vertical: -4,
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: canToggleAvailability
                      ? (value) {
                          setState(() {
                            _dirtyAvailabilityIds.add(item.id);
                            _availability[item.id] = value ?? true;
                          });
                        }
                      : null,
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

  bool _areItemsReadyForQuote(List<DriverShoppingItemModel> items) {
    return items.isNotEmpty &&
        items.every((item) => _availability[item.id] ?? item.isAvailable);
  }

  bool _isStopAvailabilityLocked(
    DriverShoppingStopModel stop,
    ShoppingMerchantQuoteModel? quote,
  ) {
    return stop.isPricePendingCustomer ||
        stop.isPriceApproved ||
        (quote?.isPendingCustomer ?? false) ||
        (quote?.isApproved ?? false);
  }

  bool _canEditAvailabilityForStop(DriverShoppingStopModel stop) {
    final quote = widget.order.shoppingNegotiation?.quoteForPickup(
      stop.pickupLocationId,
    );

    if (!widget.canEditAvailability ||
        widget.order.shoppingCapabilities.hasPendingItemChangeRequest ||
        !stop.isActive ||
        stop.fulfillmentStatus.toUpperCase() == 'PENDING' ||
        _isStopAvailabilityLocked(stop, quote)) {
      return false;
    }

    return stop.isOpenConfirmed ||
        stop.isItemsPendingCustomer ||
        stop.isItemsConfirmed;
  }

  bool _shouldShowQuotePanelForStop(
    DriverShoppingStopModel stop,
    ShoppingMerchantQuoteModel? quote,
    List<DriverShoppingItemModel> items,
  ) {
    if (quote == null ||
        !quote.hasAvailableItems ||
        !_areItemsReadyForQuote(items) ||
        stop.isItemsPendingCustomer ||
        widget.order.shoppingCapabilities.hasPendingItemChangeRequest) {
      return false;
    }

    final hasQuoteState =
        quote.amount.hasQuote || quote.isPendingDriver || quote.isApproved;

    return hasQuoteState ||
        quote.needsRequote ||
        (stop.availabilityConfirmed && quote.amount.canDriverSubmitQuote);
  }

  Widget _buildStopSection(DriverShoppingStopModel stop) {
    final activeItems = stop.items;
    final quote = widget.order.shoppingNegotiation?.quoteForPickup(
      stop.pickupLocationId,
    );
    final shouldShowQuotePanel = _shouldShowQuotePanelForStop(
      stop,
      quote,
      activeItems,
    );
    final showAvailabilityControl =
        widget.canEditAvailability &&
        !widget.order.shoppingCapabilities.hasPendingItemChangeRequest;
    final canEditStopAvailability = _canEditAvailabilityForStop(stop);
    final isSavingStopItems = widget.isSavingItems(stop.pickupLocationId);
    final isPendingMerchant = stop.fulfillmentStatus.toUpperCase() == 'PENDING';
    final isOpeningStop = widget.isMarkingMerchantOpen(stop.pickupLocationId);
    final isClosingStop = widget.isClosingMerchant(stop.pickupLocationId);

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
              if (stop.isTerminal)
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
                        ? 'Resto tutup/order batal'
                        : stop.isReplaced
                        ? 'Diganti'
                        : stop.isCompleted
                        ? 'Selesai'
                        : 'Dilewati',
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              if (stop.isActive && !isPendingMerchant)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _stopStatusLabel(stop),
                    style: const TextStyle(
                      color: AppColors.primaryDark,
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
          if (stop.isActive && isPendingMerchant) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: BangActionButton(
                    label: 'Resto tutup',
                    variant: BangActionButtonVariant.outlined,
                    icon: Icons.storefront_outlined,
                    isLoading: isClosingStop,
                    isEnabled: !widget.isOrderBusy || isClosingStop,
                    onPressed: () => _closeMerchant(stop),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: BangActionButton(
                    label: 'Resto buka',
                    icon: Icons.check_circle_outline,
                    isLoading: isOpeningStop,
                    isEnabled: !widget.isOrderBusy || isOpeningStop,
                    onPressed: () => _openMerchant(stop),
                  ),
                ),
              ],
            ),
          ],
          if (stop.isActive && !isPendingMerchant && shouldShowQuotePanel) ...[
            DriverShoppingMerchantQuotePanel(
              pickupLocationId: stop.pickupLocationId,
              quote: quote,
              isOrderBusy: widget.isOrderBusy,
              isSubmittingQuote: widget.isSubmittingQuote(
                stop.pickupLocationId,
              ),
              isBypassingPrice: widget.isBypassingPrice(stop.pickupLocationId),
              onSubmitQuote: widget.onSubmitQuote,
              onBypassApproval: widget.onBypassPrice,
            ),
          ],
          const SizedBox(height: 8),
          if (stop.isActive && !isPendingMerchant)
            ...activeItems.map(
              (item) => _buildItemEditor(
                item,
                showAvailabilityControl: showAvailabilityControl,
                canToggleAvailability: canEditStopAvailability,
              ),
            ),
          if (stop.isActive &&
              canEditStopAvailability &&
              (!stop.availabilityConfirmed ||
                  _hasItemChangesForItems(activeItems))) ...[
            const SizedBox(height: 2),
            SizedBox(
              width: double.infinity,
              child: BangActionButton(
                label: 'Simpan Ketersediaan Item',
                icon: Icons.checklist_rtl_outlined,
                isLoading: isSavingStopItems,
                isEnabled: !widget.isOrderBusy || isSavingStopItems,
                onPressed: () =>
                    _saveItemAvailability(activeItems, stop.pickupLocationId),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _stopStatusLabel(DriverShoppingStopModel stop) {
    if (stop.isOpenConfirmed) return 'Buka';
    if (stop.isItemsPendingCustomer) return 'Menunggu keputusan item';
    if (stop.isItemsConfirmed) return 'Item fix';
    if (stop.isPricePendingCustomer) return 'Menunggu harga';
    if (stop.isPriceApproved) return 'Harga disetujui';
    return stop.fulfillmentStatus;
  }

  Future<void> _openMerchant(DriverShoppingStopModel stop) async {
    final error = await widget.onMarkMerchantOpen(
      pickupLocationId: stop.pickupLocationId,
    );
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? '${stop.merchant.name} ditandai buka.'),
        backgroundColor: error == null ? null : AppColors.error,
      ),
    );
  }

  Future<void> _closeMerchant(DriverShoppingStopModel stop) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resto tutup?'),
        content: Text(
          '${stop.merchant.name} akan dibatalkan dan itemnya tidak dihitung.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    final error = await widget.onMarkMerchantClosed(
      pickupLocationId: stop.pickupLocationId,
      reason: 'Resto tutup/order batal saat driver tiba.',
    );
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? '${stop.merchant.name} ditandai tutup.'),
        backgroundColor: error == null ? null : AppColors.error,
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
    final error = await widget.onUploadReceipt(photo);

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

  bool _hasItemChangesForItems(List<DriverShoppingItemModel> items) {
    return items.any((item) => _dirtyAvailabilityIds.contains(item.id));
  }

  List<Map<String, dynamic>> _itemPayload(List<DriverShoppingItemModel> items) {
    return items
        .map(
          (item) => <String, dynamic>{
            'id': item.id,
            'quantity': item.quantity,
            'is_available': _availability[item.id] ?? item.isAvailable,
            'notes': item.notes,
          },
        )
        .toList(growable: false);
  }

  Future<void> _saveItemAvailability(
    List<DriverShoppingItemModel> items,
    int? pickupLocationId,
  ) async {
    final error = await widget.onSaveItems(
      _itemPayload(items),
      pickupLocationId,
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Ketersediaan item disimpan.'),
        backgroundColor: error == null ? null : AppColors.error,
      ),
    );

    if (error == null) {
      setState(() {
        for (final item in items) {
          _dirtyAvailabilityIds.remove(item.id);
        }
      });
    }
  }

  Future<void> _save() async {
    final error = await widget.onSave(
      _itemPayload(widget.order.shoppingItems),
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
      setState(() {
        _checkoutSavedLocally = true;
        _syncControllers();
      });
    }
  }
}
