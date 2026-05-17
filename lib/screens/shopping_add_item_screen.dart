import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_colors.dart';
import '../models/customer_order_model.dart';
import '../providers/api_providers.dart';
import '../services/customer_order_api_service.dart';
import '../utils/order_formatters.dart';

class ShoppingAddItemRouteArgs {
  const ShoppingAddItemRouteArgs({
    required this.detail,
    this.replacementForPickupLocationId,
  });

  final CustomerOrderDetailModel detail;
  final int? replacementForPickupLocationId;
}

class ShoppingAddItemResult {
  const ShoppingAddItemResult({
    required this.detail,
    required this.oldDeliveryFee,
    required this.newDeliveryFee,
    required this.oldTotal,
    required this.newTotal,
    required this.oldStopCount,
    required this.newStopCount,
  });

  final CustomerOrderDetailModel detail;
  final double oldDeliveryFee;
  final double newDeliveryFee;
  final double oldTotal;
  final double newTotal;
  final int oldStopCount;
  final int newStopCount;

  bool get deliveryFeeChanged =>
      (oldDeliveryFee - newDeliveryFee).abs() >= 0.01;

  bool get stopCountChanged => oldStopCount != newStopCount;

  String get message {
    if (deliveryFeeChanged) {
      return 'Item ditambahkan. Ongkir diperbarui dari '
          '${formatCurrency(oldDeliveryFee)} ke ${formatCurrency(newDeliveryFee)}.';
    }

    return 'Item belanja berhasil ditambahkan.';
  }
}

class _ShoppingItemDraft {
  const _ShoppingItemDraft({
    required this.id,
    required this.merchant,
    required this.name,
    required this.quantity,
    required this.notes,
  });

  final String id;
  final ShoppingMerchantOption merchant;
  final String name;
  final int quantity;
  final String? notes;
}

class ShoppingAddItemScreen extends ConsumerStatefulWidget {
  const ShoppingAddItemScreen({
    super.key,
    required this.orderId,
    required this.initialDetail,
    this.replacementForPickupLocationId,
  });

  final int? orderId;
  final CustomerOrderDetailModel? initialDetail;
  final int? replacementForPickupLocationId;

  @override
  ConsumerState<ShoppingAddItemScreen> createState() =>
      _ShoppingAddItemScreenState();
}

class _ShoppingAddItemScreenState extends ConsumerState<ShoppingAddItemScreen> {
  final TextEditingController _merchantSearchController =
      TextEditingController();
  final TextEditingController _manualItemController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  CustomerOrderDetailModel? _detail;
  List<ShoppingMerchantOption> _merchants = const <ShoppingMerchantOption>[];
  List<ShoppingMenuOption> _menus = const <ShoppingMenuOption>[];
  List<_ShoppingItemDraft> _draftItems = const <_ShoppingItemDraft>[];
  ShoppingMerchantOption? _selectedMerchant;
  bool _isLoadingDetail = false;
  bool _isLoadingMerchants = false;
  bool _isLoadingMenus = false;
  bool _isSubmitting = false;
  int _quantity = 1;
  String? _errorText;
  String? _menuErrorText;

  @override
  void initState() {
    super.initState();
    _detail = widget.initialDetail;
    _bootstrap();
  }

  @override
  void dispose() {
    _merchantSearchController.dispose();
    _manualItemController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (_detail == null) {
      await _loadDetail();
    }

    if (!mounted || _detail == null) {
      return;
    }

    await _bootstrapMerchants();
  }

