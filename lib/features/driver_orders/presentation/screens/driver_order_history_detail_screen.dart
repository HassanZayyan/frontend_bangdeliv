import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_routes.dart';
import '../../../../core/widgets/bang_async_state.dart';
import '../../../../models/driver_order_model.dart';
import '../../../../services/driver_order_service.dart';
import '../../../../widgets/order_chat_badge_icon.dart';
import '../../../orders/application/order_chat_unread_provider.dart';
import '../../application/driver_order_providers.dart';
import '../widgets/driver_active_order_action_widgets.dart';
import '../widgets/driver_active_order_meta_widgets.dart';

class DriverOrderHistoryDetailScreen extends ConsumerWidget {
  const DriverOrderHistoryDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (orderId.trim().isEmpty || !_isServerOrderId(orderId)) {
      return const Scaffold(
        body: Center(child: Text('Order ID riwayat tidak valid.')),
      );
    }

    final detailState = ref.watch(driverOrderDetailProvider(orderId));
    final parsedOrderId = int.tryParse(orderId);
    final unreadCountAsync = parsedOrderId == null
        ? const AsyncData<int>(0)
        : ref.watch(orderChatUnreadCountProvider(parsedOrderId));
    final unreadCount = unreadCountAsync.asData?.value ?? 0;

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }

        _goBackToHistory(context);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'Detail Pesanan',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          backgroundColor: AppColors.white,
          elevation: 0,
          leading: IconButton(
            tooltip: 'Kembali ke riwayat',
            icon: const Icon(
              Icons.chevron_left_rounded,
              color: AppColors.textPrimary,
            ),
            onPressed: () => _goBackToHistory(context),
          ),
          actions: [
            IconButton(
              tooltip: 'Chat customer',
              icon: OrderChatBadgeIcon(
                unreadCount: unreadCount,
                iconColor: AppColors.textPrimary,
              ),
              onPressed: () => context.push(AppRoutes.orderChatPath(orderId)),
            ),
          ],
        ),
        body: detailState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) {
            return BangErrorState(
              message: _mapDetailError(error),
              onRetry: () {
                ref.invalidate(driverOrderDetailProvider(orderId));
              },
            );
          },
          data: (order) {
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(driverOrderDetailProvider(orderId));
                await ref.read(driverOrderDetailProvider(orderId).future);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                children: [
                  DriverOrderMetaCard(order: order),
                  if (order.shoppingItems.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _HistoryShoppingItemsCard(items: order.shoppingItems),
                  ],
                  if (order.proofs.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _HistoryProofsCard(proofs: order.proofs),
                  ],
                  const SizedBox(height: 12),
                  DriverOrderTimelineCard(timeline: order.statusTimeline),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  bool _isServerOrderId(String raw) {
    return RegExp(r'^\d+$').hasMatch(raw.trim());
  }

  String _mapDetailError(Object error) {
    if (error is DriverOrderApiException) {
      if (error.statusCode == 404) {
        return 'Riwayat order tidak ditemukan di server.';
      }

      return error.message;
    }

    return error.toString();
  }

  void _goBackToHistory(BuildContext context) {
    context.go(AppRoutes.driverHistory);
  }
}

class _HistoryShoppingItemsCard extends StatelessWidget {
  const _HistoryShoppingItemsCard({required this.items});

  final List<DriverShoppingItemModel> items;

  @override
  Widget build(BuildContext context) {
    return _HistoryCardShell(
      title: 'Item Belanja',
      icon: Icons.shopping_bag_outlined,
      child: Column(
        children: items
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.quantity} item',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    if ((item.notes ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.notes!.trim(),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _HistoryProofsCard extends StatelessWidget {
  const _HistoryProofsCard({required this.proofs});

  final List<DriverOrderProofModel> proofs;

  @override
  Widget build(BuildContext context) {
    final visibleProofs = proofs
        .where((proof) => (proof.photoUrl ?? '').trim().isNotEmpty)
        .toList(growable: false);
    if (visibleProofs.isEmpty) {
      return const SizedBox.shrink();
    }

    return _HistoryCardShell(
      title: 'Bukti Foto',
      icon: Icons.photo_library_outlined,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: visibleProofs
            .map(
              (proof) => InkWell(
                onTap: () => _showProofPreview(context, proof),
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 86,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          proof.photoUrl!,
                          width: 86,
                          height: 86,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 86,
                            height: 86,
                            color: AppColors.background,
                            child: const Icon(
                              Icons.image_not_supported_outlined,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        proof.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  void _showProofPreview(BuildContext context, DriverOrderProofModel proof) {
    final url = proof.photoUrl;
    if (url == null || url.trim().isEmpty) {
      return;
    }

    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(18),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: InteractiveViewer(
            child: Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Gambar bukti belum bisa dimuat.'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryCardShell extends StatelessWidget {
  const _HistoryCardShell({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
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
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
