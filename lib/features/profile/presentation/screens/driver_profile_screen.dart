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
import '../../../../widgets/bang_ui.dart';
import '../../../../widgets/profile_avatar.dart';
import '../../../navigation/presentation/widgets/bang_floating_bottom_nav_bar.dart';

const String _supportWhatsAppNumber = '6288221164320';

class DriverProfileScreen extends ConsumerStatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  ConsumerState<DriverProfileScreen> createState() =>
      _DriverProfileScreenState();
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
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

          return RefreshIndicator(
            onRefresh: _reloadProfile,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                20,
                14,
                20,
                BangFloatingBottomNavBar.scrollClearance,
              ),
              children: [
                _buildProfileHero(profile),
                const SizedBox(height: 20),
                _buildStatsCard(profile),
                const SizedBox(height: 24),
                _sectionTitle('Data Operasional'),
                const SizedBox(height: 12),
                _buildOperationalCard(profile.driverProfile),
                const SizedBox(height: 26),
                _sectionTitle('Akun & Pengaturan'),
                const SizedBox(height: 12),
                _buildQuickActionCard(context),
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
    );
  }

  Future<void> _openEditProfile() async {
    final updated = await context.push<bool>(AppRoutes.editProfile);
    if (updated == true && mounted) {
      await _reloadProfile();
    }
  }

  Widget _buildProfileHero(UserProfileModel profile) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openEditProfile,
        borderRadius: BorderRadius.circular(18),
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
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
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile.phone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      profile.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
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
    final driverProfile = profile.driverProfile;
    final completedOrders = (driverProfile?.totalDeliveries ?? 0) > 0
        ? driverProfile!.totalDeliveries
        : profile.stats.totalOrders;

    return BangCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: _DriverStatItem(
        icon: Icons.task_alt_rounded,
        value: completedOrders.toString(),
        label: 'Order Selesai',
      ),
    );
  }

  Widget _buildOperationalCard(DriverProfileModel? driverProfile) {
    final operationalStatus = (driverProfile?.status ?? 'offline')
        .trim()
        .toLowerCase();
    final vehicleType = (driverProfile?.vehicleType ?? '').trim();
    final vehicleBrand = (driverProfile?.vehicleBrand ?? '').trim();
    final vehicleModel = (driverProfile?.vehicleModel ?? '').trim();
    final vehiclePlate = (driverProfile?.vehiclePlate ?? '').trim();

    return BangCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _labelPill(
            _operationalLabel(operationalStatus),
            foreground: _operationalColor(operationalStatus),
          ),
          const SizedBox(height: 10),
          _detailRow('Jenis Motor', vehicleType.isEmpty ? '-' : vehicleType),
          const SizedBox(height: 8),
          _detailRow('Merk Motor', vehicleBrand.isEmpty ? '-' : vehicleBrand),
          const SizedBox(height: 8),
          _detailRow('Tipe Motor', vehicleModel.isEmpty ? '-' : vehicleModel),
          const SizedBox(height: 8),
          _detailRow(
            'Plat Kendaraan',
            vehiclePlate.isEmpty ? '-' : vehiclePlate.toUpperCase(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(BuildContext context) {
    return BangCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _actionTile(
            icon: Icons.person_outline,
            title: 'Edit Profil',
            onTap: _openEditProfile,
          ),
          const Divider(height: 1, indent: 56, color: AppColors.border),
          _actionTile(
            icon: Icons.lock_outline,
            title: 'Ganti Password',
            onTap: () => context.push(AppRoutes.changePassword),
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
        ],
      ),
    );
  }

  Widget _buildHelpCard() {
    return BangCard(
      padding: EdgeInsets.zero,
      child: _actionTile(
        icon: Icons.support_agent,
        title: 'Bantuan Driver',
        onTap: _showHelpCenter,
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
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          backgroundColor: AppColors.white,
        ),
        child: const Text('Keluar'),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 15,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _labelPill(String text, {required Color foreground}) {
    return AppTextScaling.clampForCompactComponent(
      context: context,
      maxScaleFactor: AppTextScaling.denseComponentMaxScaleFactor,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: foreground,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: AppTextScaling.adaptive(context, normal: 120, large: 104),
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
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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
      enableFeedback: false,
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
      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
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

  Future<void> _showHelpCenter() async {
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
                    splashFactory: NoSplash.splashFactory,
                    overlayColor: const WidgetStatePropertyAll(
                      Colors.transparent,
                    ),
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
    final message = Uri.encodeComponent(
      'Halo BangDeliv, saya butuh bantuan sebagai driver.',
    );
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

class _DriverStatItem extends StatelessWidget {
  const _DriverStatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 24,
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: AppTextScaling.adaptive(
                    context,
                    normal: 18,
                    large: 16,
                  ),
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
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
      ],
    );
  }
}