  Future<void> _loadDetail() async {
    final orderId = widget.orderId;
    if (orderId == null || orderId <= 0) {
      setState(() => _errorText = 'Order tidak valid.');
      return;
    }

    setState(() {
      _isLoadingDetail = true;
      _errorText = null;
    });

    try {
      final detail = await ref
          .read(customerOrderApiServiceProvider)
          .fetchOrderDetail(orderId);
      if (!mounted) {
        return;
      }
      setState(() => _detail = detail);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _errorText = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoadingDetail = false);
      }
    }
  }

  Future<void> _bootstrapMerchants() async {
    final detail = _detail;
    if (detail == null) {
      return;
    }

    if (!detail.canAddShoppingMerchant) {
      final existing = detail.shoppingStops
          .where((stop) => stop.merchant.id != null)
          .map(
            (stop) => ShoppingMerchantOption(
              id: stop.merchant.id!,
              name: stop.merchant.name,
              slug: null,
              merchantType: stop.merchant.merchantType,
              address: stop.merchant.address,
            ),
          )
          .toList(growable: false);

      setState(() {
        _merchants = existing;
        _selectedMerchant = existing.isNotEmpty ? existing.first : null;
      });

      if (_selectedMerchant != null) {
        _selectMerchant(_selectedMerchant!);
      }
      return;
    }

    await _searchMerchants();
  }

  Future<void> _searchMerchants() async {
    setState(() {
      _isLoadingMerchants = true;
      _errorText = null;
    });

    try {
      final merchants = await ref
          .read(customerOrderApiServiceProvider)
          .searchShoppingMerchants(_merchantSearchController.text);
      if (!mounted) {
        return;
      }
      setState(() {
        _merchants = merchants;
        if (_selectedMerchant != null) {
          final selectedId = _selectedMerchant!.id;
          final matches = merchants.where((item) => item.id == selectedId);
          _selectedMerchant = matches.isEmpty ? null : matches.first;
          if (matches.isEmpty) {
            _manualItemController.clear();
            _noteController.clear();
          }
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _errorText = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoadingMerchants = false);
      }
    }
  }

  void _selectMerchant(ShoppingMerchantOption merchant) {
    setState(() {
      _selectedMerchant = merchant;
      _manualItemController.clear();
      _noteController.clear();
      _menus = const <ShoppingMenuOption>[];
      _menuErrorText = null;
      _quantity = 1;
      _errorText = null;
    });

    if (_isRestaurantMerchant(merchant.merchantType)) {
      unawaited(_loadMerchantMenus(merchant));
    }
  }

  Future<void> _loadMerchantMenus(ShoppingMerchantOption merchant) async {
    setState(() {
      _isLoadingMenus = true;
      _menuErrorText = null;
    });

    try {
      final menus = await ref
          .read(customerOrderApiServiceProvider)
          .searchMerchantMenus(merchant.id, '');
      if (!mounted || _selectedMerchant?.id != merchant.id) {
        return;
      }
      setState(() => _menus = menus);
    } catch (error) {
      if (!mounted || _selectedMerchant?.id != merchant.id) {
        return;
      }
      setState(() => _menuErrorText = error.toString());
    } finally {
      if (mounted && _selectedMerchant?.id == merchant.id) {
        setState(() => _isLoadingMenus = false);
      }
    }
  }

  void _addDraftItem() {
    final merchant = _selectedMerchant;
    if (merchant == null || merchant.id <= 0) {
      setState(() => _errorText = 'Pilih merchant terlebih dahulu.');
      return;
    }

    final manualName = _manualItemController.text.trim();
    if (manualName.isEmpty) {
      setState(() => _errorText = 'Nama item wajib diisi.');
      return;
    }

    if (_draftItems.length >= 30) {
      setState(() => _errorText = 'Maksimal 30 item titipan sekali kirim.');
      return;
    }

    setState(() {
      _draftItems = [
        ..._draftItems,
        _ShoppingItemDraft(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          merchant: merchant,
          name: manualName,
          quantity: _quantity,
          notes: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        ),
      ];
      _manualItemController.clear();
      _noteController.clear();
      _quantity = 1;
      _errorText = null;
    });
  }

  void _addMenuDraftItem(ShoppingMenuOption menu) {
    final merchant = _selectedMerchant;
    if (merchant == null || merchant.id <= 0) {
      setState(() => _errorText = 'Pilih merchant terlebih dahulu.');
      return;
    }

    if (_draftItems.length >= 30) {
      setState(() => _errorText = 'Maksimal 30 item titipan sekali kirim.');
      return;
    }

    setState(() {
      _draftItems = [
        ..._draftItems,
        _ShoppingItemDraft(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          merchant: merchant,
          name: menu.name,
          quantity: _quantity,
          notes: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        ),
      ];
      _noteController.clear();
      _quantity = 1;
      _errorText = null;
    });
  }

  void _removeDraftItem(_ShoppingItemDraft item) {
    setState(() {
      _draftItems = _draftItems
          .where((draft) => draft.id != item.id)
          .toList(growable: false);
      _errorText = null;
    });
  }

  void _editDraftItem(_ShoppingItemDraft item) {
    final merchantExists = _merchants.any(
      (merchant) => merchant.id == item.merchant.id,
    );

    setState(() {
      if (!merchantExists) {
        _merchants = [item.merchant, ..._merchants];
      }
      _draftItems = _draftItems
          .where((draft) => draft.id != item.id)
          .toList(growable: false);
      _selectedMerchant = item.merchant;
      _manualItemController.text = item.name;
      _noteController.text = item.notes ?? '';
      _quantity = item.quantity;
      _errorText = null;
    });
  }

  Future<void> _submitDrafts() async {
    final detail = _detail;
    if (detail == null || widget.orderId == null || widget.orderId! <= 0) {
      setState(() => _errorText = 'Order tidak valid.');
      return;
    }

    if (_draftItems.isEmpty) {
      setState(() => _errorText = 'Tambahkan minimal satu item ke daftar.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    final oldDeliveryFee = detail.shoppingPricing?.deliveryFee ?? 0;
    final oldTotal =
        detail.shoppingPricing?.totalPrice ?? detail.summary.totalAmount;
    final oldStopCount = detail.shoppingStops.length;

    try {
      final updated = await ref
          .read(customerOrderApiServiceProvider)
          .addShoppingItems(
            widget.orderId!,
            _draftItems
                .map(
                  (item) => ShoppingItemDraftPayload(
                    merchantId: item.merchant.id,
                    name: item.name,
                    quantity: item.quantity,
                    notes: item.notes,
                  ),
                )
                .toList(growable: false),
            replacementForPickupLocationId:
                widget.replacementForPickupLocationId,
          );

      final newDeliveryFee = updated.shoppingPricing?.deliveryFee ?? 0;
      final newTotal =
          updated.shoppingPricing?.totalPrice ?? updated.summary.totalAmount;
      final result = ShoppingAddItemResult(
        detail: updated,
        oldDeliveryFee: oldDeliveryFee,
        newDeliveryFee: newDeliveryFee,
        oldTotal: oldTotal,
        newTotal: newTotal,
        oldStopCount: oldStopCount,
        newStopCount: updated.shoppingStops.length,
      );

      debugPrint(
        '[ShoppingAddItem] order=${widget.orderId} '
        'oldDeliveryFee=$oldDeliveryFee newDeliveryFee=$newDeliveryFee '
        'oldTotal=$oldTotal newTotal=$newTotal '
        'oldStops=$oldStopCount newStops=${updated.shoppingStops.length} '
        'draftItems=${_draftItems.length}',
      );

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(result);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = error.toString();
        _isSubmitting = false;
      });
    }
  }

  void _setQuantity(int value) {
    setState(() => _quantity = value < 1 ? 1 : value);
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        title: const Text(
          'Tambah Item',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: _isLoadingDetail
            ? const Center(child: CircularProgressIndicator())
            : detail == null
            ? _ErrorState(
                message: _errorText ?? 'Detail order tidak tersedia.',
                onRetry: _loadDetail,
              )
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _MerchantSearchSection(
                            controller: _merchantSearchController,
                            canSearch: detail.canAddShoppingMerchant,
                            isLoading: _isLoadingMerchants,
                            merchants: _merchants,
                            selectedMerchant: _selectedMerchant,
                            onSearch: _searchMerchants,
                            onSelect: _selectMerchant,
                          ),
                          const SizedBox(height: 16),
                          if (_selectedMerchant != null)
                            _buildItemSection(_selectedMerchant!),
                          const SizedBox(height: 16),
                          _DraftItemsSection(
                            items: _draftItems,
                            onEdit: _editDraftItem,
                            onRemove: _removeDraftItem,
                          ),
                          if ((_errorText ?? '').isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Text(
                              _errorText!,
                              style: const TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  _SubmitBar(
                    itemCount: _draftItems.length,
                    totalQuantity: _draftItems.fold<int>(
                      0,
                      (total, item) => total + item.quantity,
                    ),
                    isSubmitting: _isSubmitting,
                    onSubmit: _submitDrafts,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildItemSection(ShoppingMerchantOption merchant) {
    return _ManualItemSection(
      controller: _manualItemController,
      noteController: _noteController,
      quantity: _quantity,
      isAddDisabled: _isSubmitting,
      menus: _menus,
      isLoadingMenus: _isLoadingMenus,
      menuErrorText: _menuErrorText,
      showMenus: _isRestaurantMerchant(merchant.merchantType),
      onDecrement: () => _setQuantity(_quantity - 1),
      onIncrement: () => _setQuantity(_quantity + 1),
      onAdd: _addDraftItem,
      onAddMenu: _addMenuDraftItem,
      onChanged: () => setState(() {}),
    );
  }
}

class _MerchantSearchSection extends StatelessWidget {
  const _MerchantSearchSection({
    required this.controller,
    required this.canSearch,
    required this.isLoading,
    required this.merchants,
    required this.selectedMerchant,
    required this.onSearch,
    required this.onSelect,
  });

  final TextEditingController controller;
  final bool canSearch;
  final bool isLoading;
  final List<ShoppingMerchantOption> merchants;
  final ShoppingMerchantOption? selectedMerchant;
  final VoidCallback onSearch;
  final ValueChanged<ShoppingMerchantOption> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (canSearch) ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    labelText: 'Cari merchant',
                    hintText: 'Contoh: Resto Taman Kedai',
                  ),
                  onSubmitted: (_) => onSearch(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Cari merchant',
                onPressed: isLoading ? null : onSearch,
                icon: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : const Icon(Icons.search),
              ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        const Text(
          'Merchant',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        if (isLoading && merchants.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: CircularProgressIndicator(),
            ),
          )
        else if (merchants.isEmpty)
          const _EmptyPanel(text: 'Merchant tidak ditemukan.')
        else
          ...merchants.map(
            (merchant) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _MerchantOptionCard(
                merchant: merchant,
                selected: selectedMerchant?.id == merchant.id,
                onTap: () => onSelect(merchant),
              ),
            ),
          ),
      ],
    );
  }
}

class _MerchantOptionCard extends StatelessWidget {
  const _MerchantOptionCard({
    required this.merchant,
    required this.selected,
    required this.onTap,
  });

  final ShoppingMerchantOption merchant;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _merchantIcon(merchant.merchantType),
                  color: AppColors.primary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            merchant.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _TypeBadge(type: merchant.merchantType),
                      ],
                    ),
                    if ((merchant.address ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        merchant.address!.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.check_circle,
                  color: AppColors.primary,
                  size: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ManualItemSection extends StatelessWidget {
  const _ManualItemSection({
    required this.controller,
    required this.noteController,
    required this.quantity,
    required this.isAddDisabled,
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
        Row(
          children: [
            const Expanded(
              child: Text(
                'Item Belanja',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.cardYellow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withValues(alpha: .25)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.receipt_long_outlined,
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Harga dan status berat dikonfirmasi driver dari nota',
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (showMenus) ...[
          _MenuQuickPickSection(
            menus: menus,
            isLoading: isLoadingMenus,
            errorText: menuErrorText,
            onAdd: onAddMenu,
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: controller,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Nama item',
            hintText: 'Contoh: telur 1 kg',
          ),
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: noteController,
          minLines: 1,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Catatan item',
            hintText: 'Opsional',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _QuantityStepper(
              quantity: quantity,
              onDecrement: isAddDisabled || quantity <= 1 ? null : onDecrement,
              onIncrement: isAddDisabled ? null : onIncrement,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isAddDisabled ? null : onAdd,
                icon: const Icon(Icons.playlist_add),
                label: const Text('Tambah ke daftar'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MenuQuickPickSection extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (isLoading) {
      return const _InlineInfoPanel(
        icon: Icons.restaurant_menu_outlined,
        text: 'Memuat menu resto...',
      );
    }

    if ((errorText ?? '').trim().isNotEmpty) {
      return _InlineInfoPanel(
        icon: Icons.error_outline,
        text: 'Menu belum bisa dimuat. Item manual tetap bisa ditambahkan.',
        isError: true,
      );
    }

    if (menus.isEmpty) {
      return const _InlineInfoPanel(
        icon: Icons.restaurant_menu_outlined,
        text: 'Menu resto belum tersedia. Gunakan input manual.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Menu Resto',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        ...menus
            .take(8)
            .map(
              (menu) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton.icon(
                  onPressed: () => onAdd(menu),
                  icon: const Icon(Icons.add, size: 18),
                  label: Row(
                    children: [
                      Expanded(
                        child: Text(
                          menu.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (menu.price > 0) ...[
                        const SizedBox(width: 8),
                        Text(formatCurrency(menu.price)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

class _InlineInfoPanel extends StatelessWidget {
  const _InlineInfoPanel({
    required this.icon,
    required this.text,
    this.isError = false,
  });

  final IconData icon;
  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.error : AppColors.textSecondary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DraftItemsSection extends StatelessWidget {
  const _DraftItemsSection({
    required this.items,
    required this.onEdit,
    required this.onRemove,
  });

  final List<_ShoppingItemDraft> items;
  final ValueChanged<_ShoppingItemDraft> onEdit;
  final ValueChanged<_ShoppingItemDraft> onRemove;

  @override
  Widget build(BuildContext context) {
    final groups = <int, List<_ShoppingItemDraft>>{};
    final merchantsById = <int, ShoppingMerchantOption>{};
    for (final item in items) {
      final merchantId = item.merchant.id;
      groups.putIfAbsent(merchantId, () => <_ShoppingItemDraft>[]).add(item);
      merchantsById[merchantId] = item.merchant;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Daftar Titipan',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          const _EmptyPanel(text: 'Daftar titipan masih kosong.')
        else
          ...groups.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DraftMerchantGroup(
                merchant: merchantsById[entry.key]!,
                items: entry.value,
                onEdit: onEdit,
                onRemove: onRemove,
              ),
            ),
          ),
      ],
    );
  }
}

class _DraftMerchantGroup extends StatelessWidget {
  const _DraftMerchantGroup({
    required this.merchant,
    required this.items,
    required this.onEdit,
    required this.onRemove,
  });

  final ShoppingMerchantOption merchant;
  final List<_ShoppingItemDraft> items;
  final ValueChanged<_ShoppingItemDraft> onEdit;
  final ValueChanged<_ShoppingItemDraft> onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  merchant.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _TypeBadge(type: merchant.merchantType),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map(
            (item) => _DraftItemTile(
              item: item,
              onEdit: () => onEdit(item),
              onRemove: () => onRemove(item),
            ),
          ),
        ],
      ),
    );
  }
}

class _DraftItemTile extends StatelessWidget {
  const _DraftItemTile({
    required this.item,
    required this.onEdit,
    required this.onRemove,
  });

  final _ShoppingItemDraft item;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final notes = (item.notes ?? '').trim();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '${item.quantity}x',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    notes,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit item',
            visualDensity: VisualDensity.compact,
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
          ),
          IconButton(
            tooltip: 'Hapus item',
            visualDensity: VisualDensity.compact,
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline, size: 18),
          ),
        ],
      ),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({
    required this.itemCount,
    required this.totalQuantity,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final int itemCount;
  final int totalQuantity;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final canSubmit = itemCount > 0;
    final title = itemCount == 0
        ? 'Daftar titipan kosong'
        : '$itemCount item, $totalQuantity barang';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Harga menunggu nota',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: isSubmitting || !canSubmit ? null : onSubmit,
            child: isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.white,
                    ),
                  )
                : const Text('Kirim Titipan'),
          ),
        ],
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
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
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Kurangi jumlah',
            visualDensity: VisualDensity.compact,
            onPressed: quantity <= 1 ? null : onDecrement,
            icon: const Icon(Icons.remove, size: 18),
          ),
          SizedBox(
            width: 26,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            tooltip: 'Tambah jumlah',
            visualDensity: VisualDensity.compact,
            onPressed: onIncrement,
            icon: const Icon(Icons.add, size: 18),
          ),
        ],
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final String? type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _merchantTypeLabel(type),
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 38),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Coba lagi')),
          ],
        ),
      ),
    );
  }
}

IconData _merchantIcon(String? type) {
  return switch ((type ?? '').trim().toLowerCase()) {
    'restaurant' => Icons.restaurant_outlined,
    'resto' => Icons.restaurant_outlined,
    'warung' => Icons.storefront_outlined,
    'convenience_store' => Icons.local_convenience_store_outlined,
    _ => Icons.store_mall_directory_outlined,
  };
}

String _merchantTypeLabel(String? type) {
  return switch ((type ?? '').trim().toLowerCase()) {
    'restaurant' => 'Resto',
    'resto' => 'Resto',
    'warung' => 'Warung',
    'convenience_store' => 'Minimarket',
    _ => 'Toko',
  };
}

bool _isRestaurantMerchant(String? type) {
  final normalized = (type ?? '').trim().toLowerCase();
  return normalized == 'restaurant' || normalized == 'resto';
}
