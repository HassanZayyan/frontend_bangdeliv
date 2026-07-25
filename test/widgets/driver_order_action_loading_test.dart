import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:frontend_bangdeliv/config/app_colors.dart';
import 'package:frontend_bangdeliv/features/driver_orders/presentation/widgets/driver_active_order_action_widgets.dart';
import 'package:frontend_bangdeliv/features/driver_orders/presentation/widgets/driver_active_order_proof_widgets.dart';
import 'package:frontend_bangdeliv/features/driver_orders/presentation/widgets/driver_active_order_shopping_widgets.dart';
import 'package:frontend_bangdeliv/core/widgets/bang_action_button.dart';
import 'package:frontend_bangdeliv/core/widgets/bang_swipe_action_button.dart';
import 'package:frontend_bangdeliv/models/amount_negotiation_model.dart';
import 'package:frontend_bangdeliv/models/delivery_fee_negotiation_model.dart';
import 'package:frontend_bangdeliv/models/driver_order_model.dart';
import 'package:frontend_bangdeliv/models/payment_proof_feedback_model.dart';
import 'package:frontend_bangdeliv/models/shopping_negotiation_model.dart';
import 'package:frontend_bangdeliv/models/shopping_order_capability_model.dart';
import 'package:frontend_bangdeliv/utils/order_status.dart';
import 'package:frontend_bangdeliv/utils/service_type.dart';

