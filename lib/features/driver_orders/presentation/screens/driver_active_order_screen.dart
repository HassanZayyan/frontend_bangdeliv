import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_routes.dart';
import '../../../../core/widgets/bang_async_state.dart';
import '../../../../services/driver_order_service.dart';
import '../../../../utils/service_type.dart';
import '../../../../widgets/driver_transfer_payment_card.dart';
import '../../../../widgets/order_chat_badge_icon.dart';
import '../../../orders/application/order_chat_unread_provider.dart';
import '../../application/driver_location_reporter_provider.dart';
import '../../application/driver_order_providers.dart';
import '../widgets/driver_active_order_action_widgets.dart';
import '../widgets/driver_active_order_fee_widgets.dart';
import '../widgets/driver_active_order_map_widgets.dart';
import '../widgets/driver_active_order_meta_widgets.dart';
import '../widgets/driver_active_order_proof_widgets.dart';
import '../widgets/driver_active_order_shopping_widgets.dart';

class DriverActiveOrderScreen extends ConsumerWidget {
  final String orderId;

  const DriverActiveOrderScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (orderId.trim().isEmpty || !_isServerOrderId(orderId)) {
      return const Scaffold(
        body: Center(child: Text('Order ID tidak valid untuk data server.')),
      );
    }

    final detailState = ref.watch(driverOrderDetailProvider(orderId));
    ref.watch(driverOrderDetailRealtimeProvider(orderId));
    ref.watch(driverOrderTransferProofReconciliationProvider(orderId));
    final ordersState = ref.watch(driverOrdersProvider);

