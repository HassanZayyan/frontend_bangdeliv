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
  bool _isGoogleSubmitting = false;
  bool _isPasswordVisible = false;
  bool _wasKeyboardVisible = false;
  String? _loginErrorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _emailFocusNode.addListener(_handleFieldFocusChanged);
    _passwordFocusNode.addListener(_handleFieldFocusChanged);
    _prefillLastLoginEmail();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      precacheImage(const AssetImage('assets/images/google.png'), context);
    });
  }

  void _handleFieldFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _clearLoginError() {
    if (_loginErrorMessage == null) {
      return;
    }

    setState(() {
      _loginErrorMessage = null;
    });
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
          width: 76,
          height: 76,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.white.withValues(alpha: 0.92),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Transform.scale(
            scale: 1.08,
            child: Image.asset('assets/images/logo.jpg', fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 12),
        RichText(
          text: TextSpan(
            style: GoogleFonts.leagueSpartan(
              fontSize: 42,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              height: 1,
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SizedBox(
            width: double.infinity,
            child: Text(
              'Pesan kebutuhan dan perjalananmu dengan mudah',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.white.withValues(alpha: 0.8),
                fontSize: 12.5,
                height: 1.25,
              ),
            ),
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
          SizedBox(height: isCompact ? 16 : 22),

          TextFormField(
            controller: _emailController,
            focusNode: _emailFocusNode,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            onChanged: (_) => _clearLoginError(),
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
            onChanged: (_) => _clearLoginError(),
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

          if (_loginErrorMessage != null) ...[
            _LoginErrorBanner(message: _loginErrorMessage!),
            SizedBox(height: isCompact ? 10 : 12),
          ],

          BangPrimaryButton(
            label: 'Masuk',
            isLoading: _isSubmitting,
            onPressed: _isGoogleSubmitting ? null : _handleLogin,
          ),

          SizedBox(height: isCompact ? 12 : 16),

          const _AuthDivider(label: 'atau'),

          SizedBox(height: isCompact ? 12 : 16),

          _GoogleSignInButton(
            isLoading: _isGoogleSubmitting,
            onPressed: _isSubmitting ? null : _handleGoogleLogin,
          ),

          SizedBox(height: isCompact ? 14 : 18),

          Center(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Belum punya akun? ',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                InkWell(
                  onTap: _isSubmitting || _isGoogleSubmitting
                      ? null
                      : () => context.push(AppRoutes.register),
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

    return decoded;
  }

  Future<void> _handleLogin() async {
    if (_isSubmitting || _isGoogleSubmitting) {
      return;
    }

    FocusScope.of(context).unfocus();

    final currentState = _formKey.currentState;
    if (currentState == null || !currentState.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _loginErrorMessage = null;
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

      setState(() {
        _loginErrorMessage = e.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _handleGoogleLogin() async {
    if (_isSubmitting || _isGoogleSubmitting) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isGoogleSubmitting = true;
      _loginErrorMessage = null;
    });

    try {
      await AuthService.loginWithGoogle();
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

      setState(() {
        _loginErrorMessage = e.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleSubmitting = false;
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

class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border),
          minimumSize: const Size.fromHeight(50),
          backgroundColor: AppColors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: Image.asset(
                      'assets/images/google.png',
                      fit: BoxFit.contain,
                      excludeFromSemantics: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Flexible(
                    child: Text(
                      'Masuk dengan Google',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _AuthDivider extends StatelessWidget {
  const _AuthDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.border, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.border, height: 1)),
      ],
    );
  }
}

class _LoginErrorBanner extends StatelessWidget {
  const _LoginErrorBanner({required this.message});

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
