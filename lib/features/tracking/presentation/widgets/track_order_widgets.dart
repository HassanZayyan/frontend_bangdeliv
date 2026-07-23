import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_routes.dart';
import '../../../../core/widgets/bang_amount_negotiation_card.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../core/widgets/bang_confirmation_dialog.dart';
import '../../../../core/widgets/bang_decision_action_grid.dart';
import '../../../../core/widgets/bang_shopping_merchant_request_summary.dart';
import '../../../../core/widgets/bang_unavailable_item_picker.dart';
import '../../../../models/customer_order_model.dart';
import '../../../../models/shopping_order_capability_model.dart';
import '../../../../utils/order_formatters.dart';
import '../../../../utils/order_status.dart';
import '../../../orders/application/customer_order_providers.dart';
import '../../../shopping/presentation/screens/shopping_add_item_screen.dart';
import '../../application/customer_order_tracking_provider.dart';

class TrackShoppingOrderItemsCard extends ConsumerStatefulWidget {
  final CustomerOrderDetailModel detail;
  final Future<void> Function()? onChanged;
  final GlobalKey Function(int pickupLocationId)? shoppingPriceFocusKeyFor;
  final int? selectedPickupLocationId;
  final bool showPricing;
  final bool showGlobalActions;
  final bool showStops;

  const TrackShoppingOrderItemsCard({
    super.key,
    required this.detail,
    this.onChanged,
    this.shoppingPriceFocusKeyFor,
    this.selectedPickupLocationId,
    this.showPricing = true,
    this.showGlobalActions = true,
    this.showStops = true,
  });

  @override
  ConsumerState<TrackShoppingOrderItemsCard> createState() =>
      _TrackShoppingOrderItemsCardState();
}

