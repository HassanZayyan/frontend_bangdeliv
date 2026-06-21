import '../../../services/customer_order_api_service.dart';

class ShoppingItemDraft {
  const ShoppingItemDraft({
    required this.id,
    required this.merchant,
    required this.merchantPlace,
    required this.menuId,
    required this.name,
    required this.quantity,
    required this.notes,
    required this.unitPrice,
    required this.isFromMenu,
  });

  final String id;
  final ShoppingMerchantOption merchant;
  final ShoppingMerchantPlacePayload? merchantPlace;
  final int? menuId;
  final String name;
  final int quantity;
  final String? notes;
  final double? unitPrice;
  final bool isFromMenu;

  String get itemSource => 'MANUAL';

  bool get isExternalMerchant => merchant.id <= 0 && merchantPlace != null;
}
