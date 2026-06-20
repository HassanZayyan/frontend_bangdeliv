import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_routes.dart';
import '../../../../models/customer_order_model.dart';
import '../../application/customer_order_providers.dart';
import '../../../../widgets/app_content_background.dart';
import '../../../../widgets/bang_ui.dart';
import '../../../../widgets/customer_order_card.dart';

class OrderHistoryScreen extends ConsumerStatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  ConsumerState<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends ConsumerState<OrderHistoryScreen> {
  bool _isOpeningRefresh = true;

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
    if (!mounted) return;

    setState(() {
      _isOpeningRefresh = true;
    });

    await _refreshOrders();

    if (!mounted) return;

    setState(() {
      _isOpeningRefresh = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(customerOrdersProvider);
    final historyOrders = ref.watch(customerHistoryOrdersProvider);
    final completedOrders = ref.watch(customerCompletedOrdersProvider);
    final cancelledOrders = ref.watch(customerCancelledOrdersProvider);

    return DefaultTabController(
      length: 3,
      initialIndex: 1,
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                width: double.infinity,
                child: TabBar(
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                  tabs: [
                    Tab(text: 'Semua'),
                    Tab(text: 'Selesai'),
                    Tab(text: 'Dibatalkan'),
                  ],
                ),
              ),
              Expanded(
                child: AppContentBackground(
                  child: _isOpeningRefresh
                      ? const Center(child: CircularProgressIndicator())
                      : ordersAsync.when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (error, stackTrace) => Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: BangErrorState(
                                title: 'Gagal memuat riwayat',
                                message: error.toString(),
                                onRetry: _refreshOnOpen,
                              ),
                            ),
                          ),
                          data: (_) => TabBarView(
                            children: [
                              _buildOrderList(
                                context,
                                historyOrders,
                                emptyTitle: 'Belum ada riwayat pesanan',
                                emptySubtitle:
                                    'Riwayat pesanan akan muncul di sini.',
                              ),
                              _buildOrderList(
                                context,
                                completedOrders,
                                emptyTitle: 'Belum ada pesanan selesai',
                                emptySubtitle:
                                    'Pesanan selesai akan muncul di sini.',
                              ),
                              _buildOrderList(
                                context,
                                cancelledOrders,
                                emptyTitle: 'Belum ada pesanan dibatalkan',
                                emptySubtitle:
                                    'Pesanan dibatalkan akan muncul di sini.',
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

  Widget _buildOrderList(
    BuildContext context,
    List<CustomerOrderSummaryModel> orders, {
    required String emptyTitle,
    required String emptySubtitle,
  }) {
    if (orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refreshOrders,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: BangIllustrationEmptyState(
                  title: emptyTitle,
                  subtitle: emptySubtitle,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshOrders,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 116),
        itemCount: orders.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final order = orders[index];

          return CustomerOrderCard(
            order: order,
            onTap: () => context.push(
              AppRoutes.track,
              extra: <String, dynamic>{
                'orderId': order.id,
                'fromHistory': true,
              },
            ),
            showPaymentInfo: false,
            showDetailHint: true,
            showInlinePrice: true,
          );
        },
      ),
    );
  }
}