class _TrackShoppingOrderItemsCardState
    extends ConsumerState<TrackShoppingOrderItemsCard> {
  final Set<int> _expandedStopIds = <int>{};

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    final stops = detail.shoppingStops;
    // Ringkasan (selectedPickupLocationId == null) hanya menampilkan stop aktif;
    // saat sebuah tab dipilih, stop itu ditampilkan apa adanya termasuk yang
    // sudah FAILED (tutup) -- hanya REPLACED/SKIPPED yang tak pernah tampil.
    final displayStops = widget.selectedPickupLocationId != null
        ? stops
              .where(
                (stop) =>
                    stop.pickupLocationId == widget.selectedPickupLocationId &&
                    !stop.isReplaced &&
                    !stop.isSkipped,
              )
              .toList(growable: false)
        : stops.where((stop) => stop.isActive).toList(growable: false);
    final pricing = detail.shoppingPricing;
    final isShoppingTotalTransport =
        detail.deliveryFeeNegotiation?.isActiveShoppingTotalTransport == true;
    final failedStops = stops
        .where((stop) => stop.isFailed)
        .toList(growable: false);
    final showFailedStopNotices =
        widget.showGlobalActions &&
        !detail.shoppingCapabilities.hasCheckoutSaved &&
        !detail.summary.isTerminalStatus &&
        !isTerminalOrderStatus(detail.summary.effectiveStatusCode);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(
                child: Text(
                  'Item Nitip',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              if (widget.showGlobalActions && detail.canAddShoppingMerchant)
                TextButton.icon(
                  onPressed: () => _openAddItemScreen(context, ref),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: const Size(0, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 15),
                  label: const Text('Tambah'),
                ),
            ],
          ),
          const Divider(height: 18, color: AppColors.border),
          if (showFailedStopNotices && failedStops.isNotEmpty) ...[
            ...failedStops.map((stop) => _failedStopNotice(context, ref, stop)),
            const SizedBox(height: 4),
          ],
          if (widget.showGlobalActions &&
              detail.shoppingItemChangeRequest?.isPending == true) ...[
            _shoppingItemChangeRequestNotice(detail.shoppingItemChangeRequest!),
            const SizedBox(height: 10),
          ],
          if (widget.showGlobalActions &&
              _unavailableItems(detail).isNotEmpty) ...[
            _unavailableItemsNotice(_unavailableItems(detail)),
            const SizedBox(height: 10),
          ],
          if (!widget.showStops)
            const SizedBox.shrink()
          else if (displayStops.isEmpty)
            const Text(
              'Belum ada item belanja.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            ...displayStops.indexed.map(
              (entry) => _stopSection(
                context,
                ref,
                entry.$2,
                showDivider: entry.$1 > 0,
              ),
            ),
          if (widget.showPricing && pricing != null) ...[
            const Divider(height: 18, color: AppColors.border),
            _pricingRow('Subtotal barang', pricing.subtotal),
            _pricingRow(
              isShoppingTotalTransport ? 'Total ongkir Nitip' : 'Ongkir aktif',
              pricing.deliveryFee,
            ),
            if (pricing.serviceFee > 0)
              _pricingRow(
                detail.shoppingServiceFeeLabel,
                pricing.serviceFee,
              ),
            const SizedBox(height: 4),
            _pricingRow(
              'Total pembayaran customer',
              pricing.totalPrice,
              isTotal: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _failedStopNotice(
    BuildContext context,
    WidgetRef ref,
    CustomerShoppingStopModel stop,
  ) {
    return _TrackNotice(
      margin: const EdgeInsets.only(bottom: 8),
      tone: _TrackNoticeTone.danger,
      icon: Icons.storefront_outlined,
      // Aksi ganti toko/resto, bukti foto, dan status menunggu persetujuan kini
      // hidup di tab "Tempat N" masing-masing (bukan lagi di Ringkasan). Notice
      // ini cukup mengarahkan customer ke tab tersebut.
      text:
          '${stop.merchant.name} - Tempat tutup/order batal\n${formatShoppingAttemptProgress(attemptNo: stop.chainAttemptNo, attemptLimit: stop.chainFailedAttemptLimit, totalFailed: stop.orderFailedTripCount)}'
          '${(stop.pendingReplacementApproval?.isPending ?? false) ? '\nMenunggu persetujuan driver untuk toko/resto pengganti.' : (stop.canReplaceMerchant ? '\nBuka tab tempat ini untuk ganti toko/resto.' : '')}',
    );
  }

  Widget _shoppingItemChangeRequestNotice(
    ShoppingItemChangeRequestModel request,
  ) {
    final action = (request.action ?? 'ADD').toUpperCase();
    final actionLabel = action == 'REMOVE'
        ? 'hapus item'
        : action == 'UPDATE'
        ? 'ubah item'
        : 'tambah item';

    return _TrackNotice(
      tone: _TrackNoticeTone.info,
      icon: Icons.pending_actions_outlined,
      text: 'Request $actionLabel menunggu persetujuan driver.',
      child: request.requestedStops.isEmpty
          ? null
          : BangShoppingMerchantRequestSummary(request: request, compact: true),
    );
  }

  List<CustomerShoppingItemModel> _unavailableItems(
    CustomerOrderDetailModel detail,
  ) {
    return detail.shoppingItems
        .where((item) => !item.isAvailable)
        .toList(growable: false);
  }

  Widget _unavailableItemsNotice(List<CustomerShoppingItemModel> items) {
    return _TrackNotice(
      tone: _TrackNoticeTone.danger,
      icon: Icons.inventory_2_outlined,
      text:
          'Item tidak tersedia: ${items.map((item) => item.name).join(', ')}.',
    );
  }

  Widget _shoppingNegotiationCard(
    BuildContext context,
    WidgetRef ref,
    CustomerOrderDetailModel detail,
    CustomerShoppingStopModel stop,
  ) {
    final negotiation = detail.shoppingNegotiation;
    final quote = negotiation?.quoteForPickup(stop.pickupLocationId);
    final quotedAmount = quote?.amount.quotedAmount ?? 0;

    return KeyedSubtree(
      key: widget.shoppingPriceFocusKeyFor?.call(stop.pickupLocationId),
      child: BangAmountNegotiationCard(
        label: 'Konfirmasi harga barang',
        subtitle: stop.merchant.name,
        amount: quotedAmount,
        amountLabel: 'Harga dari driver',
        reasonLabel: 'Catatan',
        reason: quote?.amount.note,
        supportingText: 'Harga barang mengikuti struk/tempat.',
        icon: Icons.receipt_long_outlined,
        approveLabel: 'Setujui harga',
        counterLabel: 'Batalkan tempat',
        counterIsDestructive: true,
        showCancelAction: false,
        onApprove: () => _respondShoppingQuote(
          context,
          ref,
          detail,
          action: 'APPROVE',
          pickupLocationId: stop.pickupLocationId,
        ),
        onCounter: () => _respondShoppingQuote(
          context,
          ref,
          detail,
          action: 'CANCEL_MERCHANT',
          pickupLocationId: stop.pickupLocationId,
        ),
        onCancel: () {},
      ),
    );
  }

  Widget _stopSection(
    BuildContext context,
    WidgetRef ref,
    CustomerShoppingStopModel stop, {
    required bool showDivider,
  }) {
    const collapsedItemLimit = 5;
    final showToggle = stop.items.length > collapsedItemLimit;
    final isExpanded = _expandedStopIds.contains(stop.pickupLocationId);
    final visibleItems = showToggle && !isExpanded
        ? stop.items.take(collapsedItemLimit).toList(growable: false)
        : stop.items;
    final hiddenCount = stop.items.length - visibleItems.length;
    final hasPendingPrice = stop.items.any((item) => item.isPricePending);
    final unavailableItems = stop.items
        .where((item) => !item.isAvailable)
        .toList(growable: false);
    final hasUnavailableItems = unavailableItems.isNotEmpty;
    final canEditUnavailable =
        widget.detail.canEditUnavailableShoppingItems &&
        hasUnavailableItems &&
        (!stop.hasExplicitUnavailableItemActions ||
            stop.canEditUnavailableItems);
    final canContinueWithoutUnavailable = stop.hasExplicitUnavailableItemActions
        ? stop.canContinueWithoutUnavailableItem
        : stop.items.any((item) => item.isAvailable);
    final canCancelUnavailableMerchant =
        !stop.hasExplicitUnavailableItemActions ||
        stop.canCancelUnavailableMerchant;
    final activeStopCount = widget.detail.shoppingStops
        .where((item) => item.isActive)
        .length;
    final sequenceNo = stop.sequenceNo <= 0 ? 1 : stop.sequenceNo;
    final stopQuote = widget.detail.shoppingNegotiation?.quoteForPickup(
      stop.pickupLocationId,
    );
    final showStopQuoteCard =
        stopQuote?.amount.canCustomerRespond == true &&
        (stopQuote?.amount.quotedAmount ?? 0) > 0;

    return Padding(
      padding: EdgeInsets.only(top: showDivider ? 12 : 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showDivider) ...[
            Divider(
              height: 1,
              thickness: 1,
              color: AppColors.border.withValues(alpha: 0.75),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (activeStopCount > 1) ...[
                          _stopNumberBadge(sequenceNo),
                          const SizedBox(width: 9),
                        ],
                        Expanded(
                          child: Text(
                            stop.merchant.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (stop.isFailed || stop.isSkipped)
                _stopStatusChip(
                  stop.isFailed ? 'Tempat tutup/order batal' : 'Dilewati',
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
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
          const SizedBox(height: 8),
          if (showStopQuoteCard) ...[
            _shoppingNegotiationCard(context, ref, widget.detail, stop),
            const SizedBox(height: 10),
          ],
          ...visibleItems.map((item) => _itemRow(context, ref, item)),
          if (stop.pendingReplacementApproval?.isPending ?? false) ...[
            const SizedBox(height: 8),
            _merchantReplacementWaitingBanner(stop),
          ],
          if (stop.isFailed && widget.showStops) ...[
            const SizedBox(height: 8),
            ..._failedStopPageContent(context, ref, stop),
          ],
          if (canEditUnavailable) ...[
            const SizedBox(height: 2),
            _unavailableItemDecisionActions(
              context,
              ref,
              stop,
              unavailableItems,
              canContinueWithoutUnavailable: canContinueWithoutUnavailable,
              canCancelMerchant: canCancelUnavailableMerchant,
            ),
          ],
          if (showToggle) ...[
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedStopIds.remove(stop.pickupLocationId);
                    } else {
                      _expandedStopIds.add(stop.pickupLocationId);
                    }
                  });
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(
                  isExpanded
                      ? 'Sembunyikan item'
                      : 'Lihat semua item (${stop.items.length})'
                            '${hiddenCount > 0 ? ' (+$hiddenCount)' : ''}',
                ),
              ),
            ),
          ],
          if (hasPendingPrice) ...[
            const SizedBox(height: 4),
            const Text(
              'Harga barang mengikuti struk dari tempat.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Konten khusus halaman stop yang FAILED (tutup): foto bukti toko tutup +
  /// aksi ganti toko/resto (atau alasan bila kuota habis / sedang menunggu
  /// persetujuan). Dipindah dari notice Ringkasan agar terpusat di tab stop.
  List<Widget> _failedStopPageContent(
    BuildContext context,
    WidgetRef ref,
    CustomerShoppingStopModel stop,
  ) {
    final photos = widget.detail.proofs
        .where(
          (proof) =>
              proof.type == 'store_closed' &&
              proof.pickupLocationId == stop.pickupLocationId &&
              (proof.photoUrl ?? '').trim().isNotEmpty,
        )
        .toList(growable: false);
    final isPending = stop.pendingReplacementApproval?.isPending ?? false;
    final blockReason = (stop.replacementBlockReason ?? '').trim();

    return [
      if (photos.isNotEmpty) ...[
        const Text(
          'Bukti foto toko tutup',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 11.5,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: photos
              .map((proof) => _storeClosedPhotoThumb(context, proof.photoUrl!))
              .toList(growable: false),
        ),
        const SizedBox(height: 10),
      ],
      if (!isPending)
        if (stop.canReplaceMerchant)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => _openAddItemScreen(
                context,
                ref,
                targetPickupLocationId: stop.pickupLocationId,
                replaceMerchant: true,
              ),
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('Ganti toko/resto'),
            ),
          )
        else if (blockReason.isNotEmpty)
          _TrackNotice(
            tone: _TrackNoticeTone.info,
            icon: Icons.info_outline_rounded,
            text: blockReason,
          ),
    ];
  }

  Widget _storeClosedPhotoThumb(BuildContext context, String url) {
    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        barrierColor: AppColors.black,
        builder: (dialogContext) => Dialog.fullscreen(
          backgroundColor: AppColors.black,
          child: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    child: Image.network(url, fit: BoxFit.contain),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.close_rounded, color: AppColors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          width: 72,
          height: 72,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            width: 72,
            height: 72,
            color: AppColors.background,
            child: const Icon(
              Icons.broken_image_outlined,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _merchantReplacementWaitingBanner(CustomerShoppingStopModel stop) {
    final approval = stop.pendingReplacementApproval;
    final newMerchant = (approval?.newMerchantName ?? '').trim();
    final distanceKm = approval?.distanceKm;
    final target = newMerchant.isEmpty ? 'toko/resto pengganti' : '"$newMerchant"';
    final distanceText = distanceKm != null
        ? ' (±${distanceKm.toStringAsFixed(1).replaceAll('.', ',')} km)'
        : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardYellow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Menunggu persetujuan driver untuk pindah ke $target$distanceText. '
              'Kalau ditolak, kamu bisa pilih opsi lain.',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _unavailableItemDecisionActions(
    BuildContext context,
    WidgetRef ref,
    CustomerShoppingStopModel stop,
    List<CustomerShoppingItemModel> unavailableItems, {
    required bool canContinueWithoutUnavailable,
    required bool canCancelMerchant,
  }) {
    final canSkipDirectly = unavailableItems.length == 1;
    final actions = <BangDecisionAction>[
      BangDecisionAction(
        key: ValueKey('shopping-action-replace-items-${stop.pickupLocationId}'),
        label: 'Ganti item',
        icon: Icons.edit_outlined,
        tone: BangDecisionActionTone.orange,
        onPressed: () => _openAddItemScreen(
          context,
          ref,
          targetPickupLocationId: stop.pickupLocationId,
        ),
      ),
      if (stop.canReplaceMerchant)
        BangDecisionAction(
          key: ValueKey(
            'shopping-action-replace-merchant-${stop.pickupLocationId}',
          ),
          label: 'Ganti toko/resto',
          icon: Icons.swap_horiz_rounded,
          tone: BangDecisionActionTone.orange,
          onPressed: () => _openAddItemScreen(
            context,
            ref,
            targetPickupLocationId: stop.pickupLocationId,
            replaceMerchant: true,
          ),
        ),
      if (canContinueWithoutUnavailable)
        BangDecisionAction(
          key: ValueKey('shopping-action-continue-${stop.pickupLocationId}'),
          label: canSkipDirectly ? 'Lanjut tanpa ini' : 'Pilih item',
          icon: Icons.remove_circle_outline,
          tone: BangDecisionActionTone.amber,
          onPressed: () {
            if (canSkipDirectly) {
              _continueWithoutUnavailableItem(
                context,
                ref,
                stop,
                unavailableItems.single,
              );
              return;
            }

            _showUnavailableItemPicker(context, ref, stop, unavailableItems);
          },
        ),
      if (canCancelMerchant)
        BangDecisionAction(
          key: ValueKey('shopping-action-cancel-${stop.pickupLocationId}'),
          label: 'Batal tempat',
          icon: Icons.storefront_outlined,
          tone: BangDecisionActionTone.red,
          onPressed: () => _cancelUnavailableMerchant(context, ref, stop),
        ),
    ];

    return BangDecisionActionGrid(actions: actions);
  }

  Widget _stopNumberBadge(int number) {
    return Container(
      width: 21,
      height: 21,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        number.toString(),
        style: const TextStyle(
          color: AppColors.primaryDark,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }

  Widget _stopStatusChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.error,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _itemRow(
    BuildContext context,
    WidgetRef ref,
    CustomerShoppingItemModel item,
  ) {
    final canRemove =
        widget.detail.canEditShoppingItems &&
        widget.detail.shoppingItems.length > 1;
    final priceText = !item.isAvailable
        ? 'Tidak tersedia'
        : item.isPricePending
        ? ''
        : item.subtotal > 0
        ? formatCurrency(item.subtotal)
        : 'Termasuk total struk';
    final statusColor = !item.isAvailable || item.isPricePending
        ? AppColors.error
        : item.subtotal > 0
        ? AppColors.primaryDark
        : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.quantity <= 0 ? 1 : item.quantity}x ${item.name}',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13.3,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
                    decoration: item.isAvailable
                        ? TextDecoration.none
                        : TextDecoration.lineThrough,
                  ),
                ),
                if ((item.notes ?? '').trim().isNotEmpty)
                  Text(
                    item.notes!.trim(),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                      height: 1.3,
                    ),
                  ),
                if (priceText.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    priceText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12.3,
                      height: 1.25,
                      fontWeight: item.subtotal > 0
                          ? FontWeight.w800
                          : FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (canRemove) ...[
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: IconButton(
                tooltip: 'Hapus item',
                visualDensity: const VisualDensity(
                  horizontal: -4,
                  vertical: -4,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                onPressed: () => _removeItem(context, ref, item),
                icon: Icon(
                  Icons.delete_outline,
                  color: AppColors.error.withValues(alpha: 0.82),
                  size: 18,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pricingRow(String label, double value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isTotal
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontWeight: isTotal ? FontWeight.w800 : FontWeight.w400,
                fontSize: isTotal ? 13.5 : 13,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            formatCurrency(value),
            textAlign: TextAlign.right,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
              fontSize: isTotal ? 14.5 : 13,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showUnavailableItemPicker(
    BuildContext context,
    WidgetRef ref,
    CustomerShoppingStopModel stop,
    List<CustomerShoppingItemModel> unavailableItems,
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
    if (selectedIds == null || selectedIds.isEmpty || !context.mounted) {
      return;
    }

    final names = unavailableItems
        .where((item) => selectedIds.contains(item.id))
        .map((item) => item.name)
        .join(', ');
    await _submitUnavailableDecision(
      context,
      ref,
      action: 'REMOVE',
      pickupLocationId: stop.pickupLocationId,
      itemIds: selectedIds,
      note: 'Customer memilih lanjut tanpa item tidak tersedia: $names.',
      successMessage:
          '${selectedIds.length} item dilewati. Driver perlu input harga baru.',
    );
  }

  Future<void> _respondShoppingQuote(
    BuildContext context,
    WidgetRef ref,
    CustomerOrderDetailModel detail, {
    required String action,
    required int pickupLocationId,
  }) async {
    try {
      await ref
          .read(customerOrderRepositoryProvider)
          .respondShoppingPriceQuote(
            detail.summary.id,
            action: action,
            pickupLocationId: pickupLocationId,
          );
      ref.invalidate(customerOrderTrackingProvider(detail.summary.id));
      ref.invalidate(customerOrdersProvider);
      await widget.onChanged?.call();

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Respons harga Nitip diproses.')),
      );
    } catch (error) {
      ref.invalidate(customerOrderTrackingProvider(widget.detail.summary.id));
      ref.invalidate(customerOrdersProvider);
      await widget.onChanged?.call();

      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _continueWithoutUnavailableItem(
    BuildContext context,
    WidgetRef ref,
    CustomerShoppingStopModel stop,
    CustomerShoppingItemModel item,
  ) async {
    final confirmed = await _confirmUnavailableDecision(
      context,
      title: 'Lanjut tanpa ${item.name}?',
      message:
          'Item ini akan dilewati, lalu driver mengirim harga baru untuk tempat ini.',
      confirmLabel: 'Lanjut tanpa ini',
    );
    if (!confirmed || !context.mounted) {
      return;
    }

    await _submitUnavailableDecision(
      context,
      ref,
      action: 'REMOVE',
      pickupLocationId: stop.pickupLocationId,
      itemIds: [item.id],
      note: 'Customer memilih lanjut tanpa item tidak tersedia: ${item.name}.',
      successMessage: '${item.name} dilewati. Driver perlu input harga baru.',
    );
  }

  Future<void> _cancelUnavailableMerchant(
    BuildContext context,
    WidgetRef ref,
    CustomerShoppingStopModel stop,
  ) async {
    final confirmed = await _confirmUnavailableDecision(
      context,
      title: 'Batalkan ${stop.merchant.name}?',
      message:
          'Semua item dari tempat ini tidak akan dibeli. Kalau ini tempat terakhir, order Nitip bisa ikut dibatalkan.',
      confirmLabel: 'Batal tempat',
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) {
      return;
    }

    await _submitUnavailableDecision(
      context,
      ref,
      action: 'CANCEL_MERCHANT',
      pickupLocationId: stop.pickupLocationId,
      note:
          'Customer membatalkan tempat karena item tidak tersedia di ${stop.merchant.name}.',
      successMessage: '${stop.merchant.name} dibatalkan.',
    );
  }

  Future<bool> _confirmUnavailableDecision(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    bool isDestructive = false,
  }) async {
    return showBangConfirmationDialog(
      context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      isDestructive: isDestructive,
    );
  }

  Future<void> _submitUnavailableDecision(
    BuildContext context,
    WidgetRef ref, {
    required String action,
    required int pickupLocationId,
    int? itemId,
    List<int> itemIds = const <int>[],
    String? note,
    required String successMessage,
  }) async {
    try {
      await ref
          .read(customerOrderRepositoryProvider)
          .requestShoppingItemChange(
            widget.detail.summary.id,
            action: action,
            requestKind: 'EDIT_UNAVAILABLE',
            itemId: itemId,
            itemIds: itemIds,
            targetPickupLocationId: pickupLocationId,
            note: note,
          );
      ref.invalidate(customerOrderTrackingProvider(widget.detail.summary.id));
      ref.invalidate(customerOrdersProvider);
      await widget.onChanged?.call();

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _openAddItemScreen(
    BuildContext context,
    WidgetRef ref, {
    int? targetPickupLocationId,
    bool replaceMerchant = false,
  }) async {
    final result = await context.push<ShoppingAddItemResult>(
      AppRoutes.shoppingAddItemPath(widget.detail.summary.id),
      extra: ShoppingAddItemRouteArgs(
        detail: widget.detail,
        targetPickupLocationId: targetPickupLocationId,
        replaceMerchant: replaceMerchant,
      ),
    );

    if (result == null || !context.mounted) {
      return;
    }

    ref.invalidate(customerOrderTrackingProvider(widget.detail.summary.id));
    ref.invalidate(customerOrdersProvider);
    await widget.onChanged?.call();
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.deliveryFeeChanged ? AppColors.success : null,
      ),
    );
  }

  Future<void> _removeItem(
    BuildContext context,
    WidgetRef ref,
    CustomerShoppingItemModel item,
  ) async {
    try {
      await ref
          .read(customerOrderRepositoryProvider)
          .removeShoppingItem(widget.detail.summary.id, item.id);
      ref.invalidate(customerOrderTrackingProvider(widget.detail.summary.id));
      ref.invalidate(customerOrdersProvider);
      await widget.onChanged?.call();
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item belanja berhasil dihapus.')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}

class TrackWaitingDriverHeroCard extends StatelessWidget {
  const TrackWaitingDriverHeroCard({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: double.infinity,
          height: 164,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.16),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.035),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: 12,
                bottom: 8,
                child: Semantics(
                  label: 'Ilustrasi driver Bang Deliv sedang dicari',
                  image: true,
                  child: Image.asset(
                    'assets/images/hero.png',
                    width: (constraints.maxWidth * 0.40).clamp(128.0, 168.0),
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 16, 18),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: 0.55,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Menunggu Driver',
                        style: TextStyle(
                          color: AppColors.primaryDark,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Kami sedang mencari driver untuk Anda.',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                          height: 1.32,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class TrackDeliveryFeeNotice extends StatelessWidget {
  const TrackDeliveryFeeNotice({super.key, required this.text, this.reason});

  final String text;
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final trimmedReason = reason?.trim();
    final normalizedReason =
        trimmedReason == 'Ongkir diperbarui karena merchant Nitip diganti.'
        ? 'Ongkir diperbarui karena toko/resto diganti.'
        : trimmedReason;

    return _TrackNotice(
      tone: _TrackNoticeTone.info,
      icon: Icons.info_outline,
      text: text,
      secondaryText: normalizedReason == null || normalizedReason.isEmpty
          ? null
          : 'Alasan: $normalizedReason',
    );
  }
}

enum _TrackNoticeTone { info, danger }

class _TrackNotice extends StatelessWidget {
  const _TrackNotice({
    required this.tone,
    required this.icon,
    required this.text,
    this.secondaryText,
    this.child,
    this.margin,
  });

  final _TrackNoticeTone tone;
  final IconData icon;
  final String text;
  final String? secondaryText;
  final Widget? child;
  final EdgeInsetsGeometry? margin;

  Color get _accentColor {
    return switch (tone) {
      _TrackNoticeTone.info => AppColors.primary,
      _TrackNoticeTone.danger => AppColors.error,
    };
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor;

    return Container(
      width: double.infinity,
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Icon(icon, color: accent, size: 16),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        height: 1.34,
                      ),
                    ),
                    if ((secondaryText ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        secondaryText!.trim(),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.32,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (child != null) ...[const SizedBox(height: 10), child!],
        ],
      ),
    );
  }
}

class TrackRoutePoint extends StatelessWidget {
  const TrackRoutePoint({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.showConnector = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool showConnector;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 20,
          child: Column(
            children: [
              Icon(icon, color: iconColor, size: 19),
              if (showConnector) ...[
                const SizedBox(height: 4),
                const _DashedRouteConnector(),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DashedRouteConnector extends StatelessWidget {
  const _DashedRouteConnector();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(2, 34),
      painter: _DashedRouteConnectorPainter(
        color: AppColors.primary.withValues(alpha: 0.34),
      ),
    );
  }
}

class _DashedRouteConnectorPainter extends CustomPainter {
  const _DashedRouteConnectorPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    const dashHeight = 4.0;
    const dashGap = 3.5;
    var y = 0.0;
    final centerX = size.width / 2;

    while (y < size.height) {
      final endY = (y + dashHeight).clamp(0.0, size.height);
      canvas.drawLine(Offset(centerX, y), Offset(centerX, endY), paint);
      y += dashHeight + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRouteConnectorPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class TrackInfoRow {
  const TrackInfoRow(this.label, this.value, {this.emphasized = false});
  final String label;
  final String value;
  final bool emphasized;
}
