import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_colors.dart';
import '../models/order_chat_model.dart';
import '../providers/auth_session_provider.dart';
import '../providers/order_chat_provider.dart';
import '../providers/order_chat_unread_provider.dart';
import '../utils/order_formatters.dart';

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
    final error = await ref
        .read(orderChatProvider(widget.orderId).notifier)
        .sendMessage(text);

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

  @override
  Widget build(BuildContext context) {
    final chatAsync = ref.watch(orderChatProvider(widget.orderId));
    final currentUserId = ref.watch(authSessionProvider).profile?.id ?? 0;

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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Chat Order',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            }
          },
        ),
      ),
      body: chatAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _ErrorState(
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
              if (chat.realtimeUnavailable) const _SyncStatusPill(),
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
                          orderChatUnreadCountProvider(widget.orderId).notifier,
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
              ),
            ],
          );
        },
      ),
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
      child: Container(
        margin: EdgeInsets.only(
          left: isMine ? 54 : 0,
          right: isMine ? 0 : 54,
          bottom: 10,
        ),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 9),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(16).copyWith(
            topLeft: Radius.circular(isMine ? 16 : 4),
            topRight: Radius.circular(isMine ? 4 : 16),
          ),
          border: isMine ? null : Border.all(color: AppColors.border),
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

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool isSending;
  final VoidCallback onSend;

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
              borderRadius: BorderRadius.circular(22),
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
                    borderRadius: BorderRadius.circular(22),
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

class _SyncStatusPill extends StatelessWidget {
  const _SyncStatusPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(strokeWidth: 1.6),
              ),
              SizedBox(width: 6),
              Text(
                'Menyinkronkan berkala',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
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
          Icon(Icons.chat_bubble_outline, color: AppColors.textSecondary),
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
            const Icon(Icons.error_outline, color: AppColors.error, size: 32),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
