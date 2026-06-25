import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_routes.dart';
import '../../../../config/app_text_scaling.dart';
import '../../../../models/customer_order_model.dart';
import '../../../../core/di/app_providers.dart';
import '../../application/customer_order_providers.dart';
import '../../../../utils/order_status.dart';
import '../../../../widgets/customer_order_card.dart';
import '../../../../widgets/bang_ui.dart';
import '../../../navigation/presentation/widgets/bang_floating_bottom_nav_bar.dart';

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  final Set<int> _cancellingOrderIds = <int>{};
  bool _isOpeningRefresh = true;
  bool _openingRefreshInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshOnOpen();
    });
  }

  bool _isCancelling(int orderId) => _cancellingOrderIds.contains(orderId);

  Future<void> _refreshOrders() async {
    ref.invalidate(customerOrdersProvider);

    try {
      await ref.read(customerOrdersProvider.future);
    } catch (_) {
      // Errors are surfaced by the provider state in UI.
    }
  }

  Future<void> _refreshOnOpen() async {
    if (!mounted || _openingRefreshInFlight) {
      return;
    }
    _openingRefreshInFlight = true;

    setState(() {
      _isOpeningRefresh = true;
    });

    try {
      await _refreshOrders();
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningRefresh = false;
        });
      }
      _openingRefreshInFlight = false;
    }
  }

  Future<void> _cancelOrder(CustomerOrderSummaryModel order) async {
    final reason = await _askCancelReason();
    if (reason == null || reason.trim().isEmpty) {
      return;
    }

    setState(() {
      _cancellingOrderIds.add(order.id);
    });

    try {
      await ref
          .read(customerOrderRepositoryProvider)
          .cancelOrder(order.id, reason: reason);

      await _refreshOrders();
      ref.invalidate(customerOrderDetailProvider(order.id));

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order berhasil dibatalkan.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _cancellingOrderIds.remove(order.id);
        });
      }
    }
  }

  Future<String?> _askCancelReason() async {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => const _CancelOrderDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(customerOrdersProvider);
    ref.watch(customerOrdersAutoRefreshProvider);
    final ongoingOrders = ref.watch(customerOngoingOrdersProvider);
    final completedOrders = ref.watch(customerCompletedOrdersProvider);
    final cancelledOrders = ref.watch(customerCancelledOrdersProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: MediaQuery(
                  data: AppTextScaling.clampedMediaQueryData(
                    context,
                    maxScaleFactor:
                        AppTextScaling.compactComponentMaxScaleFactor,
                  ),
                  child: const TabBar(
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textSecondary,
                    indicatorColor: AppColors.primary,
                    indicatorWeight: 3,
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                    tabs: [
                      Tab(text: 'Berjalan'),
                      Tab(text: 'Selesai'),
                      Tab(text: 'Dibatalkan'),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ColoredBox(
                  color: AppColors.background,
                  child: _isOpeningRefresh
                      ? const Center(child: CircularProgressIndicator())
                      : ordersAsync.when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (error, stackTrace) => Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: BangErrorState(
                                title: 'Gagal memuat aktivitas',
                                message: error.toString(),
                                onRetry: _refreshOnOpen,
                              ),
                            ),
                          ),
                          data: (_) => TabBarView(
                            children: [
                              _buildOrderList(
                                ongoingOrders,
                                emptyTitle: 'Belum ada pesanan berjalan',
                                mode: _ActivityOrderListMode.ongoing,
                                onRefresh: _refreshOrders,
                              ),
                              _buildOrderList(
                                completedOrders,
                                emptyTitle: 'Belum ada pesanan selesai',
                                mode: _ActivityOrderListMode.history,
                                onRefresh: _refreshOrders,
                              ),
                              _buildOrderList(
                                cancelledOrders,
                                emptyTitle: 'Belum ada pesanan dibatalkan',
                                mode: _ActivityOrderListMode.history,
                                onRefresh: _refreshOrders,
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<CustomerOrderSummaryModel> _sortByNewest(
    List<CustomerOrderSummaryModel> orders,
  ) {
    final sorted = orders.toList(growable: false)
      ..sort((a, b) {
        final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return bTime.compareTo(aTime);
      });
    return sorted;
  }

  Widget _buildOrderList(
    List<CustomerOrderSummaryModel> orders, {
    required String emptyTitle,
    required _ActivityOrderListMode mode,
    required Future<void> Function() onRefresh,
  }) {
    final sortedOrders = _sortByNewest(orders);

    if (sortedOrders.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: ClampingScrollPhysics(),
          ),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: BangIllustrationEmptyState(
                  title: emptyTitle,
                  subtitle: '',
                  titleFontSize: 13,
                  titleFontWeight: FontWeight.w500,
                  titleColor: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(
          20,
          20,
          20,
          BangFloatingBottomNavBar.scrollClearance,
        ),
        itemCount: sortedOrders.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final order = sortedOrders[index];
          final isOngoing = mode == _ActivityOrderListMode.ongoing;
          final canCancelBeforeDriver =
              isOngoing &&
              normalizeOrderStatusCode(order.statusCode) ==
                  OrderStatusCodes.pending;
          final openTracking = isOngoing
              ? (order.canTrack
                    ? () => context.push(AppRoutes.track, extra: order.id)
                    : null)
              : () => context.push(
                  AppRoutes.track,
                  extra: <String, dynamic>{
                    'orderId': order.id,
                    'fromHistory': true,
                  },
                );

          return CustomerOrderCard(
            order: order,
            showTrackAction: isOngoing && order.canTrack,
            showCancelAction: canCancelBeforeDriver,
            showDetailHint: !isOngoing,
            showPaymentInfo: isOngoing,
            showInlinePrice: !isOngoing,
            isCancelling: _isCancelling(order.id),
            onTap: openTracking,
            onTrack: isOngoing ? openTracking : null,
            onCancel: canCancelBeforeDriver ? () => _cancelOrder(order) : null,
          );
        },
      ),
    );
  }
}

enum _ActivityOrderListMode { ongoing, history }

class _CancelOrderDialog extends StatefulWidget {
  const _CancelOrderDialog();

  @override
  State<_CancelOrderDialog> createState() => _CancelOrderDialogState();
}

class _CancelOrderDialogState extends State<_CancelOrderDialog> {
  static const List<String> _quickReasons = [
    'Berubah pikiran',
    'Alamat salah',
    'Pesanan tidak jadi',
    'Terlalu lama',
    'Lainnya',
  ];

  late final TextEditingController _controller;
  String? _selectedReason;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(_handleReasonChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleReasonChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleReasonChanged() {
    setState(() {});
  }

  String get _note => _controller.text.trim();

  bool get _isOtherReason => _selectedReason == 'Lainnya';

  bool get _canSubmit {
    final reason = _selectedReason;
    if (reason == null) {
      return false;
    }

    return _isOtherReason ? _note.isNotEmpty : true;
  }

  String _composeReason() {
    final reason = _selectedReason;
    final note = _note;

    if (reason == null) {
      return note;
    }

    if (_isOtherReason) {
      return note;
    }

    return reason;
  }

  @override
  Widget build(BuildContext context) {
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final buttonTextStyle = GoogleFonts.inter(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      height: 1.1,
    );

    return Dialog(
      backgroundColor: AppColors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 360,
          maxHeight: viewportHeight * 0.78,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Batalkan pesanan?',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17.5,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Pilih alasan pembatalan sebelum melanjutkan.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Alasan pembatalan',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    for (final reason in _quickReasons)
                      ChoiceChip(
                        label: Text(reason),
                        selected: _selectedReason == reason,
                        onSelected: (selected) {
                          setState(() {
                            _selectedReason = selected ? reason : null;
                            if (reason != 'Lainnya') {
                              _controller.clear();
                            }
                          });
                        },
                        showCheckmark: false,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: const VisualDensity(
                          horizontal: -3,
                          vertical: -4,
                        ),
                        labelPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 0,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 0,
                          vertical: 1,
                        ),
                        labelStyle: TextStyle(
                          color: _selectedReason == reason
                              ? AppColors.primaryDark
                              : AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        selectedColor: AppColors.primary.withValues(
                          alpha: 0.12,
                        ),
                        backgroundColor: AppColors.background,
                        side: BorderSide(
                          color: _selectedReason == reason
                              ? AppColors.primary.withValues(alpha: 0.45)
                              : AppColors.border,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                  ],
                ),
                if (_isOtherReason) ...[
                  const SizedBox(height: 14),
                  TextField(
                    controller: _controller,
                    minLines: 2,
                    maxLines: 3,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Alasan lainnya',
                      hintText: 'Tulis alasan pembatalan',
                      alignLabelWithHint: true,
                      filled: true,
                      fillColor: AppColors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      labelStyle: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                      ),
                      hintStyle: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12.5,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.4,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: AppTextScaling.adaptive(
                            context,
                            normal: 42,
                            large: 46,
                          ),
                        ),
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Kembali',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: buttonTextStyle.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: AppTextScaling.adaptive(
                            context,
                            normal: 40,
                            large: 46,
                          ),
                        ),
                        child: ElevatedButton(
                          onPressed: _canSubmit
                              ? () =>
                                    Navigator.of(context).pop(_composeReason())
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            disabledBackgroundColor: AppColors.border,
                            foregroundColor: AppColors.white,
                            disabledForegroundColor: AppColors.textMuted,
                            elevation: 0,
                            minimumSize: const Size(0, 40),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Batalkan',
                              maxLines: 1,
                              softWrap: false,
                              style: buttonTextStyle.copyWith(
                                color: _canSubmit
                                    ? AppColors.white
                                    : AppColors.textMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
