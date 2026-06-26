import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_routes.dart';
import '../../../../core/widgets/bang_async_state.dart';
import '../../../../models/order_chat_model.dart';
import '../../../auth/application/auth_session_provider.dart';
import '../../../driver_orders/application/driver_order_providers.dart';
import '../../application/customer_order_providers.dart';
import '../../application/order_chat_provider.dart';
import '../../application/order_chat_unread_provider.dart';
import '../../../../utils/order_formatters.dart';
import '../../../../widgets/bang_chat_bubble.dart';
import '../../../../widgets/profile_avatar.dart';

class OrderChatScreen extends ConsumerStatefulWidget {
  const OrderChatScreen({super.key, required this.orderId});

  final int orderId;

  @override
  ConsumerState<OrderChatScreen> createState() => _OrderChatScreenState();
}

class _OrderChatScreenState extends ConsumerState<OrderChatScreen> {
  late final TextEditingController _inputController;
  late final ScrollController _scrollController;
  int _lastMarkedReadMessageId = 0;

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    _inputController.clear();
    final sendFuture = ref
        .read(orderChatProvider(widget.orderId).notifier)
        .sendMessage(text);
    _scrollToBottom();
    final error = await sendFuture;

    if (!mounted || error == null) {
      _scrollToBottom();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error), backgroundColor: AppColors.error),
    );
  }

  int _latestServerMessageId(List<OrderChatMessageModel> messages) {
    return messages
        .where((message) => message.hasServerId)
        .fold<int>(
          0,
          (maxId, message) => message.id > maxId ? message.id : maxId,
        );
  }

  Future<void> _sendPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Ambil dari kamera'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Pilih dari galeri'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
    if (source == null) {
      return;
    }

    final photo = await ImagePicker().pickImage(
      source: source,
      imageQuality: 76,
      maxWidth: 1600,
    );
    if (photo == null) {
      return;
    }

    final error = await ref
        .read(orderChatProvider(widget.orderId).notifier)
        .sendAttachment(photo, body: 'Foto order', attachmentType: 'image');

    if (!mounted || error == null) {
      _scrollToBottom();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error), backgroundColor: AppColors.error),
    );
  }

  void _markVisibleMessagesRead(List<OrderChatMessageModel> messages) {
    final latestMessageId = _latestServerMessageId(messages);
    if (latestMessageId <= 0 || latestMessageId <= _lastMarkedReadMessageId) {
      return;
    }

    _lastMarkedReadMessageId = latestMessageId;
    unawaited(
      ref
          .read(orderChatUnreadCountProvider(widget.orderId).notifier)
          .markReadThrough(latestMessageId),
    );
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }

    final session = ref.read(authSessionProvider);
    if (session.role == SessionUserRole.driver) {
      context.go(AppRoutes.driverHome);
      return;
    }

    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final chatAsync = ref.watch(orderChatProvider(widget.orderId));
    final session = ref.watch(authSessionProvider);
    final currentUserId = session.profile?.id ?? 0;
    final isDriverSession = session.role == SessionUserRole.driver;
    final customerDetailAsync = session.role == SessionUserRole.customer
        ? ref.watch(customerOrderDetailProvider(widget.orderId))
        : null;
    final driverDetailAsync = isDriverSession
        ? ref.watch(driverOrderDetailProvider(widget.orderId.toString()))
        : null;
    final customerDetail = customerDetailAsync?.asData?.value;
    final driverDetail = driverDetailAsync?.asData?.value;
    final messages =
        chatAsync.asData?.value.messages ?? const <OrderChatMessageModel>[];
    final participantName =
        (isDriverSession
                ? (driverDetail?.customerName ??
                      _participantNameFromMessages(messages, 'customer'))
                : (customerDetail?.driverName ??
                      _participantNameFromMessages(messages, 'driver')))
            .trim();
    final participantFallback = isDriverSession ? 'Customer' : 'Driver';
    final participantRoleLabel = isDriverSession ? 'customer' : 'driver';
    final participantAvatarUrl = isDriverSession
        ? null
        : customerDetail?.driverAvatarUrl?.trim();

    ref.listen<AsyncValue<OrderChatState>>(orderChatProvider(widget.orderId), (
      previous,
      next,
    ) {
      final previousLength = previous?.asData?.value.messages.length ?? 0;
      final nextMessages =
          next.asData?.value.messages ?? const <OrderChatMessageModel>[];
      final nextLength = nextMessages.length;
      _markVisibleMessagesRead(nextMessages);
      if (nextLength > previousLength) {
        _scrollToBottom();
      }
    });

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }

        _handleBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: _ChatParticipantTitle(
            participantName: participantName.isEmpty
                ? participantFallback
                : participantName,
            participantRoleLabel: participantRoleLabel,
            avatarUrl: participantAvatarUrl,
          ),
          backgroundColor: AppColors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
            onPressed: _handleBack,
          ),
        ),
        body: chatAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => BangErrorState(
            message: error.toString(),
            onRetry: () => ref.invalidate(orderChatProvider(widget.orderId)),
          ),
          data: (chat) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _markVisibleMessagesRead(chat.messages);
              }
            });

            return Column(
              children: [
                if ((chat.errorMessage ?? '').isNotEmpty)
                  _InfoBanner(text: chat.errorMessage!),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(orderChatProvider(widget.orderId));
                      await ref.read(orderChatProvider(widget.orderId).future);
                      final messages =
                          ref
                              .read(orderChatProvider(widget.orderId))
                              .asData
                              ?.value
                              .messages ??
                          const <OrderChatMessageModel>[];
                      await ref
                          .read(
                            orderChatUnreadCountProvider(
                              widget.orderId,
                            ).notifier,
                          )
                          .markReadThrough(_latestServerMessageId(messages));
                    },
                    child: ListView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                      children: [
                        if (chat.hasMore)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Center(
                              child: OutlinedButton.icon(
                                onPressed: chat.isLoadingOlder
                                    ? null
                                    : () => ref
                                          .read(
                                            orderChatProvider(
                                              widget.orderId,
                                            ).notifier,
                                          )
                                          .loadOlder(),
                                icon: chat.isLoadingOlder
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.history, size: 16),
                                label: const Text('Muat pesan lama'),
                              ),
                            ),
                          ),
                        if (chat.messages.isEmpty)
                          const _EmptyChat()
                        else
                          ...chat.messages.map(
                            (message) => _MessageBubble(
                              message: message,
                              isMine: message.senderUserId == currentUserId,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                _Composer(
                  controller: _inputController,
                  enabled: chat.canSend,
                  isSending: chat.isSending,
                  onSend: _sendMessage,
                  onAttachPhoto: _sendPhoto,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _participantNameFromMessages(
    List<OrderChatMessageModel> messages,
    String role,
  ) {
    for (final message in messages) {
      if (message.senderRole == role && message.senderName.trim().isNotEmpty) {
        return message.senderName.trim();
      }
    }

    return '';
  }
}

class _ChatParticipantTitle extends StatelessWidget {
  const _ChatParticipantTitle({
    required this.participantName,
    required this.participantRoleLabel,
    this.avatarUrl,
  });

  final String participantName;
  final String participantRoleLabel;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ProfileAvatar(name: participantName, avatarUrl: avatarUrl, size: 36),
        const SizedBox(width: 10),
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  participantName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '($participantRoleLabel)',
                maxLines: 1,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w400,
                  fontSize: 12.5,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});

  final OrderChatMessageModel message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMine ? AppColors.primary : AppColors.white;
    final textColor = isMine ? Colors.white : AppColors.textPrimary;
    final metaColor = isMine
        ? Colors.white.withValues(alpha: 0.78)
        : AppColors.textSecondary;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: BangChatBubble(
        side: isMine ? BangChatBubbleSide.right : BangChatBubbleSide.left,
        color: bubbleColor,
        borderColor: isMine ? null : AppColors.border,
        margin: EdgeInsets.only(
          left: isMine ? 54 : 0,
          right: isMine ? 0 : 54,
          bottom: 10,
        ),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 9),
        borderRadius: BorderRadius.circular(10).copyWith(
          topLeft: Radius.circular(isMine ? 10 : 4),
          topRight: Radius.circular(isMine ? 4 : 10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMine)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  _senderLabel(message),
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            if (message.hasAttachment) ...[
              _MessageAttachment(url: message.attachmentUrl!, isMine: isMine),
              if (message.body.trim().isNotEmpty) const SizedBox(height: 8),
            ],
            if (message.body.trim().isNotEmpty)
              Text(
                message.body,
                style: TextStyle(color: textColor, height: 1.42, fontSize: 14),
              ),
            const SizedBox(height: 5),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatTime(message.createdAt, includeZone: false),
                  style: TextStyle(color: metaColor, fontSize: 10.5),
                ),
                if (message.isPending) ...[
                  const SizedBox(width: 5),
                  Icon(Icons.schedule, size: 11, color: metaColor),
                ],
                if (message.isFailed) ...[
                  const SizedBox(width: 5),
                  const Icon(Icons.error_outline, size: 12, color: Colors.red),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _senderLabel(OrderChatMessageModel message) {
    final name = message.senderName.trim();
    final role = message.senderRole == 'driver' ? 'Driver' : 'Customer';
    return name.isEmpty ? role : '$role - $name';
  }
}

class _MessageAttachment extends StatelessWidget {
  const _MessageAttachment({required this.url, required this.isMine});

  final String url;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final normalized = url.trim().toLowerCase();
    final isRemote =
        normalized.startsWith('http://') || normalized.startsWith('https://');

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 220, maxHeight: 220),
        color: isMine
            ? Colors.white.withValues(alpha: 0.18)
            : AppColors.background,
        child: isRemote
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _attachmentFallback(),
              )
            : _localImageOrFallback(url),
      ),
    );
  }

  Widget _localImageOrFallback(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      return _attachmentFallback();
    }

    return Image.file(
      file,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _attachmentFallback(),
    );
  }

  Widget _attachmentFallback() {
    return const SizedBox(
      width: 180,
      height: 120,
      child: Center(
        child: Icon(Icons.image_outlined, color: AppColors.textSecondary),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.isSending,
    required this.onSend,
    required this.onAttachPhoto,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool isSending;
  final VoidCallback onSend;
  final VoidCallback onAttachPhoto;

  @override
  Widget build(BuildContext context) {
    final canSendAction = enabled;

    if (!enabled) {
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Sesi chat dengan driver berakhir',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              onPressed: canSendAction ? onAttachPhoto : null,
              tooltip: 'Kirim foto',
              icon: const Icon(Icons.photo_camera_outlined),
              color: AppColors.primary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: canSendAction ? (_) => onSend() : null,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.background,
                  hintText: 'Ketik pesan...',
                  hintStyle: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filled(
              onPressed: canSendAction ? onSend : null,
              icon: isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.primary.withValues(
                  alpha: 0.45,
                ),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.cardYellow,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 80),
      child: Column(
        children: [
          Icon(Icons.sms_outlined, color: AppColors.textSecondary),
          SizedBox(height: 10),
          Text(
            'Belum ada pesan.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
