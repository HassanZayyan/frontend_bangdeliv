import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_routes.dart';
import '../../../../models/user_profile_model.dart';
import '../../../auth/application/auth_session_provider.dart';
import '../../../../services/auth_service.dart';
import '../../../../utils/order_formatters.dart';
import '../../../../widgets/app_content_background.dart';
import '../../../../widgets/bang_ui.dart';
import '../../../../widgets/profile_avatar.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late Future<UserProfileModel> _profileFuture;
  UserProfileModel? _cachedProfile;

  @override
  void initState() {
    super.initState();
    _profileFuture = _fetchProfile();
  }

  Future<UserProfileModel> _fetchProfile() async {
    final profile = await AuthService.fetchCurrentUserProfile();
    _cachedProfile = profile;
    return profile;
  }

  Future<void> _reloadProfile() async {
    final future = _fetchProfile();
    setState(() {
      _profileFuture = future;
    });

    try {
      await future;
    } catch (_) {
      // FutureBuilder keeps the last successful profile visible.
    }
  }

  Future<void> _openEditProfile() async {
    final updated = await context.push<bool>(AppRoutes.editProfile);
    if (updated == true && mounted) {
      await _reloadProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        bottom: false,
        child: AppContentBackground(
          child: FutureBuilder<UserProfileModel>(
            future: _profileFuture,
            builder: (context, snapshot) {
              final profile = snapshot.data ?? _cachedProfile;

              if (profile == null &&
                  snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (profile == null && snapshot.hasError) {
                return _ProfileErrorView(
                  message: snapshot.error.toString(),
                  onRetry: _reloadProfile,
                );
              }

              if (profile == null) {
                return _ProfileErrorView(
                  message: 'Data profil tidak tersedia.',
                  onRetry: _reloadProfile,
                );
              }

              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _reloadProfile,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
                  children: [
                    _buildProfileHero(context, profile),
                    const SizedBox(height: 20),
                    _buildStatsCard(profile),
                    const SizedBox(height: 26),
                    const Text(
                      'Akun & Pengaturan',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSettingsCard(profile),
                    const SizedBox(height: 18),
                    _buildHelpCard(),
                    const SizedBox(height: 14),
                    _buildLogoutButton(),
                    const SizedBox(height: 12),
                    const Center(
                      child: Text(
                        'Versi Aplikasi 1.0.0',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHero(BuildContext context, UserProfileModel profile) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openEditProfile,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              ProfileAvatar(
                name: profile.name,
                avatarUrl: profile.avatarUrl,
                size: 60,
                borderColor: AppColors.primaryDark,
                borderWidth: 2,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.displayMedium
                          ?.copyWith(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.phone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard(UserProfileModel profile) {
    return BangCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          _StatItem(
            icon: Icons.shopping_bag_outlined,
            value: profile.stats.totalOrders.toString(),
            label: 'Total Order',
          ),
          const _StatDivider(),
          _StatItem(
            icon: Icons.account_balance_wallet_outlined,
            value: formatCurrency(profile.stats.totalPaid),
            label: 'Total Bayar',
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(UserProfileModel profile) {
    return BangCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _buildMenuTile(
            icon: Icons.lock_outline,
            title: 'Ganti Password',
            onTap: () => context.push(AppRoutes.changePassword),
          ),
          _divider(),
          _buildMenuTile(
            icon: Icons.location_on_outlined,
            title: 'Alamat Saya',
            onTap: () async {
              await context.push(AppRoutes.addresses);
              if (mounted) _reloadProfile();
            },
          ),
          if (_shouldShowDriverRegistration(profile)) ...[
            _divider(),
            _buildMenuTile(
              icon: Icons.two_wheeler_outlined,
              title: 'Upgrade jadi Driver',
              onTap: () => context.push(AppRoutes.registerDriver),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _handleLogout,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: BorderSide(color: AppColors.error.withValues(alpha: 0.38)),
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: GoogleFonts.nunitoSans(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          backgroundColor: AppColors.white,
        ),
        child: const Text('Keluar'),
      ),
    );
  }

  Widget _buildHelpCard() {
    return BangCard(
      child: Row(
        children: [
          const SizedBox.square(
            dimension: 28,
            child: Icon(
              Icons.support_agent,
              color: AppColors.primary,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Butuh bantuan?',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Kami siap membantu Anda.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          TextButton(onPressed: () {}, child: const Text('Hubungi Kami')),
        ],
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    String? trailingText,
    bool highlightTrailing = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 28,
              child: Icon(icon, color: AppColors.primary, size: 21),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
            if (trailingText != null) ...[
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  trailingText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: highlightTrailing
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontSize: 12.5,
                    fontWeight: highlightTrailing
                        ? FontWeight.w700
                        : FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return const Divider(height: 1, indent: 62, color: AppColors.border);
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.white,
          surfaceTintColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Keluar dari BangDeliv',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Apakah Anda yakin ingin keluar?',
                style: TextStyle(color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => dialogContext.pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                      ),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => dialogContext.pop(true),
                      child: const Text('Keluar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (shouldLogout != true) return;

    await ref.read(authSessionProvider.notifier).logout();

    if (!mounted) return;

    context.go(AppRoutes.login);
  }

  bool _shouldShowDriverRegistration(UserProfileModel profile) {
    return profile.role.trim().toLowerCase() == 'customer';
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          SizedBox.square(
            dimension: 28,
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(height: 7),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 56, color: AppColors.border);
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
        child: BangErrorState(
          title: 'Gagal memuat profil',
          message: message,
          onRetry: onRetry,
        ),
      ),
    );
  }
}
