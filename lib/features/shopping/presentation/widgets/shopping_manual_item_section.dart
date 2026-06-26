import 'package:flutter/material.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_text_scaling.dart';
import '../../../../services/customer_order_api_service.dart';
import '../../../../utils/order_formatters.dart';
import 'shopping_inline_info_panel.dart';
import 'shopping_widget_helpers.dart';

class ShoppingManualItemSection extends StatelessWidget {
  const ShoppingManualItemSection({
    super.key,
    required this.controller,
    required this.noteController,
    required this.quantity,
    required this.isAddDisabled,
    required this.isEditing,
    required this.menus,
    required this.isLoadingMenus,
    required this.menuErrorText,
    required this.showMenus,
    required this.onDecrement,
    required this.onIncrement,
    required this.onAdd,
    required this.onAddMenu,
    required this.onChanged,
  });

  final TextEditingController controller;
  final TextEditingController noteController;
  final int quantity;
  final bool isAddDisabled;
  final bool isEditing;
  final List<ShoppingMenuOption> menus;
  final bool isLoadingMenus;
  final String? menuErrorText;
  final bool showMenus;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final VoidCallback onAdd;
  final ValueChanged<ShoppingMenuOption> onAddMenu;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShoppingSectionTitle(
          title: 'Item',
          subtitle: isEditing
              ? 'Ubah item yang dipilih, lalu simpan.'
              : 'Tambahkan makanan atau barang yang ingin dititipkan.',
        ),
        const SizedBox(height: 10),
        if (showMenus) ...[
          _MenuQuickPickSection(
            menus: menus,
            isLoading: isLoadingMenus,
            errorText: menuErrorText,
            onAdd: onAddMenu,
          ),
          const SizedBox(height: 12),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                textInputAction: TextInputAction.next,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                decoration: const InputDecoration(
                  labelText: 'Nama item',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  hintText: 'Contoh: telur 1 kg',
                ),
                onChanged: (_) => onChanged(),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteController,
                minLines: 1,
                maxLines: 3,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                decoration: const InputDecoration(
                  labelText: 'Catatan',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  hintText: 'Opsional',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ShoppingQuantityStepper(
                    quantity: quantity,
                    onDecrement: isAddDisabled || quantity <= 1
                        ? null
                        : onDecrement,
                    onIncrement: isAddDisabled ? null : onIncrement,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: AppTextScaling.adaptive(
                          context,
                          normal: 42,
                          large: 48,
                        ),
                      ),
                      child: FilledButton.icon(
                        onPressed: isAddDisabled ? null : onAdd,
                        icon: Icon(
                          isEditing ? Icons.check_rounded : Icons.add_rounded,
                          size: 18,
                        ),
                        label: Text(
                          isEditing ? 'Simpan' : 'Tambah',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Harga dikonfirmasi driver dari nota.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuQuickPickSection extends StatefulWidget {
  const _MenuQuickPickSection({
    required this.menus,
    required this.isLoading,
    required this.errorText,
    required this.onAdd,
  });

  final List<ShoppingMenuOption> menus;
  final bool isLoading;
  final String? errorText;
  final ValueChanged<ShoppingMenuOption> onAdd;

  @override
  State<_MenuQuickPickSection> createState() => _MenuQuickPickSectionState();
}

class _MenuQuickPickSectionState extends State<_MenuQuickPickSection> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const ShoppingInlineInfoPanel(
        icon: Icons.restaurant_menu_outlined,
        text: 'Memuat menu...',
      );
    }

    if ((widget.errorText ?? '').trim().isNotEmpty) {
      return ShoppingInlineInfoPanel(
        icon: Icons.error_outline,
        text: 'Menu belum bisa dimuat. Item manual tetap bisa ditambahkan.',
        isError: true,
      );
    }

    if (widget.menus.isEmpty) {
      return const ShoppingInlineInfoPanel(
        icon: Icons.restaurant_menu_outlined,
        text: 'Menu belum tersedia. Gunakan input manual.',
      );
    }

    final query = _searchController.text.trim().toLowerCase();
    final visibleMenus = query.isEmpty
        ? widget.menus
        : widget.menus
              .where((menu) => menu.name.toLowerCase().contains(query))
              .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ShoppingFieldLabel('Menu tersedia'),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                decoration: const InputDecoration(
                  hintText: 'Cari menu',
                  prefixIcon: Icon(Icons.search_rounded, size: 18),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              if (visibleMenus.isEmpty)
                const ShoppingEmptyPanel(text: 'Menu tidak ditemukan.')
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.separated(
                    primary: false,
                    shrinkWrap: true,
                    itemCount: visibleMenus.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 10, color: AppColors.divider),
                    itemBuilder: (context, index) {
                      final menu = visibleMenus[index];
                      return _MenuQuickPickTile(
                        menu: menu,
                        onAdd: () => widget.onAdd(menu),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuQuickPickTile extends StatelessWidget {
  const _MenuQuickPickTile({required this.menu, required this.onAdd});

  final ShoppingMenuOption menu;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onAdd,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  menu.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  menu.price > 0
                      ? formatCurrency(menu.price)
                      : 'Harga belum tersedia',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.add_rounded, color: AppColors.primary, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
