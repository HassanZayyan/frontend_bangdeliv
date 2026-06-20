import 'package:flutter/material.dart';
import '../../../../config/app_routes.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/app_colors.dart';
import '../../../../services/auth_service.dart';
import '../../../../widgets/bang_ui.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _waController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _waFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  bool _isSubmitting = false;
  bool _isPasswordVisible = false;
  bool _wasKeyboardVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _nameFocusNode.addListener(_handleFieldFocusChanged);
    _waFocusNode.addListener(_handleFieldFocusChanged);
    _emailFocusNode.addListener(_handleFieldFocusChanged);
    _passwordFocusNode.addListener(_handleFieldFocusChanged);
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

  double _headerHeight(BuildContext context, bool isKeyboardOpen) {
    if (isKeyboardOpen) {
      return 0;
    }

    final screenHeight = MediaQuery.sizeOf(context).height;
    return screenHeight < 760 ? 108 : 132;
  }

  bool get _hasFocusedField =>
      _nameFocusNode.hasFocus ||
      _waFocusNode.hasFocus ||
      _emailFocusNode.hasFocus ||
      _passwordFocusNode.hasFocus;

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

  Widget centerHeader() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 16),
        Text(
          'Mulai dengan BangDeliv',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Satu akun untuk pesan, belanja, dan perjalanan.',
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

  Widget bottomForm(BuildContext context, {required bool isCompact}) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Buat Akun Anda',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontSize: 18),
          ),
          SizedBox(height: isCompact ? 16 : 24),

          TextFormField(
            controller: _nameController,
            focusNode: _nameFocusNode,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.next,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            decoration: _fieldDecoration('Nama Lengkap', _nameFocusNode),
            validator: (value) {
              final name = value?.trim() ?? '';
              if (name.isEmpty) {
                return 'Nama wajib diisi';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _waController,
            focusNode: _waFocusNode,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            decoration: _fieldDecoration('Nomor WhatsApp', _waFocusNode),
            validator: (value) {
              final phone = value?.trim() ?? '';
              if (phone.isEmpty) {
                return 'Nomor WhatsApp wajib diisi';
              }
              if (!_isValidPhone(phone)) {
                return 'Format nomor WhatsApp tidak valid';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

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
          const SizedBox(height: 16),

          TextFormField(
            controller: _passwordController,
            focusNode: _passwordFocusNode,
            obscureText: !_isPasswordVisible,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleRegister(),
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

          const SizedBox(height: 32),

          BangPrimaryButton(
            label: 'Daftar',
            isLoading: _isSubmitting,
            onPressed: _handleRegister,
          ),

          const SizedBox(height: 24),

          Center(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Sudah punya akun? ',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                InkWell(
                  onTap: () {
                    context.pop();
                  },
                  child: Text(
                    'Masuk Sekarang',
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

  bool _isValidPhone(String phone) {
    final normalized = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    return RegExp(r'^\+?[0-9]{10,15}$').hasMatch(normalized);
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
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

  Future<void> _handleRegister() async {
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
      await AuthService.registerCustomer(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _waController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) {
        return;
      }

      context.go(AppRoutes.registerSuccess);
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
    _nameFocusNode
      ..removeListener(_handleFieldFocusChanged)
      ..dispose();
    _waFocusNode
      ..removeListener(_handleFieldFocusChanged)
      ..dispose();
    _emailFocusNode
      ..removeListener(_handleFieldFocusChanged)
      ..dispose();
    _passwordFocusNode
      ..removeListener(_handleFieldFocusChanged)
      ..dispose();
    _nameController.dispose();
    _waController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