void main() {
  testWidgets('driver action card disables actions while processing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverOrderActionCard(
            order: _order(
              availableActions: const [
                DriverOrderActionModel(
                  actionCode: 'COLLECT_COD',
                  label: 'Catat COD',
                ),
                DriverOrderActionModel(
                  actionCode: 'COMPLETE',
                  label: 'Selesaikan Order',
                  targetStatusCode: OrderStatusCodes.completed,
                ),
              ],
            ),
            isProcessing: true,
            onTapAction: (_) async {},
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsNWidgets(2));
    final actionButtons = tester.widgetList<FilledButton>(
      find.byType(FilledButton),
    );
    expect(actionButtons, hasLength(2));
    expect(actionButtons.every((button) => button.onPressed == null), isTrue);
    expect(find.byIcon(Icons.touch_app_rounded), findsNothing);

    final actionTitle = tester.widget<Text>(find.text('Aksi Driver'));
    expect(actionTitle.style?.fontSize, 16);
    expect(actionTitle.style?.fontWeight, FontWeight.w800);
  });

  testWidgets('shopping item request title is text only', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverShoppingItemChangeRequestCard(
            request: const ShoppingItemChangeRequestModel(
              status: 'PENDING_DRIVER',
              triggerType: 'CUSTOMER_ITEM_CHANGE_REQUESTED',
              action: 'ADD',
              canDriverRespond: true,
              items: [
                ShoppingItemChangeRequestItemModel(name: 'Es teh', quantity: 1),
              ],
            ),
            isOrderBusy: false,
            isApproving: false,
            isRejecting: false,
            onRespond: (_) async => null,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.pending_actions_outlined), findsNothing);

    final requestTitle = tester.widget<Text>(
      find.text('Request Item Customer'),
    );
    expect(requestTitle.style?.fontSize, 16);
    expect(requestTitle.style?.fontWeight, FontWeight.w800);
  });

  testWidgets('proof checklist only shows spinner for selected proof type', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverOrderProofChecklistCard(
            order: _order(serviceTypeCode: ServiceTypeCodes.courier),
            isOrderBusy: true,
            isProofUploading: (type) => type == 'pickup',
            onUploadProof:
                ({
                  required String type,
                  required XFile photo,
                  String? note,
                  int? pickupLocationId,
                }) async => null,
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Ambil Foto'), findsOneWidget);
    expect(find.text('Pengambilan'), findsOneWidget);
    expect(find.text('Diterima'), findsOneWidget);
  });

  testWidgets('proof upload is locked with reason when status not allowed yet', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverOrderProofChecklistCard(
            order: _order(
              serviceTypeCode: ServiceTypeCodes.courier,
              proofCapabilities: const <String, DriverOrderProofCapability>{
                'pickup': DriverOrderProofCapability(
                  canUpload: false,
                  lockedReason: 'Tekan "Tiba di Titik Pickup" dulu.',
                ),
                'delivery': DriverOrderProofCapability(
                  canUpload: false,
                  lockedReason: 'Tekan "Tiba di Tujuan" dulu.',
                ),
              },
            ),
            isOrderBusy: false,
            isProofUploading: (_) => false,
            onUploadProof:
                ({
                  required String type,
                  required XFile photo,
                  String? note,
                  int? pickupLocationId,
                }) async => null,
          ),
        ),
      ),
    );

    // Alasan terkunci tampil untuk kedua bukti.
    expect(find.text('Tekan "Tiba di Titik Pickup" dulu.'), findsOneWidget);
    expect(find.text('Tekan "Tiba di Tujuan" dulu.'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsNWidgets(2));

    // Tombol foto tidak bisa ditekan.
    for (final button in tester.widgetList<BangActionButton>(
      find.byType(BangActionButton),
    )) {
      expect(button.isEnabled, isFalse);
    }
  });

  testWidgets('proof upload stays enabled when backend allows the status', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverOrderProofChecklistCard(
            order: _order(
              serviceTypeCode: ServiceTypeCodes.courier,
              proofCapabilities: const <String, DriverOrderProofCapability>{
                'pickup': DriverOrderProofCapability(canUpload: true),
              },
            ),
            visibleProofTypes: const <String>{'pickup'},
            isOrderBusy: false,
            isProofUploading: (_) => false,
            onUploadProof:
                ({
                  required String type,
                  required XFile photo,
                  String? note,
                  int? pickupLocationId,
                }) async => null,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.lock_outline), findsNothing);
    expect(
      tester.widget<BangActionButton>(find.byType(BangActionButton)).isEnabled,
      isTrue,
    );
  });

  testWidgets('proof checklist filters courier requirements per active step', (
    tester,
  ) async {
    await _pumpProofChecklist(tester, visibleProofTypes: const {'pickup'});

    expect(find.text('Pengambilan'), findsOneWidget);
    expect(find.text('Diterima'), findsNothing);

    await _pumpProofChecklist(tester, visibleProofTypes: const {'delivery'});

    expect(find.text('Pengambilan'), findsNothing);
    expect(find.text('Diterima'), findsOneWidget);
  });

  testWidgets('shopping checkout card keeps receipt upload separate', (
    tester,
  ) async {
    await _pumpShoppingItemsCard(
      tester,
      order: _order(
        serviceTypeCode: ServiceTypeCodes.shopping,
        shoppingItems: const [
          DriverShoppingItemModel(
            id: 1,
            itemSource: 'MANUAL',
            name: 'Mie ayam',
            quantity: 1,
            unitPrice: 12000,
            subtotal: 12000,
            isAvailable: true,
          ),
        ],
      ),
      isOrderBusy: true,
      canEditAvailability: false,
      canUploadReceipt: true,
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Ambil Foto Struk (Opsional)'), findsOneWidget);
    expect(find.text('Simpan Checkout Nitip'), findsNothing);

    final checkoutTitle = tester.widget<Text>(find.text('Checkout Belanja'));
    expect(checkoutTitle.style?.fontSize, 16);
    expect(checkoutTitle.style?.fontWeight, FontWeight.w800);
  });

  testWidgets('shopping receipt action opens camera without source picker', (
    tester,
  ) async {
    await _pumpShoppingItemsCard(
      tester,
      order: _order(
        serviceTypeCode: ServiceTypeCodes.shopping,
        shoppingItems: const [
          DriverShoppingItemModel(
            id: 1,
            itemSource: 'MANUAL',
            name: 'Mie ayam',
            quantity: 1,
            unitPrice: 12000,
            subtotal: 12000,
            isAvailable: true,
          ),
        ],
      ),
      canUploadReceipt: true,
    );

    await tester.tap(find.text('Ambil Foto Struk (Opsional)'));
    await tester.pump();

    expect(find.text('Ambil dari kamera'), findsNothing);
    expect(find.text('Pilih dari galeri'), findsNothing);
  });

  testWidgets('saved shopping checkout is not rendered inside checkout card', (
    tester,
  ) async {
    await _pumpShoppingItemsCard(
      tester,
      order: _order(
        serviceTypeCode: ServiceTypeCodes.shopping,
        shoppingItems: const [
          DriverShoppingItemModel(
            id: 1,
            itemSource: 'MANUAL',
            name: 'Mie ayam',
            quantity: 1,
            unitPrice: 12000,
            subtotal: 12000,
            isAvailable: true,
          ),
        ],
        shoppingCapabilities: const ShoppingOrderCapabilitiesModel(
          canDriverUploadReceipt: true,
          hasCheckoutSaved: true,
        ),
      ),
      canUploadReceipt: true,
    );

    expect(find.text('Checkout Nitip Tersimpan'), findsNothing);
    expect(find.text('Simpan Checkout Nitip'), findsNothing);
    expect(find.text('Ambil Foto Struk (Opsional)'), findsOneWidget);
  });

  testWidgets('shopping sticky bar saves checkout before finish action', (
    tester,
  ) async {
    var saveTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: DriverOrderStickyActionBar(
            order: _order(
              serviceTypeCode: ServiceTypeCodes.shopping,
              statusCode: OrderStatusCodes.arrivedMerchant,
              availableActions: const [
                DriverOrderActionModel(
                  actionCode: 'CONFIRM_PICKED_UP',
                  label: 'Belanja Selesai',
                  targetStatusCode: OrderStatusCodes.pickedUp,
                  blocked: true,
                  blockedReason: 'Checkout Nitip belum disimpan.',
                ),
              ],
              shoppingCapabilities: const ShoppingOrderCapabilitiesModel(
                canDriverUploadReceipt: true,
              ),
            ),
            isProcessing: false,
            onSaveShoppingCheckout: () async {
              saveTapped = true;
            },
            onTapAction: (_) async {},
          ),
        ),
      ),
    );

    expect(find.text('Simpan Checkout Nitip'), findsOneWidget);
    expect(find.text('Belanja Selesai'), findsNothing);

    await tester.tap(find.text('Simpan Checkout Nitip'));
    await tester.pump();

    expect(saveTapped, isTrue);
  });

  testWidgets('shopping sticky bar shows finish after checkout saved', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: DriverOrderStickyActionBar(
            order: _order(
              serviceTypeCode: ServiceTypeCodes.shopping,
              statusCode: OrderStatusCodes.arrivedMerchant,
              availableActions: const [
                DriverOrderActionModel(
                  actionCode: 'CONFIRM_PICKED_UP',
                  label: 'Belanja Selesai',
                  targetStatusCode: OrderStatusCodes.pickedUp,
                ),
              ],
              shoppingCapabilities: const ShoppingOrderCapabilitiesModel(
                canDriverUploadReceipt: true,
                hasCheckoutSaved: true,
              ),
            ),
            isProcessing: false,
            onSaveShoppingCheckout: () async {},
            onTapAction: (_) async {},
          ),
        ),
      ),
    );

    expect(find.text('Simpan Checkout Nitip'), findsNothing);
    expect(find.text('Belanja Selesai'), findsOneWidget);
  });

  testWidgets('compact shopping footer keeps fee edit beside checkout action', (
    tester,
  ) async {
    var editTapped = false;
    var saveTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: DriverOrderStickyActionBar(
            order: _order(
              serviceTypeCode: ServiceTypeCodes.shopping,
              statusCode: OrderStatusCodes.arrivedMerchant,
              deliveryFee: 13000,
              deliveryFeeNegotiation: const DeliveryFeeNegotiationModel(
                pricingScope:
                    DeliveryFeeNegotiationModel.shoppingTotalTransportScope,
                previousTotalTransport: 13000,
                amount: AmountNegotiationModel(
                  status: 'APPROVED',
                  canDriverSubmitQuote: true,
                  isApproved: true,
                ),
              ),
              availableActions: const [
                DriverOrderActionModel(
                  actionCode: 'CONFIRM_PICKED_UP',
                  label: 'Belanja Selesai',
                  targetStatusCode: OrderStatusCodes.pickedUp,
                  blocked: true,
                  blockedReason: 'Checkout Nitip belum disimpan.',
                ),
              ],
            ),
            isProcessing: false,
            compactForSheet: true,
            onEditDeliveryFee: () async {
              editTapped = true;
            },
            onSaveShoppingCheckout: () async {
              saveTapped = true;
            },
            onTapAction: (_) async {},
          ),
        ),
      ),
    );

    expect(find.text('Ongkir perlu disesuaikan?'), findsNothing);
    expect(find.text('Simpan Checkout Nitip'), findsNothing);
    expect(find.text('Ubah Ongkir'), findsOneWidget);
    expect(find.text('Simpan checkout'), findsOneWidget);

    final editCenter = tester.getCenter(find.text('Ubah Ongkir'));
    final saveCenter = tester.getCenter(find.text('Simpan checkout'));
    expect((editCenter.dy - saveCenter.dy).abs(), lessThan(2));
    expect(editCenter.dx, lessThan(saveCenter.dx));

    await tester.tap(find.text('Ubah Ongkir'));
    await tester.pump();
    await tester.tap(find.text('Simpan checkout'));
    await tester.pump();

    expect(editTapped, isTrue);
    expect(saveTapped, isTrue);
  });

  testWidgets(
    'pending shopping delivery fee replaces checkout with bypass resolution',
    (tester) async {
      var bypassTapped = false;
      var saveTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: DriverOrderStickyActionBar(
              order: _order(
                serviceTypeCode: ServiceTypeCodes.shopping,
                statusCode: OrderStatusCodes.arrivedMerchant,
                deliveryFee: 13000,
                deliveryFeeNegotiation: const DeliveryFeeNegotiationModel(
                  oldDeliveryFee: 13000,
                  pricingScope:
                      DeliveryFeeNegotiationModel.shoppingTotalTransportScope,
                  previousTotalTransport: 13000,
                  amount: AmountNegotiationModel(
                    status: 'PENDING_CUSTOMER',
                    quotedAmount: 18000,
                    canCustomerRespond: true,
                    approvalRequired: true,
                    isPending: true,
                  ),
                ),
                availableActions: const [
                  DriverOrderActionModel(
                    actionCode: 'CONFIRM_PICKED_UP',
                    label: 'Belanja Selesai',
                    targetStatusCode: OrderStatusCodes.pickedUp,
                    blocked: true,
                    blockedReason: 'Checkout Nitip belum disimpan.',
                  ),
                ],
              ),
              isProcessing: false,
              compactForSheet: true,
              onSaveShoppingCheckout: () async {
                saveTapped = true;
              },
              onBypassDeliveryFee: () async {
                bypassTapped = true;
              },
              onTapAction: (_) async {},
            ),
          ),
        ),
      );

      expect(find.text('Ongkir menunggu persetujuan'), findsOneWidget);
      expect(find.text('Lanjut Tanpa Persetujuan'), findsOneWidget);
      expect(find.text('Simpan checkout'), findsNothing);
      expect(find.text('Simpan Checkout Nitip'), findsNothing);

      await tester.tap(find.text('Lanjut Tanpa Persetujuan'));
      await tester.pump();

      expect(bypassTapped, isTrue);
      expect(saveTapped, isFalse);
    },
  );

  testWidgets(
    'pending Nitip footer disables bypass while request is processing',
    (tester) async {
      var bypassCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: DriverOrderStickyActionBar(
              order: _order(
                serviceTypeCode: ServiceTypeCodes.shopping,
                statusCode: OrderStatusCodes.arrivedMerchant,
                deliveryFee: 13000,
                deliveryFeeNegotiation: const DeliveryFeeNegotiationModel(
                  pricingScope:
                      DeliveryFeeNegotiationModel.shoppingTotalTransportScope,
                  previousTotalTransport: 13000,
                  amount: AmountNegotiationModel(
                    status: 'PENDING_CUSTOMER',
                    quotedAmount: 18000,
                    canCustomerRespond: true,
                    approvalRequired: true,
                    isPending: true,
                  ),
                ),
                availableActions: const [
                  DriverOrderActionModel(
                    actionCode: 'CONFIRM_PICKED_UP',
                    label: 'Belanja Selesai',
                    targetStatusCode: OrderStatusCodes.pickedUp,
                    blocked: true,
                    blockedReason: 'Checkout Nitip belum disimpan.',
                  ),
                ],
              ),
              isProcessing: false,
              isBypassingDeliveryFee: true,
              compactForSheet: true,
              onSaveShoppingCheckout: () async {},
              onBypassDeliveryFee: () async {
                bypassCount += 1;
              },
              onTapAction: (_) async {},
            ),
          ),
        ),
      );

      expect(find.text('Lanjut Tanpa Persetujuan'), findsOneWidget);
      expect(find.text('Simpan checkout'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.text('Lanjut Tanpa Persetujuan'));
      await tester.pump();

      expect(bypassCount, 0);
    },
  );

  testWidgets(
    'shopping customer counter replaces checkout with accept action',
    (tester) async {
      var counterAccepted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: DriverOrderStickyActionBar(
              order: _order(
                serviceTypeCode: ServiceTypeCodes.shopping,
                statusCode: OrderStatusCodes.arrivedMerchant,
                deliveryFee: 13000,
                deliveryFeeNegotiation: const DeliveryFeeNegotiationModel(
                  amount: AmountNegotiationModel(
                    status: 'PENDING_DRIVER',
                    counterAmount: 15000,
                    canDriverAcceptCounter: true,
                    approvalRequired: true,
                    isPending: true,
                  ),
                ),
                availableActions: const [
                  DriverOrderActionModel(
                    actionCode: 'CONFIRM_PICKED_UP',
                    label: 'Belanja Selesai',
                    targetStatusCode: OrderStatusCodes.pickedUp,
                    blocked: true,
                    blockedReason: 'Checkout Nitip belum disimpan.',
                  ),
                ],
              ),
              isProcessing: false,
              compactForSheet: true,
              onSaveShoppingCheckout: () async {},
              onAcceptDeliveryFeeCounter: () async {
                counterAccepted = true;
              },
              onTapAction: (_) async {},
            ),
          ),
        ),
      );

      expect(find.text('Terima Tawaran Customer'), findsOneWidget);
      expect(find.text('Simpan checkout'), findsNothing);

      await tester.tap(find.text('Terima Tawaran Customer'));
      await tester.pump();

      expect(counterAccepted, isTrue);
    },
  );

  testWidgets(
    'delivery fee bypass confirmation explains amount and requires swipe',
    (tester) async {
      bool? confirmed;
      final order = _order(
        serviceTypeCode: ServiceTypeCodes.shopping,
        statusCode: OrderStatusCodes.arrivedMerchant,
        deliveryFee: 13000,
        deliveryFeeNegotiation: const DeliveryFeeNegotiationModel(
          oldDeliveryFee: 13000,
          pricingScope: DeliveryFeeNegotiationModel.shoppingTotalTransportScope,
          previousTotalTransport: 13000,
          amount: AmountNegotiationModel(
            status: 'PENDING_CUSTOMER',
            quotedAmount: 18000,
            canCustomerRespond: true,
            approvalRequired: true,
            isPending: true,
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  confirmed = await showDriverDeliveryFeeBypassConfirmation(
                    context,
                    order: order,
                  );
                },
                child: const Text('Buka konfirmasi'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Buka konfirmasi'));
      await tester.pumpAndSettle();

      expect(find.text('Lanjut tanpa persetujuan?'), findsOneWidget);
      expect(find.text('Total transport sebelumnya'), findsOneWidget);
      expect(find.text('Rp13.000'), findsOneWidget);
      expect(find.text('Total usulan driver'), findsOneWidget);
      expect(find.text('Rp18.000'), findsOneWidget);
      expect(confirmed, isNull);

      await tester.drag(
        find.byType(BangSwipeActionButton),
        const Offset(500, 0),
      );
      await tester.pumpAndSettle();

      expect(confirmed, isTrue);
    },
  );

  testWidgets(
    'transfer payment blocker opens manual QRIS resolution instead of disabled finish',
    (tester) async {
      var resolveTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: DriverOrderStickyActionBar(
              order: _order(
                paymentMethod: 'TRANSFER',
                paymentStatus: 'unpaid',
                availableActions: const [
                  DriverOrderActionModel(
                    actionCode: 'COMPLETE_ORDER',
                    label: 'Selesaikan Order',
                    targetStatusCode: OrderStatusCodes.completed,
                    blocked: true,
                    blockedReason: 'Pembayaran belum dicatat.',
                  ),
                ],
              ),
              isProcessing: false,
              onResolveTransferPayment: () async {
                resolveTapped = true;
              },
              onTapAction: (_) async {},
            ),
          ),
        ),
      );

      expect(find.text('Pembayaran QRIS belum selesai'), findsOneWidget);
      expect(find.text('Catat Pembayaran QRIS Manual'), findsOneWidget);
      expect(find.text('Selesaikan Order'), findsNothing);

      await tester.tap(find.text('Catat Pembayaran QRIS Manual'));
      await tester.pump();

      expect(resolveTapped, isTrue);
    },
  );

  testWidgets(
    'transfer payment blocker shows verify QRIS CTA when proof exists',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: DriverOrderStickyActionBar(
              order: _order(
                paymentMethod: 'TRANSFER',
                paymentStatus: 'unpaid',
                proofs: [
                  DriverOrderProofModel(
                    id: 7,
                    type: 'payment_transfer',
                    label: 'Bukti QRIS',
                    photoUrl: 'https://example.com/qris.jpg',
                    status: 'pending',
                    createdAt: DateTime.utc(2026, 7, 13),
                  ),
                ],
                availableActions: const [
                  DriverOrderActionModel(
                    actionCode: 'COMPLETE_ORDER',
                    label: 'Selesaikan Order',
                    targetStatusCode: OrderStatusCodes.completed,
                    blocked: true,
                    blockedReason: 'Pembayaran belum dicatat.',
                  ),
                ],
              ),
              isProcessing: false,
              onResolveTransferPayment: () async {},
              onTapAction: (_) async {},
            ),
          ),
        ),
      );

      expect(find.text('Bukti QRIS menunggu verifikasi'), findsOneWidget);
      expect(find.text('Verifikasi QRIS'), findsOneWidget);
      expect(find.text('Selesaikan Order'), findsNothing);
    },
  );

  testWidgets(
    'transfer payment blocker shows rejected QRIS status without new proof',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: DriverOrderStickyActionBar(
              order: _order(
                paymentMethod: 'TRANSFER',
                paymentStatus: 'unpaid',
                paymentProofFeedback: const PaymentProofFeedbackModel(
                  status: 'rejected',
                  reason: 'Foto terlalu blur.',
                ),
                availableActions: const [
                  DriverOrderActionModel(
                    actionCode: 'COMPLETE_ORDER',
                    label: 'Selesaikan Order',
                    targetStatusCode: OrderStatusCodes.completed,
                    blocked: true,
                    blockedReason: 'Pembayaran belum dicatat.',
                  ),
                ],
              ),
              isProcessing: false,
              onResolveTransferPayment: () async {},
              onTapAction: (_) async {},
            ),
          ),
        ),
      );

      expect(find.text('Bukti QRIS ditolak'), findsOneWidget);
      expect(find.text('Lihat Status QRIS'), findsOneWidget);
      expect(find.text('Selesaikan Order'), findsNothing);
    },
  );

  testWidgets(
    'courier pickup proof blocker shows camera CTA instead of disabled pickup action',
    (tester) async {
      String? resolvedProofType;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: DriverOrderStickyActionBar(
              order: _order(
                serviceTypeCode: ServiceTypeCodes.courier,
                statusCode: OrderStatusCodes.arrivedPickup,
                paymentStatus: 'paid',
                availableActions: const [
                  DriverOrderActionModel(
                    actionCode: 'CONFIRM_PICKED_UP',
                    label: 'Paket Diambil',
                    targetStatusCode: OrderStatusCodes.pickedUp,
                    blocked: true,
                    blockedReason: 'Bukti foto pickup belum diupload.',
                  ),
                ],
              ),
              isProcessing: false,
              onResolveProof: (proofType) async {
                resolvedProofType = proofType;
              },
              onTapAction: (_) async {},
            ),
          ),
        ),
      );

      expect(find.text('Bukti pengambilan belum ada'), findsOneWidget);
      expect(find.text('Ambil Foto Pengambilan'), findsOneWidget);
      expect(find.text('Paket Diambil'), findsNothing);

      await tester.tap(find.text('Ambil Foto Pengambilan'));
      await tester.pump();

      expect(resolvedProofType, 'pickup');
    },
  );

  testWidgets(
    'compact courier footer prioritizes pickup proof before QRIS blocker',
    (tester) async {
      String? resolvedProofType;
      var qrisTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: DriverOrderStickyActionBar(
              order: _order(
                serviceTypeCode: ServiceTypeCodes.courier,
                statusCode: OrderStatusCodes.arrivedPickup,
                paymentMethod: 'TRANSFER',
                paymentStatus: 'unpaid',
                availableActions: const [
                  DriverOrderActionModel(
                    actionCode: 'CONFIRM_PICKED_UP',
                    label: 'Paket Diambil',
                    targetStatusCode: OrderStatusCodes.pickedUp,
                    blocked: true,
                    blockedReason:
                        'Pembayaran belum dicatat. Bukti foto pickup belum diupload.',
                  ),
                ],
              ),
              isProcessing: false,
              compactForSheet: true,
              onResolveTransferPayment: () async {
                qrisTapped = true;
              },
              onResolveProof: (proofType) async {
                resolvedProofType = proofType;
              },
              onTapAction: (_) async {},
            ),
          ),
        ),
      );

      expect(find.text('Bukti pengambilan belum ada'), findsOneWidget);
      expect(find.text('Ambil Foto Pengambilan'), findsOneWidget);
      expect(find.text('Pembayaran QRIS belum selesai'), findsNothing);
      expect(find.text('Catat Pembayaran QRIS Manual'), findsNothing);
      expect(find.text('Paket Diambil'), findsNothing);

      await tester.tap(find.text('Ambil Foto Pengambilan'));
      await tester.pump();

      expect(resolvedProofType, 'pickup');
      expect(qrisTapped, isFalse);
    },
  );

  testWidgets(
    'compact courier footer shows COD collection after pickup proof',
    (tester) async {
      DriverOrderActionModel? tappedAction;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: DriverOrderStickyActionBar(
              order: _order(
                serviceTypeCode: ServiceTypeCodes.courier,
                statusCode: OrderStatusCodes.arrivedPickup,
                paymentMethod: 'COD',
                paymentStatus: 'unpaid',
                proofs: [
                  DriverOrderProofModel(
                    id: 12,
                    type: 'pickup',
                    label: 'Bukti pengambilan',
                    photoUrl: 'https://example.com/pickup.jpg',
                    status: 'approved',
                    createdAt: DateTime.utc(2026),
                  ),
                ],
                availableActions: const [
                  DriverOrderActionModel(
                    actionCode: 'CONFIRM_PICKED_UP',
                    label: 'Paket Diambil',
                    targetStatusCode: OrderStatusCodes.pickedUp,
                    blocked: true,
                    blockedReason: 'Pembayaran belum dicatat.',
                  ),
                  DriverOrderActionModel(
                    actionCode: 'COLLECT_COD',
                    label: 'Catat Pembayaran COD',
                  ),
                ],
              ),
              isProcessing: false,
              compactForSheet: true,
              singlePrimaryAction: true,
              onTapAction: (action) async {
                tappedAction = action;
              },
            ),
          ),
        ),
      );

      expect(find.text('Catat Pembayaran COD'), findsOneWidget);
      expect(find.text('Paket Diambil'), findsNothing);

      await tester.tap(find.text('Catat Pembayaran COD'));
      await tester.pump();

      expect(tappedAction?.actionCode, 'COLLECT_COD');
    },
  );

  testWidgets(
    'courier delivery proof blocker shows camera CTA before finish action',
    (tester) async {
      String? resolvedProofType;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: DriverOrderStickyActionBar(
              order: _order(
                serviceTypeCode: ServiceTypeCodes.courier,
                statusCode: OrderStatusCodes.delivered,
                paymentStatus: 'paid',
                availableActions: const [
                  DriverOrderActionModel(
                    actionCode: 'COMPLETE_ORDER',
                    label: 'Selesaikan Order',
                    targetStatusCode: OrderStatusCodes.completed,
                    blocked: true,
                    blockedReason:
                        'Bukti foto selesai pengantaran belum diupload.',
                  ),
                ],
              ),
              isProcessing: false,
              onResolveProof: (proofType) async {
                resolvedProofType = proofType;
              },
              onTapAction: (_) async {},
            ),
          ),
        ),
      );

      expect(find.text('Bukti diterima belum ada'), findsOneWidget);
      expect(find.text('Ambil Foto Diterima'), findsOneWidget);
      expect(find.text('Selesaikan Order'), findsNothing);

      await tester.tap(find.text('Ambil Foto Diterima'));
      await tester.pump();

      expect(resolvedProofType, 'delivery');
    },
  );

  testWidgets(
    'delivery fee edit shortcut is visible from active sticky footer',
    (tester) async {
      var editTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: DriverOrderStickyActionBar(
              order: _order(
                serviceTypeCode: ServiceTypeCodes.courier,
                statusCode: OrderStatusCodes.driverAssigned,
                deliveryFee: 13000,
                deliveryFeeNegotiation: const DeliveryFeeNegotiationModel(
                  amount: AmountNegotiationModel(
                    status: 'APPROVED',
                    canDriverSubmitQuote: true,
                    isApproved: true,
                  ),
                ),
                availableActions: const [
                  DriverOrderActionModel(
                    actionCode: 'ARRIVE_PICKUP',
                    label: 'Tiba di Titik Pickup',
                    targetStatusCode: OrderStatusCodes.arrivedPickup,
                  ),
                ],
              ),
              isProcessing: false,
              compactForSheet: true,
              onEditDeliveryFee: () async {
                editTapped = true;
              },
              onTapAction: (_) async {},
            ),
          ),
        ),
      );

      expect(find.text('Ongkir perlu disesuaikan?'), findsNothing);
      expect(find.text('Ubah Ongkir'), findsOneWidget);
      expect(find.text('Tiba di Titik Pickup'), findsOneWidget);
      final editCenter = tester.getCenter(find.text('Ubah Ongkir'));
      final primaryCenter = tester.getCenter(find.text('Tiba di Titik Pickup'));
      expect((editCenter.dy - primaryCenter.dy).abs(), lessThan(2));
      expect(editCenter.dx, lessThan(primaryCenter.dx));

      await tester.tap(find.text('Ubah Ongkir'));
      await tester.pump();

      expect(editTapped, isTrue);
    },
  );

  testWidgets(
    'ride footer keeps its existing fee shortcut and primary action',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: DriverOrderStickyActionBar(
              order: _order(
                serviceTypeCode: ServiceTypeCodes.ride,
                statusCode: OrderStatusCodes.driverAssigned,
                deliveryFee: 13000,
                deliveryFeeNegotiation: const DeliveryFeeNegotiationModel(
                  amount: AmountNegotiationModel(
                    status: 'APPROVED',
                    canDriverSubmitQuote: true,
                    isApproved: true,
                  ),
                ),
                availableActions: const [
                  DriverOrderActionModel(
                    actionCode: 'ARRIVE_PICKUP',
                    label: 'Tiba di Titik Jemput',
                    targetStatusCode: OrderStatusCodes.arrivedPickup,
                  ),
                ],
              ),
              isProcessing: false,
              compactForSheet: true,
              onEditDeliveryFee: () async {},
              onTapAction: (_) async {},
            ),
          ),
        ),
      );

      expect(find.text('Ubah Ongkir'), findsOneWidget);
      expect(find.text('Tiba di Titik Jemput'), findsOneWidget);
      expect(find.text('Simpan checkout'), findsNothing);

      final editCenter = tester.getCenter(find.text('Ubah Ongkir'));
      final primaryCenter = tester.getCenter(find.text('Tiba di Titik Jemput'));
      expect((editCenter.dy - primaryCenter.dy).abs(), lessThan(2));
      expect(editCenter.dx, lessThan(primaryCenter.dx));
    },
  );

  testWidgets(
    'pending delivery fee blocker shows bypass CTA instead of disabled action',
    (tester) async {
      var bypassTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: DriverOrderStickyActionBar(
              order: _order(
                serviceTypeCode: ServiceTypeCodes.courier,
                statusCode: OrderStatusCodes.arrivedPickup,
                paymentStatus: 'paid',
                deliveryFee: 13000,
                deliveryFeeNegotiation: const DeliveryFeeNegotiationModel(
                  amount: AmountNegotiationModel(
                    status: 'PENDING_CUSTOMER',
                    quotedAmount: 18000,
                    canCustomerRespond: true,
                    approvalRequired: true,
                    isPending: true,
                  ),
                ),
                availableActions: const [
                  DriverOrderActionModel(
                    actionCode: 'CONFIRM_PICKED_UP',
                    label: 'Paket Diambil',
                    targetStatusCode: OrderStatusCodes.pickedUp,
                    blocked: true,
                    blockedReason: 'Revisi ongkir belum disetujui customer.',
                  ),
                ],
              ),
              isProcessing: false,
              onBypassDeliveryFee: () async {
                bypassTapped = true;
              },
              onTapAction: (_) async {},
            ),
          ),
        ),
      );

      expect(find.text('Ongkir menunggu persetujuan'), findsOneWidget);
      expect(find.text('Lanjut Tanpa Persetujuan'), findsOneWidget);
      expect(find.text('Paket Diambil'), findsNothing);

      await tester.tap(find.text('Lanjut Tanpa Persetujuan'));
      await tester.pump();

      expect(bypassTapped, isTrue);
    },
  );

  testWidgets('shopping closure fee hint only appears for three stops', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: DriverOrderStickyActionBar(
            order: _order(
              serviceTypeCode: ServiceTypeCodes.shopping,
              shoppingStops: [_shoppingStop(1), _shoppingStop(2)],
              shoppingPricing: _shoppingPricing(),
            ),
            isProcessing: false,
            onTapAction: (_) async {},
          ),
        ),
      ),
    );

    expect(find.textContaining('Tempat tutup/order batal'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: DriverOrderStickyActionBar(
            order: _order(
              serviceTypeCode: ServiceTypeCodes.shopping,
              shoppingStops: [
                _shoppingStop(1),
                _shoppingStop(2),
                _shoppingStop(3),
              ],
              shoppingPricing: _shoppingPricing(),
            ),
            isProcessing: false,
            onTapAction: (_) async {},
          ),
        ),
      ),
    );

    expect(find.textContaining('Tempat tutup/order batal 0/3'), findsOneWidget);
  });

  test('shopping sticky visibility follows actual visible content', () {
    final singleStopOrder = _order(
      serviceTypeCode: ServiceTypeCodes.shopping,
      shoppingStops: [_shoppingStop(1)],
      shoppingPricing: _shoppingPricing(),
      shoppingNegotiation: _shoppingCheckoutBlocked(),
    );
    final threeStopOrder = _order(
      serviceTypeCode: ServiceTypeCodes.shopping,
      shoppingStops: [_shoppingStop(1), _shoppingStop(2), _shoppingStop(3)],
      shoppingPricing: _shoppingPricing(),
      shoppingNegotiation: _shoppingCheckoutBlocked(),
    );

    expect(hasDriverOrderStickyActionBarContent(singleStopOrder), isFalse);
    expect(hasDriverOrderStickyActionBarContent(threeStopOrder), isTrue);
  });

  testWidgets('shopping merchant closed spinner is scoped to selected stop', (
    tester,
  ) async {
    const firstStop = DriverShoppingStopModel(
      pickupLocationId: 7,
      sequenceNo: 1,
      fulfillmentStatus: 'PENDING',
      merchant: DriverShoppingMerchantModel(
        id: 1,
        name: 'Kedai Tinari',
        merchantType: 'restaurant',
        address: 'Jl. Merchant 1',
      ),
      items: <DriverShoppingItemModel>[],
    );
    const secondStop = DriverShoppingStopModel(
      pickupLocationId: 8,
      sequenceNo: 2,
      fulfillmentStatus: 'PENDING',
      merchant: DriverShoppingMerchantModel(
        id: 2,
        name: 'Burjo SS',
        merchantType: 'restaurant',
        address: 'Jl. Merchant 2',
      ),
      items: <DriverShoppingItemModel>[],
    );

    await _pumpShoppingItemsCard(
      tester,
      order: _order(
        serviceTypeCode: ServiceTypeCodes.shopping,
        shoppingStops: const [firstStop, secondStop],
      ),
      isOrderBusy: true,
      closingMerchantIds: const {8},
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Tempat tutup'), findsOneWidget);
  });

  testWidgets('shopping merchant action buttons fit narrow card width', (
    tester,
  ) async {
    const stop = DriverShoppingStopModel(
      pickupLocationId: 7,
      sequenceNo: 1,
      fulfillmentStatus: 'PENDING',
      merchant: DriverShoppingMerchantModel(
        id: 1,
        name: 'Kedai Tinari',
        merchantType: 'restaurant',
        address: 'Jl. Merchant',
      ),
      items: <DriverShoppingItemModel>[],
    );

    await _pumpShoppingItemsCard(
      tester,
      order: _order(
        serviceTypeCode: ServiceTypeCodes.shopping,
        shoppingStops: const [stop],
      ),
      cardWidth: 328,
    );

    expect(find.text('Tempat tutup'), findsOneWidget);
    expect(find.text('Tempat buka'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending delivery fee revision keeps merchant actions enabled', (
    tester,
  ) async {
    const stop = DriverShoppingStopModel(
      pickupLocationId: 7,
      sequenceNo: 1,
      fulfillmentStatus: 'PENDING',
      merchant: DriverShoppingMerchantModel(
        id: 1,
        name: 'Kedai Tinari',
        merchantType: 'restaurant',
        address: 'Jl. Merchant',
      ),
      items: <DriverShoppingItemModel>[],
    );

    await _pumpShoppingItemsCard(
      tester,
      order: _order(
        serviceTypeCode: ServiceTypeCodes.shopping,
        shoppingStops: const [stop],
      ),
      isDeliveryFeeRevisionPending: true,
    );

    expect(find.text('Revisi ongkir belum disetujui customer.'), findsNothing);

    final closeButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Tempat tutup'),
    );
    final openButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Tempat buka'),
    );

    expect(closeButton.onPressed, isNotNull);
    expect(openButton.onPressed, isNotNull);
  });

  testWidgets(
    'shopping merchant quote card is hidden while item decision is pending',
    (tester) async {
      const unavailableItem = DriverShoppingItemModel(
        id: 10,
        pickupLocationId: 7,
        itemSource: 'MANUAL',
        name: 'es jeruk',
        quantity: 1,
        unitPrice: 0,
        subtotal: 0,
        isAvailable: false,
      );

      await _pumpShoppingItemsCard(
        tester,
        order: _order(
          serviceTypeCode: ServiceTypeCodes.shopping,
          shoppingItems: const [unavailableItem],
          shoppingStops: const [
            DriverShoppingStopModel(
              pickupLocationId: 7,
              sequenceNo: 1,
              fulfillmentStatus: 'ITEMS_PENDING_CUSTOMER',
              availabilityConfirmed: true,
              merchant: DriverShoppingMerchantModel(
                id: 1,
                name: 'Kedai Tinari',
                merchantType: 'restaurant',
                address: 'Jl. Merchant',
              ),
              items: [unavailableItem],
            ),
          ],
          shoppingCapabilities: const ShoppingOrderCapabilitiesModel(
            canDriverUpdateItemAvailability: true,
            hasPendingItemChangeRequest: true,
          ),
          shoppingNegotiation: _merchantRequote(pickupLocationId: 7),
        ),
        canEditAvailability: true,
      );

      expect(find.text('Menunggu keputusan item'), findsOneWidget);
      expect(find.text('Harga Nitip'), findsNothing);
      expect(find.text('Perubahan item perlu harga baru.'), findsNothing);
    },
  );

  testWidgets(
    'shopping merchant quote card is shown after all items are available',
    (tester) async {
      const availableItem = DriverShoppingItemModel(
        id: 10,
        pickupLocationId: 7,
        itemSource: 'MANUAL',
        name: 'es jeruk',
        quantity: 1,
        unitPrice: 0,
        subtotal: 0,
        isAvailable: true,
      );

      await _pumpShoppingItemsCard(
        tester,
        order: _order(
          serviceTypeCode: ServiceTypeCodes.shopping,
          shoppingItems: const [availableItem],
          shoppingStops: const [
            DriverShoppingStopModel(
              pickupLocationId: 7,
              sequenceNo: 1,
              fulfillmentStatus: 'ITEMS_CONFIRMED',
              availabilityConfirmed: true,
              merchant: DriverShoppingMerchantModel(
                id: 1,
                name: 'Kedai Tinari',
                merchantType: 'restaurant',
                address: 'Jl. Merchant',
              ),
              items: [availableItem],
            ),
          ],
          shoppingNegotiation: _merchantRequote(pickupLocationId: 7),
        ),
      );

      expect(find.text('Harga Nitip'), findsOneWidget);
      expect(find.text('Perubahan item perlu harga baru.'), findsOneWidget);
    },
  );

  testWidgets('approved shopping merchant locks item availability controls', (
    tester,
  ) async {
    const approvedItem = DriverShoppingItemModel(
      id: 10,
      pickupLocationId: 7,
      itemSource: 'MANUAL',
      name: 'ramen mala',
      quantity: 1,
      unitPrice: 0,
      subtotal: 0,
      isAvailable: true,
    );

    await _pumpShoppingItemsCard(
      tester,
      order: _order(
        serviceTypeCode: ServiceTypeCodes.shopping,
        shoppingItems: const [approvedItem],
        shoppingStops: const [
          DriverShoppingStopModel(
            pickupLocationId: 7,
            sequenceNo: 1,
            fulfillmentStatus: 'PRICE_APPROVED',
            availabilityConfirmed: true,
            merchant: DriverShoppingMerchantModel(
              id: 1,
              name: 'Kedai Tinari',
              merchantType: 'restaurant',
              address: 'Jl. Merchant',
            ),
            items: [approvedItem],
          ),
        ],
        shoppingNegotiation: _merchantApprovedQuote(pickupLocationId: 7),
      ),
      canEditAvailability: true,
    );

    final checkboxFinder = find.byType(Checkbox);
    expect(checkboxFinder, findsOneWidget);

    final itemCheckbox = tester.widget<Checkbox>(checkboxFinder);
    expect(itemCheckbox.value, isTrue);
    expect(itemCheckbox.onChanged, isNull);
    expect(find.text('Simpan Ketersediaan Item'), findsNothing);
  });

  testWidgets('driver can trigger backend-gated unavailable item bypass', (
    tester,
  ) async {
    const availableItem = DriverShoppingItemModel(
      id: 10,
      pickupLocationId: 7,
      itemSource: 'MANUAL',
      name: 'Ramen mala',
      quantity: 1,
      unitPrice: 20000,
      subtotal: 20000,
      isAvailable: true,
    );
    const unavailableItem = DriverShoppingItemModel(
      id: 11,
      pickupLocationId: 7,
      itemSource: 'MANUAL',
      name: 'Es jeruk',
      quantity: 1,
      unitPrice: 0,
      subtotal: 0,
      isAvailable: false,
    );
    var bypassedPickupId = 0;

    await _pumpShoppingItemsCard(
      tester,
      order: _order(
        serviceTypeCode: ServiceTypeCodes.shopping,
        shoppingItems: const [availableItem, unavailableItem],
        shoppingStops: const [
          DriverShoppingStopModel(
            pickupLocationId: 7,
            sequenceNo: 1,
            fulfillmentStatus: 'ITEMS_PENDING_CUSTOMER',
            availabilityConfirmed: true,
            canDriverBypassUnavailableItems: true,
            canDriverContinueWithoutUnavailableItem: true,
            merchant: DriverShoppingMerchantModel(
              id: 1,
              name: 'Kedai Tinari',
              merchantType: 'restaurant',
              address: 'Jl. Merchant',
            ),
            items: [availableItem, unavailableItem],
          ),
        ],
      ),
      onBypassUnavailableItems: (pickupLocationId) async {
        bypassedPickupId = pickupLocationId;
        return null;
      },
    );

    expect(find.text('Geser untuk bypass semua item'), findsOneWidget);
    expect(find.text('Lanjut tanpa ini'), findsNothing);
    expect(
      find.byKey(const ValueKey('driver-shopping-action-continue-7')),
      findsNothing,
    );
    expect(find.textContaining('Es jeruk akan dihapus'), findsOneWidget);
    final swipe = tester.widget<BangSwipeActionButton>(
      find.byType(BangSwipeActionButton),
    );
    await swipe.onSubmit?.call();
    expect(bypassedPickupId, 7);
  });

  testWidgets('all unavailable items keep bypass cancellation flow', (
    tester,
  ) async {
    const unavailableItem = DriverShoppingItemModel(
      id: 11,
      pickupLocationId: 7,
      itemSource: 'MANUAL',
      name: 'Es jeruk',
      quantity: 1,
      unitPrice: 0,
      subtotal: 0,
      isAvailable: false,
    );

    await _pumpShoppingItemsCard(
      tester,
      order: _order(
        serviceTypeCode: ServiceTypeCodes.shopping,
        shoppingItems: const [unavailableItem],
        shoppingStops: const [
          DriverShoppingStopModel(
            pickupLocationId: 7,
            sequenceNo: 1,
            fulfillmentStatus: 'ITEMS_PENDING_CUSTOMER',
            availabilityConfirmed: true,
            canDriverBypassUnavailableItems: true,
            merchant: DriverShoppingMerchantModel(
              id: 1,
              name: 'Kedai Tinari',
              merchantType: 'restaurant',
              address: 'Jl. Merchant',
            ),
            items: [unavailableItem],
          ),
        ],
      ),
    );

    expect(find.text('Geser untuk bypass semua item'), findsOneWidget);
    expect(find.text('Lanjut tanpa ini'), findsNothing);
    expect(
      find.textContaining('Bypass akan membatalkan tempat'),
      findsOneWidget,
    );
  });

  testWidgets('driver can open replace unavailable items wizard action', (
    tester,
  ) async {
    const unavailableItem = DriverShoppingItemModel(
      id: 11,
      pickupLocationId: 7,
      itemSource: 'MANUAL',
      name: 'Es jeruk',
      quantity: 1,
      unitPrice: 0,
      subtotal: 0,
      isAvailable: false,
    );
    var replacedPickupId = 0;
    await _pumpShoppingItemsCard(
      tester,
      order: _order(
        serviceTypeCode: ServiceTypeCodes.shopping,
        shoppingItems: const [unavailableItem],
        shoppingStops: const [
          DriverShoppingStopModel(
            pickupLocationId: 7,
            sequenceNo: 1,
            fulfillmentStatus: 'ITEMS_PENDING_CUSTOMER',
            availabilityConfirmed: true,
            canDriverReplaceUnavailableItems: true,
            merchant: DriverShoppingMerchantModel(
              id: 1,
              name: 'Kedai Tinari',
              merchantType: 'restaurant',
              address: 'Jl. Merchant',
            ),
            items: [unavailableItem],
          ),
        ],
      ),
      onReplaceUnavailableItems: (pickupLocationId) async {
        replacedPickupId = pickupLocationId;
        return null;
      },
    );

    await tester.tap(find.text('Ganti item'));
    await tester.pump();
    expect(replacedPickupId, 7);
  });

  testWidgets(
    'driver decision grid matches customer and keeps bypass separate',
    (tester) async {
      const availableItem = DriverShoppingItemModel(
        id: 10,
        pickupLocationId: 7,
        itemSource: 'MANUAL',
        name: 'Ramen mala',
        quantity: 1,
        unitPrice: 20000,
        subtotal: 20000,
        isAvailable: true,
      );
      const unavailableOne = DriverShoppingItemModel(
        id: 11,
        pickupLocationId: 7,
        itemSource: 'MANUAL',
        name: 'Es jeruk',
        quantity: 1,
        unitPrice: 0,
        subtotal: 0,
        isAvailable: false,
      );
      const unavailableTwo = DriverShoppingItemModel(
        id: 12,
        pickupLocationId: 7,
        itemSource: 'MANUAL',
        name: 'Lemon tea',
        quantity: 1,
        unitPrice: 0,
        subtotal: 0,
        isAvailable: false,
      );
      final calls = <(String, List<int>)>[];

      await _pumpShoppingItemsCard(
        tester,
        order: _order(
          serviceTypeCode: ServiceTypeCodes.shopping,
          shoppingItems: const [availableItem, unavailableOne, unavailableTwo],
          shoppingStops: const [
            DriverShoppingStopModel(
              pickupLocationId: 7,
              sequenceNo: 1,
              fulfillmentStatus: 'ITEMS_PENDING_CUSTOMER',
              availabilityConfirmed: true,
              canDriverBypassUnavailableItems: true,
              canDriverContinueWithoutUnavailableItem: true,
              canDriverCancelUnavailableMerchant: true,
              canDriverReplaceUnavailableItems: true,
              canReplaceMerchant: true,
              merchant: DriverShoppingMerchantModel(
                id: 1,
                name: 'Kedai Tinari',
                merchantType: 'restaurant',
                address: 'Jl. Merchant',
              ),
              items: [availableItem, unavailableOne, unavailableTwo],
            ),
          ],
        ),
        onDecideUnavailableItems: (pickupId, action, itemIds) async {
          expect(pickupId, 7);
          calls.add((action, itemIds));
          return null;
        },
      );

      expect(find.text('Ganti item'), findsOneWidget);
      expect(find.text('Ganti toko/resto'), findsOneWidget);
      expect(find.text('Pilih item'), findsOneWidget);
      expect(find.text('Lanjut tanpa ini'), findsNothing);
      expect(find.text('Batal tempat'), findsOneWidget);
      expect(find.text('Geser untuk bypass semua item'), findsOneWidget);

      for (final key in const [
        'driver-shopping-action-replace-items-7',
        'driver-shopping-action-replace-merchant-7',
        'driver-shopping-action-continue-7',
        'driver-shopping-action-cancel-7',
      ]) {
        final button = tester.widget<OutlinedButton>(find.byKey(ValueKey(key)));
        expect(
          button.style?.backgroundColor?.resolve(const <WidgetState>{}),
          AppColors.white,
        );
      }

      await tester.tap(
        find.byKey(const ValueKey('driver-shopping-action-continue-7')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('unavailable-item-choice-11')),
      );
      await tester.tap(
        find.byKey(const ValueKey('unavailable-item-choice-12')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('confirm-unavailable-item-selection')),
      );
      await tester.pumpAndSettle();
      expect(calls.first.$1, 'REMOVE');
      expect(calls.first.$2, [11, 12]);

      await tester.tap(
        find.byKey(const ValueKey('driver-shopping-action-cancel-7')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Batal tempat'));
      await tester.pumpAndSettle();
      expect(calls.last.$1, 'CANCEL_MERCHANT');
      expect(calls.last.$2, isEmpty);
    },
  );

  testWidgets('driver can cancel shopping order from the problem flow', (
    tester,
  ) async {
    // Tombol "Batalkan pesanan" (no-fee) kini di menu segitiga danger (screen);
    // kartu mengekspos alurnya lewat showCancelShoppingOrderFlow().
    var cancelCalls = 0;

    await _pumpShoppingItemsCard(
      tester,
      order: _order(
        serviceTypeCode: ServiceTypeCodes.shopping,
        statusCode: OrderStatusCodes.arrivedMerchant,
        shoppingCapabilities: const ShoppingOrderCapabilitiesModel(
          isExplicit: true,
          canDriverCancelShoppingOrder: true,
        ),
        shoppingStops: const [
          DriverShoppingStopModel(
            pickupLocationId: 7,
            sequenceNo: 1,
            fulfillmentStatus: 'FAILED',
            merchant: DriverShoppingMerchantModel(
              id: 1,
              name: 'Gecok JOGO ROSO TLOGO',
              merchantType: 'restaurant',
              address: 'Jl. Raya Tuntang-Beringin',
            ),
            items: [],
          ),
        ],
      ),
      onCancelShoppingOrder: () async {
        cancelCalls += 1;
        return null;
      },
    );

    // Tak ada tombol batal di kartu.
    expect(
      find.byKey(const ValueKey('driver-shopping-action-cancel-order-7')),
      findsNothing,
    );

    final dynamic cardState = tester.state(
      find.byType(DriverShoppingItemsCard),
    );
    cardState.showCancelShoppingOrderFlow();
    await tester.pumpAndSettle();

    // Konfirmasi wajib: sekali tekan tidak langsung membatalkan.
    expect(find.text('Batalkan pesanan Nitip?'), findsOneWidget);
    expect(cancelCalls, 0);
    await tester.tap(find.widgetWithText(FilledButton, 'Batalkan pesanan'));
    await tester.pumpAndSettle();
    expect(cancelCalls, 1);
  });

  testWidgets('stop card no longer renders the order-cancel button', (
    tester,
  ) async {
    // Batalkan pesanan dipindah ke menu segitiga danger: kartu tak lagi
    // menampilkannya walau backend mengizinkan batal (no-fee) pada stop tutup.
    await _pumpShoppingItemsCard(
      tester,
      order: _order(
        serviceTypeCode: ServiceTypeCodes.shopping,
        statusCode: OrderStatusCodes.arrivedMerchant,
        shoppingCapabilities: const ShoppingOrderCapabilitiesModel(
          isExplicit: true,
          canDriverCancelShoppingOrder: true,
        ),
        shoppingStops: const [
          DriverShoppingStopModel(
            pickupLocationId: 7,
            sequenceNo: 1,
            fulfillmentStatus: 'FAILED',
            merchant: DriverShoppingMerchantModel(
              id: 1,
              name: 'Gecok JOGO ROSO TLOGO',
              merchantType: 'restaurant',
              address: 'Jl. Raya Tuntang-Beringin',
            ),
            items: [],
          ),
        ],
      ),
    );

    expect(find.text('Batalkan pesanan'), findsNothing);
    expect(
      find.byKey(const ValueKey('driver-shopping-action-cancel-order-7')),
      findsNothing,
    );
  });
}

Future<void> _pumpProofChecklist(
  WidgetTester tester, {
  Set<String>? visibleProofTypes,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DriverOrderProofChecklistCard(
          order: _order(serviceTypeCode: ServiceTypeCodes.courier),
          visibleProofTypes: visibleProofTypes,
          isOrderBusy: false,
          isProofUploading: (_) => false,
          onUploadProof:
              ({
                required String type,
                required XFile photo,
                String? note,
                int? pickupLocationId,
              }) async => null,
        ),
      ),
    ),
  );
}

