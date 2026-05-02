import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../models/customer_order_model.dart';
import '../providers/api_providers.dart';
import '../providers/customer_order_providers.dart';
import '../widgets/customer_order_card.dart';

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
          .read(customerOrderApiServiceProvider)
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
      builder: (dialogContext) {
        return const _CancelOrderDialog();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(customerOrdersProvider);
    ref.watch(customerOrdersAutoRefreshProvider);
    final allActivityOrders = ref.watch(customerActivityOrdersProvider);
    final ongoingOrders = ref.watch(customerOngoingOrdersProvider);
    final cancelledOrders = ref.watch(customerCancelledOrdersProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'Aktivitas',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          backgroundColor: AppColors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: [
              Tab(text: 'Semua'),
              Tab(text: 'Berjalan'),
              Tab(text: 'Dibatalkan'),
            ],
          ),
        ),
        body: _isOpeningRefresh
            ? const Center(child: CircularProgressIndicator())
            : ordersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          error.toString(),
                          textAlign: TextAlign.center,
                          style:
                              const TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _refreshOnOpen,
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (_) {
                  return TabBarView(
                    children: [
                      _buildOrderList(
                        allActivityOrders,
                        emptyMessage: 'Belum ada aktivitas order.',
                        onRefresh: _refreshOrders,
                      ),
                      _buildOrderList(
                        ongoingOrders,
                        emptyMessage: 'Belum ada order yang sedang berjalan.',
                        onRefresh: _refreshOrders,
                      ),
                      _buildOrderList(
                        cancelledOrders,
                        emptyMessage: 'Belum ada order dibatalkan.',
                        onRefresh: _refreshOrders,
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _buildOrderList(
    List<CustomerOrderSummaryModel> orders, {
    required String emptyMessage,
    required Future<void> Function() onRefresh,
  }) {
    if (orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          children: [
            SizedBox(
              height: 220,
              child: Center(
                child: Text(
                  emptyMessage,
                  style: const TextStyle(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
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
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        itemCount: orders.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final order = orders[index];

          return CustomerOrderCard(
            order: order,
            showTrackAction: order.canTrack,
            showCancelAction: order.canCancel,
            isCancelling: _isCancelling(order.id),
            onTrack: order.canTrack
                ? () => context.push(AppRoutes.track, extra: order.id)
                : null,
            onCancel: order.canCancel ? () => _cancelOrder(order) : null,
          );
        },
      ),
    );
  }
}

class _CancelOrderDialog extends StatefulWidget {
  const _CancelOrderDialog();

  @override
  State<_CancelOrderDialog> createState() => _CancelOrderDialogState();
}

class _CancelOrderDialogState extends State<_CancelOrderDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: 'Perubahan rencana.');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Batalkan Order'),
      content: TextField(
        controller: _controller,
        maxLines: 3,
        decoration: const InputDecoration(
          hintText: 'Tulis alasan pembatalan',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Konfirmasi'),
        ),
      ],
    );
  }
}
