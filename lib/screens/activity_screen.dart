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

  bool _isCancelling(int orderId) => _cancellingOrderIds.contains(orderId);

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

      ref.invalidate(customerOrdersProvider);
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
    final controller = TextEditingController(text: 'Perubahan rencana.');

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Batalkan Order'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Tulis alasan pembatalan',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: const Text('Konfirmasi'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(customerOrdersProvider);
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
        body: ordersAsync.when(
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
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(customerOrdersProvider),
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
                ),
                _buildOrderList(
                  ongoingOrders,
                  emptyMessage: 'Belum ada order yang sedang berjalan.',
                ),
                _buildOrderList(
                  cancelledOrders,
                  emptyMessage: 'Belum ada order dibatalkan.',
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
  }) {
    if (orders.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.separated(
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
    );
  }
}
