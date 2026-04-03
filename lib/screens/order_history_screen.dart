import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../models/order_model.dart';
import 'package:go_router/go_router.dart';

class OrderHistoryScreen extends StatelessWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Riwayat Pesanan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          backgroundColor: AppColors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              }
            },
          ),
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: [
              Tab(text: 'Semua'),
              Tab(text: 'Selesai'),
              Tab(text: 'Dibatalkan'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildOrderList([]),
            _buildOrderList([]),
            _buildOrderList([]),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderList(List<OrderModel> orders) {
    if (orders.isEmpty) {
      return const Center(
        child: Text('Tidak ada pesanan.', style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: orders.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return _buildOrderCard(orders[index]);
      },
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    final bool isCompleted = order.status == 'Selesai';
    final bool isCancelled = order.status == 'Dibatalkan';

    Color statusColor = AppColors.primary;
    IconData statusIcon = Icons.delivery_dining;

    if (isCompleted) {
      statusColor = AppColors.success;
      statusIcon = Icons.check;
    } else if (isCancelled) {
      statusColor = Colors.red;
      statusIcon = Icons.close;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardYellow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (ID and Status)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(order.id, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      order.status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Restaurant and Items
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Text('🍜', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.restaurantName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(order.items, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isCompleted && order.rating > 0)
            Row(
              children: List.generate(5, (index) {
                return Icon(
                  index < order.rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 16,
                );
              }),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: AppColors.border, height: 1),
          ),
          // Price and Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.formattedPrice,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryDark),
                  ),
                  const SizedBox(height: 2),
                  Text(order.date, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () {},
                icon: Icon(order.status == 'Diantar' ? Icons.location_on : Icons.refresh, size: 16),
                label: Text(order.status == 'Diantar' ? 'Lacak' : 'Pesan Lagi'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: order.status == 'Diantar' ? AppColors.primary : AppColors.textSecondary,
                  side: BorderSide(color: order.status == 'Diantar' ? AppColors.primary : AppColors.textSecondary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
