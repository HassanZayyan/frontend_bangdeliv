import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_text_scaling.dart';
import '../../../../services/auth_service.dart';

enum PasswordFormMode { change, create }

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key, this.mode = PasswordFormMode.change});

  final PasswordFormMode mode;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _currentPasswordFocusNode = FocusNode();
  final _newPasswordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();

  bool _isSubmitting = false;
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  bool get _isCreateMode => widget.mode == PasswordFormMode.create;

  @override
  void initState() {
    super.initState();
    _currentPasswordFocusNode.addListener(_handleFieldFocusChanged);
    _newPasswordFocusNode.addListener(_handleFieldFocusChanged);
    _confirmPasswordFocusNode.addListener(_handleFieldFocusChanged);
  }

  void _handleFieldFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _isCreateMode ? 'Login & Keamanan' : 'Ganti Password',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
          onPressed: () => context.pop(false),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isCreateMode) ...[
                        _buildCreatePasswordIntro(),
                        const SizedBox(height: 18),
                      ],
                      if (!_isCreateMode) ...[
                        _buildPasswordField(
                          label: 'Password Saat Ini',
                          hintText: 'Masukkan password lama',
                          controller: _currentPasswordController,
                          focusNode: _currentPasswordFocusNode,
                          isVisible: _showCurrentPassword,
                          onToggleVisibility: () {
                            setState(() {
                              _showCurrentPassword = !_showCurrentPassword;
                            });
                          },
                          validator: (value) {
                            final text = value ?? '';
                            if (text.isEmpty) {
                              return 'Password saat ini wajib diisi';
                            }
                            if (text.length < 8) {
                              return 'Password minimal 8 karakter';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                      ],
                      _buildPasswordField(
                        label: _isCreateMode
                            ? 'Password BangDeliv'
                            : 'Password Baru',
                        hintText: _isCreateMode
                            ? 'Tambah password untuk login email'
                            : 'Masukkan password baru',
                        controller: _newPasswordController,
                        focusNode: _newPasswordFocusNode,
                        isVisible: _showNewPassword,
                        onToggleVisibility: () {
                          setState(() {
                            _showNewPassword = !_showNewPassword;
                          });
                        },
                        validator: (value) {
                          final text = value ?? '';
                          if (text.isEmpty) {
                            return 'Password baru wajib diisi';
                          }
                          if (text.length < 8) {
                            return 'Password minimal 8 karakter';
                          }
                          if (!_isCreateMode &&
                              text == _currentPasswordController.text) {
                            return 'Password baru harus berbeda';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      _buildPasswordField(
                        label: 'Konfirmasi Password Baru',
                        hintText: 'Ulangi password baru',
                        controller: _confirmPasswordController,
                        focusNode: _confirmPasswordFocusNode,
                        isVisible: _showConfirmPassword,
                        onToggleVisibility: () {
                          setState(() {
                            _showConfirmPassword = !_showConfirmPassword;
                          });
                        },
                        validator: (value) {
                          final text = value ?? '';
                          if (text.isEmpty) {
                            return 'Konfirmasi password wajib diisi';
                          }
                          if (text != _newPasswordController.text) {
                            return 'Konfirmasi password tidak sama';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      _buildPasswordRequirementInfo(),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: AppTextScaling.adaptive(
                        context,
                        normal: 52,
                        large: 56,
                      ),
                    ),
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.white,
                              ),
                            )
                          : Text(
                              _isCreateMode
                                  ? 'Tambah Password'
                                  : 'Simpan Password',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordRequirementInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Kata sandi baru disarankan',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        _buildPasswordTip('Gunakan minimal 8 karakter'),
        _buildPasswordTip('Kombinasikan huruf besar, huruf kecil, dan angka'),
        _buildPasswordTip('Tambahkan karakter khusus seperti !@#%'),
        _buildPasswordTip('Hindari menggunakan informasi pribadi'),
      ],
    );
  }

  Widget _buildCreatePasswordIntro() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 24,
            child: Icon(
              Icons.verified_user_outlined,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Google sudah terhubung',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Password BangDeliv bersifat opsional. Tambahkan hanya jika ingin bisa masuk juga dengan email dan password.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.textMuted,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11.5,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required String label,
    required String hintText,
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool isVisible,
    required VoidCallback onToggleVisibility,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: !isVisible,
      style: TextStyle(
        color: AppColors.textPrimary,
        fontSize: AppTextScaling.adaptive(context, normal: 14, large: 13.4),
        fontWeight: FontWeight.w400,
      ),
      validator: validator,
      decoration: InputDecoration(
        labelText: focusNode.hasFocus ? label : null,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: AppTextScaling.adaptive(context, normal: 13, large: 12.6),
          color: AppColors.textSecondary,
        ),
        hintText: hintText,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        filled: true,
        fillColor: AppColors.white,
        hintStyle: TextStyle(
          color: AppColors.textSecondary,
          fontSize: AppTextScaling.adaptive(context, normal: 14, large: 13.4),
          fontWeight: FontWeight.w400,
        ),
        suffixIcon: IconButton(
          onPressed: onToggleVisibility,
          iconSize: 20,
          icon: Icon(
            isVisible ? Icons.visibility : Icons.visibility_off,
            color: AppColors.textSecondary,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
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
      if (_isCreateMode) {
        await AuthService.createPassword(
          newPassword: _newPasswordController.text,
          newPasswordConfirmation: _confirmPasswordController.text,
        );
      } else {
        await AuthService.changePassword(
          currentPassword: _currentPasswordController.text,
          newPassword: _newPasswordController.text,
          newPasswordConfirmation: _confirmPasswordController.text,
        );
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isCreateMode
                ? 'Password BangDeliv berhasil ditambahkan.'
                : 'Password berhasil diperbarui.',
          ),
          backgroundColor: AppColors.success,
        ),
      );

      context.pop(true);
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
    _currentPasswordFocusNode
      ..removeListener(_handleFieldFocusChanged)
      ..dispose();
    _newPasswordFocusNode
      ..removeListener(_handleFieldFocusChanged)
      ..dispose();
    _confirmPasswordFocusNode
      ..removeListener(_handleFieldFocusChanged)
      ..dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
