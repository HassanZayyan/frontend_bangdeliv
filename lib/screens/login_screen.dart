import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_routes.dart';
import 'package:go_router/go_router.dart';
import '../config/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_session_provider.dart';
import '../services/auth_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _prefillLastLoginEmail();
  }

  Future<void> _prefillLastLoginEmail() async {
    final email = await AuthService.getLastLoginEmail();

    if (!mounted || email == null) {
      return;
    }

    _emailController.text = email;
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final isCompact = MediaQuery.sizeOf(context).height < 860;
    final canPop = Navigator.of(context).canPop();

    return PopScope<void>(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.go(AppRoutes.home);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: SafeArea(
          bottom: !isKeyboardOpen,
          child: Column(
            children: [
              if (!isKeyboardOpen) ...[
                // Top Header (Orange)
                Expanded(flex: 3, child: centerHeader()),
              ],

              // Bottom Card (White)
              Expanded(
                flex: isKeyboardOpen ? 1 : (isCompact ? 7 : 6),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 20 : 24,
                    vertical: isKeyboardOpen ? 16 : (isCompact ? 20 : 28),
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: isKeyboardOpen
                      ? SingleChildScrollView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          child: bottomForm(context, isCompact: isCompact),
                        )
                      : bottomForm(context, isCompact: isCompact),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget centerHeader() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ClipOval(
          child: Image.asset(
            'assets/images/logo.jpg',
            width: 100,
            height: 100,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 16),
        RichText(
          text: TextSpan(
            style: GoogleFonts.bebasNeue(fontSize: 48, letterSpacing: 2),
            children: const [
              TextSpan(
                text: 'BANG',
                style: TextStyle(color: Colors.white),
              ),
              TextSpan(
                text: ' DELIV',
                style: TextStyle(color: Colors.black),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Pesan makanan lokal, cepat & terjangkau',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.white.withValues(alpha: 0.8),
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
            style: Theme.of(context).textTheme.displayMedium,
          ),
          SizedBox(height: isCompact ? 16 : 24),

          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'Email',
              prefixIcon: Icon(
                Icons.email_outlined,
                color: AppColors.textSecondary,
              ),
            ),
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
            obscureText: !_isPasswordVisible,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleLogin(),
            decoration: InputDecoration(
              hintText: 'Password',
              prefixIcon: const Icon(
                Icons.lock_outline,
                color: AppColors.textSecondary,
              ),
              suffixIcon: IconButton(
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
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          SizedBox(height: isCompact ? 10 : 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _handleLogin,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : const Text('Masuk ->'),
            ),
          ),

          SizedBox(height: isCompact ? 14 : 24),

          Row(
            children: [
              const Expanded(child: Divider(color: AppColors.border)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'atau lanjutkan dengan',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const Expanded(child: Divider(color: AppColors.border)),
            ],
          ),

          SizedBox(height: isCompact ? 12 : 24),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Text(
                'G',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
              label: Text(
                'Masuk dengan Google',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: AppColors.textPrimary),
              ),
            ),
          ),

          SizedBox(height: isCompact ? 16 : 24),

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
                  child: const Text(
                    'Daftar Sekarang',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
