import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../models/user_profile_model.dart';
import '../providers/auth_session_provider.dart';
import '../services/auth_service.dart';

class DriverProfileScreen extends ConsumerStatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  ConsumerState<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends ConsumerState<DriverProfileScreen> {
  late Future<UserProfileModel> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _fetchAndSyncProfile();
  }

  Future<void> _reloadProfile() async {
    final nextFuture = _fetchAndSyncProfile();

    setState(() {
      _profileFuture = nextFuture;
    });

    try {
      await nextFuture;
    } catch (_) {
      // Error handling is surfaced via FutureBuilder state.
    }
  }

  Future<UserProfileModel> _fetchAndSyncProfile() async {
    final profile = await AuthService.fetchCurrentUserProfile();
    if (mounted) {
      ref.read(authSessionProvider.notifier).syncProfile(profile);
    }
    return profile;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Profil Driver',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: FutureBuilder<UserProfileModel>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Gagal memuat profil driver.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () => _reloadProfile(),
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            );
          }

          final profile = snapshot.data!;
          final driverProfile = profile.driverProfile;

          return RefreshIndicator(
            onRefresh: _reloadProfile,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildIdentityCard(profile),
                const SizedBox(height: 12),
                _buildOperationalCard(profile.driverProfile),
                const SizedBox(height: 12),
                _buildStatusCard(driverProfile),
                const SizedBox(height: 12),
                _buildQuickActionCard(context),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _handleLogout,
                    icon: const Icon(Icons.logout, color: AppColors.primary),
                    label: const Text(
                      'Keluar dari Akun',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primaryLight),
                      backgroundColor: AppColors.white,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildIdentityCard(UserProfileModel profile) {
    final driverProfile = profile.driverProfile;
    final completedOrders = (driverProfile?.totalDeliveries ?? 0) > 0
        ? driverProfile!.totalDeliveries
        : profile.stats.totalOrders;

    final resolvedRating = (driverProfile?.avgRating ?? 0) > 0
        ? driverProfile!.avgRating
        : profile.stats.rating;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: _buildAvatarImage(profile.avatarUrl),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.phone,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      profile.email,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.border),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _miniStat('Order Selesai', completedOrders.toString())),
              Expanded(
                child: _miniStat(
                  'Rating',
                  resolvedRating <= 0 ? '-' : '${resolvedRating.toStringAsFixed(1)}★',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOperationalCard(DriverProfileModel? driverProfile) {
    final operationalStatus = (driverProfile?.status ?? 'offline').trim().toLowerCase();
    final vehicleType = (driverProfile?.vehicleType ?? '').trim();
    final vehicleBrand = (driverProfile?.vehicleBrand ?? '').trim();
    final vehicleModel = (driverProfile?.vehicleModel ?? '').trim();
    final vehiclePlate = (driverProfile?.vehiclePlate ?? '').trim();
    final rawLicenseNumber = (driverProfile?.licenseNumber ?? '').trim();
    final maskedLicenseNumber = rawLicenseNumber.length <= 4
        ? (rawLicenseNumber.isEmpty ? '-' : rawLicenseNumber)
        : '${rawLicenseNumber.substring(0, 2)}***${rawLicenseNumber.substring(rawLicenseNumber.length - 2)}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Data Operasional',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _operationalColor(operationalStatus).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _operationalLabel(operationalStatus),
              style: TextStyle(
                color: _operationalColor(operationalStatus),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _detailRow('Jenis Motor', vehicleType.isEmpty ? '-' : vehicleType),
          const SizedBox(height: 8),
          _detailRow('Merk Motor', vehicleBrand.isEmpty ? '-' : vehicleBrand),
          const SizedBox(height: 8),
          _detailRow('Tipe Motor', vehicleModel.isEmpty ? '-' : vehicleModel),
          const SizedBox(height: 8),
          _detailRow('Plat Kendaraan', vehiclePlate.isEmpty ? '-' : vehiclePlate.toUpperCase()),
          const SizedBox(height: 8),
          _detailRow('Nomor SIM', maskedLicenseNumber),
        ],
      ),
    );
  }

  Widget _buildStatusCard(DriverProfileModel? driverProfile) {
    final status = (driverProfile?.registrationStatus ?? 'unknown').trim().toLowerCase();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Status Verifikasi',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _statusColor(status).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _statusLabel(status),
              style: TextStyle(
                color: _statusColor(status),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Kelola dokumen dan pantau status verifikasi akun driver Anda.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () async {
              await context.push(AppRoutes.driverVerificationStatus);
              if (mounted) {
                await _reloadProfile();
              }
            },
            icon: const Icon(Icons.badge_outlined),
            label: const Text('Lihat Status Verifikasi'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _actionTile(
            icon: Icons.person_outline,
            title: 'Edit Profil',
            onTap: () async {
              final updated = await context.push<bool>(AppRoutes.editProfile);
              if (updated == true && mounted) {
                await _reloadProfile();
              }
            },
          ),
          const Divider(height: 1, indent: 56, color: AppColors.border),
          _actionTile(
            icon: Icons.lock_outline,
            title: 'Ganti Password',
            onTap: () => context.push(AppRoutes.changePassword),
          ),
          const Divider(height: 1, indent: 56, color: AppColors.border),
          _actionTile(
            icon: Icons.notifications_outlined,
            title: 'Notifikasi',
            onTap: () => context.push(AppRoutes.notificationSettings),
          ),
          const Divider(height: 1, indent: 56, color: AppColors.border),
          _actionTile(
            icon: Icons.shield_outlined,
            title: 'Kebijakan Privasi',
            onTap: () => context.push(AppRoutes.privacyMapPreview),
          ),
          const Divider(height: 1, indent: 56, color: AppColors.border),
          _actionTile(
            icon: Icons.badge_outlined,
            title: 'Status Verifikasi',
            onTap: () async {
              await context.push(AppRoutes.driverVerificationStatus);
              if (mounted) {
                await _reloadProfile();
              }
            },
          ),
          const Divider(height: 1, indent: 56, color: AppColors.border),
          _actionTile(
            icon: Icons.help_outline,
            title: 'Bantuan Driver',
            onTap: _showHelpCenter,
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: AppColors.primary),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return AppColors.success;
      case 'pending':
        return AppColors.primaryDark;
      case 'rejected':
      case 'suspended':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'active':
        return 'Aktif';
      case 'pending':
        return 'Menunggu Verifikasi';
      case 'rejected':
        return 'Ditolak';
      case 'suspended':
        return 'Ditangguhkan';
      default:
        return 'Belum tersedia';
    }
  }

  Widget _buildAvatarImage(String? avatarUrl) {
    final normalized = avatarUrl?.trim() ?? '';
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          color: AppColors.primary.withValues(alpha: 0.12),
          alignment: Alignment.center,
          child: const Icon(Icons.person, color: AppColors.primaryDark),
        ),
        if (normalized.isNotEmpty)
          Image.network(
            normalized,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return const SizedBox.shrink();
            },
          ),
      ],
    );
  }

  Color _operationalColor(String status) {
    switch (status) {
      case 'available':
      case 'online':
        return AppColors.success;
      case 'busy':
        return AppColors.primaryDark;
      default:
        return AppColors.textSecondary;
    }
  }

  String _operationalLabel(String status) {
    switch (status) {
      case 'available':
      case 'online':
        return 'Online - Siap Terima Order';
      case 'busy':
        return 'Sedang Mengantar';
      default:
        return 'Offline';
    }
  }

  void _showHelpCenter() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Bantuan Driver'),
          content: const Text(
            'Hubungi tim operasional driver jika butuh bantuan cepat:\n\n'
            'WhatsApp: 0812-0000-1234\n'
            'Email: driver.support@bangdeliv.id',
          ),
          actions: [
            TextButton(
              onPressed: () => dialogContext.pop(),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Keluar dari Akun',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: const Text(
            'Apakah Anda yakin ingin keluar dari aplikasi BangDeliv?',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => dialogContext.pop(false),
              child: const Text(
                'Batal',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => dialogContext.pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Ya, Keluar',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) {
      return;
    }

    await ref.read(authSessionProvider.notifier).logout();

    if (!mounted) {
      return;
    }

    context.go(AppRoutes.login);
  }
}
