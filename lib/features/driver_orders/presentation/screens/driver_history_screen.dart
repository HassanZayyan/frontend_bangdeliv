import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/app_colors.dart';
import '../../../../core/widgets/bang_async_state.dart';
import '../../../../models/driver_order_model.dart';
import '../../application/driver_order_providers.dart';
import '../../../../utils/order_formatters.dart';

class DriverHistoryScreen extends ConsumerStatefulWidget {
  const DriverHistoryScreen({super.key});

  @override
  ConsumerState<DriverHistoryScreen> createState() =>
      _DriverHistoryScreenState();
}

class _DriverHistoryScreenState extends ConsumerState<DriverHistoryScreen> {
  static const _allFilter = 'Semua';
  static const _todayFilter = 'Hari Ini';
  static const _weekFilter = 'Minggu Ini';

  String _selectedFilter = _weekFilter;

  @override
  Widget build(BuildContext context) {
    final historyState = ref.watch(driverHistoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Riwayat Driver',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: historyState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) {
          return BangErrorState(
            message: error.toString(),
            onRetry: () => ref.read(driverHistoryProvider.notifier).refresh(),
          );
        },
        data: (orders) {
          final filteredOrders = _applyFilter(orders);
          final completedCount = filteredOrders
              .where((order) => order.status == 'Selesai')
              .length;
          final totalIncome = filteredOrders
              .where((order) => order.status == 'Selesai')
              .fold<int>(0, (total, order) => total + order.fee);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  children: [
                    _buildFilterChip(_allFilter),
                    const SizedBox(width: 8),
                    _buildFilterChip(_todayFilter),
                    const SizedBox(width: 8),
                    _buildFilterChip(_weekFilter),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        title: 'Order Selesai',
                        value: completedCount.toString(),
                        icon: Icons.check_circle_outline,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SummaryCard(
                        title: 'Pendapatan',
                        value: formatCurrency(totalIncome),
                        icon: Icons.payments_outlined,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filteredOrders.isEmpty
                    ? const _EmptyHistoryState()
                    : RefreshIndicator(
                        onRefresh: () async {
                          await ref
                              .read(driverHistoryProvider.notifier)
                              .refresh(showLoading: false);
                        },
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: filteredOrders.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final order = filteredOrders[index];
                            return _HistoryCard(
                              order: order,
                              formatter: formatCurrency,
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String filter) {
    final selected = _selectedFilter == filter;
    return ChoiceChip(
      label: Text(filter),
      selected: selected,
      onSelected: (isSelected) {
        if (!isSelected) {
          return;
        }

        setState(() {
          _selectedFilter = filter;
        });
      },
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: selected ? AppColors.primaryDark : AppColors.textSecondary,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
      showCheckmark: false,
      backgroundColor: AppColors.white,
    );
  }

  List<DriverHistoryOrderModel> _applyFilter(
    List<DriverHistoryOrderModel> orders,
  ) {
    final now = wibNow();

    if (_selectedFilter == _todayFilter) {
      return orders
          .where((order) {
            final orderDate = toWib(order.date);
            return orderDate.year == now.year &&
                orderDate.month == now.month &&
                orderDate.day == now.day;
          })
          .toList(growable: false);
    }

    if (_selectedFilter == _weekFilter) {
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final normalizedStart = DateTime.utc(
        startOfWeek.year,
        startOfWeek.month,
        startOfWeek.day,
      );

      return orders
          .where((order) => toWib(order.date).isAfter(normalizedStart))
          .toList(growable: false);
    }

    return orders;
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final DriverHistoryOrderModel order;
  final String Function(num amount) formatter;

  const _HistoryCard({required this.order, required this.formatter});

  @override
  Widget build(BuildContext context) {
    final isCompleted = order.status == 'Selesai';
    final statusColor = isCompleted ? AppColors.success : AppColors.error;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                order.id,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  order.status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Customer: ${order.customerName}',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatDate(order.date),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isCompleted ? formatter(order.fee) : 'Tidak ada pendapatan',
            style: TextStyle(
              color: isCompleted
                  ? AppColors.primaryDark
                  : AppColors.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return formatDateTime(date);
  }
}

class _EmptyHistoryState extends StatelessWidget {
  const _EmptyHistoryState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Belum ada riwayat order pada periode ini.',
        style: TextStyle(color: AppColors.textSecondary),
      ),
    );
  }
}
