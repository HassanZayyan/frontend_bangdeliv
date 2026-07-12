import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_routes.dart';
import '../../../../config/app_text_scaling.dart';
import '../../../../models/customer_order_model.dart';
import '../../application/customer_order_providers.dart';
import '../../../../widgets/customer_order_card.dart';
import '../../../../widgets/bang_ui.dart';
import '../../../navigation/presentation/widgets/bang_floating_bottom_nav_bar.dart';

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  bool _isOpeningRefresh = true;
  bool _openingRefreshInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshOnOpen();
    });
  }

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
            showDetailHint: isOngoing && order.canTrack,
            showPaymentInfo: isOngoing,
            showInlinePrice: !isOngoing,
            onTap: openTracking,
            onTrack: null,
          );
        },
      ),
    );
  }
}

enum _ActivityOrderListMode { ongoing, history }
