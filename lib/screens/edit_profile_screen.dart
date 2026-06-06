import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../config/app_colors.dart';
import '../providers/auth_session_provider.dart';
import '../services/auth_service.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/vehicle_info_fields.dart';

enum _AvatarPickerAction { camera, gallery, remove }

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  String? _selectedVehicleType;
  String? _selectedVehicleBrand;
  final _vehicleModelController = TextEditingController();
  bool _isDriver = false;
  final ImagePicker _imagePicker = ImagePicker();

  XFile? _selectedAvatar;
  String? _currentAvatarUrl;
  bool _removeAvatar = false;

  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final profile = await AuthService.fetchCurrentUserProfile();
      _nameController.text = profile.name;
      _phoneController.text = profile.phone;
      _emailController.text = profile.email;
      _isDriver = profile.role.trim().toLowerCase() == 'driver';
      final currentVehicleType = (profile.driverProfile?.vehicleType ?? '')
          .trim();
      _selectedVehicleType = currentVehicleType.isEmpty
          ? null
          : currentVehicleType;
      final currentVehicleBrand = (profile.driverProfile?.vehicleBrand ?? '')
          .trim();
      _selectedVehicleBrand = currentVehicleBrand.isEmpty
          ? null
          : currentVehicleBrand;
      _vehicleModelController.text = (profile.driverProfile?.vehicleModel ?? '')
          .trim();
      _currentAvatarUrl = profile.avatarUrl;
      _selectedAvatar = null;
      _removeAvatar = false;
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
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Edit Profil',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
          onPressed: () => context.pop(false),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              top: false,
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
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 20),
                            Stack(
                              children: [
                                ValueListenableBuilder<TextEditingValue>(
                                  valueListenable: _nameController,
                                  builder: (context, value, _) {
                                    return _buildAvatarPreview(value.text);
                                  },
                                ),
                                Positioned(
                                  bottom: -6,
                                  right: -6,
                                  child: Tooltip(
                                    message: 'Ganti foto profil',
                                    child: InkWell(
                                      onTap: _isSubmitting
                                          ? null
                                          : _openAvatarPickerSheet,
                                      borderRadius: BorderRadius.circular(100),
                                      child: SizedBox(
                                        width: 44,
                                        height: 44,
                                        child: Center(
                                          child: Container(
                                            width: 30,
                                            height: 30,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: AppColors.white,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: AppColors.primaryLight,
                                                width: 1.5,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: AppColors.black
                                                      .withValues(alpha: 0.14),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: const Icon(
                                              Icons.camera_alt,
                                              color: AppColors.primary,
                                              size: 15,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 30),
                            _buildTextField(
                              label: 'Nama Lengkap',
                              controller: _nameController,
                              keyboardType: TextInputType.name,
                              validator: (value) {
                                final name = value?.trim() ?? '';
                                if (name.isEmpty) {
                                  return 'Nama wajib diisi';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            _buildTextField(
                              label: 'Nomor Telepon',
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              validator: (value) {
                                final phone = value?.trim() ?? '';
                                if (phone.isEmpty) {
                                  return 'Nomor telepon wajib diisi';
                                }
                                final normalized = phone.replaceAll(
                                  RegExp(r'[^0-9+]'),
                                  '',
                                );
                                if (!RegExp(
                                  r'^\+?[0-9]{10,15}$',
                                ).hasMatch(normalized)) {
                                  return 'Format nomor telepon tidak valid';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            _buildTextField(
                              label: 'Email',
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                final email = value?.trim() ?? '';
                                if (email.isEmpty) {
                                  return 'Email wajib diisi';
                                }
                                final valid = RegExp(
                                  r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                ).hasMatch(email);
                                if (!valid) {
                                  return 'Format email tidak valid';
                                }
                                return null;
                              },
                            ),
                            if (_isDriver) ...[
                              const SizedBox(height: 20),
                              VehicleInfoFields(
                                selectedVehicleType: _selectedVehicleType,
                                selectedVehicleBrand: _selectedVehicleBrand,
                                vehicleModelController: _vehicleModelController,
                                enabled: !_isSubmitting,
                                requiredFields: _isDriver,
                                showLabels: true,
                                filled: true,
                                fillColor: Colors.white,
                                onVehicleTypeChanged: (value) {
                                  setState(() {
                                    _selectedVehicleType = value;
                                    if ((value ?? '').trim().isEmpty) {
                                      _selectedVehicleBrand = null;
                                      _vehicleModelController.clear();
                                    }
                                  });
                                },
                                onVehicleBrandChanged: (value) {
                                  setState(() {
                                    _selectedVehicleBrand = value;
                                    if ((value ?? '').trim().isEmpty) {
                                      _vehicleModelController.clear();
                                    }
                                  });
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    _buildBottomSubmitButton(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildBottomSubmitButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _isSubmitting ? null : _handleSubmit,
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
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
              : const Text('Simpan Perubahan'),
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
      final updatedProfile = await AuthService.updateCurrentUserProfile(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        vehicleType: _isDriver ? (_selectedVehicleType ?? '').trim() : null,
        vehicleBrand: _isDriver ? (_selectedVehicleBrand ?? '').trim() : null,
        vehicleModel: _isDriver ? _vehicleModelController.text.trim() : null,
        avatarPath: _selectedAvatar?.path,
        removeAvatar: _removeAvatar,
      );

      ref.read(authSessionProvider.notifier).syncProfile(updatedProfile);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil berhasil diperbarui.'),
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

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required TextInputType keyboardType,
    required String? Function(String?) validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          validator: validator,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarPreview(String name) {
    final normalizedAvatarUrl = (_currentAvatarUrl ?? '').trim();
    final selectedAvatar = _selectedAvatar;

    return ProfileAvatar(
      name: name,
      avatarUrl: _removeAvatar ? null : normalizedAvatarUrl,
      imageProvider: selectedAvatar == null
          ? null
          : FileImage(File(selectedAvatar.path)),
      size: 84,
      borderColor: AppColors.primaryLight,
      borderWidth: 3,
    );
  }

  Future<void> _openAvatarPickerSheet() async {
    final hasAvatar =
        _selectedAvatar != null ||
        (!_removeAvatar && (_currentAvatarUrl ?? '').trim().isNotEmpty);

    final action = await showDialog<_AvatarPickerAction>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.white,
          surfaceTintColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Foto Profil',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AvatarPickerOption(
                icon: Icons.camera_alt_outlined,
                title: 'Ambil dari Kamera',
                onTap: () => dialogContext.pop(_AvatarPickerAction.camera),
              ),
              _AvatarPickerOption(
                icon: Icons.photo_library_outlined,
                title: 'Pilih dari Galeri',
                onTap: () => dialogContext.pop(_AvatarPickerAction.gallery),
              ),
              if (hasAvatar)
                _AvatarPickerOption(
                  icon: Icons.delete_outline,
                  title: 'Hapus Foto Profil',
                  color: AppColors.error,
                  onTap: () => dialogContext.pop(_AvatarPickerAction.remove),
                ),
            ],
          ),
        );
      },
    );

    if (action == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    if (action == _AvatarPickerAction.remove) {
      setState(() {
        _selectedAvatar = null;
        _removeAvatar = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto profil akan dihapus saat disimpan.'),
        ),
      );

      return;
    }

    final source = action == _AvatarPickerAction.camera
        ? ImageSource.camera
        : ImageSource.gallery;

    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (!mounted || picked == null) {
        return;
      }

      setState(() {
        _selectedAvatar = picked;
        _removeAvatar = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memilih foto profil.'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _vehicleModelController.dispose();
    super.dispose();
  }
}

class _AvatarPickerOption extends StatelessWidget {
  const _AvatarPickerOption({
    required this.icon,
    required this.title,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? AppColors.textPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Icon(icon, color: resolvedColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: resolvedColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
