import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../models/user_profile_model.dart';
import '../providers/auth_session_provider.dart';
import '../services/auth_service.dart';
import '../utils/currency_formatter.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late Future<UserProfileModel> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = AuthService.fetchCurrentUserProfile();
  }

  void _reloadProfile() {
    setState(() {
      _profileFuture = AuthService.fetchCurrentUserProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<UserProfileModel>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ProfileErrorView(
              message: snapshot.error.toString(),
              onRetry: _reloadProfile,
            );
          }

          final profile = snapshot.data;
          if (profile == null) {
            return _ProfileErrorView(
              message: 'Data profil tidak tersedia.',
              onRetry: _reloadProfile,
            );
          }

          return SingleChildScrollView(
            child: Column(
              children: [_buildHeader(profile), _buildCardArea(profile)],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(UserProfileModel profile) {
    return Stack(
      children: [
        Container(
          height: 380,
          width: double.infinity,
          decoration: const BoxDecoration(color: AppColors.primary),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  height: 100,
                  width: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 4,
                    ),
                    color: AppColors.darkBlue,
                  ),
                  child: ClipOval(child: _buildAvatarImage(profile.avatarUrl)),
                ),
                const SizedBox(height: 16),
                Text(
                  profile.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.phone,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(color: const Color(0xFFC94A1D)),
                  child: IntrinsicHeight(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatItem(
                          profile.stats.totalOrders.toString(),
                          'Total Order',
                        ),
                        VerticalDivider(
                          color: Colors.white.withValues(alpha: 0.2),
                          thickness: 1,
                        ),
                        _buildStatItem(
                          _formatCurrency(profile.stats.totalPaid),
                          'Total Bayar',
                        ),
                        VerticalDivider(
                          color: Colors.white.withValues(alpha: 0.2),
                          thickness: 1,
                        ),
                        _buildStatItem(
                          profile.stats.rating <= 0
                              ? '-'
                              : '${profile.stats.rating.toStringAsFixed(1)}★',
                          'Rating',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCardArea(UserProfileModel profile) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              'AKUN',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                _buildMenuTile(
                  icon: Icons.person_outline,
                  title: 'Edit Profil',
                  onTap: () async {
                    final updated = await context.push<bool>(
                      AppRoutes.editProfile,
                    );
                    if (updated == true && mounted) {
                      _reloadProfile();
                    }
                  },
                ),
                const Divider(height: 1, indent: 60, color: AppColors.border),
                _buildMenuTile(
                  icon: Icons.lock_outline,
                  title: 'Ganti Password',
                  onTap: () => context.push(AppRoutes.changePassword),
                ),
                const Divider(height: 1, indent: 60, color: AppColors.border),
                _buildMenuTile(
                  icon: Icons.location_on_outlined,
                  title: 'Alamat Saya',
                  trailingText: '${profile.addressCount} alamat',
                  onTap: () async {
                    await context.push(AppRoutes.addresses);
                    if (mounted) {
                      _reloadProfile();
                    }
                  },
                ),
                const Divider(height: 1, indent: 60, color: AppColors.border),
                _buildMenuTile(
                  icon: Icons.notifications_outlined,
                  title: 'Notifikasi',
                  trailingText: 'Aktif',
                  onTap: () => context.push(AppRoutes.notificationSettings),
                ),
                if (_shouldShowDriverRegistration(profile)) ...[
                  const Divider(height: 1, indent: 60, color: AppColors.border),
                  _buildMenuTile(
                    icon: Icons.two_wheeler_outlined,
                    title: 'Upgrade jadi Driver',
                    trailingText: 'Baru',
                    onTap: () => context.push(AppRoutes.registerDriver),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              'LAINNYA',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                _buildMenuTile(
                  icon: Icons.shield_outlined,
                  title: 'Kebijakan Privasi',
                  onTap: () => context.push(AppRoutes.privacyMapPreview),
                ),
                const Divider(height: 1, indent: 60, color: AppColors.border),
                _buildMenuTile(
                  icon: Icons.description_outlined,
                  title: 'Syarat & Ketentuan',
                ),
                const Divider(height: 1, indent: 60, color: AppColors.border),
                _buildMenuTile(
                  icon: Icons.info_outline,
                  title: 'Versi Aplikasi',
                  trailingText: 'v1.0.0',
                  showChevron: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: _handleLogout,
              icon: const Icon(Icons.logout, color: AppColors.primary),
              label: const Text(
                'Keluar dari Akun',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(color: AppColors.primaryLight),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
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

  bool _shouldShowDriverRegistration(UserProfileModel profile) {
    return profile.role.trim().toLowerCase() == 'customer';
  }

  Widget _buildStatItem(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    String? trailingText,
    bool showChevron = true,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null)
            Text(
              trailingText,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          if (trailingText != null && showChevron) const SizedBox(width: 8),
          if (showChevron)
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.textSecondary,
            ),
        ],
      ),
      onTap: onTap ?? () {},
    );
  }

  Widget _buildAvatarImage(String? avatarUrl) {
    final normalized = avatarUrl?.trim() ?? '';
    if (normalized.isEmpty) {
      return const Icon(Icons.person, size: 50, color: AppColors.primary);
    }

    return Image.network(
      normalized,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return const Icon(Icons.person, size: 50, color: AppColors.primary);
      },
    );
  }

  String _formatCurrency(double amount) {
    return formatRupiah(amount);
  }
}

class _ProfileErrorView extends StatelessWidget {
  const _ProfileErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 42),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Coba Lagi')),
          ],
        ),
      ),
    );
  }
}
