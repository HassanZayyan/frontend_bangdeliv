import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_routes.dart';
import '../../../../core/widgets/bang_async_state.dart';
import '../../../../models/driver_order_model.dart';
import '../../../../services/driver_order_service.dart';
import '../../../../utils/order_status.dart';
import '../../../../utils/service_type.dart';
import '../../../../widgets/driver_transfer_payment_card.dart';
import '../../../../widgets/order_chat_badge_icon.dart';
import '../../../navigation/presentation/widgets/bang_floating_bottom_nav_bar.dart';
import '../../../orders/application/order_chat_unread_provider.dart';
import '../../application/driver_location_reporter_provider.dart';
import '../../application/driver_order_providers.dart';
import '../widgets/driver_active_order_action_widgets.dart';
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
    final ordersSnapshot = ordersState.asData?.value;
    final isOrderBusy = ordersSnapshot?.isProcessing(orderId) ?? false;
    bool isProcessingAction(String actionKey) {
      return ordersSnapshot?.isProcessingAction(actionKey) ?? false;
    }

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
      bottomNavigationBar: detailState.maybeWhen(
        data: (order) =>
            _buildStickyActionBar(context, ref, order, isOrderBusy),
        orElse: () => null,
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

          final hasStickyActionBar = order.availableActions.isNotEmpty ||
              (normalizeServiceTypeCode(order.serviceTypeCode) ==
                      ServiceTypeCodes.shopping &&
                  order.shoppingStops.any((stop) => stop.isActive) &&
                  order.shoppingPricing?.canCancelWithFee != true &&
                  (normalizeOrderStatusCode(order.statusCode) ==
                          OrderStatusCodes.driverAssigned ||
                      normalizeOrderStatusCode(order.statusCode) ==
                          OrderStatusCodes.arrivedMerchant));

          final bottomPadding = hasStickyActionBar
              ? 16.0
              : BangFloatingBottomNavBar.scrollClearance;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(driverOrderDetailProvider(orderId));
              await ref.read(driverOrderDetailProvider(orderId).future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                bottomPadding,
              ),
              children: [
                DriverActiveOrderMapCard(
                  order: order,
                  driverPosition: driverPosition,
                ),
                const SizedBox(height: 12),
                DriverOrderCustomerCard(order: order),
                const SizedBox(height: 12),
                DriverOrderRouteCard(order: order),
                const SizedBox(height: 12),
                if (normalizeServiceTypeCode(order.serviceTypeCode) ==
                    ServiceTypeCodes.courier) ...[
                  DriverOrderPackageCard(order: order),
                  const SizedBox(height: 12),
                ],
                DriverOrderPricingCard(
                  order: order,
                  isProcessing: isProcessingAction(
                    DriverOrderActionKeys.updateFee(order.id),
                  ),
                  onEditDeliveryFee:
                      ({
                        required amount,
                        required reason,
                      }) async {
                        final error = await ref
                            .read(driverOrdersProvider.notifier)
                            .updateDeliveryFeeOverride(
                              orderId: order.id,
                              amount: amount,
                              reason: reason,
                            );
                        if (error == null) {
                          ref.invalidate(driverOrderDetailProvider(order.id));
                        }
                        return error;
                      },
                ),
                const SizedBox(height: 12),
                if (normalizeServiceTypeCode(order.serviceTypeCode) ==
                    ServiceTypeCodes.courier) ...[
                  DriverOrderProofChecklistCard(
                    order: order,
                    isOrderBusy: isOrderBusy,
                    isProofUploading: (type) => isProcessingAction(
                      DriverOrderActionKeys.uploadProof(order.id, type),
                    ),
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
                if (order.shoppingItems.isNotEmpty) ...[
                  if (DriverShoppingItemChangeRequestCard.shouldShow(
                    order,
                  )) ...[
                    DriverShoppingItemChangeRequestCard(
                      request: order.shoppingItemChangeRequest!,
                      isOrderBusy: isOrderBusy,
                      isApproving: isProcessingAction(
                        DriverOrderActionKeys.respondShoppingItemChange(
                          order.id,
                          'APPROVE',
                        ),
                      ),
                      isRejecting: isProcessingAction(
                        DriverOrderActionKeys.respondShoppingItemChange(
                          order.id,
                          'REJECT',
                        ),
                      ),
                      onRespond: (action) async {
                        final error = await ref
                            .read(driverOrdersProvider.notifier)
                            .respondShoppingItemChange(
                              orderId: order.id,
                              action: action,
                            );
                        if (error == null) {
                          ref.invalidate(driverOrderDetailProvider(order.id));
                        }
                        return error;
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  DriverShoppingItemsCard(
                    order: order,
                    isOrderBusy: isOrderBusy,
                    isSavingCheckout: isProcessingAction(
                      DriverOrderActionKeys.shoppingCheckout(order.id),
                    ),
                    isSavingItems: (pickupLocationId) => isProcessingAction(
                      DriverOrderActionKeys.updateShoppingItems(
                        order.id,
                        pickupLocationId,
                      ),
                    ),
                    canEditAvailability: order
                        .shoppingCapabilities
                        .canDriverUpdateItemAvailability,
                    canUploadReceipt:
                        order.shoppingCapabilities.canDriverUploadReceipt,
                    canCheckout:
                        order.shoppingNegotiation?.checkoutAllowed == true &&
                        !order.shoppingCapabilities.hasPendingItemChangeRequest,
                    isSubmittingQuote: (pickupLocationId) => isProcessingAction(
                      DriverOrderActionKeys.shoppingPriceQuote(
                        order.id,
                        pickupLocationId,
                      ),
                    ),
                    isBypassingPrice: (pickupLocationId) => isProcessingAction(
                      DriverOrderActionKeys.bypassShoppingPrice(
                        order.id,
                        pickupLocationId,
                      ),
                    ),
                    isMarkingMerchantOpen: (pickupLocationId) =>
                        isProcessingAction(
                          DriverOrderActionKeys.markShoppingMerchantOpen(
                            order.id,
                            pickupLocationId,
                          ),
                        ),
                    isClosingMerchant: (pickupLocationId) => isProcessingAction(
                      DriverOrderActionKeys.pickupFailed(
                        order.id,
                        pickupLocationId,
                      ),
                    ),
                    onUploadReceipt: (photo) {
                      return ref
                          .read(driverOrdersProvider.notifier)
                          .uploadProof(
                            orderId: order.id,
                            type: 'receipt',
                            photo: photo,
                          );
                    },
                    onSubmitQuote: ({required amount, pickupLocationId}) async {
                      final error = await ref
                          .read(driverOrdersProvider.notifier)
                          .submitShoppingPriceQuote(
                            orderId: order.id,
                            amount: amount,
                            pickupLocationId: pickupLocationId,
                          );
                      if (error == null) {
                        ref.invalidate(driverOrderDetailProvider(order.id));
                      }
                      return error;
                    },
                    onBypassPrice: ({required pickupLocationId}) async {
                      final error = await ref
                          .read(driverOrdersProvider.notifier)
                          .bypassShoppingPriceQuote(
                            orderId: order.id,
                            pickupLocationId: pickupLocationId,
                          );
                      if (error == null) {
                        ref.invalidate(driverOrderDetailProvider(order.id));
                      }
                      return error;
                    },
                    onMarkMerchantOpen: ({required pickupLocationId}) async {
                      final error = await ref
                          .read(driverOrdersProvider.notifier)
                          .markShoppingMerchantOpen(
                            orderId: order.id,
                            pickupLocationId: pickupLocationId,
                          );
                      if (error == null) {
                        ref.invalidate(driverOrderDetailProvider(order.id));
                      }
                      return error;
                    },
                    onMarkMerchantClosed:
                        ({required pickupLocationId, required reason}) async {
                          final error = await ref
                              .read(driverOrdersProvider.notifier)
                              .recordShoppingPickupFailed(
                                orderId: order.id,
                                pickupLocationId: pickupLocationId,
                                reason: reason,
                              );
                          if (error == null) {
                            ref.invalidate(driverOrderDetailProvider(order.id));
                          }
                          return error;
                        },
                    onSaveItems: (items, pickupLocationId) async {
                      final error = await ref
                          .read(driverOrdersProvider.notifier)
                          .updateShoppingItems(
                            orderId: order.id,
                            items: items,
                            pickupLocationId: pickupLocationId,
                          );

                      if (error == null) {
                        ref.invalidate(driverOrderDetailProvider(order.id));
                      }

                      return error;
                    },
                    onSave: (items, receiptPhoto) async {
                      final error = await ref
                          .read(driverOrdersProvider.notifier)
                          .updateShoppingCheckout(
                            orderId: order.id,
                            items: items,
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
                    isOrderBusy: isOrderBusy,
                    isConfirmingQris: isProcessingAction(
                      DriverOrderActionKeys.confirmQris(order.id),
                    ),
                    onConfirmTransfer: ({required amount}) async {
                      final error = await ref
                          .read(driverOrdersProvider.notifier)
                          .confirmTransferPayment(
                            orderId: order.id,
                            amount: amount,
                          );

                      if (!context.mounted) {
                        return;
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            error ?? 'Pembayaran QRIS berhasil diverifikasi.',
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
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStickyActionBar(
    BuildContext context,
    WidgetRef ref,
    DriverOrderModel order,
    bool isProcessing,
  ) {
    return DriverOrderStickyActionBar(
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
                content: Text(error ?? 'Merchant tutup berhasil dicatat.'),
                backgroundColor: error == null ? null : AppColors.error,
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('${action.label} berhasil.')));
          ref.invalidate(driverOrderDetailProvider(order.id));
          if (action.targetStatusCode != null &&
              !isDriverRunningOrderStatus(action.targetStatusCode!)) {
            context.go(AppRoutes.driverOrders);
          }
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: AppColors.error),
        );
      },
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
