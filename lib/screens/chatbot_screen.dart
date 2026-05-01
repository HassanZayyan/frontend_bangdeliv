import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../models/address_location_picker_result.dart';
import '../providers/auth_session_provider.dart';
import '../providers/chatbot_conversation_provider.dart';

part 'chatbot_screen_courier_handler.dart';

class ChatbotScreen extends ConsumerStatefulWidget {
  const ChatbotScreen({super.key});

  @override
  ConsumerState<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends ConsumerState<ChatbotScreen> {
  late final TextEditingController _inputController;
  late final ScrollController _scrollController;
  String? _bootstrappedServiceType;

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController();
    _scrollController = ScrollController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final serviceType = _serviceContext.serviceType;
    if (_bootstrappedServiceType == serviceType) {
      // Already bootstrapped for this service type — just scroll to the
      // bottom so the user lands at the latest message on re-entry.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToBottom();
      });
      return;
    }

    _bootstrappedServiceType = serviceType;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _bootstrapConversation();
    });
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
              'Halo! Saya BangBot untuk layanan Antar Jemput. Kamu bisa kirim tujuan lewat chat. Jika belum punya alamat, isi Alamat Saya dulu.',
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
              'Halo! Saya BangBot untuk layanan Kurir. Tulis lokasi ambil, tujuan kirim, isi paket, atau pilih titik langsung di map.',
          suggestions: ['Kirim dokumen', 'Ambil di kantor', 'Kirim ke rumah'],
        );
      default:
        return const _ServiceContext(
          serviceType: 'nitip',
          title: 'BangBot AI - Nitip',
          subtitle: 'Mode titip belanja aktif',
          welcomeMessage:
              'Halo! Saya BangBot untuk layanan Nitip. Setelah menu siap, kamu bisa pilih titik antar custom di map.',
          suggestions: ['Mie Ayam', 'Ayam Geprek', 'Minuman dingin'],
        );
    }
  }

  Future<void> _bootstrapConversation() async {
    await ref
        .read(chatbotConversationProvider.notifier)
        .bootstrap(
          serviceType: _serviceContext.serviceType,
          welcomeMessage: _serviceContext.welcomeMessage,
        );
    _scrollToBottom();
  }

  Future<void> _sendMessage([String? presetText]) async {
    final raw = (presetText ?? _inputController.text).trim();
    if (raw.isEmpty) {
      return;
    }

    _inputController.clear();

    await ref
        .read(chatbotConversationProvider.notifier)
        .sendMessage(raw, serviceType: _serviceContext.serviceType);

    _scrollToBottom();
  }

  Future<void> _openSessionPicker() async {
    final notifier = ref.read(chatbotConversationProvider.notifier);
    await notifier.refreshSessions(serviceType: _serviceContext.serviceType);

    if (!mounted) {
      return;
    }

    final state = ref.read(chatbotConversationProvider);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final sessions = state.sessions;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pilih Sesi Chat',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                if (sessions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Belum ada sesi tersimpan untuk layanan ini.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: sessions.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: AppColors.border),
                      itemBuilder: (context, index) {
                        final session = sessions[index];
                        final isActive =
                            session.sessionId == state.sessionId?.trim();

                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 2,
                          ),
                          title: Text(
                            session.lastMessage.isEmpty
                                ? session.sessionId
                                : session.lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                          subtitle: Text(
                            'Pesan: ${session.messageCount}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: isActive
                              ? const Icon(
                                  Icons.check_circle,
                                  color: AppColors.success,
                                  size: 18,
                                )
                              : null,
                          onTap: () async {
                            Navigator.of(context).pop();
                            await notifier.selectSession(
                              session.sessionId,
                              serviceType: _serviceContext.serviceType,
                              welcomeMessage: _serviceContext.welcomeMessage,
                            );
                            if (!mounted) {
                              return;
                            }
                            _scrollToBottom();
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatbotConversationProvider);
    final isServiceMismatch = state.serviceType != _serviceContext.serviceType;
    final effectiveBusy = state.isBusy || isServiceMismatch;

    // Auto-scroll whenever the message list grows (new send / map-pin response)
    ref.listen<ChatbotConversationState>(chatbotConversationProvider, (
      previous,
      next,
    ) {
      if ((previous?.messages.length ?? 0) < next.messages.length) {
        _scrollToBottom();
      }
    });
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
            icon: const Icon(Icons.history, color: AppColors.textPrimary),
            onPressed: effectiveBusy ? null : _openSessionPicker,
          ),
        ],
      ),
      body: Column(
        children: [
          if ((state.errorMessage ?? '').isNotEmpty)
            Container(
              width: double.infinity,
              color: AppColors.cardYellow,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                state.errorMessage!,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Expanded(
            child:
                (state.isBootstrapping && state.messages.isEmpty) ||
                    isServiceMismatch
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(20),
                    children: state.messages
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
                          _buildSuggestionChip(
                            suggestion,
                            enabled: !effectiveBusy,
                          ),
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
                            onSubmitted: (_) {
                              if (effectiveBusy) {
                                return;
                              }
                              _sendMessage();
                            },
                            decoration: const InputDecoration(
                              filled: true,
                              fillColor: AppColors.background,
                              hintText: 'Ketik kebutuhan layanan...',
                              hintStyle: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(25),
                                ),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(25),
                                ),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(25),
                                ),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: EdgeInsets.symmetric(
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
                        onTap: effectiveBusy ? null : _sendMessage,
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: effectiveBusy
                                ? AppColors.primary.withValues(alpha: 0.7)
                                : AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: effectiveBusy
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

  Widget _buildSuggestionChip(String label, {required bool enabled}) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: enabled ? () => _sendMessage(label) : null,
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

  Widget _buildMessageItem(ChatbotConversationMessage message) {
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
                _buildMessageTextContent(
                  message: message,
                  textColor: textColor,
                ),
                if (message.meta != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    message.meta!,
                    style: TextStyle(color: metaColor, fontSize: 11),
                  ),
                ],
                if (message.actionHints.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final actionHint in message.actionHints)
                        OutlinedButton.icon(
                          onPressed: () => _handleActionHint(actionHint),
                          icon: Icon(
                            switch (actionHint.type) {
                              ChatbotMessageActionType.openAddresses =>
                                Icons.home_outlined,
                              ChatbotMessageActionType.openMapPicker =>
                                Icons.location_on_outlined,
                              ChatbotMessageActionType.sendPresetMessage =>
                                Icons.bolt_rounded,
                              ChatbotMessageActionType.openTrackOrder =>
                                Icons.map_outlined,
                              ChatbotMessageActionType.openActivity =>
                                Icons.receipt_long_outlined,
                            },
                            size: 16,
                          ),
                          label: Text(actionHint.label),
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

  Widget _buildMessageTextContent({
    required ChatbotConversationMessage message,
    required Color textColor,
  }) {
    if (message.isUser) {
      return Text(
        message.text,
        style: TextStyle(color: textColor, height: 1.5),
      );
    }

    final parts = _tryParseDraftMessage(message.text);
    if (parts == null) {
      return Text(
        message.text,
        style: TextStyle(color: textColor, height: 1.5),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          parts.headline,
          style: TextStyle(
            color: textColor,
            height: 1.45,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        _buildDraftField(
          label: parts.pickupLabel,
          value: parts.pickupAddress,
          textColor: textColor,
        ),
        const SizedBox(height: 8),
        _buildDraftField(
          label: 'Tujuan',
          value: parts.destinationAddress,
          textColor: textColor,
        ),
        if (parts.packageDescription != null && parts.packageDescription!.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildDraftField(
            label: 'Barang',
            value: parts.packageDescription!,
            textColor: textColor,
          ),
        ],
        if (parts.feeLine.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.cardYellow.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              parts.feeLine,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
        if (parts.instructionLine.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            parts.instructionLine,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDraftField({
    required String label,
    required String value,
    required Color textColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            height: 1.45,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  _DraftMessageParts? _tryParseDraftMessage(String raw) {
    final normalized = raw.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty) {
      return null;
    }

    final lines = normalized
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    if (lines.length < 4) {
      return null;
    }

    final pickupIndex = lines.indexWhere(
      (line) => line.toLowerCase().startsWith('jemput:') || line.toLowerCase().startsWith('ambil:'),
    );
    final destinationIndex = lines.indexWhere(
      (line) => line.toLowerCase().startsWith('tujuan:'),
    );
    final packageIndex = lines.indexWhere(
      (line) => line.toLowerCase().startsWith('barang:'),
    );
    final feeIndex = lines.indexWhere((line) {
      final lower = line.toLowerCase();
      return lower.startsWith('estimasi ongkir sementara:') ||
          lower.startsWith('ongkir:');
    });

    if (pickupIndex < 0 || destinationIndex < 0 || feeIndex < 0) {
      return null;
    }

    final introText = lines.take(pickupIndex).join('\n').trim();
    if (introText.isEmpty ||
        (!introText.toLowerCase().contains('antar jemput') && !introText.toLowerCase().contains('kurir'))) {
      return null;
    }

    final pickupAddress = lines[pickupIndex].replaceFirst(
      RegExp(r'^(Jemput|Ambil):\s*', caseSensitive: false),
      '',
    );
    final destinationAddress = lines[destinationIndex].replaceFirst(
      RegExp(r'^Tujuan:\s*', caseSensitive: false),
      '',
    );

    final packageDescription = packageIndex >= 0 ? lines[packageIndex].replaceFirst(
      RegExp(r'^Barang:\s*', caseSensitive: false),
      '',
    ) : null;

    if (pickupAddress.isEmpty || destinationAddress.isEmpty) {
      return null;
    }

    final instructionLine = feeIndex + 1 < lines.length
        ? lines.skip(feeIndex + 1).join(' ').trim()
        : '';

    return _DraftMessageParts(
      headline: introText,
      pickupLabel: lines[pickupIndex].toLowerCase().startsWith('ambil:') ? 'Ambil' : 'Jemput',
      pickupAddress: pickupAddress,
      destinationAddress: destinationAddress,
      packageDescription: packageDescription,
      feeLine: lines[feeIndex],
      instructionLine: instructionLine,
    );
  }
}

class _DraftMessageParts {
  const _DraftMessageParts({
    required this.headline,
    required this.pickupLabel,
    required this.pickupAddress,
    required this.destinationAddress,
    this.packageDescription,
    required this.feeLine,
    required this.instructionLine,
  });

  final String headline;
  final String pickupLabel;
  final String pickupAddress;
  final String destinationAddress;
  final String? packageDescription;
  final String feeLine;
  final String instructionLine;
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
