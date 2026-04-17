import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_colors.dart';
import '../models/user_profile_model.dart';
import '../providers/auth_session_provider.dart';
import '../services/auth_service.dart';

class AddAddressScreen extends ConsumerStatefulWidget {
  const AddAddressScreen({super.key, this.initialAddress});

  final SavedAddressModel? initialAddress;

  @override
  ConsumerState<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends ConsumerState<AddAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _recipientController = TextEditingController();
  final _phoneController = TextEditingController();
  final _fullAddressController = TextEditingController();
  final _detailController = TextEditingController();

  String? _selectedLabel;
  String? _labelErrorText;

  bool _isDefault = false;
  bool _isLoadingProfile = true;
  bool _isSubmitting = false;
  bool _isDeleting = false;

  bool get _isEditMode => widget.initialAddress != null;

  String _normalizeAddressLabel(String rawLabel) {
    final normalized = rawLabel.trim().toLowerCase();
    if (normalized.contains('kantor') || normalized.contains('office')) {
      return 'Kantor';
    }
    return 'Rumah';
  }

  void _fillFormFromAddress(SavedAddressModel address) {
    _selectedLabel = _normalizeAddressLabel(address.label);
    _labelErrorText = null;
    _recipientController.text = address.recipientName;
    _phoneController.text = address.phone;

    final rawFullAddress = address.fullAddress.trim();
    if (rawFullAddress.isNotEmpty) {
      _fullAddressController.text = rawFullAddress;
    } else {
      // Fallback for legacy/partial payloads so edit form is never blank.
      _fullAddressController.text = address.displayAddress.trim();
    }

    _detailController.text = address.detail;
    _isDefault = address.isDefault;
    _isLoadingProfile = false;
  }

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _fillFormFromAddress(widget.initialAddress!);
    } else {
      _prefillUserData();
    }
  }

  @override
  void didUpdateWidget(covariant AddAddressScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldId = oldWidget.initialAddress?.id;
    final newAddress = widget.initialAddress;

    if (newAddress != null && newAddress.id != oldId) {
      setState(() {
        _fillFormFromAddress(newAddress);
      });
    }
  }

  Future<void> _prefillUserData() async {
    try {
      final profile = await AuthService.fetchCurrentUserProfile();
      _recipientController.text = profile.name;
      _phoneController.text = profile.phone;
    } catch (_) {
      // Keep fields empty if profile prefill fails.
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).height < 760;
    final fieldSpacing = isCompact ? 10.0 : 12.0;
    final buttonHeight = isCompact ? 48.0 : 52.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Form Alamat',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
          onPressed: () => context.pop(false),
        ),
      ),
      body: _isLoadingProfile
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final keyboardBottomInset = MediaQuery.viewInsetsOf(
                    context,
                  ).bottom;

                  return SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      12 + keyboardBottomInset,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildAddressLabelSelector(),
                            SizedBox(height: fieldSpacing),
                            _buildTextField(
                              label: 'Nama Penerima',
                              controller: _recipientController,
                              hintText: 'Nama penerima',
                              validator: (value) {
                                final text = value?.trim() ?? '';
                                if (text.isEmpty) {
                                  return 'Nama penerima wajib diisi';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: fieldSpacing),
                            _buildTextField(
                              label: 'Nomor Telepon',
                              controller: _phoneController,
                              hintText: '08xxxxxxxxxx',
                              keyboardType: TextInputType.phone,
                              validator: (value) {
                                final text = value?.trim() ?? '';
                                if (text.isEmpty) {
                                  return 'Nomor telepon wajib diisi';
                                }
                                final normalized = text.replaceAll(
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
                            SizedBox(height: fieldSpacing),
                            _buildTextField(
                              label: 'Alamat Lengkap',
                              controller: _fullAddressController,
                              hintText: 'Masukkan alamat lengkap',
                              maxLines: isCompact ? 2 : 3,
                              validator: (value) {
                                final text = value?.trim() ?? '';
                                if (text.isEmpty) {
                                  return 'Alamat lengkap wajib diisi';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: fieldSpacing),
                            _buildTextField(
                              label: 'Detail Tambahan (Opsional)',
                              controller: _detailController,
                              hintText: 'Contoh: Pagar hitam, lantai 2',
                              maxLines: isCompact ? 1 : 2,
                            ),
                            const SizedBox(height: 4),
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Jadikan alamat utama'),
                              value: _isDefault,
                              onChanged: (value) {
                                setState(() {
                                  _isDefault = value;
                                });
                              },
                              activeThumbColor: AppColors.primary,
                            ),
                            SizedBox(height: isCompact ? 10 : 14),
                            if (_isEditMode)
                              Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: buttonHeight,
                                      child: OutlinedButton(
                                        onPressed:
                                            (_isSubmitting || _isDeleting)
                                            ? null
                                            : _handleDeleteAddress,
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(
                                            color: AppColors.error,
                                          ),
                                          foregroundColor: AppColors.error,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                        child: _isDeleting
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: AppColors.error,
                                                    ),
                                              )
                                            : const Text('Hapus Alamat'),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: SizedBox(
                                      height: buttonHeight,
                                      child: ElevatedButton(
                                        onPressed:
                                            (_isSubmitting || _isDeleting)
                                            ? null
                                            : _handleSave,
                                        style: ElevatedButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                        child: _isSubmitting
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: AppColors.white,
                                                    ),
                                              )
                                            : const Text('Simpan'),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else
                              SizedBox(
                                width: double.infinity,
                                height: buttonHeight,
                                child: ElevatedButton(
                                  onPressed: (_isSubmitting || _isDeleting)
                                      ? null
                                      : _handleSave,
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
                                      : const Text('Simpan Alamat'),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Future<void> _handleSave() async {
    if (_isSubmitting) {
      return;
    }

    final currentState = _formKey.currentState;
    if (currentState == null) {
      return;
    }

    final isFormValid = currentState.validate();
    final hasSelectedLabel = (_selectedLabel ?? '').trim().isNotEmpty;

    if (!hasSelectedLabel) {
      setState(() {
        _labelErrorText = 'Label alamat wajib dipilih';
      });
    }

    if (!isFormValid || !hasSelectedLabel) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      if (_isEditMode) {
        await AuthService.updateSavedAddress(
          addressId: widget.initialAddress!.id,
          label: _selectedLabel!,
          recipientName: _recipientController.text.trim(),
          phone: _phoneController.text.trim(),
          fullAddress: _fullAddressController.text.trim(),
          detail: _detailController.text.trim(),
          isDefault: _isDefault,
        );
      } else {
        await AuthService.createSavedAddress(
          label: _selectedLabel!,
          recipientName: _recipientController.text.trim(),
          phone: _phoneController.text.trim(),
          fullAddress: _fullAddressController.text.trim(),
          detail: _detailController.text.trim(),
          isDefault: _isDefault,
        );
      }

      await ref.read(authSessionProvider.notifier).refreshSession();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditMode
                ? 'Alamat berhasil diperbarui.'
                : 'Alamat berhasil disimpan.',
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

  Future<void> _handleDeleteAddress() async {
    if (!_isEditMode || _isDeleting || _isSubmitting) {
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hapus Alamat'),
          content: const Text('Yakin ingin menghapus alamat ini?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    try {
      await AuthService.deleteSavedAddress(
        addressId: widget.initialAddress!.id,
      );

      await ref.read(authSessionProvider.notifier).refreshSession();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alamat berhasil dihapus.'),
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
          _isDeleting = false;
        });
      }
    }
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hintText,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            filled: true,
            fillColor: AppColors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddressLabelSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Label Alamat',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _buildAddressLabelOption(
                label: 'Rumah',
                isSelected: _selectedLabel == 'Rumah',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAddressLabelOption(
                label: 'Kantor',
                isSelected: _selectedLabel == 'Kantor',
              ),
            ),
          ],
        ),
        if (_labelErrorText != null) ...[
          const SizedBox(height: 6),
          Text(
            _labelErrorText!,
            style: const TextStyle(color: AppColors.error, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _buildAddressLabelOption({
    required String label,
    required bool isSelected,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (_isSubmitting || _isDeleting) {
            return;
          }
          setState(() {
            _selectedLabel = label;
            _labelErrorText = null;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryLight : AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _phoneController.dispose();
    _fullAddressController.dispose();
    _detailController.dispose();
    super.dispose();
  }
}
