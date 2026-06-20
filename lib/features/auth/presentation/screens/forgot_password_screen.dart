import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/app_colors.dart';
import '../../../../config/app_routes.dart';
import '../../../../widgets/bang_ui.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with WidgetsBindingObserver {
  final _emailController = TextEditingController();
  final _emailFocusNode = FocusNode();
  bool _wasKeyboardVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _emailFocusNode.addListener(_handleFieldFocusChanged);
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

  void _syncKeyboardVisibility(bool isKeyboardOpen) {
    _wasKeyboardVisible = isKeyboardOpen;
  }

  bool get _hasFocusedField => _emailFocusNode.hasFocus;

  void _unfocusWhenKeyboardClosed() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || MediaQuery.viewInsetsOf(context).bottom > 0) {
        return;
      }

      if (_hasFocusedField) {
        FocusScope.of(context).unfocus();
      }
    });
  }

  void _handleBackNavigation() {
    if (_hasFocusedField || MediaQuery.viewInsetsOf(context).bottom > 0) {
      FocusScope.of(context).unfocus();
      _unfocusWhenKeyboardClosed();
      return;
    }

    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    context.go(AppRoutes.login);
  }

  double _headerHeight(BuildContext context, bool isKeyboardOpen) {
    if (isKeyboardOpen) {
      return 0;
    }

    final screenHeight = MediaQuery.sizeOf(context).height;
    return screenHeight < 760 ? 108 : 132;
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final isCompact = MediaQuery.sizeOf(context).height < 860;
    _syncKeyboardVisibility(isKeyboardOpen);

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }

        _handleBackNavigation();
      },
      child: AuthKeyboardSafeScaffold(
        topBarHeight: 56,
        topBar: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: _handleBackNavigation,
            ),
          ),
        ),
        header: _buildHeader(context),
        headerHeightBuilder: _headerHeight,
        cardPaddingBuilder: (context, isKeyboardOpen) {
          return EdgeInsets.symmetric(
            horizontal: isCompact ? 20 : 24,
            vertical: isKeyboardOpen ? 16 : (isCompact ? 20 : 28),
          );
        },
        child: _buildForm(context),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Pulihkan Akun',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Masukkan email atau WhatsApp terdaftar.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.white.withValues(alpha: 0.86),
            fontSize: 13,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Kami akan mengirimkan instruksi untuk mengatur ulang password Anda.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        TextField(
          key: const ValueKey('forgot-password-identity-field'),
          controller: _emailController,
          focusNode: _emailFocusNode,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          decoration: InputDecoration(
            hintText: 'Email atau Nomor WhatsApp',
            labelText: _emailFocusNode.hasFocus
                ? 'Email atau Nomor WhatsApp'
                : null,
            floatingLabelBehavior: FloatingLabelBehavior.always,
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              // Simulasi pengiriman tautan reset
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Instruksi pemulihan telah dikirim!'),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
              // Kembali ke halaman login setelah beberapa saat
              Future.delayed(const Duration(seconds: 2), () {
                if (context.mounted) {
                  context.pop();
                }
              });
            },
            child: const Text(
              'Kirim Tautan Pemulihan',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _emailFocusNode
      ..removeListener(_handleFieldFocusChanged)
      ..dispose();
    _emailController.dispose();
    super.dispose();
  }
}
