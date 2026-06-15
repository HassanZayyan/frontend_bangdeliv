import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:frontend_bangdeliv/features/driver_orders/presentation/widgets/driver_active_order_action_widgets.dart';
import 'package:frontend_bangdeliv/features/driver_orders/presentation/widgets/driver_active_order_proof_widgets.dart';
import 'package:frontend_bangdeliv/features/driver_orders/presentation/widgets/driver_active_order_shopping_widgets.dart';
import 'package:frontend_bangdeliv/models/driver_order_model.dart';
import 'package:frontend_bangdeliv/utils/order_status.dart';
import 'package:frontend_bangdeliv/utils/service_type.dart';

void main() {
  testWidgets('driver action card only shows spinner on selected action', (
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
            isOrderBusy: true,
            isReportPickupFailedProcessing: false,
            isActionProcessing: (action) => action.actionCode == 'COMPLETE',
            onReportPickupFailed: null,
            onTapAction: (_) async {},
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Catat COD'), findsOneWidget);
    final codButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Catat COD'),
    );
    expect(codButton.onPressed, isNull);
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
    expect(find.text('Upload'), findsOneWidget);
    expect(find.text('Diterima'), findsOneWidget);
  });

  testWidgets('shopping checkout loading does not spin receipt upload button', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverShoppingItemsCard(
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
                  isHeavy: false,
                ),
              ],
            ),
            isOrderBusy: true,
            isSavingCheckout: true,
            onUploadReceipt: (_, _) async => null,
            onSave: (_, _, _, _, _) async => null,
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Upload Foto Struk'), findsOneWidget);
  });
}

DriverOrderModel _order({
  String serviceTypeCode = ServiceTypeCodes.ride,
  List<DriverOrderActionModel> availableActions =
      const <DriverOrderActionModel>[],
  List<DriverShoppingItemModel> shoppingItems =
      const <DriverShoppingItemModel>[],
}) {
  return DriverOrderModel(
    id: '99',
    customerName: 'Customer',
    serviceTypeCode: serviceTypeCode,
    pickupAddress: 'Pickup',
    dropoffAddress: 'Dropoff',
    etaMinutes: 8,
    fee: 9000,
    totalPrice: 9000,
    itemCount: 1,
    statusCode: OrderStatusCodes.driverAssigned,
    paymentMethod: 'COD',
    paymentStatus: 'unpaid',
    availableActions: availableActions,
    shoppingItems: shoppingItems,
  );
}