Future<void> _pumpShoppingItemsCard(
  WidgetTester tester, {
  required DriverOrderModel order,
  bool isOrderBusy = false,
  bool canEditAvailability = false,
  bool canUploadReceipt = false,
  bool isDeliveryFeeRevisionPending = false,
  Set<int> closingMerchantIds = const <int>{},
  Future<String?> Function(int pickupLocationId)? onBypassUnavailableItems,
  Future<String?> Function(
    int pickupLocationId,
    String action,
    List<int> itemIds,
  )?
  onDecideUnavailableItems,
  Future<String?> Function(int pickupLocationId)? onReplaceUnavailableItems,
  Future<String?> Function()? onCancelShoppingOrder,
  double? cardWidth,
}) async {
  final card = DriverShoppingItemsCard(
    order: order,
    isOrderBusy: isOrderBusy,
    isSavingItems: (_) => false,
    canEditAvailability: canEditAvailability,
    canUploadReceipt: canUploadReceipt,
    isSubmittingQuote: (_) => false,
    isBypassingPrice: (_) => false,
    isBypassingUnavailableItems: (_) => false,
    isDecidingUnavailableItems: (_, _) => false,
    isMarkingMerchantOpen: (_) => false,
    isClosingMerchant: (pickupLocationId) =>
        closingMerchantIds.contains(pickupLocationId),
    isDeliveryFeeRevisionPending: isDeliveryFeeRevisionPending,
    onUploadReceipt: (_) async => null,
    onSubmitQuote: ({required amount, pickupLocationId}) async => null,
    onBypassPrice: ({required pickupLocationId}) async => null,
    onBypassUnavailableItems: ({required pickupLocationId}) async =>
        onBypassUnavailableItems?.call(pickupLocationId),
    onDecideUnavailableItems:
        ({
          required pickupLocationId,
          required action,
          required itemIds,
        }) async =>
            onDecideUnavailableItems?.call(pickupLocationId, action, itemIds),
    onMarkMerchantOpen: ({required pickupLocationId}) async => null,
    onMarkMerchantClosed:
        ({
          required pickupLocationId,
          required reason,
          storeClosedPhoto,
        }) async => null,
    onReplaceMerchant: (_) async => null,
    onCancelShoppingOrder: () async => onCancelShoppingOrder?.call(),
    onApproveMerchantReplacement: (_) async => null,
    onRejectMerchantReplacement: (_) async => null,
    onReplaceUnavailableItems: (stop) async =>
        onReplaceUnavailableItems?.call(stop.pickupLocationId),
    onSaveItems: (_, _) async => null,
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: cardWidth == null
            ? card
            : Center(
                child: SizedBox(width: cardWidth, child: card),
              ),
      ),
    ),
  );
}

