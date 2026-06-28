import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_routes.dart';
import '../../../../config/app_text_scaling.dart';
import '../../../../core/widgets/bang_async_state.dart';
import '../../../../models/driver_order_model.dart';
import '../../../navigation/presentation/widgets/bang_floating_bottom_nav_bar.dart';
import '../../application/driver_earnings_summary.dart';
import '../../application/driver_order_providers.dart';
import '../../../../utils/order_formatters.dart';
import '../../../../widgets/bang_ui.dart' show BangIllustrationEmptyState;

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
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
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
          final summary = DriverEarningsSummary.fromHistory(filteredOrders);

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
                        value: summary.completedCount.toString(),
                        icon: Icons.task_alt_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SummaryCard(
                        title: 'Pendapatan',
                        value: formatCurrency(summary.netIncomeTotal),
                        icon: Icons.payments_outlined,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filteredOrders.isEmpty
                    ? _EmptyHistoryState(
                        onRefresh: () async {
                          await ref
                              .read(driverHistoryProvider.notifier)
                              .refresh(showLoading: false);
                        },
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          await ref
                              .read(driverHistoryProvider.notifier)
                              .refresh(showLoading: false);
                        },
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: ClampingScrollPhysics(),
                          ),
                          padding: const EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            BangFloatingBottomNavBar.scrollClearance,
                          ),
                          itemCount: filteredOrders.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final order = filteredOrders[index];
                            return _HistoryCard(
                              order: order,
                              formatter: formatCurrency,
                              onTap: order.orderId == null
                                  ? null
                                  : () => context.go(
                                      AppRoutes.driverHistoryDetailPath(
                                        order.orderId!,
                                      ),
                                    ),
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
      selectedColor: AppColors.white,
      labelStyle: TextStyle(
        color: selected ? AppColors.primaryDark : AppColors.textSecondary,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
      showCheckmark: false,
      backgroundColor: AppColors.white,
      surfaceTintColor: AppColors.white,
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

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.025),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.textSecondary, size: 18),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: AppTextScaling.adaptive(
                context,
                normal: 16,
                large: 14.5,
              ),
              fontWeight: FontWeight.w800,
              height: 1.1,
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
  final VoidCallback? onTap;

  const _HistoryCard({
    required this.order,
    required this.formatter,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCompleted = order.status == 'Selesai';

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.025),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    order.displayOrderNumber,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  _statusLabel(
                    context,
                    order.status,
                    foreground: isCompleted
                        ? AppColors.success
                        : AppColors.error,
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
                isCompleted
                    ? formatter(order.netIncomeRounded)
                    : 'Tidak ada pendapatan',
                style: TextStyle(
                  color: isCompleted
                      ? AppColors.primaryDark
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isCompleted && order.hasAdminFeeBreakdown) ...[
                const SizedBox(height: 4),
                Text(
                  'Bruto ${formatter(order.driverIncomeGross.round())} - Admin ${_formatPercent(order.driverAdminFeePercent)} ${formatter(order.driverAdminFee.round())}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return formatDateMonthTime(date);
  }

  Widget _statusLabel(
    BuildContext context,
    String text, {
    required Color foreground,
  }) {
    return AppTextScaling.clampForCompactComponent(
      context: context,
      maxScaleFactor: AppTextScaling.denseComponentMaxScaleFactor,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: foreground,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPercent(double percent) {
    final fixed = percent.toStringAsFixed(2);
    return '${fixed.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')}%';
  }
}

class _EmptyHistoryState extends StatelessWidget {
  const _EmptyHistoryState({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: const CustomScrollView(
        physics: AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: BangIllustrationEmptyState(
              title: 'Belum ada riwayat order',
              subtitle: '',
              titleFontSize: 13,
              titleFontWeight: FontWeight.w500,
              titleColor: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
