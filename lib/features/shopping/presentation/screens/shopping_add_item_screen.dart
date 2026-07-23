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
import '../../../../services/api_exception.dart';
import '../../../../utils/order_formatters.dart';

import '../../../../core/widgets/bang_async_state.dart';
import '../../application/shopping_item_draft.dart';
import '../widgets/shopping_draft_items_section.dart';
import '../widgets/shopping_inline_info_panel.dart';
import '../widgets/shopping_manual_item_section.dart';
import '../widgets/shopping_merchant_search_section.dart';
import '../widgets/shopping_widget_helpers.dart';
import 'shopping_merchant_map_picker_screen.dart';

class ShoppingAddItemRouteArgs {
  const ShoppingAddItemRouteArgs({
    required this.detail,
    this.targetPickupLocationId,
    this.replaceMerchant = false,
  });

  final CustomerOrderDetailModel detail;
  final int? targetPickupLocationId;
  final bool replaceMerchant;
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
    this.requestSubmitted = false,
    this.merchantReplaced = false,
    this.pendingDriverApproval = false,
  });

  final CustomerOrderDetailModel detail;
  final double oldDeliveryFee;
  final double newDeliveryFee;
  final double oldTotal;
  final double newTotal;
  final int oldStopCount;
  final int newStopCount;
  final bool requestSubmitted;
  final bool merchantReplaced;
  final bool pendingDriverApproval;

  bool get deliveryFeeChanged =>
      (oldDeliveryFee - newDeliveryFee).abs() >= 0.01;

  bool get stopCountChanged => oldStopCount != newStopCount;

  String get message {
    if (pendingDriverApproval) {
      return 'Toko/resto pengganti agak jauh. Menunggu persetujuan driver dulu.';
    }
    if (merchantReplaced) {
      return 'Toko/resto berhasil diganti. Rute dan ongkir telah diperbarui.';
    }
    if (requestSubmitted) {
      return 'Item pengganti disimpan. Driver perlu input harga baru.';
    }

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
    this.targetPickupLocationId,
    this.replaceMerchant = false,
  });

  final int? orderId;
  final CustomerOrderDetailModel? initialDetail;
  final int? targetPickupLocationId;
  final bool replaceMerchant;

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
  String? _replacementIdempotencyKey;
  int _currentStep = 0;

  bool get _isRequestMode {
    final detail = _detail;
    if (detail == null) {
      return false;
    }

    return !detail.canEditShoppingItems &&
        (detail.canRequestAddShoppingStop ||
            (widget.targetPickupLocationId != null &&
                detail.canEditUnavailableShoppingItems));
  }

  bool get _isReplacementMode =>
      widget.replaceMerchant && widget.targetPickupLocationId != null;

  bool get _isEditUnavailableMode =>
      widget.targetPickupLocationId != null && !_isReplacementMode;

  CustomerShoppingStopModel? get _replacementSourceStop {
    if (!_isReplacementMode) {
      return null;
    }
    for (final stop in _detail?.shoppingStops ?? const []) {
      if (stop.pickupLocationId == widget.targetPickupLocationId) {
        return stop;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _detail = widget.initialDetail;
    _currentStep = _isEditUnavailableMode ? 1 : 0;
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

    if (_isReplacementMode) {
      if (_replacementSourceStop == null) {
        setState(
          () => _errorText = 'Toko/resto yang ingin diganti tidak valid.',
        );
        return;
      }
      await _searchMerchants();
      return;
    }

    if (_isEditUnavailableMode) {
      CustomerShoppingStopModel? stop;
      for (final candidate in detail.shoppingStops) {
        if (candidate.pickupLocationId == widget.targetPickupLocationId) {
          stop = candidate;
          break;
        }
      }
      if (stop == null) {
        setState(() => _errorText = 'Tempat yang ingin diedit tidak valid.');
        return;
      }
      final merchant = ShoppingMerchantOption(
        id: stop.merchant.id ?? 0,
        name: stop.merchant.name,
        slug: null,
        merchantType: stop.merchant.merchantType,
        address: stop.merchant.address,
        latitude: stop.merchant.latitude,
        longitude: stop.merchant.longitude,
      );
      setState(() {
        _merchants = [merchant];
        _selectedMerchant = merchant;
      });
      _selectMerchant(merchant, scrollToItem: false);
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
      final visibleMerchants = _isRequestMode && !_isEditUnavailableMode
          ? merchants
                .where((merchant) => !_isExistingActiveMerchant(merchant))
                .toList(growable: false)
          : merchants;
      setState(() {
        _merchants = visibleMerchants;
        if (_selectedMerchant != null) {
          final selectedId = _selectedMerchant!.id;
          final matches = visibleMerchants.where(
            (item) => item.id == selectedId,
          );
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

  Future<void> _selectMerchant(
    ShoppingMerchantOption merchant, {
    bool scrollToItem = true,
  }) async {
    if (_isRequestMode &&
        !_isEditUnavailableMode &&
        _isExistingActiveMerchant(merchant)) {
      setState(
        () => _errorText =
            'Tempat ini sudah ada di order. Gunakan edit jika item tidak tersedia.',
      );
      return;
    }

    final current = _selectedMerchant;
    final isDifferentMerchant =
        current != null &&
        (current.id != merchant.id ||
            _normalizeMerchantName(current.name) !=
                _normalizeMerchantName(merchant.name));
    if (isDifferentMerchant && _draftItems.isNotEmpty) {
      final discard = await _confirmDiscardItems();
      if (!discard || !mounted) {
        return;
      }
    }

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
      _replacementIdempotencyKey = null;
      if (isDifferentMerchant) {
        _draftItems = const <ShoppingItemDraft>[];
      }
      _currentStep = 1;
    });

    if (merchant.id > 0) {
      unawaited(_loadMerchantMenus(merchant));
    }

    if (scrollToItem) {
      _scrollToItemSection();
    }
  }

  bool _isExistingActiveMerchant(ShoppingMerchantOption merchant) {
    final detail = _detail;
    if (detail == null) {
      return false;
    }

    return detail.shoppingStops.where((stop) => stop.isActive).any((stop) {
      final stopMerchantId = stop.merchant.id;
      if (merchant.id > 0 && stopMerchantId != null) {
        return merchant.id == stopMerchantId;
      }

      return _normalizeMerchantName(stop.merchant.name) ==
          _normalizeMerchantName(merchant.name);
    });
  }

  Future<void> _openMapPicker() async {
    final detail = _detail;
    final orderId = widget.orderId;
    if (orderId == null || orderId <= 0) {
      setState(() => _errorText = 'Order tidak valid.');
      return;
    }

    final result = await context.push<ShoppingMerchantPickerResult>(
      AppRoutes.shoppingMerchantMapPickerPath(orderId),
      extra: ShoppingMerchantMapPickerArgs(
        initialLatitude: detail?.dropoffLatitude,
        initialLongitude: detail?.dropoffLongitude,
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    if (result.isOfficial) {
      final officialMerchant = ShoppingMerchantOption(
        id: result.merchantId!,
        name: result.place.name,
        slug: null,
        merchantType: shoppingMerchantTypeFromPlace(
          name: result.place.name,
          types: result.place.types,
        ),
        address: result.place.address,
        latitude: result.place.latitude,
        longitude: result.place.longitude,
      );
      final exists = _merchants.any((item) => item.id == officialMerchant.id);
      if (!exists) {
        setState(() => _merchants = [officialMerchant, ..._merchants]);
      }
      await _selectMerchant(officialMerchant);
      return;
    }

    final matchedMerchant = await _resolveDatabaseMerchantForPlace(
      result.place,
    );
    if (!mounted) {
      return;
    }

    if (matchedMerchant != null) {
      final exists = _merchants.any((item) => item.id == matchedMerchant.id);
      if (!exists) {
        setState(() => _merchants = [matchedMerchant, ..._merchants]);
      }
      await _selectMerchant(matchedMerchant);
      return;
    }

    await _selectExternalMerchantPlace(result.place);
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

  Future<void> _selectExternalMerchantPlace(
    ShoppingMerchantPlacePayload place,
  ) async {
    final merchant = ShoppingMerchantOption(
      id: 0,
      name: place.name,
      slug: null,
      merchantType: shoppingMerchantTypeFromPlace(
        name: place.name,
        types: place.types,
      ),
      address: place.address,
      latitude: place.latitude,
      longitude: place.longitude,
    );

    final current = _selectedMerchant;
    final isDifferentMerchant =
        current != null &&
        _normalizeMerchantName(current.name) !=
            _normalizeMerchantName(merchant.name);
    if (isDifferentMerchant && _draftItems.isNotEmpty) {
      final discard = await _confirmDiscardItems();
      if (!discard || !mounted) {
        return;
      }
    }

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
      _replacementIdempotencyKey = null;
      _merchants = [merchant, ..._merchants.where((item) => item.id > 0)];
      if (isDifferentMerchant) {
        _draftItems = const <ShoppingItemDraft>[];
      }
      _currentStep = 1;
    });

    _scrollToItemSection();
  }

  bool _canUseMerchantForDraft(
    ShoppingMerchantOption? merchant,
    ShoppingMerchantPlacePayload? merchantPlace,
  ) {
    if (merchant == null) {
      return false;
    }

    if (merchant.id > 0 || merchantPlace != null) {
      return true;
    }

    return _isEditUnavailableMode && widget.targetPickupLocationId != null;
  }

  int? _merchantIdForPayload(ShoppingItemDraft item) {
    return item.merchant.id > 0 ? item.merchant.id : null;
  }

  Future<bool> _confirmDiscardItems() async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Ganti toko/resto?'),
            content: const Text(
              'Item yang sudah dipilih akan dikosongkan agar tidak terbawa ke toko/resto baru.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Tetap di sini'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Kosongkan item'),
              ),
            ],
          ),
        ) ??
        false;
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
    if (merchant == null || !_canUseMerchantForDraft(merchant, merchantPlace)) {
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
      _replacementIdempotencyKey = null;
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
        menuId: null,
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
      _replacementIdempotencyKey = null;
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

  void _decrementDraftItem(ShoppingItemDraft item) {
    setState(() {
      final nextQuantity = item.quantity - 1;
      if (nextQuantity <= 0) {
        _draftItems = _draftItems
            .where((draft) => draft.id != item.id)
            .toList(growable: false);
        if (_editingDraftItem?.id == item.id) {
          _editingDraftItem = null;
          _manualItemController.clear();
          _noteController.clear();
          _quantity = 1;
        }
      } else {
        _draftItems = _draftItems
            .map(
              (draft) => draft.id == item.id
                  ? ShoppingItemDraft(
                      id: draft.id,
                      merchant: draft.merchant,
                      merchantPlace: draft.merchantPlace,
                      menuId: draft.menuId,
                      name: draft.name,
                      quantity: nextQuantity,
                      notes: draft.notes,
                      unitPrice: draft.unitPrice,
                      isFromMenu: draft.isFromMenu,
                    )
                  : draft,
            )
            .toList(growable: false);
      }
      _errorText = null;
      _replacementIdempotencyKey = null;
    });
  }

  void _incrementDraftItem(ShoppingItemDraft item) {
    setState(() {
      _draftItems = _draftItems
          .map(
            (draft) => draft.id == item.id
                ? ShoppingItemDraft(
                    id: draft.id,
                    merchant: draft.merchant,
                    merchantPlace: draft.merchantPlace,
                    menuId: draft.menuId,
                    name: draft.name,
                    quantity: draft.quantity + 1,
                    notes: draft.notes,
                    unitPrice: draft.unitPrice,
                    isFromMenu: draft.isFromMenu,
                  )
                : draft,
          )
          .toList(growable: false);
      _errorText = null;
      _replacementIdempotencyKey = null;
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
      final payload = _draftItems
          .map(
            (item) => ShoppingItemDraftPayload(
              merchantId: _merchantIdForPayload(item),
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

      if (_isReplacementMode) {
        final source = _replacementSourceStop;
        final merchant = _selectedMerchant;
        if (source == null || merchant == null) {
          throw StateError('Pilih toko/resto pengganti terlebih dahulu.');
        }
        final repository = ref.read(customerOrderRepositoryProvider);
        final preview = await repository.previewShoppingMerchantReplacement(
          widget.orderId!,
          pickupLocationId: source.pickupLocationId,
          expectedVersion: source.stateVersion,
          merchantId: merchant.id > 0 ? merchant.id : null,
          merchantPlace: merchant.id > 0 ? null : _selectedMerchantPlace,
          items: payload,
        );
        if (!mounted) {
          return;
        }
        final confirmed = await _confirmReplacement(preview);
        if (!mounted) {
          return;
        }
        if (!confirmed) {
          setState(() => _isSubmitting = false);
          return;
        }
        _replacementIdempotencyKey ??=
            '${widget.orderId}-${source.pickupLocationId}-${DateTime.now().microsecondsSinceEpoch}-${math.Random.secure().nextInt(1 << 32)}';
        final outcome = await repository.replaceShoppingMerchant(
          widget.orderId!,
          pickupLocationId: source.pickupLocationId,
          expectedVersion: preview.expectedVersion,
          idempotencyKey: _replacementIdempotencyKey!,
          merchantId: merchant.id > 0 ? merchant.id : null,
          merchantPlace: merchant.id > 0 ? null : _selectedMerchantPlace,
          items: payload,
        );
        final updated = outcome.detail;
        final result = ShoppingAddItemResult(
          detail: updated,
          oldDeliveryFee: oldDeliveryFee,
          newDeliveryFee: updated.shoppingPricing?.deliveryFee ?? oldDeliveryFee,
          oldTotal: oldTotal,
          newTotal:
              updated.shoppingPricing?.totalPrice ??
              updated.summary.totalAmount,
          oldStopCount: oldStopCount,
          newStopCount: updated.shoppingStops.length,
          merchantReplaced: !outcome.pendingDriverApproval,
          pendingDriverApproval: outcome.pendingDriverApproval,
        );
        if (mounted) {
          Navigator.of(context).pop(result);
        }
        return;
      }

      final requestMode = _isRequestMode;
      final updated = requestMode
          ? await ref
                .read(customerOrderRepositoryProvider)
                .requestShoppingItemChange(
                  widget.orderId!,
                  action: 'ADD',
                  requestKind: 'EDIT_UNAVAILABLE',
                  items: payload,
                  targetPickupLocationId: widget.targetPickupLocationId,
                )
          : await ref
                .read(customerOrderRepositoryProvider)
                .addShoppingItems(widget.orderId!, payload);

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
        requestSubmitted: requestMode,
      );

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(result);
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_isReplacementMode &&
          error is ApiException &&
          error.statusCode == 409) {
        try {
          final refreshed = await ref
              .read(customerOrderRepositoryProvider)
              .fetchOrderDetail(widget.orderId!);
          if (!mounted) {
            return;
          }
          setState(() {
            _detail = refreshed;
            _replacementIdempotencyKey = null;
            _errorText =
                'Keputusan toko/resto sudah diambil pihak lain. Detail order telah dimuat ulang.';
            _isSubmitting = false;
          });
          return;
        } catch (_) {
          // Fall through to the actionable server error while retaining draft.
        }
      }
      setState(() {
        _errorText = error.toString();
        _isSubmitting = false;
      });
    }
  }

  Future<bool> _confirmReplacement(
    ShoppingMerchantReplacementPreview preview,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Konfirmasi ganti toko/resto'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${preview.oldMerchantName} → ${preview.newMerchantName}',
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${preview.items.length} item baru akan digunakan di toko/resto pengganti.',
                    ),
                    const SizedBox(height: 12),
                    _replacementPriceRow(
                      'Ongkir aktif',
                      preview.activeDeliveryFee,
                      emphasized: true,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Toko/resto pengganti ke-${preview.nextAttemptNo} dari 3. Aksi pertama dari customer atau driver yang tersimpan akan berlaku.',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Periksa lagi'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Ganti toko/resto'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _replacementPriceRow(
    String label,
    double amount, {
    bool emphasized = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            formatCurrency(amount),
            style: TextStyle(
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
              color: emphasized ? AppColors.primaryDark : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  void _setQuantity(int value) {
    setState(() => _quantity = value < 1 ? 1 : value);
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final canPickMerchant =
        _isReplacementMode ||
        (!_isEditUnavailableMode && detail?.canAddShoppingMerchant == true);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        title: Text(
          _isReplacementMode
              ? 'Ganti Toko/Resto'
              : _isEditUnavailableMode
              ? 'Ganti Item'
              : 'Tambah Item',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.w700),
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
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 56),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStepIndicator(),
                          const SizedBox(height: 18),
                          if (_currentStep == 0)
                            ShoppingMerchantSearchSection(
                              controller: _merchantSearchController,
                              canSearch: canPickMerchant,
                              isLoading: _isLoadingMerchants,
                              merchants: _merchants,
                              selectedMerchant: _selectedMerchant,
                              onSearch: _searchMerchants,
                              onOpenMapPicker: canPickMerchant
                                  ? _openMapPicker
                                  : null,
                              onSelect: _selectMerchant,
                            )
                          else if (_currentStep == 1) ...[
                            if (_selectedMerchant != null)
                              _buildSelectedMerchantSummary(_selectedMerchant!),
                            const SizedBox(height: 14),
                            if (_selectedMerchant != null)
                              KeyedSubtree(
                                key: _itemSectionKey,
                                child: _buildItemSection(_selectedMerchant!),
                              ),
                            const SizedBox(height: 16),
                            ShoppingDraftItemsSection(
                              key: _draftItemsSectionKey,
                              items: _draftItems,
                              onDecrement: _decrementDraftItem,
                              onIncrement: _incrementDraftItem,
                            ),
                          ] else
                            _buildReviewStep(),
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
                  _buildWizardFooter(),
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
      showMenus: merchant.id > 0,
      onDecrement: () => _setQuantity(_quantity - 1),
      onIncrement: () => _setQuantity(_quantity + 1),
      onAdd: _addDraftItem,
      onAddMenu: _addMenuDraftItem,
      onChanged: () => setState(() {}),
    );
  }

  Widget _buildStepIndicator() {
    const labels = ['Toko/resto', 'Item', 'Review'];
    return Semantics(
      label: 'Langkah ${_currentStep + 1} dari 3: ${labels[_currentStep]}',
      child: Row(
        children: List.generate(labels.length, (index) {
          final active = index == _currentStep;
          final complete = index < _currentStep;
          return Expanded(
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active || complete
                        ? AppColors.primary
                        : AppColors.background,
                    shape: BoxShape.circle,
                  ),
                  child: complete
                      ? const Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: AppColors.white,
                        )
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: active
                                ? AppColors.white
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    labels[index],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: active
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
                if (index < labels.length - 1) const SizedBox(width: 6),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSelectedMerchantSummary(ShoppingMerchantOption merchant) {
    return Card(
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
          merchant.address ?? 'Alamat toko/resto tidak tersedia',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: _isEditUnavailableMode
            ? const Icon(Icons.lock_outline_rounded)
            : TextButton(
                onPressed: () => setState(() => _currentStep = 0),
                child: const Text('Ubah'),
              ),
      ),
    );
  }

  Widget _buildReviewStep() {
    final merchant = _selectedMerchant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isReplacementMode ? 'Review penggantian' : 'Review item',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          _isReplacementMode
              ? 'Item lama tetap tersimpan sebagai riwayat. Hanya item di bawah yang aktif di toko/resto baru.'
              : 'Periksa toko/resto, item, dan jumlah sebelum dikirim.',
          style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 16),
        if (merchant != null) _buildSelectedMerchantSummary(merchant),
        const SizedBox(height: 16),
        ShoppingDraftItemsSection(
          items: _draftItems,
          onDecrement: _decrementDraftItem,
          onIncrement: _incrementDraftItem,
        ),
      ],
    );
  }

  Widget _buildWizardFooter() {
    final canContinue = switch (_currentStep) {
      0 => _selectedMerchant != null,
      1 => _draftItems.isNotEmpty && _editingDraftItem == null,
      _ => _draftItems.isNotEmpty,
    };
    final primaryLabel = _currentStep < 2
        ? 'Lanjut'
        : _isReplacementMode
        ? 'Konfirmasi Ganti'
        : 'Konfirmasi Item';
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            if (_currentStep > (_isEditUnavailableMode ? 1 : 0)) ...[
              OutlinedButton(
                onPressed: _isSubmitting
                    ? null
                    : () => setState(() => _currentStep -= 1),
                child: const Text('Kembali'),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _isSubmitting || !canContinue
                      ? null
                      : () {
                          if (_currentStep < 2) {
                            setState(() => _currentStep += 1);
                          } else {
                            _submitDrafts();
                          }
                        },
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                      : Text(primaryLabel),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _normalizeMerchantName(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
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
