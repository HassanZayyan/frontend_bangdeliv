import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/app_colors.dart';

class SavedAddressesScreen extends StatelessWidget {
  const SavedAddressesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Alamat Tersimpan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.primary),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildAddressCard('Rumah', 'Jl. Sudirman No. 123, Kec. Sidomukti, Salatiga', true),
          const SizedBox(height: 16),
          _buildAddressCard('Kantor', 'Gedung Indosat Lt. 4, Jl. Diponegoro No. 45, Salatiga', false),
          const SizedBox(height: 16),
          _buildAddressCard('Kos', 'Jl. Kemiri Raya, Gang Ikhlas No. 8, Salatiga', false),
        ],
      ),
    );
  }

  Widget _buildAddressCard(String title, String address, bool isPrimary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isPrimary ? AppColors.primary : AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isPrimary ? AppColors.primary.withValues(alpha: 0.1) : AppColors.background,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.location_on,
              color: isPrimary ? AppColors.primary : AppColors.textSecondary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    if (isPrimary) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Utama', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  address,
                  style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: AppColors.textSecondary, size: 20),
            onPressed: () {},
          )
        ],
      ),
    );
  }
}
