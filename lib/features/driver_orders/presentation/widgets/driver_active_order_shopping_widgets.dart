import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../config/app_colors.dart';
import '../../../../core/widgets/bang_action_button.dart';
import '../../../../core/widgets/bang_confirmation_dialog.dart';
import '../../../../core/widgets/bang_decision_action_grid.dart';
import '../../../../core/widgets/bang_negotiation_status_panel.dart';
import '../../../../core/widgets/bang_shopping_merchant_request_summary.dart';
import '../../../../core/widgets/bang_swipe_action_button.dart';
import '../../../../core/widgets/bang_unavailable_item_picker.dart';
import '../../../../models/driver_order_model.dart';
import '../../../../models/shopping_negotiation_model.dart';
import '../../../../models/shopping_order_capability_model.dart';
import '../../../../utils/order_formatters.dart';
import '../../../../utils/rupiah_input_formatter.dart';
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
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Request Item Customer',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
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

    showDriverActiveOrderSnackBar(
      context,
      message: error ?? 'Request item diproses.',
      isError: error != null,
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
    this.initialDraft = '',
    this.onDraftChanged,
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
  final String initialDraft;
  final ValueChanged<String>? onDraftChanged;

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
    if (widget.initialDraft.trim().isNotEmpty) {
      _amountController.text = formatRupiahInputText(widget.initialDraft);
    } else {
      _primeAmount();
    }
  }

  @override
  void didUpdateWidget(covariant DriverShoppingMerchantQuotePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pickupLocationId != widget.pickupLocationId) {
      _amountController.text = formatRupiahInputText(widget.initialDraft);
      if (_amountController.text.trim().isEmpty) {
        _primeAmount();
      }
    } else if (oldWidget.quote?.displayAmount != widget.quote?.displayAmount &&
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
      _amountController.text = formatRupiahInputAmount(amount!);
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
        borderRadius: BorderRadius.circular(10),
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
            BangSwipeActionButton(
              label: 'Geser untuk bypass harga',
              loadingLabel: 'Memproses harga...',
              isLoading: widget.isBypassingPrice,
              isEnabled: !widget.isOrderBusy && !widget.isBypassingPrice,
              onSubmit: _bypassApproval,
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
          inputFormatters: const [RupiahInputFormatter()],
          enabled: canSubmitQuote && !widget.isOrderBusy,
          onChanged: widget.onDraftChanged,
          decoration: driverDialogInputDecoration(
            labelText: 'Harga tempat',
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
      _showSnack('Harga tempat harus lebih dari 0.', isError: true);
      return;
    }

    final error = await widget.onSubmitQuote(
      amount: amount,
      pickupLocationId: widget.pickupLocationId,
    );
    if (!mounted) {
      return;
    }

    if (error == null) {
      widget.onDraftChanged?.call('');
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
    showDriverActiveOrderSnackBar(context, message: message, isError: isError);
  }
}

class DriverShoppingItemsDraftStore {
  final Map<int, bool> availability = <int, bool>{};
  final Set<int> dirtyAvailabilityIds = <int>{};
  final Map<int, String> quoteDrafts = <int, String>{};
}

class DriverShoppingItemsCard extends StatefulWidget {
  final DriverOrderModel order;
  final bool isOrderBusy;
  final bool Function(int pickupLocationId) isSavingItems;
  final bool canEditAvailability;
  final bool canUploadReceipt;
  final bool Function(int pickupLocationId) isSubmittingQuote;
  final bool Function(int pickupLocationId) isBypassingPrice;
  final bool Function(int pickupLocationId) isBypassingUnavailableItems;
  final bool Function(int pickupLocationId, String action)
  isDecidingUnavailableItems;
  final bool Function(int pickupLocationId) isMarkingMerchantOpen;
  final bool Function(int pickupLocationId) isClosingMerchant;
  final bool isDeliveryFeeRevisionPending;
  final int? selectedPickupLocationId;
  final bool mapFirstMode;
  final bool readOnly;
  final DriverShoppingItemsDraftStore? draftStore;
  final Future<String?> Function(XFile photo) onUploadReceipt;
  final Future<String?> Function({
    required double amount,
    int? pickupLocationId,
  })
  onSubmitQuote;
  final Future<String?> Function({required int pickupLocationId}) onBypassPrice;
  final Future<String?> Function({required int pickupLocationId})
  onBypassUnavailableItems;
  final Future<String?> Function({
    required int pickupLocationId,
    required String action,
    required List<int> itemIds,
  })
  onDecideUnavailableItems;
  final Future<String?> Function({required int pickupLocationId})
  onMarkMerchantOpen;
  final Future<String?> Function({
    required int pickupLocationId,
    required String reason,
    XFile? storeClosedPhoto,
  })
  onMarkMerchantClosed;
  final Future<String?> Function(DriverShoppingStopModel stop)
  onReplaceMerchant;
  final Future<String?> Function() onCancelShoppingOrder;
  final Future<String?> Function(DriverShoppingStopModel stop)
  onApproveMerchantReplacement;
  final Future<String?> Function(DriverShoppingStopModel stop)
  onRejectMerchantReplacement;
  final Future<String?> Function(DriverShoppingStopModel stop)
  onReplaceUnavailableItems;
  final Future<String?> Function(
    List<Map<String, dynamic>> items,
    int? pickupLocationId,
  )
  onSaveItems;

  const DriverShoppingItemsCard({
    super.key,
    required this.order,
    required this.isOrderBusy,
    required this.isSavingItems,
    required this.canEditAvailability,
    required this.canUploadReceipt,
    required this.isSubmittingQuote,
    required this.isBypassingPrice,
    required this.isBypassingUnavailableItems,
    required this.isDecidingUnavailableItems,
    required this.isMarkingMerchantOpen,
    required this.isClosingMerchant,
    this.isDeliveryFeeRevisionPending = false,
    this.selectedPickupLocationId,
    this.mapFirstMode = false,
    this.readOnly = false,
    this.draftStore,
    required this.onUploadReceipt,
    required this.onSubmitQuote,
    required this.onBypassPrice,
    required this.onBypassUnavailableItems,
    required this.onDecideUnavailableItems,
    required this.onMarkMerchantOpen,
    required this.onMarkMerchantClosed,
    required this.onReplaceMerchant,
    required this.onCancelShoppingOrder,
    required this.onApproveMerchantReplacement,
    required this.onRejectMerchantReplacement,
    required this.onReplaceUnavailableItems,
    required this.onSaveItems,
  });

  @override
  State<DriverShoppingItemsCard> createState() =>
      DriverShoppingItemsCardState();
}

class DriverShoppingItemsCardState extends State<DriverShoppingItemsCard> {
  final Map<int, bool> _localAvailability = {};
  final Set<int> _localDirtyAvailabilityIds = {};
  final Map<int, String> _localQuoteDrafts = {};
  final Set<int> _replacingPickupIds = {};
  final Set<int> _respondingApprovalPickupIds = {};
  bool _isUploadingReceipt = false;
  bool _isCancellingShoppingOrder = false;

  Map<int, bool> get _availability =>
      widget.draftStore?.availability ?? _localAvailability;
  Set<int> get _dirtyAvailabilityIds =>
      widget.draftStore?.dirtyAvailabilityIds ?? _localDirtyAvailabilityIds;
  Map<int, String> get _quoteDrafts =>
      widget.draftStore?.quoteDrafts ?? _localQuoteDrafts;

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
        !widget.order.shoppingCapabilities.hasPendingItemChangeRequest &&
        (widget.order.shoppingNegotiation?.checkoutAllowed ?? false);
    final checkoutSaved = widget.order.shoppingCapabilities.hasCheckoutSaved;
    final showCheckoutFields =
        !widget.readOnly &&
        widget.canUploadReceipt &&
        (checkoutAllowed || checkoutSaved);
    final canEditAvailability =
        !widget.readOnly &&
        widget.canEditAvailability &&
        !widget.order.shoppingCapabilities.hasPendingItemChangeRequest;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
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
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
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
          // Permintaan approval ganti toko oleh customer ditampilkan di level
          // order (memindai SEMUA stop), bukan hanya di stop terpilih -- karena
          // permintaan biasanya jatuh di stop FAILED/parkir yang tidak sedang
          // dilihat driver.
          for (final stop in widget.order.shoppingStops)
            if (stop.pendingReplacementApproval?.isPending ?? false) ...[
              _buildMerchantReplacementApprovalCard(stop),
              const SizedBox(height: 10),
            ],
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
                .where((stop) => !stop.isSkipped)
                .where(
                  (stop) => widget.selectedPickupLocationId != null
                      // Tab spesifik dipilih: tampilkan apa adanya sebagai
                      // history, termasuk yang sudah diganti (REPLACED).
                      ? stop.pickupLocationId == widget.selectedPickupLocationId
                      : !stop.isReplaced,
                )
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
                  ? 'Ambil Foto Struk (Opsional)'
                  : 'Foto Struk Siap',
              variant: BangActionButtonVariant.outlined,
              icon: Icons.photo_camera_outlined,
              isLoading: _isUploadingReceipt,
              isEnabled: !widget.isOrderBusy || _isUploadingReceipt,
              onPressed: _uploadReceiptPhoto,
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

    if (widget.readOnly ||
        !widget.canEditAvailability ||
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
    final merchantAddress = _displayMerchantAddress(stop.merchant);
    final quote = widget.order.shoppingNegotiation?.quoteForPickup(
      stop.pickupLocationId,
    );
    final shouldShowQuotePanel =
        !widget.readOnly &&
        _shouldShowQuotePanelForStop(stop, quote, activeItems);
    final showAvailabilityControl =
        !widget.readOnly &&
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
                width: 21,
                height: 21,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  '${stop.sequenceNo <= 0 ? 1 : stop.sequenceNo}',
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    height: 1,
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
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    stop.isFailed
                        ? 'Tempat tutup/order batal'
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
                    borderRadius: BorderRadius.circular(10),
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
          if (merchantAddress != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Text(
                merchantAddress,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.only(left: 32, top: 5),
            child: Text(
              formatShoppingAttemptProgress(
                attemptNo: stop.chainAttemptNo,
                attemptLimit: stop.chainFailedAttemptLimit,
                totalFailed: stop.orderFailedTripCount,
              ),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (stop.isActive && isPendingMerchant && !widget.mapFirstMode) ...[
            const SizedBox(height: 10),
            _buildPendingMerchantActions(
              stop: stop,
              isClosingStop: isClosingStop,
              isOpeningStop: isOpeningStop,
            ),
          ],
          if (stop.isActive && !isPendingMerchant && shouldShowQuotePanel) ...[
            DriverShoppingMerchantQuotePanel(
              key: ValueKey('shopping-quote-${stop.pickupLocationId}'),
              pickupLocationId: stop.pickupLocationId,
              quote: quote,
              isOrderBusy: widget.isOrderBusy,
              isSubmittingQuote: widget.isSubmittingQuote(
                stop.pickupLocationId,
              ),
              isBypassingPrice: widget.isBypassingPrice(stop.pickupLocationId),
              onSubmitQuote: widget.onSubmitQuote,
              onBypassApproval: widget.onBypassPrice,
              initialDraft: _quoteDrafts[stop.pickupLocationId] ?? '',
              onDraftChanged: (value) {
                if (value.trim().isEmpty) {
                  _quoteDrafts.remove(stop.pickupLocationId);
                } else {
                  _quoteDrafts[stop.pickupLocationId] = value;
                }
              },
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
          // Ganti toko/resto (canReplaceMerchant) dan Batalkan pesanan boleh
          // muncul walau stop read-only (mis. sudah FAILED/parkir) -- backend
          // sudah memvalidasi kelayakannya. Aksi berbasis item lain tetap butuh
          // mode edit.
          if ((!widget.readOnly &&
                  (stop.canDriverReplaceUnavailableItems ||
                      stop.canDriverContinueWithoutUnavailableItem ||
                      stop.canDriverCancelUnavailableMerchant)) ||
              stop.canReplaceMerchant ||
              (_canCancelShoppingOrder && _stopClosedForCancel(stop))) ...[
            const SizedBox(height: 10),
            _buildUnavailableDecisionActions(stop),
          ],
          if (!widget.readOnly && stop.canDriverBypassUnavailableItems) ...[
            const SizedBox(height: 10),
            _buildUnavailableItemBypassPanel(stop),
          ],
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

  Widget _buildMerchantReplacementApprovalCard(DriverShoppingStopModel stop) {
    final approval = stop.pendingReplacementApproval;
    final newMerchant = (approval?.newMerchantName ?? '').trim();
    final distanceKm = approval?.distanceKm;
    final distanceText = distanceKm != null
        ? '±${distanceKm.toStringAsFixed(1).replaceAll('.', ',')} km dari toko lama'
        : 'lebih jauh dari toko lama';
    final isResponding = _respondingApprovalPickupIds.contains(
      stop.pickupLocationId,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardYellow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.swap_horiz_rounded,
                size: 18,
                color: AppColors.primaryDark,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Customer minta ganti toko/resto',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            newMerchant.isEmpty
                ? 'Toko/resto pengganti $distanceText. Kamu yang menempuh jaraknya — setujui hanya jika sanggup.'
                : 'Ganti ke "$newMerchant" ($distanceText). Kamu yang menempuh jaraknya — setujui hanya jika sanggup.',
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: BangActionButton(
                  label: 'Tolak',
                  variant: BangActionButtonVariant.outlined,
                  icon: Icons.close_rounded,
                  isLoading: isResponding,
                  isEnabled: !widget.isOrderBusy || isResponding,
                  onPressed: () =>
                      _respondMerchantReplacementApproval(stop, approve: false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: BangActionButton(
                  label: 'Terima',
                  icon: Icons.check_rounded,
                  isLoading: isResponding,
                  isEnabled: !widget.isOrderBusy || isResponding,
                  onPressed: () =>
                      _respondMerchantReplacementApproval(stop, approve: true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Izin batal level-order dari backend (otomatis mati begitu ada resto yang
  /// sudah dibeli). Backend tetap gerbang terakhirnya.
  bool get _canCancelShoppingOrder =>
      widget.order.shoppingCapabilities.canDriverCancelShoppingOrder;

  /// "Batalkan pesanan" hanya boleh tampil setelah driver menandai stop ini
  /// tutup lewat "Tempat tutup" (stop -> FAILED) atau batas percobaan tercapai
  /// (ABANDONED). Sebelum itu stop masih "Tujuan berikutnya" sehingga opsi batal
  /// tidak ditampilkan.
  bool _stopClosedForCancel(DriverShoppingStopModel stop) =>
      stop.isFailed || stop.isAbandoned;

  Widget _buildUnavailableDecisionActions(DriverShoppingStopModel stop) {
    final unavailableItems = stop.items
        .where((item) => !item.isAvailable)
        .toList(growable: false);
    final isRemoving = widget.isDecidingUnavailableItems(
      stop.pickupLocationId,
      'REMOVE',
    );
    final isCancelling = widget.isDecidingUnavailableItems(
      stop.pickupLocationId,
      'CANCEL_MERCHANT',
    );
    final isReplacingMerchant = _replacingPickupIds.contains(
      stop.pickupLocationId,
    );

    return BangDecisionActionGrid(
      actions: [
        if (stop.canDriverReplaceUnavailableItems)
          BangDecisionAction(
            key: ValueKey(
              'driver-shopping-action-replace-items-${stop.pickupLocationId}',
            ),
            label: 'Ganti item',
            icon: Icons.find_replace_rounded,
            tone: BangDecisionActionTone.orange,
            isEnabled: !widget.isOrderBusy,
            onPressed: () => _replaceUnavailableItems(stop),
          ),
        if (stop.canReplaceMerchant)
          BangDecisionAction(
            key: ValueKey(
              'driver-shopping-action-replace-merchant-${stop.pickupLocationId}',
            ),
            label: 'Ganti toko/resto',
            icon: Icons.swap_horiz_rounded,
            tone: BangDecisionActionTone.orange,
            isLoading: isReplacingMerchant,
            isEnabled: !widget.isOrderBusy || isReplacingMerchant,
            onPressed: () => _replaceMerchant(stop),
          ),
        if (stop.canDriverContinueWithoutUnavailableItem &&
            unavailableItems.length > 1)
          BangDecisionAction(
            key: ValueKey(
              'driver-shopping-action-continue-${stop.pickupLocationId}',
            ),
            label: 'Pilih item',
            icon: Icons.remove_circle_outline,
            tone: BangDecisionActionTone.amber,
            isLoading: isRemoving,
            isEnabled: !widget.isOrderBusy || isRemoving,
            onPressed: () => _pickUnavailableItems(stop, unavailableItems),
          ),
        if (stop.canDriverCancelUnavailableMerchant)
          BangDecisionAction(
            key: ValueKey(
              'driver-shopping-action-cancel-${stop.pickupLocationId}',
            ),
            label: 'Batal tempat',
            icon: Icons.storefront_outlined,
            tone: BangDecisionActionTone.red,
            isLoading: isCancelling,
            isEnabled: !widget.isOrderBusy || isCancelling,
            onPressed: () => _cancelUnavailableMerchant(stop),
          ),
        if (_canCancelShoppingOrder && _stopClosedForCancel(stop))
          BangDecisionAction(
            key: ValueKey(
              'driver-shopping-action-cancel-order-${stop.pickupLocationId}',
            ),
            label: 'Batalkan pesanan',
            icon: Icons.close_rounded,
            tone: BangDecisionActionTone.red,
            isLoading: _isCancellingShoppingOrder,
            isEnabled: !widget.isOrderBusy || _isCancellingShoppingOrder,
            onPressed: _cancelShoppingOrder,
          ),
      ],
    );
  }

  Widget _buildUnavailableItemBypassPanel(DriverShoppingStopModel stop) {
    final unavailableItems = stop.items
        .where((item) => !item.isAvailable)
        .toList(growable: false);
    final merchantWillBeCancelled = !stop.items.any((item) => item.isAvailable);
    final isBypassing = widget.isBypassingUnavailableItems(
      stop.pickupLocationId,
    );
    final itemLabel = unavailableItems.length == 1
        ? unavailableItems.first.name
        : '${unavailableItems.length} item tidak tersedia';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardYellow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.inventory_2_outlined,
                color: AppColors.primaryDark,
                size: 18,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Menunggu keputusan item',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            merchantWillBeCancelled
                ? 'Semua item toko/resto tidak tersedia. Bypass akan membatalkan tempat dan dapat membatalkan order sesuai aturan biaya Nitip.'
                : '$itemLabel akan dihapus dari order. Item lain di toko/resto ini tetap dilanjutkan dan harga perlu dikirim ulang.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          BangSwipeActionButton(
            label: 'Geser untuk bypass semua item',
            loadingLabel: 'Memproses bypass item...',
            isLoading: isBypassing,
            isEnabled: !widget.isOrderBusy || isBypassing,
            color: merchantWillBeCancelled
                ? AppColors.error
                : AppColors.primary,
            onSubmit: () => _bypassUnavailableItems(stop),
          ),
        ],
      ),
    );
  }

  Future<void> _pickUnavailableItems(
    DriverShoppingStopModel stop,
    List<DriverShoppingItemModel> unavailableItems,
  ) async {
    final selectedIds = await showBangUnavailableItemPicker(
      context,
      items: unavailableItems
          .map(
            (item) => BangUnavailableItemChoice(
              id: item.id,
              label: '${item.quantity <= 0 ? 1 : item.quantity}x ${item.name}',
            ),
          )
          .toList(growable: false),
    );
    if (selectedIds == null || selectedIds.isEmpty || !mounted) {
      return;
    }

    await _submitUnavailableDecision(
      stop,
      action: 'REMOVE',
      itemIds: selectedIds,
      successMessage: '${selectedIds.length} item dilewati.',
    );
  }

  Future<void> _cancelUnavailableMerchant(DriverShoppingStopModel stop) async {
    final confirmed = await showBangConfirmationDialog(
      context,
      title: 'Batalkan ${stop.merchant.name}?',
      message:
          'Semua item dari tempat ini tidak akan dibeli. Jika ini tempat terakhir, order Nitip dapat ikut dibatalkan.',
      confirmLabel: 'Batal tempat',
      isDestructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }

    await _submitUnavailableDecision(
      stop,
      action: 'CANCEL_MERCHANT',
      itemIds: const <int>[],
      successMessage: '${stop.merchant.name} dibatalkan.',
    );
  }

  Future<void> _submitUnavailableDecision(
    DriverShoppingStopModel stop, {
    required String action,
    required List<int> itemIds,
    required String successMessage,
  }) async {
    final error = await widget.onDecideUnavailableItems(
      pickupLocationId: stop.pickupLocationId,
      action: action,
      itemIds: itemIds,
    );
    if (!mounted) {
      return;
    }

    showDriverActiveOrderSnackBar(
      context,
      message: error ?? successMessage,
      isError: error != null,
    );
  }

  Future<void> _bypassUnavailableItems(DriverShoppingStopModel stop) async {
    final error = await widget.onBypassUnavailableItems(
      pickupLocationId: stop.pickupLocationId,
    );
    if (!mounted) {
      return;
    }

    showDriverActiveOrderSnackBar(
      context,
      message: error ?? 'Order dilanjutkan tanpa item yang tidak tersedia.',
      isError: error != null,
    );
  }

  Widget _buildPendingMerchantActions({
    required DriverShoppingStopModel stop,
    required bool isClosingStop,
    required bool isOpeningStop,
  }) {
    // A pending route-fee proposal blocks final checkout, not merchant work.
    final canPressMerchantAction = !widget.isOrderBusy || isClosingStop;
    final canPressOpenAction = !widget.isOrderBusy || isOpeningStop;
    final closeButton = BangActionButton(
      label: 'Tempat tutup',
      variant: BangActionButtonVariant.outlined,
      icon: Icons.cancel_outlined,
      isLoading: isClosingStop,
      isEnabled: canPressMerchantAction,
      onPressed: () => _closeMerchant(stop),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.error,
        disabledForegroundColor: AppColors.textMuted,
        disabledBackgroundColor: AppColors.white,
        side: const BorderSide(color: AppColors.error),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800),
      ),
    );
    final openButton = BangActionButton(
      label: 'Tempat buka',
      icon: Icons.storefront_outlined,
      isLoading: isOpeningStop,
      isEnabled: canPressOpenAction,
      onPressed: () => _openMerchant(stop),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        disabledBackgroundColor: AppColors.surfaceAlt,
        disabledForegroundColor: AppColors.textMuted,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final buttons = constraints.maxWidth < 240
            ? Column(
                children: [
                  SizedBox(width: double.infinity, child: closeButton),
                  const SizedBox(height: 8),
                  SizedBox(width: double.infinity, child: openButton),
                ],
              )
            : Row(
                children: [
                  Expanded(child: closeButton),
                  const SizedBox(width: 8),
                  Expanded(child: openButton),
                ],
              );

        return buttons;
      },
    );
  }

  String? _displayMerchantAddress(DriverShoppingMerchantModel merchant) {
    final address = (merchant.address ?? '').trim();
    final hasMapPoint = merchant.latitude != null && merchant.longitude != null;
    if (address.isEmpty || address == '-') {
      return hasMapPoint ? 'Titik lokasi toko/resto' : null;
    }

    final lower = address.toLowerCase();
    final looksLikeCoordinate = RegExp(
      r'-?\d+\.\d+,\s*-?\d+\.\d+',
    ).hasMatch(address);
    if (looksLikeCoordinate ||
        lower.contains('dummy') ||
        lower.startsWith('lokasi bangdeliv') ||
        lower.startsWith('lokasi bang deliv')) {
      return hasMapPoint ? 'Titik lokasi toko/resto' : null;
    }

    var cleaned = address;
    final merchantPrefix = '${merchant.name.trim()},';
    if (cleaned.toLowerCase().startsWith(merchantPrefix.toLowerCase())) {
      cleaned = cleaned.substring(merchantPrefix.length).trim();
    }

    final segments = cleaned
        .split(',')
        .map((segment) => segment.trim())
        .where(
          (segment) =>
              segment.isNotEmpty && segment.toLowerCase() != 'indonesia',
        )
        .toList(growable: false);
    if (segments.isEmpty) {
      return null;
    }

    return segments.take(3).join(', ');
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

    showDriverActiveOrderSnackBar(
      context,
      message: error ?? '${stop.merchant.name} ditandai buka.',
      isError: error != null,
    );
  }

  Future<void> _closeMerchant(DriverShoppingStopModel stop) async {
    final confirmed = await showBangConfirmationDialog(
      context,
      title: 'Tempat tutup?',
      message:
          '${stop.merchant.name} akan dibatalkan dan itemnya tidak dihitung.',
      confirmLabel: 'Tutup',
      isDestructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }

    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 78,
      maxWidth: 1600,
    );
    if (!mounted) {
      return;
    }
    if (photo == null) {
      final continueWithoutCompensation = await showBangConfirmationDialog(
        context,
        title: 'Lanjut tanpa foto?',
        message:
            'Toko/resto tetap dapat ditutup, tetapi perjalanan ini tidak masuk kompensasi sampai bukti tervalidasi.',
        confirmLabel: 'Lanjut tanpa foto',
        isDestructive: true,
      );
      if (!continueWithoutCompensation || !mounted) {
        return;
      }
    }

    final error = await widget.onMarkMerchantClosed(
      pickupLocationId: stop.pickupLocationId,
      reason: 'Tempat tutup/order batal saat driver tiba.',
      storeClosedPhoto: photo,
    );
    if (!mounted) {
      return;
    }

    showDriverActiveOrderSnackBar(
      context,
      message: error ?? '${stop.merchant.name} ditandai tutup.',
      isError: error != null,
    );
  }

  Future<void> showMerchantClosedFlow(int pickupLocationId) async {
    for (final stop in widget.order.shoppingStops) {
      if (stop.pickupLocationId == pickupLocationId) {
        await _closeMerchant(stop);
        return;
      }
    }
  }

  Future<void> _cancelShoppingOrder() async {
    final confirmed = await showBangConfirmationDialog(
      context,
      title: 'Batalkan pesanan Nitip?',
      message:
          'Karena belum ada toko/resto yang dibeli, pesanan bisa dibatalkan '
          'tanpa biaya. Tindakan ini tidak bisa dibatalkan.',
      confirmLabel: 'Batalkan pesanan',
      isDestructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }

    setState(() => _isCancellingShoppingOrder = true);
    final error = await widget.onCancelShoppingOrder();
    if (!mounted) {
      return;
    }
    setState(() => _isCancellingShoppingOrder = false);
    if (error != null) {
      showDriverActiveOrderSnackBar(context, message: error, isError: true);
    }
  }

  Future<void> _replaceMerchant(DriverShoppingStopModel stop) async {
    setState(() => _replacingPickupIds.add(stop.pickupLocationId));
    final error = await widget.onReplaceMerchant(stop);
    if (!mounted) {
      return;
    }
    setState(() => _replacingPickupIds.remove(stop.pickupLocationId));
    if (error != null) {
      showDriverActiveOrderSnackBar(context, message: error, isError: true);
    }
  }

  Future<void> _respondMerchantReplacementApproval(
    DriverShoppingStopModel stop, {
    required bool approve,
  }) async {
    setState(() => _respondingApprovalPickupIds.add(stop.pickupLocationId));
    final error = approve
        ? await widget.onApproveMerchantReplacement(stop)
        : await widget.onRejectMerchantReplacement(stop);
    if (!mounted) {
      return;
    }
    setState(() => _respondingApprovalPickupIds.remove(stop.pickupLocationId));
    if (error != null) {
      showDriverActiveOrderSnackBar(context, message: error, isError: true);
    }
  }

  Future<void> _replaceUnavailableItems(DriverShoppingStopModel stop) async {
    final error = await widget.onReplaceUnavailableItems(stop);
    if (!mounted || error == null) {
      return;
    }
    showDriverActiveOrderSnackBar(context, message: error, isError: true);
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
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 96,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
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

  Future<void> _uploadReceiptPhoto() async {
    final photo = await pickDriverOrderCameraImage(context);
    if (photo == null || !mounted) {
      return;
    }

    setState(() => _isUploadingReceipt = true);
    final error = await widget.onUploadReceipt(photo);

    if (!mounted) {
      return;
    }

    setState(() => _isUploadingReceipt = false);
    showDriverActiveOrderSnackBar(
      context,
      message: error ?? 'Foto struk berhasil diupload.',
      isError: error != null,
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

    showDriverActiveOrderSnackBar(
      context,
      message: error ?? 'Ketersediaan item disimpan.',
      isError: error != null,
    );

    if (error == null) {
      setState(() {
        for (final item in items) {
          _dirtyAvailabilityIds.remove(item.id);
        }
      });
    }
  }
}
