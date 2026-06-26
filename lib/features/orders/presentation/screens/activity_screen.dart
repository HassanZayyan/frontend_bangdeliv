import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      builder: (sheetContext) => const _CancelOrderSheet(),
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
            showTrackAction: false,
            showCancelAction: canCancelBeforeDriver,
            showDetailHint: isOngoing && order.canTrack,
            showPaymentInfo: isOngoing,
            showInlinePrice: !isOngoing,
            isCancelling: _isCancelling(order.id),
            onTap: openTracking,
            onTrack: null,
            onCancel: canCancelBeforeDriver ? () => _cancelOrder(order) : null,
          );
        },
      ),
    );
  }
}

enum _ActivityOrderListMode { ongoing, history }

class _CancelOrderSheet extends StatefulWidget {
  const _CancelOrderSheet();

  @override
  State<_CancelOrderSheet> createState() => _CancelOrderSheetState();
}

class _CancelOrderSheetState extends State<_CancelOrderSheet> {
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
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final viewportHeight = MediaQuery.sizeOf(context).height;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: viewportHeight * 0.86),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Batalkan pesanan?',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1.18,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Pesanan akan dibatalkan setelah kamu memilih alasan.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.42,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Alasan pembatalan',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      for (var index = 0; index < _quickReasons.length; index++)
                        _CancelReasonTile(
                          label: _quickReasons[index],
                          selected: _selectedReason == _quickReasons[index],
                          showDivider: index < _quickReasons.length - 1,
                          onTap: () {
                            setState(() {
                              final reason = _quickReasons[index];
                              _selectedReason = reason;
                              if (reason != 'Lainnya') {
                                _controller.clear();
                              }
                            });
                          },
                        ),
                    ],
                  ),
                ),
                if (_isOtherReason) ...[
                  const SizedBox(height: 14),
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    minLines: 2,
                    maxLines: 3,
                    textInputAction: TextInputAction.done,
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
                        horizontal: 14,
                        vertical: 12,
                      ),
                      labelStyle: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                      ),
                      hintStyle: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: AppTextScaling.adaptive(
                          context,
                          normal: 48,
                          large: 52,
                        ),
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Kembali',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: AppTextScaling.adaptive(
                          context,
                          normal: 48,
                          large: 52,
                        ),
                        child: ElevatedButton(
                          onPressed: _canSubmit
                              ? () =>
                                    Navigator.of(context).pop(_composeReason())
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            disabledBackgroundColor: AppColors.surfaceAlt,
                            foregroundColor: AppColors.white,
                            disabledForegroundColor: AppColors.textMuted,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Batalkan Pesanan',
                              maxLines: 1,
                              softWrap: false,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
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

class _CancelReasonTile extends StatelessWidget {
  const _CancelReasonTile({
    required this.label,
    required this.selected,
    required this.showDivider,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.border,
                      width: selected ? 5.5 : 1.4,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(height: 1, indent: 46, color: AppColors.border),
      ],
    );
  }
}