ShoppingNegotiationModel _merchantRequote({required int pickupLocationId}) {
  return ShoppingNegotiationModel(
    amount: const AmountNegotiationModel(status: 'NEEDS_REQUOTE'),
    merchantQuotes: [
      ShoppingMerchantQuoteModel(
        pickupLocationId: pickupLocationId,
        merchantName: 'Kedai Tinari',
        amount: const AmountNegotiationModel(
          status: 'NEEDS_REQUOTE',
          canDriverSubmitQuote: true,
        ),
      ),
    ],
  );
}

ShoppingNegotiationModel _merchantApprovedQuote({
  required int pickupLocationId,
}) {
  return ShoppingNegotiationModel(
    amount: const AmountNegotiationModel(status: 'APPROVED'),
    merchantQuotes: [
      ShoppingMerchantQuoteModel(
        pickupLocationId: pickupLocationId,
        merchantName: 'Kedai Tinari',
        amount: const AmountNegotiationModel(
          status: 'APPROVED',
          approvedAmount: 30000,
        ),
      ),
    ],
    checkoutAllowed: true,
  );
}

ShoppingNegotiationModel _shoppingCheckoutBlocked() {
  return const ShoppingNegotiationModel(
    amount: AmountNegotiationModel(status: 'APPROVED'),
    checkoutAllowed: false,
  );
}

