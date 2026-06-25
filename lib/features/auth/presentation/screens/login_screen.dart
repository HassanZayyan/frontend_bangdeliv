import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/app_routes.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../application/auth_session_provider.dart';
import '../../../../services/auth_service.dart';
import '../../../../widgets/bang_ui.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  bool _isSubmitting = false;
  bool _isPasswordVisible = false;
  bool _wasKeyboardVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _emailFocusNode.addListener(_handleFieldFocusChanged);
    _passwordFocusNode.addListener(_handleFieldFocusChanged);
    _prefillLastLoginEmail();
  }

  void _handleFieldFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _prefillLastLoginEmail() async {
    final email = await AuthService.getLastLoginEmail();

    if (!mounted || email == null) {
      return;
    }

    _emailController.text = email;
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        if (_hasFocusedField && MediaQuery.viewInsetsOf(context).bottom == 0) {
          FocusScope.of(context).unfocus();
        }
      });
    }
  }

  void _syncKeyboardVisibility(bool isKeyboardOpen) {
    _wasKeyboardVisible = isKeyboardOpen;
  }

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
        header: centerHeader(),
        headerHeightBuilder: _headerHeight,
        cardPaddingBuilder: (context, isKeyboardOpen) {
          return EdgeInsets.symmetric(
            horizontal: isCompact ? 20 : 24,
            vertical: isKeyboardOpen ? 16 : (isCompact ? 20 : 28),
          );
        },
        child: bottomForm(context, isCompact: isCompact),
      ),
    );
  }

  double _headerHeight(BuildContext context, bool isKeyboardOpen) {
    if (isKeyboardOpen) {
      return 0;
    }

    final screenHeight = MediaQuery.sizeOf(context).height;
    return (screenHeight * 0.32).clamp(190.0, 285.0);
  }

  Widget centerHeader() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 96,
          height: 96,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset('assets/images/logo.jpg', fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 14),
        RichText(
          text: TextSpan(
            style: GoogleFonts.inter(
              fontSize: 40,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
            children: [
              const TextSpan(
                text: 'BANG',
                style: TextStyle(color: Colors.white),
              ),
              TextSpan(
                text: ' DELIV',
                style: const TextStyle(color: AppColors.darkBlue),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Pesan kebutuhan dan perjalananmu dengan mudah',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.white.withValues(alpha: 0.8),
            fontSize: 12.5,
          ),
        ),
      ],
    );
  }

  Widget bottomForm(BuildContext context, {required bool isCompact}) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Masuk ke Akun',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontSize: 18),
          ),
          SizedBox(height: isCompact ? 16 : 24),

          TextFormField(
            controller: _emailController,
            focusNode: _emailFocusNode,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            decoration: _fieldDecoration('Email', _emailFocusNode),
            validator: (value) {
              final email = value?.trim() ?? '';
              if (email.isEmpty) {
                return 'Email wajib diisi';
              }
              if (!_isValidEmail(email)) {
                return 'Format email tidak valid';
              }
              return null;
            },
          ),
          SizedBox(height: isCompact ? 12 : 16),

          TextFormField(
            controller: _passwordController,
            focusNode: _passwordFocusNode,
            obscureText: !_isPasswordVisible,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleLogin(),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            decoration: _fieldDecoration(
              'Password',
              _passwordFocusNode,
              suffixIcon: IconButton(
                iconSize: 20,
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  color: AppColors.textSecondary,
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              ),
            ),
            validator: (value) {
              final password = value ?? '';
              if (password.isEmpty) {
                return 'Password wajib diisi';
              }
              if (password.length < 8) {
                return 'Password minimal 8 karakter';
              }
              return null;
            },
            ),

          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                context.push(AppRoutes.forgotPassword);
              },
              child: const Text(
                'Lupa password?',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          SizedBox(height: isCompact ? 10 : 16),

          BangPrimaryButton(
            label: 'Masuk',
            isLoading: _isSubmitting,
            onPressed: _handleLogin,
          ),

          SizedBox(height: isCompact ? 16 : 22),

          Center(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Belum punya akun? ',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                InkWell(
                  onTap: () {
                    context.push(AppRoutes.register);
                  },
                  child: Text(
                    'Daftar Sekarang',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  bool get _hasFocusedField =>
      _emailFocusNode.hasFocus || _passwordFocusNode.hasFocus;

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

    context.go(AppRoutes.home);
  }

  InputDecoration _fieldDecoration(
    String label,
    FocusNode focusNode, {
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: label,
      labelText: focusNode.hasFocus ? label : null,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      suffixIcon: suffixIcon,
    );
  }

  String? _resolveIntendedRoute() {
    final returnTo = GoRouterState.of(context).uri.queryParameters['returnTo'];
    if (returnTo == null || returnTo.trim().isEmpty) {
      return null;
    }

    final decoded = Uri.decodeComponent(returnTo).trim();
    if (!decoded.startsWith('/')) {
      return null;
    }

    if (decoded.startsWith(AppRoutes.login) || decoded == AppRoutes.splash) {
      return null;
    }

    if (_shouldRedirectHomeAfterLogin(decoded)) {
      return AppRoutes.home;
    }

    return decoded;
  }

  bool _shouldRedirectHomeAfterLogin(String route) {
    return route == AppRoutes.activity ||
        route == AppRoutes.history ||
        route == AppRoutes.profile;
  }

  Future<void> _handleLogin() async {
    if (_isSubmitting) {
      return;
    }

    final currentState = _formKey.currentState;
    if (currentState == null || !currentState.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await AuthService.loginWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      await ref.read(authSessionProvider.notifier).handleLoginSuccess();

      if (!mounted) {
        return;
      }

      final intendedRoute = _resolveIntendedRoute();
      if (intendedRoute != null) {
        context.go(intendedRoute);
      } else {
        context.go(AppRoutes.splash);
      }
    } on AuthException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red.shade600,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _emailFocusNode
      ..removeListener(_handleFieldFocusChanged)
      ..dispose();
    _passwordFocusNode
      ..removeListener(_handleFieldFocusChanged)
      ..dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
