part of 'chatbot_screen.dart';

extension _CourierChatHandler on _ChatbotScreenState {
  bool _hasSavedAddressInProfile() {
    final authState = ref.read(authSessionProvider);
    final addresses = authState.profile?.addresses ?? const [];

    return addresses.any((item) => item.fullAddress.trim().isNotEmpty);
  }

  Future<void> _handleActionHint(ChatbotMessageActionHint actionHint) async {
    switch (actionHint.type) {
      case ChatbotMessageActionType.openAddresses:
        await _handleOpenAddressesAction();
        return;
      case ChatbotMessageActionType.openMapPicker:
        await _handleOpenMapPickerAction(actionHint);
        return;
      case ChatbotMessageActionType.openRoutePicker:
        await _handleOpenRoutePickerAction(actionHint);
        return;
      case ChatbotMessageActionType.sendPresetMessage:
        await _handleSendPresetMessageAction(actionHint);
        return;
      case ChatbotMessageActionType.openTrackOrder:
        await _handleOpenTrackOrderAction(actionHint);
        return;
      case ChatbotMessageActionType.openActivity:
        _handleOpenActivityAction();
        return;
    }
  }

  Future<void> _handleSendPresetMessageAction(
    ChatbotMessageActionHint actionHint,
  ) async {
    final presetMessage = (actionHint.presetMessage ?? actionHint.label).trim();
    if (presetMessage.isEmpty) {
      return;
    }

    await _sendMessage(presetMessage);
  }

  Future<void> _handleOpenAddressesAction() async {
    await context.push(AppRoutes.addresses);
    if (!mounted) {
      return;
    }

    await ref.read(authSessionProvider.notifier).refreshSession();

    ref
        .read(chatbotConversationProvider.notifier)
        .onAddressBookUpdated(serviceType: _serviceContext.serviceType);

    await ref
        .read(chatbotConversationProvider.notifier)
        .refreshSessions(serviceType: _serviceContext.serviceType);

    _scrollToBottom();
  }

  Future<void> _handleOpenMapPickerAction(
    ChatbotMessageActionHint actionHint,
  ) async {
    if ((_serviceContext.serviceType == 'antar_jemput' ||
            _serviceContext.serviceType == 'kurir') &&
        !_hasSavedAddressInProfile()) {
      await _handleOpenAddressesAction();
      return;
    }

    final pickerExtra = <String, dynamic>{
      ...?(actionHint.initialLatitude == null
          ? null
          : <String, dynamic>{'latitude': actionHint.initialLatitude}),
      ...?(actionHint.initialLongitude == null
          ? null
          : <String, dynamic>{'longitude': actionHint.initialLongitude}),
    };

    final result = await context.push(
      AppRoutes.addressLocationPicker,
      extra: pickerExtra,
    );

    if (!mounted || result is! AddressLocationPickerResult) {
      return;
    }

    final target = (actionHint.target ?? '').trim();
    if (target.isEmpty) {
      return;
    }

    await ref
        .read(chatbotConversationProvider.notifier)
        .applyMapPinAction(
          serviceType: _serviceContext.serviceType,
          target: target,
          latitude: result.latitude,
          longitude: result.longitude,
          address: null,
        );

    _scrollToBottom();
  }

  Future<void> _handleOpenRoutePickerAction(
    ChatbotMessageActionHint actionHint,
  ) async {
    if (!_hasSavedAddressInProfile()) {
      await _handleOpenAddressesAction();
      return;
    }

    final serviceType = _serviceContext.serviceType;
    if (serviceType != 'antar_jemput' && serviceType != 'kurir') {
      return;
    }

    final defaultPickup = _defaultSavedAddress();
    if (defaultPickup == null || !_hasValidCoordinate(defaultPickup)) {
      await _handleOpenAddressesAction();
      return;
    }

    ChatbotRoutePointHint? pointFor(String target) {
      for (final point in actionHint.routePoints) {
        if (point.target == target) {
          return point;
        }
      }
      return null;
    }

    final pickupPoint = pointFor('pickup');
    final destinationTarget = serviceType == 'kurir'
        ? 'dropoff'
        : 'destination';
    final destinationPoint = pointFor(destinationTarget);
    final isCourier = serviceType == 'kurir';

    final result = await context.push(
      AppRoutes.routeLocationPicker,
      extra: RouteLocationPickerArgs(
        serviceType: serviceType,
        pickupTarget: 'pickup',
        destinationTarget: destinationTarget,
        pickupLabel: isCourier ? 'Ambil' : 'Jemput',
        destinationLabel: 'Tujuan',
        title: isCourier ? 'Atur Rute Kurir' : 'Atur Rute Antar Jemput',
        confirmLabel: isCourier ? 'Simpan Rute Kurir' : 'Simpan Rute',
        defaultPickupAddress: defaultPickup.fullAddress,
        defaultPickupLatitude: defaultPickup.latitude,
        defaultPickupLongitude: defaultPickup.longitude,
        pickupInitialLatitude: pickupPoint?.initialLatitude,
        pickupInitialLongitude: pickupPoint?.initialLongitude,
        pickupInitialAddress: pickupPoint?.address,
        destinationInitialLatitude: destinationPoint?.initialLatitude,
        destinationInitialLongitude: destinationPoint?.initialLongitude,
        destinationInitialAddress: destinationPoint?.address,
      ),
    );

    if (!mounted || result is! RouteLocationPickerResult) {
      return;
    }

    final locations = result.locations
        .map(
          (location) => ChatbotLocationPatch(
            target: location.target,
            latitude: location.latitude,
            longitude: location.longitude,
            address: (location.address ?? '').trim().isEmpty
                ? null
                : location.address!.trim(),
          ),
        )
        .toList(growable: false);

    await ref
        .read(chatbotConversationProvider.notifier)
        .applyRoutePickerAction(serviceType: serviceType, locations: locations);

    _scrollToBottom();
  }

  Future<void> _handleOpenTrackOrderAction(
    ChatbotMessageActionHint actionHint,
  ) async {
    final orderId = actionHint.orderId;
    if (orderId != null && orderId > 0) {
      await context.push(AppRoutes.track, extra: orderId);
      return;
    }

    await context.push(AppRoutes.track);
  }

  void _handleOpenActivityAction() {
    context.go(AppRoutes.activity);
  }

  SavedAddressModel? _defaultSavedAddress() {
    final addresses =
        ref.read(authSessionProvider).profile?.addresses ??
        const <SavedAddressModel>[];
    final validAddresses = addresses
        .where((address) => address.fullAddress.trim().isNotEmpty)
        .where(_hasValidCoordinate)
        .toList(growable: false);
    if (validAddresses.isEmpty) {
      return null;
    }

    for (final address in validAddresses) {
      if (address.isDefault) {
        return address;
      }
    }

    return validAddresses.first;
  }

  bool _hasValidCoordinate(SavedAddressModel address) {
    return address.latitude >= -90 &&
        address.latitude <= 90 &&
        address.longitude >= -180 &&
        address.longitude <= 180 &&
        !(address.latitude == 0 && address.longitude == 0);
  }
}
