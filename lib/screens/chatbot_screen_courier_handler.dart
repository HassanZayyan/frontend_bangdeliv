part of 'chatbot_screen.dart';

extension _CourierChatHandler on _ChatbotScreenState {
  String _composeCourierOutboundMessage(String rawMessage) {
    return rawMessage;
  }

  _ChatMessageAction? _buildMessageAction(ChatbotResult result) {
    if (_serviceContext.serviceType != 'kurir' &&
        _serviceContext.serviceType != 'antar_jemput') {
      return null;
    }

    if (result.isOrderCreated) {
      return null;
    }

    final validation = result.validation;
    if (validation == null) {
      return null;
    }

    final requiresAddressSetup =
        validation.nextActions
            .map((action) => action.trim().toUpperCase())
            .contains('OPEN_ADDRESSES') ||
        validation.rejectionReasons.any(
          (reason) =>
              reason.toLowerCase().contains('alamat saya') ||
              reason.toLowerCase().contains('alamat jemput'),
        );

    if (!requiresAddressSetup) {
      return null;
    }

    return _ChatMessageAction(
      label: 'Isi Alamat Saya',
      onTap: () async {
        await context.push(AppRoutes.addresses);
        if (!mounted) {
          return;
        }
        await ref.read(authSessionProvider.notifier).refreshSession();
      },
    );
  }
}
