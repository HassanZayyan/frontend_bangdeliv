import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_routes.dart';
import '../../../../services/auth_service.dart';
import '../../../../widgets/bang_ui.dart';
import '../../application/auth_session_provider.dart';

/// Verifikasi akun lewat kode OTP 6 digit yang dikirim ke email.
///
/// Layar ini dipaksa tampil oleh redirect router selama profil masih
/// menandai `requiresPhoneVerification`.
class VerifyOtpScreen extends ConsumerStatefulWidget {
  const VerifyOtpScreen({super.key});

  @override
  ConsumerState<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends ConsumerState<VerifyOtpScreen> {
  static const int _codeLength = 6;

  final _codeController = TextEditingController();
  final _codeFocusNode = FocusNode();

  Timer? _resendTimer;
  int _resendCountdown = 0;
  bool _isSending = false;
  bool _isVerifying = false;
  String? _errorMessage;
  String? _infoMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestCode(isResend: false);
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _codeController.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  void _startResendCountdown(int seconds) {
    _resendTimer?.cancel();
    if (seconds <= 0) {
      setState(() => _resendCountdown = 0);
      return;
    }

    setState(() => _resendCountdown = seconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _resendCountdown -= 1;
        if (_resendCountdown <= 0) {
          _resendCountdown = 0;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _requestCode({required bool isResend}) async {
    if (_isSending) {
      return;
    }

    setState(() {
      _isSending = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      final result = await AuthService.sendPhoneOtp();

      if (!mounted) {
        return;
      }

      if (result.alreadyVerified) {
        // Nomor sudah terverifikasi di sisi server (mis. dari perangkat lain).
        await ref.read(authSessionProvider.notifier).refreshSession();
        if (mounted) {
          context.go(AppRoutes.splash);
        }
        return;
      }

      _startResendCountdown(result.resendAvailableIn);
      setState(() {
        _infoMessage = isResend
            ? 'Kode baru sudah dikirim ke email Anda.'
            : 'Kode verifikasi dikirim ke email Anda.';
      });
    } on OtpCooldownException catch (e) {
      if (!mounted) {
        return;
      }

      _startResendCountdown(e.retryAfterSeconds);
      setState(() => _errorMessage = e.message);
    } on AuthException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _handleVerify() async {
    if (_isVerifying) {
      return;
    }

    final code = _codeController.text.trim();
    if (code.length != _codeLength) {
      setState(() => _errorMessage = 'Masukkan $_codeLength digit kode OTP.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isVerifying = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      final profile = await AuthService.verifyPhoneOtp(code: code);
      ref.read(authSessionProvider.notifier).syncProfile(profile);

      if (!mounted) {
        return;
      }

      context.go(AppRoutes.splash);
    } on AuthException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = e.message;
        _codeController.clear();
      });
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  Future<void> _handleLogout() async {
    await ref.read(authSessionProvider.notifier).logout();

    if (!mounted) {
      return;
    }

    context.go(AppRoutes.login);
  }

  /// Menyamarkan email agar aman ditampilkan: bu••••@gmail.com.
  String _maskEmail(String email) {
    final trimmed = email.trim();
    final atIndex = trimmed.indexOf('@');
    if (atIndex <= 0) {
      return trimmed;
    }

    final local = trimmed.substring(0, atIndex);
    final domain = trimmed.substring(atIndex);
    if (local.length <= 2) {
      return '$local$domain';
    }

    final prefix = local.substring(0, 2);
    return '$prefix${'•' * (local.length - 2)}$domain';
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).height < 820;
    final email = ref.watch(authSessionProvider).profile?.email ?? '';

    return PopScope<void>(
      canPop: false,
      child: AuthKeyboardSafeScaffold(
        header: _buildHeader(context),
        headerHeightBuilder: (context, isKeyboardOpen) {
          if (isKeyboardOpen) {
            return 0;
          }

          final screenHeight = MediaQuery.sizeOf(context).height;
          return (screenHeight * 0.28).clamp(160.0, 230.0);
        },
        cardPaddingBuilder: (context, isKeyboardOpen) {
          return EdgeInsets.symmetric(
            horizontal: isCompact ? 20 : 24,
            vertical: isKeyboardOpen ? 18 : (isCompact ? 22 : 30),
          );
        },
        child: _buildBody(context, isCompact: isCompact, email: email),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 84,
          height: 84,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: AppColors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/logo.jpg',
              fit: BoxFit.cover,
              semanticLabel: 'Logo Bang Deliv',
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Verifikasi Email',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required bool isCompact,
    required String email,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Masukkan Kode Verifikasi',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
        ),
        const SizedBox(height: 8),
        Text(
          email.isEmpty
              ? 'Kode dikirim ke email Anda.'
              : 'Kode 6 digit dikirim ke ${_maskEmail(email)} lewat email.',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
        SizedBox(height: isCompact ? 18 : 24),
        _buildCodeInput(),
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          _VerifyOtpBanner(message: _errorMessage!, isError: true),
        ],
        if (_errorMessage == null && _infoMessage != null) ...[
          const SizedBox(height: 12),
          _VerifyOtpBanner(message: _infoMessage!, isError: false),
        ],
        SizedBox(height: isCompact ? 22 : 30),
        BangPrimaryButton(
          label: 'Verifikasi',
          isLoading: _isVerifying,
          onPressed: _handleVerify,
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: (_resendCountdown > 0 || _isSending || _isVerifying)
                ? null
                : () => _requestCode(isResend: true),
            child: Text(
              _resendCountdown > 0
                  ? 'Kirim ulang kode dalam $_resendCountdown detik'
                  : 'Kirim Ulang Kode',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: _isVerifying ? null : _handleLogout,
            child: const Text(
              'Keluar dari akun ini',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  /// Enam kotak digit yang digerakkan satu field tersembunyi.
  Widget _buildCodeInput() {
    return Stack(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(_codeLength, (index) {
            final code = _codeController.text;
            final hasDigit = index < code.length;
            final isNext = index == code.length && _codeFocusNode.hasFocus;

            return Container(
              key: ValueKey('otp-box-$index'),
              width: 46,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isNext
                      ? AppColors.primary
                      : AppColors.textSecondary.withValues(alpha: 0.32),
                  width: isNext ? 1.8 : 1,
                ),
              ),
              child: Text(
                hasDigit ? code[index] : '',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }),
        ),
        Positioned.fill(
          child: Opacity(
            opacity: 0,
            child: TextField(
              key: const ValueKey('otp-hidden-field'),
              controller: _codeController,
              focusNode: _codeFocusNode,
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              maxLength: _codeLength,
              showCursor: false,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(_codeLength),
              ],
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
              ),
              onChanged: (value) {
                setState(() => _errorMessage = null);
                if (value.length == _codeLength) {
                  _handleVerify();
                }
              },
              onSubmitted: (_) => _handleVerify(),
            ),
          ),
        ),
      ],
    );
  }
}

class _VerifyOtpBanner extends StatelessWidget {
  const _VerifyOtpBanner({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.error : AppColors.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.info_outline_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
