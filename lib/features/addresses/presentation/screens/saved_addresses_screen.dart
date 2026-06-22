import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_routes.dart';
import '../../../../config/app_text_scaling.dart';
import '../../../../models/user_profile_model.dart';
import '../../../auth/application/auth_session_provider.dart';
import '../../../../services/auth_service.dart';

class SavedAddressesScreen extends ConsumerStatefulWidget {
  const SavedAddressesScreen({
    super.key,
    this.selectionMode = false,
    this.orderEntry = false,
  });

  final bool selectionMode;
  final bool? orderEntry;

  @override
  ConsumerState<SavedAddressesScreen> createState() =>
      _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends ConsumerState<SavedAddressesScreen> {
  late Future<List<SavedAddressModel>> _addressesFuture;
  int? _selectingAddressId;

  bool get _isOrderEntry => widget.orderEntry == true;

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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
            return _buildEmptyAddressState();
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
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: AppTextScaling.adaptive(
                context,
                normal: 52,
                large: 56,
              ),
            ),
            child: ElevatedButton.icon(
              onPressed: _openAddAddress,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(
                _isOrderEntry ? 'Tambah Alamat' : 'Tambah Alamat Baru',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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

  Widget _buildEmptyAddressState() {
    if (!_isOrderEntry) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Belum ada alamat tersimpan untuk akun ini.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 20, 28, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(
              Icons.add_location_alt_outlined,
              color: AppColors.primary,
              size: 42,
            ),
            SizedBox(height: 12),
            Text(
              'Tambahkan alamat dulu',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Alamat diperlukan agar BangDeliv bisa menyesuaikan layanan, rute, dan lokasi penjemputan.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
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
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: widget.selectionMode ? () => _selectAddress(address) : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
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
    if (widget.selectionMode) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSelectionIndicator(address, isSelecting: isSelecting),
          const SizedBox(width: 12),
          Expanded(child: _buildAddressSummary(address)),
          const SizedBox(width: 8),
          _buildEditTextButton(address),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildAddressSummary(address, addressMaxLines: 2)),
        const SizedBox(width: 8),
        _buildEditTextButton(address),
      ],
    );
  }

  Widget _buildSelectionIndicator(
    SavedAddressModel address, {
    required bool isSelecting,
  }) {
    return SizedBox.square(
      dimension: 28,
      child: Center(
        child: isSelecting
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : _AddressChoiceDot(isSelected: address.isDefault),
      ),
    );
  }

  Widget _buildAddressSummary(
    SavedAddressModel address, {
    int addressMaxLines = 2,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                address.label.isEmpty ? 'Alamat' : address.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ),
            if (address.isDefault) ...[
              const SizedBox(width: 8),
              _DefaultAddressBadge(),
            ],
          ],
        ),
        const SizedBox(height: 6),
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
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                '|',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11.5,
                  height: 1.2,
                ),
              ),
            ),
            Flexible(
              child: Text(
                address.phone,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11.5,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          address.displayAddress,
          maxLines: addressMaxLines,
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

  Widget _buildEditTextButton(SavedAddressModel address) {
    return TextButton(
      onPressed: () => _openEditAddress(address),
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 2),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: AppColors.primary,
      ),
      child: const Text(
        'Ubah',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
    );
  }
}

class _AddressChoiceDot extends StatelessWidget {
  const _AddressChoiceDot({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
          width: isSelected ? 2.2 : 1.5,
        ),
      ),
      child: isSelected
          ? Center(
              child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }
}

class _DefaultAddressBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppTextScaling.clampForCompactComponent(
      context: context,
      maxScaleFactor: AppTextScaling.denseComponentMaxScaleFactor,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.primary, width: 1),
        ),
        child: const Text(
          'Utama',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
        ),
      ),
    );
  }
}
