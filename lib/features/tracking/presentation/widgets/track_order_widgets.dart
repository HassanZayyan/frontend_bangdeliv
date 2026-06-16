import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_routes.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../core/widgets/bang_amount_negotiation_card.dart';
import '../../../../core/widgets/bang_counter_amount_dialog.dart';
import '../../../../core/widgets/bang_negotiation_cancel_sheet.dart';
import '../../../../models/customer_order_model.dart';
import '../../../../utils/order_formatters.dart';
import '../../../../widgets/shopping_fee_breakdown.dart';
import '../../../orders/application/customer_order_providers.dart';
import '../../../shopping/presentation/screens/shopping_add_item_screen.dart';
import '../../application/customer_order_tracking_provider.dart';

class TrackShoppingOrderItemsCard extends ConsumerStatefulWidget {
  final CustomerOrderDetailModel detail;
  final Future<void> Function()? onChanged;

  const TrackShoppingOrderItemsCard({
    super.key,
    required this.detail,
    this.onChanged,
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
              if (detail.canEditShoppingItems)
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
            ...failedStops.map((stop) => _failedStopNotice(context, ref, stop)),
            const SizedBox(height: 4),
          ],
          if (detail.shoppingNegotiation?.canCustomerRespond == true) ...[
            _shoppingNegotiationCard(context, ref, detail),
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
            _pricingRow('Service fee', pricing.serviceFee),
            ShoppingFeeBreakdown(
              items: pricing.feeBreakdown
                  .map(
                    (item) => ShoppingFeeBreakdownItem(
                      label: item.label,
                      description: item.description,
                      amount: item.amount,
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 4),
            _pricingRow('Total', pricing.totalPrice, isTotal: true),
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
    final canResolveFailedStop = widget.detail.canEditShoppingItems;

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
                  '${stop.merchant.name} - Resto tutup/order batal',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          if ((stop.failureReason ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              stop.failureReason!.trim(),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
          if (canResolveFailedStop) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openAddItemScreen(
                    context,
                    ref,
                    replacementForPickupLocationId: stop.pickupLocationId,
                  ),
                  icon: const Icon(Icons.add_business_outlined, size: 16),
                  label: const Text('Tambah pengganti'),
                ),
                TextButton.icon(
                  onPressed: () => _skipFailedStop(context, ref, stop),
                  icon: const Icon(Icons.done_outline, size: 16),
                  label: const Text('Lanjut tanpa ini'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _shoppingNegotiationCard(
    BuildContext context,
    WidgetRef ref,
    CustomerOrderDetailModel detail,
  ) {
    final negotiation = detail.shoppingNegotiation;
    final quotedAmount = negotiation?.quotedAmount ?? 0;

    return BangAmountNegotiationCard(
      label: 'Harga merchant',
      amount: quotedAmount,
      onApprove: () =>
          _respondShoppingQuote(context, ref, detail, action: 'APPROVE'),
      onCounter: () => _showCounterDialog(context, ref, detail),
      onCancel: () => _showCancelQuoteSheet(context, ref, detail),
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
    final address = _displayMerchantAddress(stop.merchant.address);
    final activeStopCount = widget.detail.shoppingStops
        .where((item) => item.isActive)
        .length;
    final sequenceNo = stop.sequenceNo <= 0 ? 1 : stop.sequenceNo;

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
              if (activeStopCount > 1) ...[
                _stopNumberBadge(sequenceNo),
                const SizedBox(width: 9),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stop.merchant.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        height: 1.25,
                      ),
                    ),
                    if (address != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        address,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (stop.isFailed || stop.isSkipped)
                _stopStatusChip(
                  stop.isFailed ? 'Resto tutup/order batal' : 'Dilewati',
                ),
            ],
          ),
          const SizedBox(height: 8),
          ...visibleItems.map((item) => _itemRow(context, ref, item)),
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
              'Harga barang mengikuti struk dari merchant.',
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
                    fontSize: 13.8,
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
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isTotal
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
                fontSize: isTotal ? 13.5 : 12.8,
              ),
            ),
          ),
          Text(
            formatCurrency(value),
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: isTotal ? FontWeight.w800 : FontWeight.w700,
              fontSize: isTotal ? 14.5 : 12.8,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCounterDialog(
    BuildContext context,
    WidgetRef ref,
    CustomerOrderDetailModel detail,
  ) async {
    final amount = await showBangCounterAmountDialog(
      context,
      title: 'Tawar harga',
    );

    if (amount == null || amount <= 0 || !context.mounted) {
      return;
    }

    await _respondShoppingQuote(
      context,
      ref,
      detail,
      action: 'COUNTER',
      counterAmount: amount,
    );
  }

  Future<void> _showCancelQuoteSheet(
    BuildContext context,
    WidgetRef ref,
    CustomerOrderDetailModel detail,
  ) async {
    final action = await showBangNegotiationCancelSheet(
      context,
      options: const [
        BangNegotiationCancelOption(
          action: 'CANCEL_MERCHANT',
          label: 'Batalkan merchant ini',
          icon: Icons.storefront_outlined,
        ),
        BangNegotiationCancelOption(
          action: 'CANCEL_ORDER',
          label: 'Batalkan pesanan',
          icon: Icons.cancel_outlined,
        ),
      ],
    );

    if (action == null || !context.mounted) {
      return;
    }

    await _respondShoppingQuote(context, ref, detail, action: action);
  }

  Future<void> _respondShoppingQuote(
    BuildContext context,
    WidgetRef ref,
    CustomerOrderDetailModel detail, {
    required String action,
    double? counterAmount,
  }) async {
    try {
      await ref
          .read(customerOrderRepositoryProvider)
          .respondShoppingPriceQuote(
            detail.summary.id,
            action: action,
            counterAmount: counterAmount,
            pickupLocationId: detail.shoppingNegotiation?.pickupLocationId,
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

  Future<void> _openAddItemScreen(
    BuildContext context,
    WidgetRef ref, {
    int? replacementForPickupLocationId,
  }) async {
    final result = await context.push<ShoppingAddItemResult>(
      AppRoutes.shoppingAddItemPath(widget.detail.summary.id),
      extra: ShoppingAddItemRouteArgs(
        detail: widget.detail,
        replacementForPickupLocationId: replacementForPickupLocationId,
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

  Future<void> _skipFailedStop(
    BuildContext context,
    WidgetRef ref,
    CustomerShoppingStopModel stop,
  ) async {
    try {
      await ref
          .read(customerOrderRepositoryProvider)
          .skipFailedShoppingStop(
            widget.detail.summary.id,
            stop.pickupLocationId,
          );
      ref.invalidate(customerOrderTrackingProvider(widget.detail.summary.id));
      ref.invalidate(customerOrdersProvider);
      await widget.onChanged?.call();
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${stop.merchant.name} dilewati.')),
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
