import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_routes.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../models/driver_order_model.dart';
import '../../../../services/customer_order_api_service.dart';
import '../../../shopping/application/shopping_item_draft.dart';
import '../../../shopping/presentation/screens/shopping_merchant_map_picker_screen.dart';
import '../../../shopping/presentation/widgets/shopping_draft_items_section.dart';
import '../../../shopping/presentation/widgets/shopping_inline_info_panel.dart';
import '../../../shopping/presentation/widgets/shopping_manual_item_section.dart';
import '../../../shopping/presentation/widgets/shopping_widget_helpers.dart';
import '../../application/driver_order_providers.dart';

class DriverShoppingChangeWizardScreen extends ConsumerStatefulWidget {
  const DriverShoppingChangeWizardScreen({
    super.key,
    required this.order,
    required this.stop,
    required this.replaceMerchant,
  });

  final DriverOrderModel order;
  final DriverShoppingStopModel stop;
  final bool replaceMerchant;

  @override
  ConsumerState<DriverShoppingChangeWizardScreen> createState() =>
      _DriverShoppingChangeWizardScreenState();
}

class _DriverShoppingChangeWizardScreenState
    extends ConsumerState<DriverShoppingChangeWizardScreen> {
  final _manualItemController = TextEditingController();
  final _noteController = TextEditingController();
  ShoppingMerchantOption? _merchant;
  ShoppingMerchantPlacePayload? _merchantPlace;
  List<ShoppingMenuOption> _menus = const [];
  List<ShoppingItemDraft> _items = const [];
  int _step = 0;
  int _quantity = 1;
  bool _loadingMenus = false;
  bool _submitting = false;
  String? _error;
  String? _idempotencyKey;

  @override
  void initState() {
    super.initState();
    if (!widget.replaceMerchant) {
      _merchant = ShoppingMerchantOption(
        id: widget.stop.merchant.id ?? 0,
        name: widget.stop.merchant.name,
        slug: null,
        merchantType: widget.stop.merchant.merchantType,
        address: widget.stop.merchant.address,
        latitude: widget.stop.merchant.latitude,
        longitude: widget.stop.merchant.longitude,
      );
      _step = 1;
      if (_merchant!.id > 0) {
        _loadMenus();
      }
    }
  }

  @override
  void dispose() {
    _manualItemController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickMerchant() async {
    final result = await context.push<ShoppingMerchantPickerResult>(
      AppRoutes.shoppingMerchantMapPickerPath(widget.order.id),
      extra: ShoppingMerchantMapPickerArgs(
        initialLatitude: widget.stop.merchant.latitude,
        initialLongitude: widget.stop.merchant.longitude,
      ),
    );
    if (!mounted || result == null) return;
    if (_items.isNotEmpty) {
      final discard = await _confirmDiscard();
      if (!discard || !mounted) return;
    }
    final type = shoppingMerchantTypeFromPlace(
      name: result.place.name,
      types: result.place.types,
    );
    setState(() {
      _merchant = ShoppingMerchantOption(
        id: result.merchantId ?? 0,
        name: result.place.name,
        slug: null,
        merchantType: type,
        address: result.place.address,
        latitude: result.place.latitude,
        longitude: result.place.longitude,
      );
      _merchantPlace = result.isOfficial ? null : result.place;
      _items = const [];
      _menus = const [];
      _error = null;
      _idempotencyKey = null;
      _step = 1;
    });
    if (_merchant!.id > 0) await _loadMenus();
  }

  Future<bool> _confirmDiscard() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Ganti toko/resto?'),
            content: const Text(
              'Item yang sudah dipilih akan dikosongkan agar tidak terbawa ke tempat baru.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Tetap di sini'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Kosongkan item'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _loadMenus() async {
    final merchant = _merchant;
    if (merchant == null || merchant.id <= 0) return;
    setState(() => _loadingMenus = true);
    try {
      final menus = await ref
          .read(customerOrderRepositoryProvider)
          .searchMerchantMenus(merchant.id, '');
      if (mounted && _merchant?.id == merchant.id) {
        setState(() => _menus = menus);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loadingMenus = false);
    }
  }

  void _addManual() {
    final merchant = _merchant;
    final name = _manualItemController.text.trim();
    if (merchant == null || name.isEmpty) {
      setState(() => _error = 'Nama item wajib diisi.');
      return;
    }
    _appendItem(
      ShoppingItemDraft(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        merchant: merchant,
        merchantPlace: _merchantPlace,
        menuId: null,
        name: name,
        quantity: _quantity,
        notes: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        unitPrice: null,
        isFromMenu: false,
      ),
    );
  }

  void _addMenu(ShoppingMenuOption menu) {
    final merchant = _merchant;
    if (merchant == null) return;
    final existingIndex = _items.indexWhere(
      (item) => item.isFromMenu && item.name == menu.name,
    );
    if (existingIndex >= 0) {
      _changeQuantity(
        _items[existingIndex],
        _items[existingIndex].quantity + 1,
      );
      return;
    }
    _appendItem(
      ShoppingItemDraft(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        merchant: merchant,
        merchantPlace: null,
        menuId: null,
        name: menu.name,
        quantity: _quantity,
        notes: null,
        unitPrice: menu.price,
        isFromMenu: true,
      ),
    );
  }

  void _appendItem(ShoppingItemDraft item) {
    setState(() {
      _items = [..._items, item];
      _manualItemController.clear();
      _noteController.clear();
      _quantity = 1;
      _error = null;
      _idempotencyKey = null;
    });
  }

  void _changeQuantity(ShoppingItemDraft item, int quantity) {
    setState(() {
      _idempotencyKey = null;
      if (quantity <= 0) {
        _items = _items.where((candidate) => candidate.id != item.id).toList();
      } else {
        _items = _items
            .map(
              (candidate) => candidate.id == item.id
                  ? ShoppingItemDraft(
                      id: candidate.id,
                      merchant: candidate.merchant,
                      merchantPlace: candidate.merchantPlace,
                      menuId: candidate.menuId,
                      name: candidate.name,
                      quantity: quantity,
                      notes: candidate.notes,
                      unitPrice: candidate.unitPrice,
                      isFromMenu: candidate.isFromMenu,
                    )
                  : candidate,
            )
            .toList();
      }
    });
  }

  List<ShoppingItemDraftPayload> get _payload => _items
      .map(
        (item) => ShoppingItemDraftPayload(
          merchantId: item.merchant.id > 0 ? item.merchant.id : null,
          merchantPlace: item.merchantPlace,
          menuId: null,
          itemSource: item.itemSource,
          name: item.name,
          quantity: item.quantity,
          notes: item.notes,
          unitPrice: item.unitPrice,
        ),
      )
      .toList(growable: false);

  Future<void> _submit() async {
    final merchant = _merchant;
    if (merchant == null || _items.isEmpty) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      _idempotencyKey ??= _newIdempotencyKey();
      if (!widget.replaceMerchant) {
        final error = await ref
            .read(driverOrdersProvider.notifier)
            .replaceUnavailableShoppingItems(
              orderId: widget.order.id,
              pickupLocationId: widget.stop.pickupLocationId,
              idempotencyKey: _idempotencyKey!,
              items: _payload,
            );
        if (error != null) throw StateError(error);
      } else {
        final repository = ref.read(driverOrderRepositoryProvider);
        final preview = await repository.previewShoppingMerchantReplacement(
          orderId: widget.order.id,
          pickupLocationId: widget.stop.pickupLocationId,
          expectedVersion: widget.stop.stateVersion,
          merchantId: merchant.id > 0 ? merchant.id : null,
          merchantPlace: merchant.id > 0 ? null : _merchantPlace,
          items: _payload,
        );
        await repository.replaceShoppingMerchant(
          orderId: widget.order.id,
          pickupLocationId: widget.stop.pickupLocationId,
          expectedVersion: preview.expectedVersion,
          idempotencyKey: _idempotencyKey!,
          merchantId: merchant.id > 0 ? merchant.id : null,
          merchantPlace: merchant.id > 0 ? null : _merchantPlace,
          items: _payload,
        );
        ref.invalidate(driverOrdersProvider);
      }
      ref.invalidate(driverOrderDetailProvider(widget.order.id));
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      ref.invalidate(driverOrderDetailProvider(widget.order.id));
      ref.invalidate(driverOrdersProvider);
      if (mounted) {
        setState(() {
          _error = error.toString().replaceFirst('Bad state: ', '');
          _submitting = false;
        });
      }
    }
  }

  String _newIdempotencyKey() =>
      '${widget.order.id}-${widget.stop.pickupLocationId}-${DateTime.now().microsecondsSinceEpoch}-${math.Random.secure().nextInt(1 << 32)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.replaceMerchant ? 'Ganti Toko/Resto' : 'Ganti Item'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _StepHeader(step: _step),
                  const SizedBox(height: 18),
                  if (_step == 0)
                    _MerchantStep(onPick: _pickMerchant)
                  else if (_step == 1) ...[
                    _MerchantSummary(
                      merchant: _merchant!,
                      locked: !widget.replaceMerchant,
                      onChange: () => setState(() => _step = 0),
                    ),
                    const SizedBox(height: 14),
                    ShoppingManualItemSection(
                      controller: _manualItemController,
                      noteController: _noteController,
                      quantity: _quantity,
                      isAddDisabled: _submitting,
                      isEditing: false,
                      menus: _menus,
                      isLoadingMenus: _loadingMenus,
                      menuErrorText: null,
                      showMenus: _merchant!.id > 0,
                      onDecrement: () => setState(
                        () => _quantity = math.max(1, _quantity - 1),
                      ),
                      onIncrement: () => setState(() => _quantity += 1),
                      onAdd: _addManual,
                      onAddMenu: _addMenu,
                      onChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    ShoppingDraftItemsSection(
                      items: _items,
                      onDecrement: (item) =>
                          _changeQuantity(item, item.quantity - 1),
                      onIncrement: (item) =>
                          _changeQuantity(item, item.quantity + 1),
                    ),
                  ] else ...[
                    Text(
                      widget.replaceMerchant
                          ? 'Review penggantian'
                          : 'Review item pengganti',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.replaceMerchant
                          ? 'Item lama tetap menjadi riwayat. Toko/resto pengganti hanya menerima item baru berikut.'
                          : 'Semua item tidak tersedia akan diganti sekaligus. Item yang masih tersedia tetap dipertahankan.',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _MerchantSummary(
                      merchant: _merchant!,
                      locked: true,
                      onChange: null,
                    ),
                    const SizedBox(height: 16),
                    ShoppingDraftItemsSection(
                      items: _items,
                      onDecrement: (item) =>
                          _changeQuantity(item, item.quantity - 1),
                      onIncrement: (item) =>
                          _changeQuantity(item, item.quantity + 1),
                    ),
                  ],
                  if ((_error ?? '').isNotEmpty) ...[
                    const SizedBox(height: 14),
                    ShoppingInlineInfoPanel(
                      icon: Icons.error_outline_rounded,
                      text: _error!,
                      isError: true,
                    ),
                  ],
                ],
              ),
            ),
            _WizardFooter(
              step: _step,
              minimumStep: widget.replaceMerchant ? 0 : 1,
              enabled: _step == 0 ? _merchant != null : _items.isNotEmpty,
              loading: _submitting,
              onBack: () => setState(() => _step -= 1),
              onNext: () => _step < 2 ? setState(() => _step += 1) : _submit(),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step});
  final int step;
  @override
  Widget build(BuildContext context) {
    const labels = ['Toko/resto', 'Item', 'Review'];
    return Row(
      children: List.generate(3, (index) {
        final selected = index <= step;
        return Expanded(
          child: Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: selected
                    ? AppColors.primary
                    : AppColors.border,
                child: index < step
                    ? const Icon(Icons.check, size: 17, color: Colors.white)
                    : Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  labels[index],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: index == step
                        ? FontWeight.w800
                        : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _MerchantStep extends StatelessWidget {
  const _MerchantStep({required this.onPick});
  final VoidCallback onPick;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(
            Icons.storefront_outlined,
            size: 44,
            color: AppColors.primary,
          ),
          const SizedBox(height: 12),
          const Text(
            'Pilih toko/resto pengganti',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Cari toko/resto resmi BangDeliv atau tentukan titik melalui Maps.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.map_outlined),
              label: const Text('Cari toko/resto'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _MerchantSummary extends StatelessWidget {
  const _MerchantSummary({
    required this.merchant,
    required this.locked,
    required this.onChange,
  });
  final ShoppingMerchantOption merchant;
  final bool locked;
  final VoidCallback? onChange;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: ListTile(
      leading: const CircleAvatar(child: Icon(Icons.storefront_outlined)),
      title: Text(
        merchant.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        merchant.address ?? 'Alamat tidak tersedia',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: locked
          ? const Icon(Icons.lock_outline)
          : TextButton(onPressed: onChange, child: const Text('Ubah')),
    ),
  );
}

class _WizardFooter extends StatelessWidget {
  const _WizardFooter({
    required this.step,
    required this.minimumStep,
    required this.enabled,
    required this.loading,
    required this.onBack,
    required this.onNext,
  });
  final int step;
  final int minimumStep;
  final bool enabled;
  final bool loading;
  final VoidCallback onBack;
  final VoidCallback onNext;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (step > minimumStep) ...[
            OutlinedButton(
              onPressed: loading ? null : onBack,
              child: const Text('Kembali'),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: loading || !enabled ? null : onNext,
                child: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(step < 2 ? 'Lanjut' : 'Konfirmasi'),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