DriverOrderModel _order({
  String serviceTypeCode = ServiceTypeCodes.ride,
  String statusCode = OrderStatusCodes.driverAssigned,
  String paymentMethod = 'COD',
  String paymentStatus = 'unpaid',
  List<DriverOrderActionModel> availableActions =
      const <DriverOrderActionModel>[],
  List<DriverShoppingItemModel> shoppingItems =
      const <DriverShoppingItemModel>[],
  List<DriverShoppingStopModel> shoppingStops =
      const <DriverShoppingStopModel>[],
  List<DriverOrderProofModel> proofs = const <DriverOrderProofModel>[],
  Map<String, DriverOrderProofCapability> proofCapabilities =
      const <String, DriverOrderProofCapability>{},
  PaymentProofFeedbackModel? paymentProofFeedback,
  double? deliveryFee,
  DeliveryFeeNegotiationModel? deliveryFeeNegotiation,
  DriverShoppingPricingModel? shoppingPricing,
  ShoppingOrderCapabilitiesModel shoppingCapabilities =
      const ShoppingOrderCapabilitiesModel(canDriverUploadReceipt: true),
  ShoppingNegotiationModel? shoppingNegotiation,
}) {
  return DriverOrderModel(
    id: '99',
    customerName: 'Customer',
    serviceTypeCode: serviceTypeCode,
    pickupAddress: 'Pickup',
    dropoffAddress: 'Dropoff',
    etaMinutes: 8,
    fee: 9000,
    deliveryFee: deliveryFee,
    totalPrice: 9000,
    itemCount: 1,
    statusCode: statusCode,
    paymentMethod: paymentMethod,
    paymentStatus: paymentStatus,
    availableActions: availableActions,
    shoppingItems: shoppingItems,
    shoppingStops: shoppingStops,
    proofs: proofs,
    proofCapabilities: proofCapabilities,
    paymentProofFeedback: paymentProofFeedback,
    shoppingPricing: shoppingPricing,
    deliveryFeeNegotiation: deliveryFeeNegotiation,
    shoppingCapabilities: shoppingCapabilities,
    shoppingNegotiation:
        shoppingNegotiation ??
        const ShoppingNegotiationModel(
          amount: AmountNegotiationModel(status: 'APPROVED'),
          checkoutAllowed: true,
        ),
  );
}

DriverShoppingStopModel _shoppingStop(int sequenceNo) {
  return DriverShoppingStopModel(
    pickupLocationId: sequenceNo,
    sequenceNo: sequenceNo,
    fulfillmentStatus: 'PENDING',
    merchant: DriverShoppingMerchantModel(
      id: sequenceNo,
      name: 'Merchant',
      merchantType: 'restaurant',
      address: 'Jl. Merchant',
    ),
    items: <DriverShoppingItemModel>[],
  );
}

DriverShoppingPricingModel _shoppingPricing() {
  return const DriverShoppingPricingModel(
    subtotal: 0,
    deliveryFee: 5000,
    serviceFee: 0,
    totalPrice: 5000,
    cancellationPenalty: 0,
    recalculationVersion: 0,
    hasPendingManualPrices: false,
    failedAttemptCount: 0,
    failedAttemptThreshold: 3,
  );
}
