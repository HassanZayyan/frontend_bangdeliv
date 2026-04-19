import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../models/chatbot_model.dart';
import '../providers/auth_session_provider.dart';
import '../providers/api_providers.dart';
import '../services/api_exception.dart';

part 'chatbot_screen_courier_handler.dart';

class ChatbotScreen extends ConsumerStatefulWidget {
  const ChatbotScreen({super.key});

  @override
  ConsumerState<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends ConsumerState<ChatbotScreen> {
  final List<_ChatMessage> _messages = <_ChatMessage>[];

  late final TextEditingController _inputController;
  late final ScrollController _scrollController;
  late final String _sessionId;
  bool _isSending = false;
  bool _hasInitializedWelcome = false;

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController();
    _scrollController = ScrollController();
    _sessionId =
        'chat-${DateTime.now().millisecondsSinceEpoch}-${identityHashCode(this)}';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_hasInitializedWelcome) {
      return;
    }

    _messages.add(
      _ChatMessage.bot(
        text: _serviceContext.welcomeMessage,
        timestamp: _nowLabel(),
      ),
    );
    _hasInitializedWelcome = true;
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  _ServiceContext get _serviceContext {
    final rawServiceType =
        GoRouterState.of(context).uri.queryParameters['service_type'] ??
        'nitip';

    switch (rawServiceType) {
      case 'antar_jemput':
        return const _ServiceContext(
          serviceType: 'antar_jemput',
          title: 'BangBot AI - Antar Jemput',
          subtitle: 'Mode perjalanan aktif',
          welcomeMessage:
              'Halo! Saya BangBot 🤖 untuk layanan Antar Jemput. Alamat jemput diambil dari Alamat Saya pada profilmu, jadi tinggal ketik tujuanmu.',
          suggestions: [
            'Saya mau pergi ke Jalan Sudirman',
            'Antar ke Stasiun Gambir',
            'Tujuan ke Bandara Soekarno-Hatta',
          ],
        );
      case 'kurir':
        return const _ServiceContext(
          serviceType: 'kurir',
          title: 'BangBot AI - Kurir',
          subtitle: 'Mode pengiriman paket aktif',
          welcomeMessage:
              'Halo! Saya BangBot 🤖 untuk layanan Kurir. Tulis lokasi ambil, tujuan kirim, dan isi paket.',
          suggestions: ['Kirim dokumen', 'Ambil di kantor', 'Kirim ke rumah'],
        );
      default:
        return const _ServiceContext(
          serviceType: 'nitip',
          title: 'BangBot AI - Nitip',
          subtitle: 'Mode titip belanja aktif',
          welcomeMessage:
              'Halo! Saya BangBot 🤖 untuk layanan Nitip. Ketik kebutuhanmu secara natural, saya bantu proses.',
          suggestions: ['Mie Ayam', 'Ayam Geprek', 'Minuman dingin'],
        );
    }
  }

