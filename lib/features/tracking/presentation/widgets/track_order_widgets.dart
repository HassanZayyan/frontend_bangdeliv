import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_routes.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../core/widgets/bang_shopping_merchant_request_summary.dart';
import '../../../../models/customer_order_model.dart';
import '../../../../models/shopping_order_capability_model.dart';
import '../../../../utils/order_formatters.dart';
import '../../../orders/application/customer_order_providers.dart';
import '../../../shopping/presentation/screens/shopping_add_item_screen.dart';
import '../../application/customer_order_tracking_provider.dart';

class TrackShoppingOrderItemsCard extends ConsumerStatefulWidget {
  final CustomerOrderDetailModel detail;
  final Future<void> Function()? onChanged;
  final GlobalKey Function(int pickupLocationId)? shoppingPriceFocusKeyFor;

  const TrackShoppingOrderItemsCard({
    super.key,
    required this.detail,
    this.onChanged,
    this.shoppingPriceFocusKeyFor,
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
    final activeStops = stops
        .where((stop) => stop.isActive)
        .toList(growable: false);
    final pricing = detail.shoppingPricing;
    final failedStops = stops
        .where((stop) => stop.isFailed)
        .toList(growable: false);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
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
              if (detail.canAddShoppingMerchant)
                TextButton.icon(
                  onPressed: () => _openAddItemScreen(context, ref),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: const Size(0, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: GoogleFonts.nunitoSans(
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
          if (failedStops.isNotEmpty) ...[
            ...failedStops.map(_failedStopNotice),
            const SizedBox(height: 4),
          ],
          if (detail.shoppingItemChangeRequest?.isPending == true) ...[
            _shoppingItemChangeRequestNotice(detail.shoppingItemChangeRequest!),
            const SizedBox(height: 10),
          ],
          if (_unavailableItems(detail).isNotEmpty) ...[
            _unavailableItemsNotice(_unavailableItems(detail)),
            const SizedBox(height: 10),
          ],
          if (activeStops.isEmpty)
            const Text(
              'Belum ada item belanja.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            ...activeStops.indexed.map(
              (entry) => _stopSection(
                context,
                ref,
                entry.$2,
                showDivider: entry.$1 > 0,
              ),
            ),
          if (pricing != null) ...[
            const Divider(height: 18, color: AppColors.border),
            _pricingRow('Subtotal barang', pricing.subtotal),
            _pricingRow('Ongkir', pricing.deliveryFee),
            _pricingRow(detail.shoppingServiceFeeLabel, pricing.serviceFee),
            const SizedBox(height: 4),
            _pricingRow('Total', pricing.totalPrice, isTotal: true),
          ],
        ],
      ),
    );
  }

  Widget _failedStopNotice(CustomerShoppingStopModel stop) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.storefront_outlined,
                color: AppColors.error,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${stop.merchant.name} - Tempat tutup/order batal',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.pending_actions_outlined,
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Request $actionLabel menunggu persetujuan driver.',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (request.requestedStops.isNotEmpty) ...[
            const SizedBox(height: 10),
            BangShoppingMerchantRequestSummary(request: request, compact: true),
          ],
        ],
      ),
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            color: AppColors.error,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Item tidak tersedia: ${items.map((item) => item.name).join(', ')}.',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
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
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Harga ${stop.merchant.name}',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              formatCurrency(quotedAmount),
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            if ((quote?.amount.note ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                quote!.amount.note!.trim(),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _respondShoppingQuote(
                      context,
                      ref,
                      detail,
                      action: 'CANCEL_MERCHANT',
                      pickupLocationId: stop.pickupLocationId,
                    ),
                    child: const Text('Batalkan tempat ini'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _respondShoppingQuote(
                      context,
                      ref,
                      detail,
                      action: 'APPROVE',
                      pickupLocationId: stop.pickupLocationId,
                    ),
                    child: const Text('Iya'),
                  ),
                ),
              ],
            ),
          ],
        ),
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
    final address = _displayMerchantAddress(stop.merchant.address);
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
    final stopTextIndent = activeStopCount > 1 ? 30.0 : 0.0;

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
                    if (address != null) ...[
                      const SizedBox(height: 3),
                      Padding(
                        padding: EdgeInsets.only(left: stopTextIndent),
                        child: Text(
                          address,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11.5,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (stop.isFailed || stop.isSkipped)
                _stopStatusChip(
                  stop.isFailed ? 'Tempat tutup/order batal' : 'Dilewati',
                )
              else if (canEditUnavailable)
                TextButton.icon(
                  onPressed: () => _openAddItemScreen(
                    context,
                    ref,
                    targetPickupLocationId: stop.pickupLocationId,
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 15),
                  label: const Text('Edit'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (showStopQuoteCard) ...[
            _shoppingNegotiationCard(context, ref, widget.detail, stop),
            const SizedBox(height: 10),
          ],
          ...visibleItems.map((item) => _itemRow(context, ref, item)),
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
                  textStyle: GoogleFonts.nunitoSans(
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

  Widget _unavailableItemDecisionActions(
    BuildContext context,
    WidgetRef ref,
    CustomerShoppingStopModel stop,
    List<CustomerShoppingItemModel> unavailableItems, {
    required bool canContinueWithoutUnavailable,
    required bool canCancelMerchant,
  }) {
    final canSkipDirectly = unavailableItems.length == 1;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (canContinueWithoutUnavailable)
          OutlinedButton.icon(
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
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              minimumSize: const Size(0, 38),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.remove_circle_outline, size: 16),
            label: Text(canSkipDirectly ? 'Lanjut tanpa ini' : 'Pilih item'),
          ),
        if (canCancelMerchant)
          OutlinedButton.icon(
            onPressed: () => _cancelUnavailableMerchant(context, ref, stop),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: BorderSide(color: AppColors.error.withValues(alpha: 0.65)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              minimumSize: const Size(0, 38),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.storefront_outlined, size: 16),
            label: const Text('Batal tempat'),
          ),
      ],
    );
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

  String? _displayMerchantAddress(String? rawAddress) {
    final address = (rawAddress ?? '').trim();
    if (address.isEmpty || address == '-') {
      return null;
    }

    final lower = address.toLowerCase();
    final looksLikeCoordinate = RegExp(
      r'-?\d+\.\d+,\s*-?\d+\.\d+',
    ).hasMatch(address);
    if (looksLikeCoordinate || lower.contains('dummy')) {
      return null;
    }

    return address;
  }

  Widget _stopStatusChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
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
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pilih item yang dilewati',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              for (final item in unavailableItems)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${item.quantity <= 0 ? 1 : item.quantity}x ${item.name}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text('Tidak tersedia'),
                  trailing: TextButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _continueWithoutUnavailableItem(context, ref, stop, item);
                    },
                    child: const Text('Lanjut'),
                  ),
                ),
            ],
          ),
        ),
      ),
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
      itemId: item.id,
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Kembali'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: isDestructive
                ? FilledButton.styleFrom(backgroundColor: AppColors.error)
                : null,
            child: Text(confirmLabel),
          ),
        ],
      ),
    );

    return confirmed == true;
  }

  Future<void> _submitUnavailableDecision(
    BuildContext context,
    WidgetRef ref, {
    required String action,
    required int pickupLocationId,
    int? itemId,
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
  }) async {
    final result = await context.push<ShoppingAddItemResult>(
      AppRoutes.shoppingAddItemPath(widget.detail.summary.id),
      extra: ShoppingAddItemRouteArgs(
        detail: widget.detail,
        targetPickupLocationId: targetPickupLocationId,
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
            borderRadius: BorderRadius.circular(18),
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
                  label: 'Ilustrasi driver BangDeliv sedang dicari',
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
                          fontSize: 20,
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
  const TrackDeliveryFeeNotice({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
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
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 19),
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

class TrackInfoRow {
  const TrackInfoRow(this.label, this.value, {this.emphasized = false});
  final String label;
  final String value;
  final bool emphasized;
}
