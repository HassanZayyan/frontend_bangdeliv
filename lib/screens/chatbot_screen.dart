import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_colors.dart';
import '../providers/api_providers.dart';
import '../services/api_exception.dart';

class ChatbotScreen extends ConsumerStatefulWidget {
  const ChatbotScreen({super.key});

  @override
  ConsumerState<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends ConsumerState<ChatbotScreen> {
  final List<_ChatMessage> _messages = <_ChatMessage>[
    _ChatMessage.bot(
      text:
          'Halo! Saya BangBot 🤖\nMau pesan apa hari ini? Ketik pesananmu secara natural, saya yang mengurus sisanya!',
      timestamp: _nowLabel(),
    ),
  ];

  late final TextEditingController _inputController;
  late final ScrollController _scrollController;
  bool _isSending = false;

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

  Future<void> _sendMessage([String? presetText]) async {
    if (_isSending) {
      return;
    }

    final raw = (presetText ?? _inputController.text).trim();
    if (raw.isEmpty) {
      return;
    }

    _inputController.clear();

    setState(() {
      _messages.add(_ChatMessage.user(text: raw, timestamp: _nowLabel()));
      _isSending = true;
    });
    _scrollToBottom();

    try {
      final chatbotService = ref.read(chatbotApiServiceProvider);
      final result = await chatbotService.sendMessage(raw);

      setState(() {
        _messages.add(
          _ChatMessage.bot(
            text: result.toAssistantText(),
            timestamp: _nowLabel(),
            meta: result.modelUsed == null
                ? null
                : 'Model: ${result.modelUsed}',
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
      backgroundColor: const Color(0xFF141624),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B1E30),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: AppColors.white),
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BangBot AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Online & Siap Membantu',
                      style: TextStyle(color: Colors.greenAccent, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz, color: AppColors.white),
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
              color: Color(0xFF1B1E30),
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
                        _buildSuggestionChip('🍜 Mie Ayam'),
                        const SizedBox(width: 8),
                        _buildSuggestionChip('🍗 Ayam Geprek'),
                        const SizedBox(width: 8),
                        _buildSuggestionChip('🥤 Minuman'),
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
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendMessage(),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: const Color(0xFF141624),
                              hintText: 'Ketik pesanan...',
                              hintStyle: const TextStyle(
                                color: Colors.white54,
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
      onTap: () => _sendMessage(label.replaceAll(RegExp(r'^[^\s]+\s+'), '')),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF20202F),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.primary, width: 1.2),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 13,
            fontWeight: FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageItem(_ChatMessage message) {
    final isUser = message.isUser;

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
              color: isUser ? AppColors.primary : const Color(0xFF1E2138),
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
                  style: const TextStyle(color: Colors.white, height: 1.5),
                ),
                if (message.meta != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    message.meta!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 11,
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
              style: const TextStyle(color: Colors.white54, fontSize: 12),
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

  const _ChatMessage({
    required this.text,
    required this.timestamp,
    required this.isUser,
    this.meta,
  });

  factory _ChatMessage.user({required String text, required String timestamp}) {
    return _ChatMessage(text: text, timestamp: timestamp, isUser: true);
  }

  factory _ChatMessage.bot({
    required String text,
    required String timestamp,
    String? meta,
  }) {
    return _ChatMessage(
      text: text,
      timestamp: timestamp,
      isUser: false,
      meta: meta,
    );
  }
}
