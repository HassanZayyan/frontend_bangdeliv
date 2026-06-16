import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_routes.dart';
import '../../../../models/customer_order_model.dart';
import '../../../../core/di/app_providers.dart';
import '../../../../services/customer_order_api_service.dart';
import '../../../../utils/order_formatters.dart';

import '../../../../core/widgets/bang_async_state.dart';
import '../../application/shopping_item_draft.dart';
import '../widgets/shopping_draft_items_section.dart';
import '../widgets/shopping_inline_info_panel.dart';
import '../widgets/shopping_manual_item_section.dart';
import '../widgets/shopping_merchant_search_section.dart';
import '../widgets/shopping_submit_bar.dart';
import '../widgets/shopping_widget_helpers.dart';
import 'shopping_merchant_map_picker_screen.dart';

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
  final GlobalKey _itemSectionKey = GlobalKey();
  final GlobalKey _draftItemsSectionKey = GlobalKey();

  CustomerOrderDetailModel? _detail;
  List<ShoppingMerchantOption> _merchants = const <ShoppingMerchantOption>[];
  List<ShoppingMenuOption> _menus = const <ShoppingMenuOption>[];
  List<ShoppingItemDraft> _draftItems = const <ShoppingItemDraft>[];
  ShoppingMerchantOption? _selectedMerchant;
  ShoppingMerchantPlacePayload? _selectedMerchantPlace;
  ShoppingItemDraft? _editingDraftItem;
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
          .read(customerOrderRepositoryProvider)
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
              latitude: stop.merchant.latitude,
              longitude: stop.merchant.longitude,
            ),
          )
          .toList(growable: false);

      setState(() {
        _merchants = existing;
        _selectedMerchant = existing.isNotEmpty ? existing.first : null;
      });

      if (_selectedMerchant != null) {
        _selectMerchant(_selectedMerchant!, scrollToItem: false);
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
          .read(customerOrderRepositoryProvider)
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
            _selectedMerchantPlace = null;
            _editingDraftItem = null;
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

  void _selectMerchant(
    ShoppingMerchantOption merchant, {
    bool scrollToItem = true,
  }) {
    setState(() {
      _selectedMerchant = merchant;
      _selectedMerchantPlace = null;
      _manualItemController.clear();
      _noteController.clear();
      _menus = const <ShoppingMenuOption>[];
      _menuErrorText = null;
      _quantity = 1;
      _editingDraftItem = null;
      _errorText = null;
    });

    if (isRestaurantMerchantType(merchant.merchantType)) {
      unawaited(_loadMerchantMenus(merchant));
    }

    if (scrollToItem) {
      _scrollToItemSection();
    }
  }

  Future<void> _openMapPicker() async {
    final detail = _detail;
    final orderId = widget.orderId;
    if (orderId == null || orderId <= 0) {
      setState(() => _errorText = 'Order tidak valid.');
      return;
    }

    final result = await context.push<ShoppingMerchantPlacePayload>(
      AppRoutes.shoppingMerchantMapPickerPath(orderId),
      extra: ShoppingMerchantMapPickerArgs(
        initialLatitude: detail?.dropoffLatitude,
        initialLongitude: detail?.dropoffLongitude,
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    final matchedMerchant = await _resolveDatabaseMerchantForPlace(result);
    if (!mounted) {
      return;
    }

    if (matchedMerchant != null) {
      final exists = _merchants.any((item) => item.id == matchedMerchant.id);
      if (!exists) {
        setState(() => _merchants = [matchedMerchant, ..._merchants]);
      }
      _selectMerchant(matchedMerchant);
      return;
    }

    _selectExternalMerchantPlace(result);
  }

  Future<ShoppingMerchantOption?> _resolveDatabaseMerchantForPlace(
    ShoppingMerchantPlacePayload place,
  ) async {
    try {
      final candidates = await ref
          .read(customerOrderRepositoryProvider)
          .searchShoppingMerchants(place.name);

      for (final candidate in candidates) {
        if (_normalizeMerchantName(candidate.name) !=
            _normalizeMerchantName(place.name)) {
          continue;
        }

        final latitude = candidate.latitude;
        final longitude = candidate.longitude;
        if (latitude == null || longitude == null) {
          return candidate;
        }

        if (_distanceMeters(
              latitude,
              longitude,
              place.latitude,
              place.longitude,
            ) <=
            180) {
          return candidate;
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  void _selectExternalMerchantPlace(ShoppingMerchantPlacePayload place) {
    final merchant = ShoppingMerchantOption(
      id: 0,
      name: place.name,
      slug: null,
      merchantType: _merchantTypeFromPlaceTypes(place.types),
      address: place.address,
      latitude: place.latitude,
      longitude: place.longitude,
    );

    setState(() {
      _selectedMerchant = merchant;
      _selectedMerchantPlace = place;
      _manualItemController.clear();
      _noteController.clear();
      _menus = const <ShoppingMenuOption>[];
      _menuErrorText = null;
      _quantity = 1;
      _editingDraftItem = null;
      _errorText = null;
      _merchants = [merchant, ..._merchants.where((item) => item.id > 0)];
    });

    _scrollToItemSection();
  }

  void _scrollToItemSection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final itemContext = _itemSectionKey.currentContext;
      if (itemContext == null) {
        return;
      }

      Scrollable.ensureVisible(
        itemContext,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
        alignment: 0.08,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      );
    });
  }

  void _scrollToDraftItemsSection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final draftContext = _draftItemsSectionKey.currentContext;
      if (draftContext == null) {
        return;
      }

      Scrollable.ensureVisible(
        draftContext,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
        alignment: 0.34,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      );
    });
  }

  Future<void> _loadMerchantMenus(ShoppingMerchantOption merchant) async {
    setState(() {
      _isLoadingMenus = true;
      _menuErrorText = null;
    });

    try {
      final menus = await ref
          .read(customerOrderRepositoryProvider)
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
    final merchantPlace = _selectedMerchantPlace;
    if (merchant == null || (merchant.id <= 0 && merchantPlace == null)) {
      setState(() => _errorText = 'Pilih toko/resto terlebih dahulu.');
      return;
    }

    final manualName = _manualItemController.text.trim();
    if (manualName.isEmpty) {
      setState(() => _errorText = 'Nama item wajib diisi.');
      return;
    }

    final editingItem = _editingDraftItem;
    if (editingItem == null && _draftItems.length >= 30) {
      setState(() => _errorText = 'Maksimal 30 item titipan sekali kirim.');
      return;
    }

    setState(() {
      final draft = ShoppingItemDraft(
        id: editingItem?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        merchant: merchant,
        merchantPlace: merchantPlace,
        menuId: null,
        name: manualName,
        quantity: _quantity,
        notes: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        unitPrice: null,
        isFromMenu: false,
      );

      _draftItems = _upsertDraftItem(draft, editingItem);
      _manualItemController.clear();
      _noteController.clear();
      _quantity = 1;
      _editingDraftItem = null;
      _errorText = null;
    });

    _scrollToDraftItemsSection();
  }

  void _addMenuDraftItem(ShoppingMenuOption menu) {
    final merchant = _selectedMerchant;
    if (merchant == null || merchant.id <= 0) {
      setState(() => _errorText = 'Pilih toko/resto terlebih dahulu.');
      return;
    }

    final editingItem = _editingDraftItem;
    final notes = _noteController.text.trim().isEmpty
        ? null
        : _noteController.text.trim();
    final existingMenuDraft = _draftItems.any(
      (item) =>
          item.isFromMenu &&
          item.merchant.id == merchant.id &&
          item.name == menu.name &&
          (item.notes ?? '') == (notes ?? ''),
    );
    if (editingItem == null && _draftItems.length >= 30 && !existingMenuDraft) {
      setState(() => _errorText = 'Maksimal 30 item titipan sekali kirim.');
      return;
    }

    setState(() {
      final draft = ShoppingItemDraft(
        id: editingItem?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        merchant: merchant,
        merchantPlace: null,
        menuId: menu.id,
        name: menu.name,
        quantity: _quantity,
        notes: notes,
        unitPrice: menu.price,
        isFromMenu: true,
      );

      _draftItems = editingItem == null
          ? _appendOrIncrementMenuDraftItem(draft)
          : _upsertDraftItem(draft, editingItem);
      _manualItemController.clear();
      _noteController.clear();
      _quantity = 1;
      _editingDraftItem = null;
      _errorText = null;
    });

    _scrollToDraftItemsSection();
  }

  List<ShoppingItemDraft> _appendOrIncrementMenuDraftItem(
    ShoppingItemDraft draft,
  ) {
    var didUpdate = false;
    final drafts = _draftItems
        .map((item) {
          final sameMenuItem =
              item.isFromMenu &&
              item.merchant.id == draft.merchant.id &&
              item.name == draft.name &&
              (item.notes ?? '') == (draft.notes ?? '');
          if (!sameMenuItem) {
            return item;
          }

          didUpdate = true;
          return ShoppingItemDraft(
            id: item.id,
            merchant: item.merchant,
            merchantPlace: item.merchantPlace,
            menuId: item.menuId,
            name: item.name,
            quantity: item.quantity + draft.quantity,
            notes: item.notes,
            unitPrice: item.unitPrice,
            isFromMenu: true,
          );
        })
        .toList(growable: false);

    return didUpdate ? drafts : [...drafts, draft];
  }

  List<ShoppingItemDraft> _upsertDraftItem(
    ShoppingItemDraft draft,
    ShoppingItemDraft? editingItem,
  ) {
    if (editingItem == null) {
      return [..._draftItems, draft];
    }

    var didReplace = false;
    final drafts = _draftItems
        .map((item) {
          if (item.id == editingItem.id) {
            didReplace = true;
            return draft;
          }
          return item;
        })
        .toList(growable: false);

    return didReplace ? drafts : [...drafts, draft];
  }

  void _removeDraftItem(ShoppingItemDraft item) {
    setState(() {
      _draftItems = _draftItems
          .where((draft) => draft.id != item.id)
          .toList(growable: false);
      if (_editingDraftItem?.id == item.id) {
        _editingDraftItem = null;
        _manualItemController.clear();
        _noteController.clear();
        _quantity = 1;
      }
      _errorText = null;
    });
  }

  void _editDraftItem(ShoppingItemDraft item) {
    if (item.isFromMenu) {
      return;
    }

    final merchantExists = _merchants.any(
      (merchant) => _isSameMerchantOption(merchant, item.merchant),
    );

    setState(() {
      if (!merchantExists) {
        _merchants = [item.merchant, ..._merchants];
      }
      _editingDraftItem = item;
      _selectedMerchant = item.merchant;
      _selectedMerchantPlace = item.merchantPlace;
      _manualItemController.text = item.name;
      _noteController.text = item.notes ?? '';
      _menus = const <ShoppingMenuOption>[];
      _menuErrorText = null;
      _quantity = item.quantity;
      _errorText = null;
    });

    if (item.merchant.id > 0 &&
        isRestaurantMerchantType(item.merchant.merchantType)) {
      unawaited(_loadMerchantMenus(item.merchant));
    }

    _scrollToItemSection();
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

    if (_editingDraftItem != null) {
      setState(() => _errorText = 'Simpan perubahan item terlebih dahulu.');
      _scrollToItemSection();
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
          .read(customerOrderRepositoryProvider)
          .addShoppingItems(
            widget.orderId!,
            _draftItems
                .map(
                  (item) => ShoppingItemDraftPayload(
                    merchantId: item.merchant.id,
                    merchantPlace: item.merchantPlace,
                    menuId: item.menuId,
                    itemSource: item.itemSource,
                    name: item.name,
                    quantity: item.quantity,
                    notes: item.notes,
                    unitPrice: item.unitPrice,
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
            ? BangErrorState(
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
                          ShoppingMerchantSearchSection(
                            controller: _merchantSearchController,
                            canSearch: detail.canAddShoppingMerchant,
                            isLoading: _isLoadingMerchants,
                            merchants: _merchants,
                            selectedMerchant: _selectedMerchant,
                            onSearch: _searchMerchants,
                            onOpenMapPicker: detail.canAddShoppingMerchant
                                ? _openMapPicker
                                : null,
                            onSelect: _selectMerchant,
                          ),
                          const SizedBox(height: 16),
                          if (_selectedMerchant != null)
                            KeyedSubtree(
                              key: _itemSectionKey,
                              child: _buildItemSection(_selectedMerchant!),
                            ),
                          const SizedBox(height: 16),
                          ShoppingDraftItemsSection(
                            key: _draftItemsSectionKey,
                            items: _draftItems,
                            onEdit: _editDraftItem,
                            onRemove: _removeDraftItem,
                          ),
                          if ((_errorText ?? '').isNotEmpty) ...[
                            const SizedBox(height: 14),
                            ShoppingInlineInfoPanel(
                              icon: Icons.error_outline_rounded,
                              text: _errorText!,
                              isError: true,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  ShoppingSubmitBar(
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
    return ShoppingManualItemSection(
      controller: _manualItemController,
      noteController: _noteController,
      quantity: _quantity,
      isAddDisabled: _isSubmitting,
      isEditing: _editingDraftItem != null,
      menus: _menus,
      isLoadingMenus: _isLoadingMenus,
      menuErrorText: _menuErrorText,
      showMenus:
          merchant.id > 0 && isRestaurantMerchantType(merchant.merchantType),
      onDecrement: () => _setQuantity(_quantity - 1),
      onIncrement: () => _setQuantity(_quantity + 1),
      onAdd: _addDraftItem,
      onAddMenu: _addMenuDraftItem,
      onChanged: () => setState(() {}),
    );
  }
}

String _normalizeMerchantName(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}

bool _isSameMerchantOption(
  ShoppingMerchantOption first,
  ShoppingMerchantOption second,
) {
  if (first.id > 0 || second.id > 0) {
    return first.id == second.id;
  }

  final sameName =
      _normalizeMerchantName(first.name) == _normalizeMerchantName(second.name);
  if (!sameName) {
    return false;
  }

  final firstLatitude = first.latitude;
  final firstLongitude = first.longitude;
  final secondLatitude = second.latitude;
  final secondLongitude = second.longitude;
  if (firstLatitude == null ||
      firstLongitude == null ||
      secondLatitude == null ||
      secondLongitude == null) {
    return true;
  }

  return _distanceMeters(
        firstLatitude,
        firstLongitude,
        secondLatitude,
        secondLongitude,
      ) <=
      30;
}

String _merchantTypeFromPlaceTypes(List<String> types) {
  final normalized = types.map((type) => type.toLowerCase()).toSet();
  if (normalized.any(
    (type) =>
        type.contains('restaurant') ||
        type == 'food' ||
        type == 'meal_takeaway' ||
        type == 'cafe',
  )) {
    return 'restaurant';
  }

  if (normalized.any(
    (type) =>
        type == 'convenience_store' ||
        type == 'supermarket' ||
        type == 'grocery_or_supermarket',
  )) {
    return 'convenience_store';
  }

  return 'other';
}

double _distanceMeters(
  double originLatitude,
  double originLongitude,
  double targetLatitude,
  double targetLongitude,
) {
  const earthRadiusMeters = 6371000.0;
  final originLatitudeRad = originLatitude * math.pi / 180;
  final targetLatitudeRad = targetLatitude * math.pi / 180;
  final deltaLatitudeRad = (targetLatitude - originLatitude) * math.pi / 180;
  final deltaLongitudeRad = (targetLongitude - originLongitude) * math.pi / 180;

  final haversine =
      math.sin(deltaLatitudeRad / 2) * math.sin(deltaLatitudeRad / 2) +
      math.cos(originLatitudeRad) *
          math.cos(targetLatitudeRad) *
          math.sin(deltaLongitudeRad / 2) *
          math.sin(deltaLongitudeRad / 2);
  final safeHaversine = math.min(1.0, math.max(0.0, haversine));

  return earthRadiusMeters *
      2 *
      math.atan2(math.sqrt(safeHaversine), math.sqrt(1 - safeHaversine));
}
