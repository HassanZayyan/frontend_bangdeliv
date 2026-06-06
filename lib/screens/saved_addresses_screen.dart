import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../models/user_profile_model.dart';
import '../providers/auth_session_provider.dart';
import '../services/auth_service.dart';

class SavedAddressesScreen extends ConsumerStatefulWidget {
  const SavedAddressesScreen({super.key, this.selectionMode = false});

  final bool selectionMode;

  @override
  ConsumerState<SavedAddressesScreen> createState() =>
      _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends ConsumerState<SavedAddressesScreen> {
  late Future<List<SavedAddressModel>> _addressesFuture;
  int? _selectingAddressId;

  @override
  void initState() {
    super.initState();
    _addressesFuture = AuthService.fetchSavedAddresses();
  }

  void _reloadAddresses() {
    setState(() {
      _addressesFuture = AuthService.fetchSavedAddresses();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.selectionMode ? 'Pilih Alamat' : 'Alamat Saya',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      bottomNavigationBar: _buildBottomAddButton(),
      body: FutureBuilder<List<SavedAddressModel>>(
        future: _addressesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.location_off_outlined,
                      color: AppColors.error,
                      size: 40,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      onPressed: _reloadAddresses,
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            );
          }

          final addresses = snapshot.data ?? [];
          if (addresses.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Belum ada alamat tersimpan untuk akun ini.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: addresses.length,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final address = addresses[index];
              return _buildAddressCard(address);
            },
          );
        },
      ),
    );
  }

  Widget _buildBottomAddButton() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _openAddAddress,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Tambah Alamat Baru'),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openAddAddress() async {
    final created = await context.push<bool>(AppRoutes.addAddress);
    if (created == true && mounted) {
      await ref.read(authSessionProvider.notifier).refreshSession();
      _reloadAddresses();
    }
  }

  Future<void> _openEditAddress(SavedAddressModel address) async {
    final updated = await context.push<bool>(
      AppRoutes.addAddress,
      extra: {
        'id': address.id,
        'label': address.label,
        'recipient_name': address.recipientName,
        'phone': address.phone,
        'full_address': address.fullAddress,
        'detail': address.detail,
        'latitude': address.latitude,
        'longitude': address.longitude,
        'is_default': address.isDefault,
      },
    );
    if (updated == true && mounted) {
      await ref.read(authSessionProvider.notifier).refreshSession();
      _reloadAddresses();
    }
  }

  Future<void> _selectAddress(SavedAddressModel address) async {
    if (!widget.selectionMode || _selectingAddressId != null) {
      return;
    }

    if (address.isDefault) {
      context.pop(true);
      return;
    }

    setState(() {
      _selectingAddressId = address.id;
    });

    try {
      await AuthService.updateSavedAddress(
        addressId: address.id,
        label: address.label,
        recipientName: address.recipientName,
        phone: address.phone,
        fullAddress: address.fullAddress,
        detail: address.detail,
        latitude: address.latitude,
        longitude: address.longitude,
        isDefault: true,
      );

      await ref.read(authSessionProvider.notifier).refreshSession();

      if (!mounted) {
        return;
      }

      context.pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _selectingAddressId = null;
        });
      }
    }
  }

  Widget _buildAddressCard(SavedAddressModel address) {
    final isSelecting = _selectingAddressId == address.id;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: widget.selectionMode ? () => _selectAddress(address) : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: _buildAddressCardContent(address, isSelecting: isSelecting),
        ),
      ),
    );
  }

  Widget _buildAddressCardContent(
    SavedAddressModel address, {
    required bool isSelecting,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      address.label.isEmpty ? 'Alamat' : address.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (address.isDefault) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.primary, width: 1),
                      ),
                      child: const Text(
                        'Utama',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          height: 1,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _buildAddressTrailing(address, isSelecting: isSelecting),
          ],
        ),
        const SizedBox(height: 1),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                address.recipientName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                '|',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.2,
                ),
              ),
            ),
            Text(
              address.phone,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11.5,
                height: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          address.displayAddress,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildAddressTrailing(
    SavedAddressModel address, {
    required bool isSelecting,
  }) {
    if (widget.selectionMode) {
      return SizedBox.square(
        dimension: 32,
        child: isSelecting
            ? const Padding(
                padding: EdgeInsets.all(7),
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                address.isDefault
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: address.isDefault
                    ? AppColors.primary
                    : AppColors.textSecondary,
                size: 20,
              ),
      );
    }

    return Tooltip(
      message: 'Edit alamat',
      child: InkResponse(
        onTap: () => _openEditAddress(address),
        radius: 20,
        child: const SizedBox.square(
          dimension: 32,
          child: Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
        ),
      ),
    );
  }
}