  Future<void> _sendMessage([String? presetText]) async {
    if (_isSending) {
      return;
    }

    final raw = (presetText ?? _inputController.text).trim();
    if (raw.isEmpty) {
      return;
    }

    final outboundMessage = _composeCourierOutboundMessage(raw);

    _inputController.clear();

    setState(() {
      _messages.add(_ChatMessage.user(text: raw, timestamp: _nowLabel()));
      _isSending = true;
    });
    _scrollToBottom();

    try {
      final chatbotService = ref.read(chatbotApiServiceProvider);
      final result = await chatbotService.sendMessage(
        outboundMessage,
        serviceType: _serviceContext.serviceType,
        sessionId: _sessionId,
      );

      final botMessage = result.toAssistantText();
      final metaParts = <String>['Layanan: ${_serviceContext.serviceType}'];
      if (result.modelUsed != null && result.modelUsed!.trim().isNotEmpty) {
        metaParts.add('Model: ${result.modelUsed}');
      }
      if (result.isOrderCreated) {
        final orderRef = result.createdOrderNumber?.trim();
        if (orderRef != null && orderRef.isNotEmpty) {
          metaParts.add('Order: $orderRef');
        } else if (result.createdOrderId != null) {
          metaParts.add('Order ID: ${result.createdOrderId}');
        }
      }

      setState(() {
        _messages.add(
          _ChatMessage.bot(
            text: botMessage,
            timestamp: _nowLabel(),
            meta: metaParts.join(' • '),
            action: _buildMessageAction(result),
          ),
        );
      });
    } on ApiException catch (error) {
      setState(() {
        _messages.add(
          _ChatMessage.bot(
            text: 'Maaf, terjadi kendala: ${error.message}',
            timestamp: _nowLabel(),
          ),
        );
      });
    } catch (_) {
      setState(() {
        _messages.add(
          _ChatMessage.bot(
            text: 'Maaf, layanan chatbot belum bisa digunakan saat ini.',
            timestamp: _nowLabel(),
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  static String _nowLabel() {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        toolbarHeight: 72,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _serviceContext.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _serviceContext.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.success,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz, color: AppColors.textPrimary),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              children: _messages
                  .map(_buildMessageItem)
                  .toList(growable: false),
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: const BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final suggestion
                            in _serviceContext.suggestions) ...[
                          _buildSuggestionChip(suggestion),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: TextField(
                            controller: _inputController,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                            ),
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendMessage(),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: AppColors.background,
                              hintText: 'Ketik kebutuhan layanan...',
                              hintStyle: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                              border: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(25),
                                ),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(25),
                                ),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(25),
                                ),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 0,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      InkWell(
                        borderRadius: BorderRadius.circular(25),
                        onTap: _isSending ? null : _sendMessage,
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: _isSending
                                ? AppColors.primary.withValues(alpha: 0.7)
                                : AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: _isSending
                              ? const Padding(
                                  padding: EdgeInsets.all(14),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String label) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: () => _sendMessage(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.primary, width: 1.2),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.primaryDark,
            fontSize: 13,
            fontWeight: FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageItem(_ChatMessage message) {
    final isUser = message.isUser;
    final bubbleColor = isUser ? AppColors.primary : AppColors.white;
    final textColor = isUser ? Colors.white : AppColors.textPrimary;
    final metaColor = isUser
        ? Colors.white.withValues(alpha: 0.8)
        : AppColors.textSecondary;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(
              left: isUser ? 50 : 0,
              right: isUser ? 0 : 50,
              bottom: 6,
            ),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bubbleColor,
              border: isUser
                  ? null
                  : Border.all(color: AppColors.border, width: 1),
              borderRadius: BorderRadius.circular(16).copyWith(
                topLeft: isUser
                    ? const Radius.circular(16)
                    : const Radius.circular(4),
                topRight: isUser
                    ? const Radius.circular(4)
                    : const Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.text,
                  style: TextStyle(color: textColor, height: 1.5),
                ),
                if (message.meta != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    message.meta!,
                    style: TextStyle(color: metaColor, fontSize: 11),
                  ),
                ],
                if (message.action != null) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: message.action!.onTap,
                    icon: const Icon(Icons.location_on_outlined, size: 16),
                    label: Text(message.action!.label),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isUser
                          ? Colors.white
                          : AppColors.primaryDark,
                      side: BorderSide(
                        color: isUser
                            ? Colors.white.withValues(alpha: 0.35)
                            : AppColors.primary,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              message.timestamp,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final String timestamp;
  final bool isUser;
  final String? meta;
  final _ChatMessageAction? action;

  const _ChatMessage({
    required this.text,
    required this.timestamp,
    required this.isUser,
    this.meta,
    this.action,
  });

  factory _ChatMessage.user({required String text, required String timestamp}) {
    return _ChatMessage(text: text, timestamp: timestamp, isUser: true);
  }

  factory _ChatMessage.bot({
    required String text,
    required String timestamp,
    String? meta,
    _ChatMessageAction? action,
  }) {
    return _ChatMessage(
      text: text,
      timestamp: timestamp,
      isUser: false,
      meta: meta,
      action: action,
    );
  }
}

class _ChatMessageAction {
  final String label;
  final VoidCallback onTap;

  const _ChatMessageAction({required this.label, required this.onTap});
}

class _ServiceContext {
  final String serviceType;
  final String title;
  final String subtitle;
  final String welcomeMessage;
  final List<String> suggestions;

  const _ServiceContext({
    required this.serviceType,
    required this.title,
    required this.subtitle,
    required this.welcomeMessage,
    required this.suggestions,
  });
}
