import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_routes.dart';
import '../../../../config/app_text_scaling.dart';
import '../../../../models/user_profile_model.dart';
import '../../../auth/application/auth_session_provider.dart';
import '../../../../services/auth_service.dart';
import '../../../../utils/order_formatters.dart';
import '../../../../widgets/bang_ui.dart';
import '../../../../widgets/profile_avatar.dart';
import '../../../navigation/presentation/widgets/bang_floating_bottom_nav_bar.dart';

const String _supportWhatsAppNumber = '6288221164320';

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
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ColoredBox(
          color: AppColors.background,
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
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: ClampingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    14,
                    20,
                    BangFloatingBottomNavBar.scrollClearance,
                  ),
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
                    const SizedBox(height: 12),
                    _buildHelpCard(),
                    const SizedBox(height: 12),
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
    final nameFontSize = AppTextScaling.adaptive(
      context,
      normal: 16.5,
      large: 15.4,
    );

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
                size: 56,
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
                            fontSize: nameFontSize,
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
          ] else if (_shouldShowDriverVerificationStatus(profile)) ...[
            _divider(),
            _buildMenuTile(
              icon: Icons.assignment_outlined,
              title: 'Verifikasi Driver',
              trailingText: _driverRegistrationStatusLabel(profile),
              highlightTrailing: _shouldHighlightDriverStatus(profile),
              onTap: () => context.push(AppRoutes.driverVerificationStatus),
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
      padding: EdgeInsets.zero,
      child: _buildMenuTile(
        icon: Icons.support_agent,
        title: 'Butuh bantuan?',
        onTap: _showContactSupportSheet,
      ),
    );
  }

  Future<void> _showContactSupportSheet() async {
    final shouldOpen = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Butuh bantuan?',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Admin siap membantu.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () => sheetContext.pop(false),
                      icon: const Icon(Icons.close_rounded),
                      color: AppColors.textSecondary,
                      tooltip: 'Tutup',
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Material(
                  color: AppColors.surfaceAlt,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => sheetContext.pop(true),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      child: Row(
                        children: [
                          Image.asset(
                            'assets/images/WhatsApp.webp',
                            width: 24,
                            height: 24,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'WhatsApp Admin',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (shouldOpen == true) {
      await _openSupportWhatsApp();
    }
  }

  Future<void> _openSupportWhatsApp() async {
    final message = Uri.encodeComponent('Halo BangDeliv, saya butuh bantuan.');
    final uri = Uri.parse(
      'https://wa.me/$_supportWhatsAppNumber?text=$message',
    );

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('WhatsApp tidak dapat dibuka di perangkat ini.'),
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
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: AppColors.primary),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null) ...[
            SizedBox(
              width: AppTextScaling.adaptive(context, normal: 82, large: 96),
              child: AppTextScaling.clampForCompactComponent(
                context: context,
                maxScaleFactor: AppTextScaling.denseComponentMaxScaleFactor,
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
            ),
            const SizedBox(width: 8),
          ],
          const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ],
      ),
    );
  }

  Widget _divider() {
    return const Divider(height: 1, indent: 56, color: AppColors.border);
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
    return profile.role.trim().toLowerCase() == 'customer' &&
        profile.driverProfile == null;
  }

  bool _shouldShowDriverVerificationStatus(UserProfileModel profile) {
    return profile.driverProfile != null;
  }

  bool _shouldHighlightDriverStatus(UserProfileModel profile) {
    final status = _normalizedDriverRegistrationStatus(profile);
    return status == 'pending' || status == 'submitted' || status == 'review';
  }

  String _driverRegistrationStatusLabel(UserProfileModel profile) {
    switch (_normalizedDriverRegistrationStatus(profile)) {
      case 'active':
      case 'approved':
        return 'Aktif';
      case 'rejected':
        return 'Ditolak';
      case 'suspended':
        return 'Suspend';
      case 'pending':
      case 'submitted':
      case 'review':
      default:
        return 'Menunggu';
    }
  }

  String _normalizedDriverRegistrationStatus(UserProfileModel profile) {
    return (profile.driverProfile?.registrationStatus ?? '')
        .trim()
        .toLowerCase();
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
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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
