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
    if (_serviceContext.serviceType == 'antar_jemput' &&
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
          address:
              'Pin ${result.latitude.toStringAsFixed(6)}, ${result.longitude.toStringAsFixed(6)}',
        );

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
}