    final isProcessing = ordersState.maybeWhen(
      data: (value) => value.isProcessing(orderId),
      orElse: () => false,
    );
    final parsedOrderId = int.tryParse(orderId);
    final unreadCountAsync = parsedOrderId == null
        ? const AsyncData<int>(0)
        : ref.watch(orderChatUnreadCountProvider(parsedOrderId));
    final unreadCount = unreadCountAsync.asData?.value ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Order Aktif',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
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
          final locationState = ref.watch(driverLocationReporterProvider);
          final latestPosition = locationState.activeOrderId == order.id
              ? locationState.latestPosition
              : null;
          final driverPosition = latestPosition == null
              ? null
              : LatLng(latestPosition.latitude, latestPosition.longitude);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(driverOrderDetailProvider(orderId));
              await ref.read(driverOrderDetailProvider(orderId).future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              children: [
                DriverActiveOrderMapCard(
                  order: order,
                  driverPosition: driverPosition,
                ),
                const SizedBox(height: 12),
                DriverOrderMetaCard(order: order),
                const SizedBox(height: 12),
                if (normalizeServiceTypeCode(order.serviceTypeCode) ==
                    ServiceTypeCodes.courier) ...[
                  DriverOrderProofChecklistCard(
                    order: order,
                    isProcessing: isProcessing,
                    onUploadProof:
                        ({
                          required type,
                          required photo,
                          note,
                          pickupLocationId,
                        }) {
                          return ref
                              .read(driverOrdersProvider.notifier)
                              .uploadProof(
                                orderId: order.id,
                                type: type,
                                photo: photo,
                                note: note,
                                pickupLocationId: pickupLocationId,
                              );
                        },
                  ),
                  const SizedBox(height: 12),
                ],
                DriverManualDeliveryFeeCard(
                  order: order,
                  isProcessing: isProcessing,
                  onSave:
                      ({
                        required amount,
                        required reason,
                        required carefulCarryRequired,
                      }) {
                        return ref
                            .read(driverOrdersProvider.notifier)
                            .updateDeliveryFeeOverride(
                              orderId: order.id,
                              amount: amount,
                              reason: reason,
                              carefulCarryRequired: carefulCarryRequired,
                            );
                      },
                ),
                const SizedBox(height: 12),
                if (order.shoppingItems.isNotEmpty) ...[
                  DriverShoppingItemsCard(
                    order: order,
                    isProcessing: isProcessing,
                    onUploadReceipt: (photo, note) {
                      return ref
                          .read(driverOrdersProvider.notifier)
                          .uploadProof(
                            orderId: order.id,
                            type: 'receipt',
                            photo: photo,
                            note: note,
                          );
                    },
                    onSave:
                        (
                          items,
                          shoppingTotalAmount,
                          deliveryFeeOverride,
                          receiptNote,
                          receiptPhoto,
                        ) async {
                          final error = await ref
                              .read(driverOrdersProvider.notifier)
                              .updateShoppingCheckout(
                                orderId: order.id,
                                items: items,
                                shoppingTotalAmount: shoppingTotalAmount,
                                deliveryFeeOverride: deliveryFeeOverride,
                                receiptNote: receiptNote,
                                receiptPhoto: receiptPhoto,
                              );

                          if (error == null) {
                            ref.invalidate(driverOrderDetailProvider(order.id));
                            try {
                              await ref.read(
                                driverOrderDetailProvider(order.id).future,
                              );
                            } catch (_) {
                              return 'Checkout tersimpan, tapi detail order belum berhasil dimuat ulang. Tarik layar untuk refresh.';
                            }
                          }

                          return error;
                        },
                  ),
                  const SizedBox(height: 12),
                ],
                if (DriverTransferPaymentCard.shouldShow(order)) ...[
                  DriverTransferPaymentCard(
                    order: order,
                    isProcessing: isProcessing,
                    onConfirmTransfer: ({required amount, required note}) async {
                      final error = await ref
                          .read(driverOrdersProvider.notifier)
                          .confirmTransferPayment(
                            orderId: order.id,
                            amount: amount,
                            note: note,
                          );

                      if (!context.mounted) {
                        return;
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            error ??
                                'Pembayaran transfer berhasil diverifikasi.',
                          ),
                          backgroundColor: error == null
                              ? null
                              : AppColors.error,
                        ),
                      );
                      if (error == null) {
                        ref.invalidate(driverOrderDetailProvider(order.id));
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                DriverOrderTimelineCard(timeline: order.statusTimeline),
                const SizedBox(height: 12),
                DriverOrderActionCard(
                  order: order,
                  isProcessing: isProcessing,
                  onReportPickupFailed:
                      ({
                        required pickupLocationId,
                        required reason,
                        required storeClosedPhoto,
                      }) async {
                        final error = await ref
                            .read(driverOrdersProvider.notifier)
                            .recordShoppingPickupFailed(
                              orderId: order.id,
                              pickupLocationId: pickupLocationId,
                              reason: reason,
                              storeClosedPhoto: storeClosedPhoto,
                            );

                        if (!context.mounted) {
                          return;
                        }

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              error ?? 'Merchant tutup berhasil dicatat.',
                            ),
                            backgroundColor: error == null
                                ? null
                                : AppColors.error,
                          ),
                        );
                        if (error == null) {
                          ref.invalidate(driverOrderDetailProvider(order.id));
                        }
                      },
                  onTapAction: (action) async {
                    final notifier = ref.read(driverOrdersProvider.notifier);

                    String? error;
                    if (action.isCodCollection) {
                      error = await notifier.collectCod(
                        orderId: order.id,
                        amount: order.totalPrice,
                        note:
                            normalizeServiceTypeCode(order.serviceTypeCode) ==
                                ServiceTypeCodes.courier
                            ? 'Pembayaran courier dicatat saat pickup dari app driver.'
                            : 'Pembayaran COD dicatat dari app driver.',
                      );
                    } else {
                      error = await notifier.transitionOrderStatus(
                        orderId: order.id,
                        actionCode: action.actionCode,
                        targetStatusCode: action.targetStatusCode,
                      );
                    }

                    if (!context.mounted) {
                      return;
                    }

                    if (error == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${action.label} berhasil.')),
                      );
                      ref.invalidate(driverOrderDetailProvider(order.id));
                      return;
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(error),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  bool _isServerOrderId(String raw) {
    return RegExp(r'^\d+$').hasMatch(raw.trim());
  }

  String _mapDetailError(Object error) {
    if (error is DriverOrderApiException) {
      if (error.statusCode == 404) {
        return 'Order tidak ditemukan di server. Coba refresh daftar order.';
      }

      return error.message;
    }

    return error.toString();
  }
}
