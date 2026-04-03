import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import 'package:go_router/go_router.dart';
import '../config/app_routes.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Orange Background
            Stack(
              children: [
                Container(
                  height: 380,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Avatar
                        Container(
                          height: 100,
                          width: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 4),
                            color: AppColors.darkBlue,
                          ),
                          child: const Icon(Icons.person, size: 50, color: AppColors.primary),
                        ),
                        const SizedBox(height: 16),
                        // Name and Info
                        const Text(
                          'Hassan Naufal',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '+62 812-3456-7890',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Stats Card
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC94A1D), // Darker orange as per screenshot
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: IntrinsicHeight(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildStatItem('38', 'Total Order'),
                                VerticalDivider(color: Colors.white.withValues(alpha: 0.2), thickness: 1),
                                _buildStatItem('Rp 742K', 'Total Bayar'),
                                VerticalDivider(color: Colors.white.withValues(alpha: 0.2), thickness: 1),
                                _buildStatItem('4.9★', 'Rating'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            // Cards Area
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // AKUN Card
                  const Padding(
                    padding: EdgeInsets.only(left: 8, bottom: 8),
                    child: Text('AKUN', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        _buildMenuTile(
                          icon: Icons.person,
                          title: 'Edit Profil',
                          iconColor: AppColors.darkBlue,
                          onTap: () => context.push(AppRoutes.editProfile),
                        ),
                        const Divider(height: 1, indent: 60, color: AppColors.border),
                        _buildMenuTile(
                          icon: Icons.location_on,
                          title: 'Alamat Tersimpan',
                          iconColor: Colors.pinkAccent, // Matching icon distinct colors like in design
                          trailingText: '3 alamat',
                          onTap: () => context.push(AppRoutes.addresses),
                        ),
                        const Divider(height: 1, indent: 60, color: AppColors.border),
                        _buildMenuTile(
                          icon: Icons.notifications,
                          title: 'Notifikasi',
                          iconColor: Colors.orangeAccent,
                          trailingText: 'Aktif',
                          onTap: () => context.push(AppRoutes.notificationSettings),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // LAINNYA Card
                  const Padding(
                    padding: EdgeInsets.only(left: 8, bottom: 8),
                    child: Text('LAINNYA', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        _buildMenuTile(
                          icon: Icons.security,
                          title: 'Kebijakan Privasi',
                          iconColor: Colors.blueAccent,
                        ),
                        const Divider(height: 1, indent: 60, color: AppColors.border),
                        _buildMenuTile(
                          icon: Icons.description,
                          title: 'Syarat & Ketentuan',
                          iconColor: Colors.brown,
                        ),
                        const Divider(height: 1, indent: 60, color: AppColors.border),
                        _buildMenuTile(
                          icon: Icons.info,
                          title: 'Versi Aplikasi',
                          iconColor: Colors.blue,
                          trailingText: 'v1.0.0',
                          showChevron: false,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Logout Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: const Text('Keluar dari Akun', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              content: const Text('Apakah Anda yakin ingin keluar dari aplikasi BangDeliv?', style: TextStyle(color: AppColors.textSecondary)),
                              actions: [
                                TextButton(
                                  onPressed: () => context.pop(),
                                  child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                                ),
                                ElevatedButton(
                                  onPressed: () => context.go(AppRoutes.login),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    elevation: 0,
                                  ),
                                  child: const Text('Ya, Keluar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            );
                          },
                        );
                      },
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required Color iconColor,
    String? trailingText,
    bool showChevron = true,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null)
            Text(
              trailingText,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          if (trailingText != null && showChevron) const SizedBox(width: 8),
          if (showChevron) const Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondary),
        ],
      ),
      onTap: onTap ?? () {},
    );
  }
}
