import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../models/chatbot_model.dart';
import '../models/user_profile_model.dart';
import '../providers/auth_session_provider.dart';
import '../providers/api_providers.dart';
import '../services/api_exception.dart';

class ChatbotScreen extends ConsumerStatefulWidget {
  const ChatbotScreen({super.key});

  @override
  ConsumerState<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends ConsumerState<ChatbotScreen> {
  static const double _fallbackRideFee = 5000;

  final List<_ChatMessage> _messages = <_ChatMessage>[];

  late final TextEditingController _inputController;
  late final ScrollController _scrollController;
  late final String _sessionId;
  String? _pendingCourierDraft;
  bool _isSending = false;
  bool _hasInitializedWelcome = false;
  _RideConversationState _rideConversation = const _RideConversationState(
    stage: _RideConversationStage.needPickup,
  );

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

    if (_serviceContext.serviceType == 'antar_jemput') {
      final reply = await _buildRideReply(raw);

      if (!mounted) {
        return;
      }

      setState(() {
        _messages.add(
          _ChatMessage.bot(
            text: reply.text,
            timestamp: _nowLabel(),
            meta: reply.meta,
            action: reply.action,
          ),
        );
        _isSending = false;
      });
      _scrollToBottom();
      return;
    }

    try {
      final chatbotService = ref.read(chatbotApiServiceProvider);
      final result = await chatbotService.sendMessage(
        outboundMessage,
        serviceType: _serviceContext.serviceType,
        sessionId: _sessionId,
      );

      _updateCourierDraftAfterResponse(result, outboundMessage);

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

  String _composeCourierOutboundMessage(String rawMessage) {
    if (_serviceContext.serviceType != 'kurir') {
      return rawMessage;
    }

    final current = rawMessage.trim();
    if (current.isEmpty) {
      return current;
    }

    if (_isCourierResetIntent(current)) {
      _pendingCourierDraft = null;
      return current;
    }

    final previous = _pendingCourierDraft?.trim();
    if (previous == null || previous.isEmpty) {
      return current;
    }

    final normalizedPrevious = previous.toLowerCase();
    final normalizedCurrent = current.toLowerCase();
    if (normalizedPrevious.contains(normalizedCurrent)) {
      return previous;
    }

    return '$previous\n$current';
  }

  bool _isCourierResetIntent(String text) {
    final normalized = text.trim().toLowerCase();
    return normalized == 'reset' ||
        normalized == 'ulang' ||
        normalized == 'batal' ||
        normalized == 'order baru';
  }

  void _updateCourierDraftAfterResponse(ChatbotResult result, String outbound) {
    if (_serviceContext.serviceType != 'kurir') {
      return;
    }

    if (result.isOrderCreated) {
      _pendingCourierDraft = null;
      return;
    }

    final validation = result.validation;
    if (validation == null) {
      _pendingCourierDraft = null;
      return;
    }

    if (validation.isValidOrder) {
      _pendingCourierDraft = null;
      return;
    }

    _pendingCourierDraft = outbound.trim();
  }

  _ChatMessageAction? _buildMessageAction(ChatbotResult result) {
    if (_serviceContext.serviceType != 'kurir') {
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
              reason.toLowerCase().contains('alamat saya sebagai default'),
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

  Future<_RideReply> _buildRideReply(String userInput) async {
    var session = ref.read(authSessionProvider);
    final profile = session.profile;
    final displayName = _resolveDisplayName(profile?.name);
    var pickupAddressModel = _resolvePickupAddressModel(session);
    var pickupAddress = pickupAddressModel?.displayAddress.trim();

    if (pickupAddress == null) {
      await ref.read(authSessionProvider.notifier).refreshSession();
      session = ref.read(authSessionProvider);
      pickupAddressModel = _resolvePickupAddressModel(session);
      pickupAddress = pickupAddressModel?.displayAddress.trim();
    }

    if (pickupAddress == null) {
      _rideConversation = const _RideConversationState(
        stage: _RideConversationStage.needPickup,
      );
      return _RideReply(
        text:
            'Sebelum lanjut Antar Jemput, alamat penjemputan wajib diisi dulu di menu Alamat Saya pada profil. Setelah itu, kirim lagi tujuanmu, misalnya: "Saya mau pergi ke Jalan XXX".',
        meta: 'Layanan: antar_jemput • Butuh alamat profil',
        action: _buildRideAddressAction(),
      );
    }

    var nextConversation = _rideConversation.copyWith(
      pickupAddress: pickupAddress,
    );
    final normalizedInput = userInput.trim();

    if (_isRideResetCommand(normalizedInput)) {
      nextConversation = nextConversation.copyWith(
        stage: _RideConversationStage.needDestination,
        clearDestination: true,
      );
      _rideConversation = nextConversation;
      return _RideReply(
        text:
            'Baik $displayName, tujuan sebelumnya saya reset. Alamat jemput kamu di $pickupAddress. Sekarang kirim tujuan baru, misalnya: "Antar ke Jalan XXX".',
        meta: 'Layanan: antar_jemput • Tujuan direset',
      );
    }

    if (_isRideConfirmCommand(normalizedInput)) {
      if (nextConversation.stage == _RideConversationStage.readyConfirm &&
          nextConversation.destination != null) {
        final currentDestination = nextConversation.destination!;

        if (pickupAddressModel == null) {
          _rideConversation = const _RideConversationState(
            stage: _RideConversationStage.needPickup,
          );
          return _RideReply(
            text:
                'Alamat jemput belum terdeteksi. Buka Alamat Saya dulu, lalu kirim lagi tujuanmu.',
            meta: 'Layanan: antar_jemput • Butuh alamat profil',
            action: _buildRideAddressAction(),
          );
        }

        try {
          final rideOrderApiService = ref.read(rideOrderApiServiceProvider);
          final submission = await rideOrderApiService.createRideOrder(
            addressId: pickupAddressModel.id,
            destinationAddress: currentDestination,
            notes: 'Dibuat dari BangBot Antar Jemput.',
          );

          nextConversation = nextConversation.copyWith(
            stage: _RideConversationStage.confirmed,
          );
          _rideConversation = nextConversation;

          final orderCode = (submission.orderNumber ?? '').trim().isNotEmpty
              ? submission.orderNumber!.trim()
              : '#${submission.orderId}';
          final feeLabel = _formatCurrency(
            submission.deliveryFee ?? _fallbackRideFee,
          );

          return _RideReply(
            text:
                'Siap $displayName, order Antar Jemput kamu sudah dikonfirmasi dan tersimpan. Kode order: $orderCode. Jemput di $pickupAddress dan tujuan di $currentDestination.\nOngkir: $feeLabel.',
            meta: 'Layanan: antar_jemput • Pesanan dikonfirmasi',
          );
        } on ApiException catch (error) {
          final normalizedMessage = error.message.toLowerCase();
          if (normalizedMessage.contains('tidak valid') ||
              normalizedMessage.contains('tidak ditemukan')) {
            nextConversation = nextConversation.copyWith(
              stage: _RideConversationStage.needDestination,
              clearDestination: true,
            );
            _rideConversation = nextConversation;
            return _RideReply(
              text:
                  'Tujuan sebelumnya tidak valid di peta. Kirim ulang tujuan yang lebih spesifik, misalnya: "Antar ke Jalan Sudirman No 10 Jakarta".',
              meta: 'Layanan: antar_jemput • Tujuan tidak valid',
            );
          }

          _rideConversation = nextConversation;
          return _RideReply(
            text:
                'Konfirmasi gagal: ${error.message}. Coba ketik "Konfirmasi" lagi atau "Ubah Tujuan".',
            meta: 'Layanan: antar_jemput • Gagal membuat order',
          );
        } catch (_) {
          _rideConversation = nextConversation;
          return const _RideReply(
            text:
                'Konfirmasi gagal karena gangguan koneksi. Coba ketik "Konfirmasi" lagi.',
            meta: 'Layanan: antar_jemput • Gagal membuat order',
          );
        }
      }

      nextConversation = nextConversation.copyWith(
        stage: _RideConversationStage.needDestination,
      );
      _rideConversation = nextConversation;
      return _RideReply(
        text:
            'Alamat tujuan belum ada. Alamat jemput kamu di $pickupAddress. Kirim dulu tujuanmu, misalnya: "Antar ke Jalan XXX".',
        meta: 'Layanan: antar_jemput • Menunggu tujuan',
      );
    }

    final destination = _extractRideDestination(userInput);
    if (destination != null) {
      try {
        final rideOrderApiService = ref.read(rideOrderApiServiceProvider);
        final validatedDestination = await rideOrderApiService
            .validateDestinationAddress(destinationAddress: destination);
        final normalizedDestination =
            validatedDestination.formattedAddress.isEmpty
            ? destination
            : validatedDestination.formattedAddress;

        nextConversation = nextConversation.copyWith(
          stage: _RideConversationStage.readyConfirm,
          destination: normalizedDestination,
        );
        _rideConversation = nextConversation;
        final feeLabel = _formatCurrency(_fallbackRideFee);
        return _RideReply(
          text:
              'Baik $displayName, alamat jemput kamu di $pickupAddress dan tujuan kamu di $normalizedDestination.\nEstimasi ongkir sementara: $feeLabel (kalkulasi detail menyusul).\nKetik "Konfirmasi" untuk lanjut atau "Ubah Tujuan" untuk ganti tujuan.',
          meta: 'Layanan: antar_jemput • Draft perjalanan',
        );
      } on ApiException catch (error) {
        final normalizedMessage = error.message.toLowerCase();
        final isInvalidDestination =
            normalizedMessage.contains('tidak valid') ||
            normalizedMessage.contains('tidak ditemukan');

        nextConversation = nextConversation.copyWith(
          stage: _RideConversationStage.needDestination,
          clearDestination: true,
        );
        _rideConversation = nextConversation;

        if (isInvalidDestination) {
          return _RideReply(
            text:
                'Tujuan "$destination" tidak ditemukan di peta. Coba kirim alamat yang lebih lengkap, misalnya: "Antar ke Jalan Sudirman No 10 Jakarta".',
            meta: 'Layanan: antar_jemput • Tujuan tidak valid',
          );
        }

        return _RideReply(
          text:
              'Saya belum bisa memvalidasi tujuan sekarang (${error.message}). Coba ulangi dengan alamat yang lebih lengkap.',
          meta: 'Layanan: antar_jemput • Validasi tujuan gagal',
        );
      } catch (_) {
        nextConversation = nextConversation.copyWith(
          stage: _RideConversationStage.needDestination,
          clearDestination: true,
        );
        _rideConversation = nextConversation;
        return const _RideReply(
          text:
              'Gagal memvalidasi tujuan karena gangguan jaringan. Coba kirim ulang tujuanmu.',
          meta: 'Layanan: antar_jemput • Validasi tujuan gagal',
        );
      }
    }

    if (nextConversation.stage == _RideConversationStage.readyConfirm &&
        nextConversation.destination != null) {
      _rideConversation = nextConversation;
      final feeLabel = _formatCurrency(_fallbackRideFee);
      return _RideReply(
        text:
            'Draft perjalananmu: jemput di $pickupAddress dan tujuan di ${nextConversation.destination}.\nEstimasi ongkir sementara: $feeLabel (kalkulasi detail menyusul).\nKetik "Konfirmasi" untuk lanjut atau "Ubah Tujuan" untuk ganti tujuan.',
        meta: 'Layanan: antar_jemput • Menunggu konfirmasi',
      );
    }

    if (nextConversation.stage == _RideConversationStage.confirmed) {
      nextConversation = nextConversation.copyWith(
        stage: _RideConversationStage.needDestination,
        clearDestination: true,
      );
      _rideConversation = nextConversation;
      return _RideReply(
        text:
            'Perjalanan sebelumnya sudah dikonfirmasi. Kalau mau buat perjalanan baru, kirim tujuan baru kamu, misalnya: "Antar ke Jalan XXX".',
        meta: 'Layanan: antar_jemput • Menunggu tujuan baru',
      );
    }

    nextConversation = nextConversation.copyWith(
      stage: _RideConversationStage.needDestination,
    );
    _rideConversation = nextConversation;
    final feeLabel = _formatCurrency(_fallbackRideFee);
    return _RideReply(
      text:
          'Siap $displayName. Alamat jemput kamu di $pickupAddress. Estimasi ongkir awal: $feeLabel (sementara). Sekarang kirim alamat tujuanmu, misalnya: "Antar ke Jalan XXX".',
      meta: 'Layanan: antar_jemput • Menunggu tujuan',
    );
  }

  Future<void> _openAddressManager() async {
    if (_isSending) {
      return;
    }

    await context.push<bool>(AppRoutes.addresses);
    if (!mounted) {
      return;
    }

    await ref.read(authSessionProvider.notifier).refreshSession();
    if (!mounted) {
      return;
    }

    final session = ref.read(authSessionProvider);
    final pickupAddress = _resolvePickupAddress(session);

    setState(() {
      if (pickupAddress == null) {
        _rideConversation = const _RideConversationState(
          stage: _RideConversationStage.needPickup,
        );
        _messages.add(
          _ChatMessage.bot(
            text:
                'Alamat jemput belum terdeteksi. Pastikan kamu sudah menyimpan alamat utama di menu Alamat Saya, lalu kembali ke chat ini.',
            timestamp: _nowLabel(),
            meta: 'Layanan: antar_jemput • Alamat profil belum tersedia',
          ),
        );
      } else {
        _rideConversation = _rideConversation.copyWith(
          stage: _RideConversationStage.needDestination,
          pickupAddress: pickupAddress,
          clearDestination: true,
        );
        _messages.add(
          _ChatMessage.bot(
            text:
                'Alamat jemput sudah tersinkron: $pickupAddress. Sekarang kirim tujuanmu, misalnya "Antar ke Jalan XXX".',
            timestamp: _nowLabel(),
            meta: 'Layanan: antar_jemput • Alamat profil tersinkron',
          ),
        );
      }
    });

    _scrollToBottom();
  }

  String _resolveDisplayName(String? rawName) {
    final name = (rawName ?? '').trim();
    return name.isEmpty ? 'Kak' : name;
  }

  SavedAddressModel? _resolvePickupAddressModel(AuthSessionState session) {
    final addresses = session.profile?.addresses ?? const <SavedAddressModel>[];

    for (final address in addresses) {
      final value = address.displayAddress.trim();
      if (address.isDefault && value.isNotEmpty) {
        return address;
      }
    }

    for (final address in addresses) {
      final value = address.displayAddress.trim();
      if (value.isNotEmpty) {
        return address;
      }
    }

    return null;
  }

  String? _resolvePickupAddress(AuthSessionState session) {
    final pickup = _resolvePickupAddressModel(session);
    final value = pickup?.displayAddress.trim();
    if (value == null || value.isEmpty) {
      return null;
    }

    return value;
  }

  _ChatMessageAction _buildRideAddressAction() {
    return _ChatMessageAction(
      label: 'Isi Alamat Saya',
      onTap: () {
        _openAddressManager();
      },
    );
  }

  String _formatCurrency(double amount) {
    final rounded = amount.round().toString();
    final formatted = rounded.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );

    return 'Rp $formatted';
  }

  String? _extractRideDestination(String rawMessage) {
    final input = rawMessage.trim();
    if (input.isEmpty || _isRideControlCommand(input)) {
      return null;
    }

    final patterns = <RegExp>[
      RegExp(
        r'(?:pergi\s+ke|menuju\s+ke|mau\s+ke|antar(?:kan)?\s+ke|drop\s?off\s+(?:di|ke)|tujuan(?:nya)?\s*(?:di|ke)?)\s+(.+)$',
        caseSensitive: false,
      ),
      RegExp(r'\bke\s+(.+)$', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(input);
      if (match == null) {
        continue;
      }
      final normalized = _normalizeRideLocation(match.group(1));
      if (normalized != null) {
        return normalized;
      }
    }

    if (_looksLikeLocation(input)) {
      return _normalizeRideLocation(input);
    }

    return null;
  }

  bool _isRideControlCommand(String text) {
    return _isRideConfirmCommand(text) || _isRideResetCommand(text);
  }

  bool _isRideConfirmCommand(String text) {
    final normalized = text.trim().toLowerCase();
    return normalized == 'konfirmasi' ||
        normalized == 'lanjut' ||
        normalized == 'oke' ||
        normalized == 'ok' ||
        normalized == 'siap' ||
        normalized == 'jemput sekarang';
  }

  bool _isRideResetCommand(String text) {
    final normalized = text.trim().toLowerCase();
    return normalized == 'ubah tujuan' ||
        normalized == 'ganti tujuan' ||
        normalized == 'reset tujuan';
  }

  String? _normalizeRideLocation(String? rawLocation) {
    final cleaned = (rawLocation ?? '')
        .replaceAll(RegExp(r'^[\s,.:;\-]+'), '')
        .replaceAll(RegExp(r'[\s,.:;!?\-]+$'), '')
        .trim();

    if (cleaned.length < 4) {
      return null;
    }

    return cleaned;
  }

  bool _looksLikeLocation(String text) {
    final normalized = text.toLowerCase();
    const locationHints = <String>[
      'jalan',
      'jl',
      'gang',
      'gg',
      'blok',
      'no',
      'stasiun',
      'bandara',
      'terminal',
      'mall',
      'rumah',
      'apartemen',
      'kampus',
      'kantor',
      'kecamatan',
      'kelurahan',
    ];

    for (final hint in locationHints) {
      if (normalized.contains(hint)) {
        return true;
      }
    }

    return RegExp(r'\d').hasMatch(normalized);
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

enum _RideConversationStage {
  needPickup,
  needDestination,
  readyConfirm,
  confirmed,
}

class _RideConversationState {
  final _RideConversationStage stage;
  final String? pickupAddress;
  final String? destination;

  const _RideConversationState({
    required this.stage,
    this.pickupAddress,
    this.destination,
  });

  _RideConversationState copyWith({
    _RideConversationStage? stage,
    String? pickupAddress,
    bool clearPickupAddress = false,
    String? destination,
    bool clearDestination = false,
  }) {
    return _RideConversationState(
      stage: stage ?? this.stage,
      pickupAddress: clearPickupAddress
          ? null
          : (pickupAddress ?? this.pickupAddress),
      destination: clearDestination ? null : (destination ?? this.destination),
    );
  }
}

class _RideReply {
  final String text;
  final String meta;
  final _ChatMessageAction? action;

  const _RideReply({required this.text, required this.meta, this.action});
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
