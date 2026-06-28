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
        ? driverDetail?.customerAvatarUrl?.trim()
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
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final availableEmptyHeight =
                            constraints.hasBoundedHeight
                            ? constraints.maxHeight - 30
                            : 240.0;
                        final emptyStateHeight = availableEmptyHeight < 180
                            ? 180.0
                            : availableEmptyHeight;
                        final maxBubbleContentWidth =
                            _MessageBubble.maxContentWidthFor(
                              constraints.maxWidth,
                            );

                        return ListView(
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
                              _EmptyChat(height: emptyStateHeight)
                            else
                              for (
                                var index = 0;
                                index < chat.messages.length;
                                index += 1
                              )
                                _MessageBubble(
                                  message: chat.messages[index],
                                  isMine:
                                      chat.messages[index].senderUserId ==
                                      currentUserId,
                                  maxContentWidth: maxBubbleContentWidth,
                                  showTail: _startsSenderRun(
                                    chat.messages,
                                    index,
                                  ),
                                ),
                          ],
                        );
                      },
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

  bool _startsSenderRun(List<OrderChatMessageModel> messages, int index) {
    if (index <= 0 || index >= messages.length) {
      return true;
    }

    final current = messages[index];
    final previous = messages[index - 1];

    if (current.senderUserId > 0 && previous.senderUserId > 0) {
      return current.senderUserId != previous.senderUserId;
    }

    return current.senderRole != previous.senderRole ||
        current.senderName != previous.senderName;
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
        ProfileAvatar(name: participantName, avatarUrl: avatarUrl, size: 30),
        const SizedBox(width: 8),
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
                    fontSize: 13.5,
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
                  fontSize: 11,
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
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.maxContentWidth,
    required this.showTail,
  });

  static const double _listHorizontalPadding = 32;
  static const double _sideRunOffset = 54;
  static const double _bubbleTailWidth = 10;
  static const double _horizontalPadding = 28;

  final OrderChatMessageModel message;
  final bool isMine;
  final double maxContentWidth;
  final bool showTail;

  static double maxContentWidthFor(double viewportWidth) {
    if (!viewportWidth.isFinite || viewportWidth <= 0) {
      return 240;
    }

    final width =
        viewportWidth -
        _listHorizontalPadding -
        _sideRunOffset -
        _bubbleTailWidth -
        _horizontalPadding;
    return width < 120 ? 120 : width;
  }

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMine ? AppColors.primary : AppColors.white;
    final textColor = isMine ? Colors.white : AppColors.textPrimary;
    final metaColor = isMine
        ? Colors.white.withValues(alpha: 0.78)
        : AppColors.textSecondary;
    final body = message.body.trim();
    final hasBody = body.isNotEmpty;
    final attachmentContentWidth = _MessageAttachment.contentWidthFor(
      maxContentWidth,
    );

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: BangChatBubble(
        side: isMine ? BangChatBubbleSide.right : BangChatBubbleSide.left,
        color: bubbleColor,
        borderColor: isMine ? null : AppColors.border,
        showTail: showTail,
        margin: EdgeInsets.only(
          left: isMine ? 54 : 0,
          right: isMine ? 0 : 54,
          bottom: 10,
        ),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 9),
        borderRadius: BorderRadius.circular(10).copyWith(
          topLeft: Radius.circular(!isMine && showTail ? 4 : 10),
          topRight: Radius.circular(isMine && showTail ? 4 : 10),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!isMine)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      _senderLabel(message),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                if (message.hasAttachment) ...[
                  _MessageAttachment(
                    url: message.attachmentUrl!,
                    isMine: isMine,
                    maxContentWidth: maxContentWidth,
                  ),
                  if (hasBody) const SizedBox(height: 8),
                ],
                if (hasBody && message.hasAttachment)
                  _MessageAttachmentCaptionWithMeta(
                    body: body,
                    textColor: textColor,
                    metaColor: metaColor,
                    createdAt: message.createdAt,
                    isPending: message.isPending,
                    isFailed: message.isFailed,
                    width: attachmentContentWidth,
                  )
                else if (hasBody)
                  _MessageTextWithAdaptiveMeta(
                    body: body,
                    textColor: textColor,
                    metaColor: metaColor,
                    createdAt: message.createdAt,
                    isPending: message.isPending,
                    isFailed: message.isFailed,
                    alignInlineMetaToEnd: !isMine,
                    maxInlineWidth: maxContentWidth,
                  )
                else ...[
                  if (message.hasAttachment) const SizedBox(height: 5),
                  SizedBox(
                    width: message.hasAttachment
                        ? attachmentContentWidth
                        : null,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _MessageMeta(
                        color: metaColor,
                        createdAt: message.createdAt,
                        isPending: message.isPending,
                        isFailed: message.isFailed,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
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

class _MessageAttachmentCaptionWithMeta extends StatelessWidget {
  const _MessageAttachmentCaptionWithMeta({
    required this.body,
    required this.textColor,
    required this.metaColor,
    required this.createdAt,
    required this.isPending,
    required this.isFailed,
    required this.width,
  });

  final String body;
  final Color textColor;
  final Color metaColor;
  final DateTime? createdAt;
  final bool isPending;
  final bool isFailed;
  final double width;

  @override
  Widget build(BuildContext context) {
    final textStyle = DefaultTextStyle.of(
      context,
    ).style.copyWith(color: textColor, height: 1.45);

    return SizedBox(
      width: width,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: Text(body, style: textStyle)),
          const SizedBox(width: 10),
          Transform.translate(
            offset: const Offset(0, 1),
            child: _MessageMeta(
              color: metaColor,
              createdAt: createdAt,
              isPending: isPending,
              isFailed: isFailed,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageTextWithAdaptiveMeta extends StatelessWidget {
  const _MessageTextWithAdaptiveMeta({
    required this.body,
    required this.textColor,
    required this.metaColor,
    required this.createdAt,
    required this.isPending,
    required this.isFailed,
    required this.alignInlineMetaToEnd,
    required this.maxInlineWidth,
  });

  static const double _metaSpacing = 8;
  static const double _opponentMetaSpacing = 20;

  final String body;
  final Color textColor;
  final Color metaColor;
  final DateTime? createdAt;
  final bool isPending;
  final bool isFailed;
  final bool alignInlineMetaToEnd;
  final double maxInlineWidth;

  @override
  Widget build(BuildContext context) {
    final textStyle = DefaultTextStyle.of(
      context,
    ).style.copyWith(color: textColor, height: 1.5);
    final metaSpacing = alignInlineMetaToEnd
        ? _opponentMetaSpacing
        : _metaSpacing;
    final useInlineMeta = _canPlaceMetaInline(context, textStyle, metaSpacing);

    if (useInlineMeta) {
      return RichText(
        text: TextSpan(
          style: textStyle,
          children: [
            TextSpan(text: body),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: Padding(
                padding: EdgeInsets.only(left: metaSpacing),
                child: Transform.translate(
                  offset: const Offset(0, 1.5),
                  child: _MessageMeta(
                    color: metaColor,
                    createdAt: createdAt,
                    isPending: isPending,
                    isFailed: isFailed,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(body, style: textStyle),
        const SizedBox(height: 5),
        Align(
          alignment: Alignment.centerRight,
          child: _MessageMeta(
            color: metaColor,
            createdAt: createdAt,
            isPending: isPending,
            isFailed: isFailed,
          ),
        ),
      ],
    );
  }

  bool _canPlaceMetaInline(
    BuildContext context,
    TextStyle textStyle,
    double metaSpacing,
  ) {
    if (!maxInlineWidth.isFinite || maxInlineWidth <= 0) {
      return true;
    }

    final direction = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final bodyPainter = TextPainter(
      text: TextSpan(text: body, style: textStyle),
      textDirection: direction,
      textScaler: textScaler,
    )..layout(maxWidth: maxInlineWidth);
    final lines = bodyPainter.computeLineMetrics();
    if (lines.isEmpty) {
      return true;
    }

    final lastLineWidth = lines.last.width;
    final metaWidth = _estimatedMetaWidth(
      textDirection: direction,
      textScaler: textScaler,
    );
    return lastLineWidth + metaSpacing + metaWidth <= maxInlineWidth;
  }

  double _estimatedMetaWidth({
    required TextDirection textDirection,
    required TextScaler textScaler,
  }) {
    final metaPainter = TextPainter(
      text: TextSpan(
        text: formatTime(createdAt, includeZone: false),
        style: const TextStyle(fontSize: 10.5),
      ),
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout();

    var width = metaPainter.width;
    if (isPending) {
      width += 5 + 11;
    }
    if (isFailed) {
      width += 5 + 12;
    }
    return width;
  }
}

class _MessageMeta extends StatelessWidget {
  const _MessageMeta({
    required this.color,
    required this.createdAt,
    required this.isPending,
    required this.isFailed,
  });

  final Color color;
  final DateTime? createdAt;
  final bool isPending;
  final bool isFailed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          formatTime(createdAt, includeZone: false),
          style: TextStyle(color: color, fontSize: 10.5),
        ),
        if (isPending) ...[
          const SizedBox(width: 5),
          Icon(Icons.schedule, size: 11, color: color),
        ],
        if (isFailed) ...[
          const SizedBox(width: 5),
          const Icon(Icons.error_outline, size: 12, color: Colors.red),
        ],
      ],
    );
  }
}

class _MessageAttachment extends StatelessWidget {
  const _MessageAttachment({
    required this.url,
    required this.isMine,
    required this.maxContentWidth,
  });

  static const double maxPreviewWidth = 220;
  static const double maxPreviewHeight = 220;

  final String url;
  final bool isMine;
  final double maxContentWidth;

  static double contentWidthFor(double maxContentWidth) {
    if (!maxContentWidth.isFinite || maxContentWidth <= 0) {
      return maxPreviewWidth;
    }

    return maxContentWidth < maxPreviewWidth
        ? maxContentWidth
        : maxPreviewWidth;
  }

  @override
  Widget build(BuildContext context) {
    final normalized = url.trim().toLowerCase();
    final isRemote =
        normalized.startsWith('http://') || normalized.startsWith('https://');
    final contentWidth = contentWidthFor(maxContentWidth);

    return Semantics(
      button: true,
      label: 'Lihat foto chat',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _openPreview(context, isRemote: isRemote),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: contentWidth,
              constraints: const BoxConstraints(maxHeight: maxPreviewHeight),
              color: isMine
                  ? Colors.white.withValues(alpha: 0.18)
                  : AppColors.background,
              child: _attachmentImage(
                isRemote: isRemote,
                fit: BoxFit.cover,
                fallbackSize: const Size(180, 120),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openPreview(BuildContext context, {required bool isRemote}) {
    showDialog<void>(
      context: context,
      barrierColor: AppColors.black,
      builder: (context) {
        return Dialog.fullscreen(
          backgroundColor: AppColors.black,
          child: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: _attachmentImage(
                      isRemote: isRemote,
                      fit: BoxFit.contain,
                      fallbackSize: const Size(220, 160),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.white,
                    ),
                    tooltip: 'Tutup',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _attachmentImage({
    required bool isRemote,
    required BoxFit fit,
    required Size fallbackSize,
  }) {
    if (isRemote) {
      return Image.network(
        url,
        fit: fit,
        errorBuilder: (_, _, _) => _attachmentFallback(fallbackSize),
      );
    }

    final file = File(url);
    if (!file.existsSync()) {
      return _attachmentFallback(fallbackSize);
    }

    return Image.file(
      file,
      fit: fit,
      errorBuilder: (_, _, _) => _attachmentFallback(fallbackSize),
    );
  }

  Widget _attachmentFallback(Size size) {
    return SizedBox(
      width: size.width,
      height: size.height,
      child: const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: AppColors.textSecondary,
        ),
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
  const _EmptyChat({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sms_outlined, color: AppColors.textSecondary),
            SizedBox(height: 10),
            Text(
              'Belum ada pesan.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
