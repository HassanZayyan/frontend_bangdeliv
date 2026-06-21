import 'package:flutter/material.dart';

import '../../../../config/app_colors.dart';

class ShoppingSectionTitle extends StatelessWidget {
  const ShoppingSectionTitle({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final normalizedSubtitle = (subtitle ?? '').trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (normalizedSubtitle.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            normalizedSubtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              height: 1.28,
            ),
          ),
        ],
      ],
    );
  }
}

class ShoppingFieldLabel extends StatelessWidget {
  const ShoppingFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class ShoppingQuantityStepper extends StatelessWidget {
  const ShoppingQuantityStepper({
    super.key,
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
  });

  final int quantity;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
        color: AppColors.white,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 36,
            height: 40,
            child: IconButton(
              tooltip: 'Kurangi jumlah',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              onPressed: quantity <= 1 ? null : onDecrement,
              icon: const Icon(Icons.remove_rounded, size: 18),
            ),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          SizedBox(
            width: 36,
            height: 40,
            child: IconButton(
              tooltip: 'Tambah jumlah',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              onPressed: onIncrement,
              icon: const Icon(Icons.add_rounded, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class ShoppingTypeBadge extends StatelessWidget {
  const ShoppingTypeBadge({super.key, required this.type});

  final String? type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        shoppingMerchantTypeLabel(type),
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class ShoppingEmptyPanel extends StatelessWidget {
  const ShoppingEmptyPanel({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

IconData shoppingMerchantIcon(String? type) {
  return switch ((type ?? '').trim().toLowerCase()) {
    'restaurant' => Icons.restaurant_outlined,
    'resto' => Icons.restaurant_outlined,
    'warung' => Icons.storefront_outlined,
    'convenience_store' => Icons.local_convenience_store_outlined,
    _ => Icons.store_mall_directory_outlined,
  };
}

String shoppingMerchantTypeLabel(String? type) {
  return switch ((type ?? '').trim().toLowerCase()) {
    'restaurant' => 'Resto',
    'resto' => 'Resto',
    'warung' => 'Warung',
    'convenience_store' => 'Minimarket',
    _ => 'Toko',
  };
}

bool isRestaurantMerchantType(String? type) {
  final normalized = (type ?? '').trim().toLowerCase();
  return normalized == 'restaurant' || normalized == 'resto';
}

bool isAllowedShoppingMerchantPlace({
  required String name,
  required List<String> types,
}) {
  final normalizedTypes = types.map((type) => type.toLowerCase()).toSet();
  final normalizedName = name.toLowerCase();

  final hasBlockedType = normalizedTypes.any(
    (type) => {
      'atm',
      'bank',
      'finance',
      'gym',
      'health',
      'hospital',
      'insurance_agency',
      'school',
      'spa',
    }.contains(type),
  );
  if (hasBlockedType) {
    return false;
  }

  final hasFoodOrMarketType = normalizedTypes.any(
    (type) =>
        type == 'restaurant' ||
        type == 'food' ||
        type == 'meal_takeaway' ||
        type == 'cafe' ||
        type == 'convenience_store' ||
        type == 'supermarket' ||
        type == 'grocery_or_supermarket',
  );
  if (hasFoodOrMarketType) {
    return true;
  }

  return _hasShoppingMerchantNameKeyword(normalizedName);
}

String shoppingMerchantTypeFromPlace({
  required String name,
  required List<String> types,
}) {
  final normalizedTypes = types.map((type) => type.toLowerCase()).toSet();
  final normalizedName = name.toLowerCase();

  if (normalizedName.startsWith('warung ') ||
      normalizedName == 'warung' ||
      normalizedName.contains(' warung ')) {
    return 'warung';
  }

  if (normalizedTypes.any(
        (type) =>
            type == 'convenience_store' ||
            type == 'supermarket' ||
            type == 'grocery_or_supermarket',
      ) ||
      normalizedName.contains('alfamart') ||
      normalizedName.contains('indomaret') ||
      normalizedName.contains('minimarket') ||
      normalizedName.contains('supermarket') ||
      normalizedName.contains('hypermart')) {
    return 'convenience_store';
  }

  if (normalizedName.contains('foto copy') ||
      normalizedName.contains('fotocopy') ||
      normalizedName.contains('print') ||
      normalizedName.contains('atk')) {
    return 'other';
  }

  if (normalizedTypes.any(
    (type) =>
        type.contains('restaurant') ||
        type == 'meal_takeaway' ||
        type == 'cafe',
  )) {
    return 'restaurant';
  }

  if (normalizedTypes.contains('food') &&
      (normalizedName.contains('resto') ||
          normalizedName.contains('warung') ||
          normalizedName.contains('kedai') ||
          normalizedName.contains('ayam') ||
          normalizedName.contains('bakso') ||
          normalizedName.contains('mie'))) {
    return 'restaurant';
  }

  return 'other';
}

bool _hasShoppingMerchantNameKeyword(String normalizedName) {
  return normalizedName.contains('warung') ||
      normalizedName.contains('resto') ||
      normalizedName.contains('restoran') ||
      normalizedName.contains('rumah makan') ||
      normalizedName.contains('kedai') ||
      normalizedName.contains('cafe') ||
      normalizedName.contains('kafe') ||
      normalizedName.contains('coffee') ||
      normalizedName.contains('coffeshop') ||
      normalizedName.contains('coffee shop') ||
      normalizedName.contains('kopi') ||
      normalizedName.contains('minimarket') ||
      normalizedName.contains('supermarket') ||
      normalizedName.contains('hypermart') ||
      normalizedName.contains('alfamart') ||
      normalizedName.contains('indomaret') ||
      normalizedName.contains('bakso') ||
      normalizedName.contains('mie') ||
      normalizedName.contains('ayam') ||
      normalizedName.contains('seblak') ||
      normalizedName.contains('martabak') ||
      normalizedName.contains('nasgor') ||
      normalizedName.contains('nasi goreng');
}
