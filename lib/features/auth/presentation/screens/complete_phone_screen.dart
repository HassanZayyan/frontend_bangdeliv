import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_routes.dart';
import '../../../../services/auth_service.dart';
import '../../../../widgets/bang_ui.dart';
import '../../application/auth_session_provider.dart';

class CompletePhoneScreen extends ConsumerStatefulWidget {
  const CompletePhoneScreen({super.key});

  @override
  ConsumerState<CompletePhoneScreen> createState() =>
      _CompletePhoneScreenState();
}

class _CompletePhoneScreenState extends ConsumerState<CompletePhoneScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _phoneFocusNode = FocusNode();
  bool _isSubmitting = false;
  bool _wasKeyboardVisible = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _phoneFocusNode.addListener(_handleFieldFocusChanged);
  }

  void _handleFieldFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!mounted) {
      return;
    }

    final isKeyboardVisible = View.of(context).viewInsets.bottom > 0;
    final didKeyboardClose = _wasKeyboardVisible && !isKeyboardVisible;
    _wasKeyboardVisible = isKeyboardVisible;

    if (didKeyboardClose) {
      _unfocusWhenKeyboardClosed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final isCompact = MediaQuery.sizeOf(context).height < 820;
    _wasKeyboardVisible = isKeyboardOpen;

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
        child: _buildForm(context, isCompact: isCompact),
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
              semanticLabel: 'Logo BangDeliv',
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Lengkapi Nomor',
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

  Widget _buildForm(BuildContext context, {required bool isCompact}) {
    final profile = ref.watch(authSessionProvider).profile;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nomor WhatsApp Aktif',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            profile?.email ?? 'Akun Google',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: isCompact ? 18 : 24),
          TextFormField(
            key: const ValueKey('complete-phone-field'),
            controller: _phoneController,
            focusNode: _phoneFocusNode,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleSubmit(),
            onChanged: (_) => _clearError(),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            decoration: InputDecoration(
              hintText: 'Nomor WhatsApp',
              labelText: _phoneFocusNode.hasFocus ? 'Nomor WhatsApp' : null,
              floatingLabelBehavior: FloatingLabelBehavior.always,
            ),
            validator: (value) {
              final phone = value?.trim() ?? '';
              if (phone.isEmpty) {
                return 'Nomor WhatsApp wajib diisi';
              }
              final normalized = phone.replaceAll(RegExp(r'[^0-9+]'), '');
              if (!RegExp(r'^\+?[0-9]{10,15}$').hasMatch(normalized)) {
                return 'Format nomor WhatsApp tidak valid';
              }
              return null;
            },
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            _CompletePhoneErrorBanner(message: _errorMessage!),
          ],
          SizedBox(height: isCompact ? 22 : 30),
          BangPrimaryButton(
            label: 'Simpan Nomor',
            isLoading: _isSubmitting,
            onPressed: _handleSubmit,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _isSubmitting ? null : _handleLogout,
              child: const Text(
                'Keluar dari akun ini',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _clearError() {
    if (_errorMessage == null) {
      return;
    }

    setState(() {
      _errorMessage = null;
    });
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) {
      return;
    }

    FocusScope.of(context).unfocus();
    final currentState = _formKey.currentState;
    if (currentState == null || !currentState.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final profile = await AuthService.completePhone(
        phone: _phoneController.text.trim(),
      );
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
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
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

  void _unfocusWhenKeyboardClosed() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || MediaQuery.viewInsetsOf(context).bottom > 0) {
        return;
      }

      if (_phoneFocusNode.hasFocus) {
        FocusScope.of(context).unfocus();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _phoneFocusNode
      ..removeListener(_handleFieldFocusChanged)
      ..dispose();
    _phoneController.dispose();
    super.dispose();
  }
}

class _CompletePhoneErrorBanner extends StatelessWidget {
  const _CompletePhoneErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.32)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.error,
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
