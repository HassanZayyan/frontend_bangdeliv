import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/app_colors.dart';
import '../../../../config/app_routes.dart';
import '../../../auth/application/auth_session_provider.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  bool _orderUpdates = true;
  bool _chatMessages = true;
  bool _appUpdates = false;

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }

    final session = ref.read(authSessionProvider);
    final fallbackRoute = session.role == SessionUserRole.driver
        ? AppRoutes.driverProfile
        : AppRoutes.profile;
    context.go(fallbackRoute);
  }

  Widget _buildBackNavigationGuard() {
    return PopScope<void>(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }

        _handleBack();
      },
      child: const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Pengaturan Notifikasi',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Kembali',
          icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
          onPressed: _handleBack,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSettingsGroup(
            title: 'Pesanan & Chat',
            children: [
              _buildSwitchTile(
                title: 'Update Pesanan',
                subtitle: 'Pemberitahuan perubahan status pesanan Anda',
                value: _orderUpdates,
                onChanged: (val) => setState(() => _orderUpdates = val),
              ),
              const Divider(
                height: 1,
                indent: 20,
                endIndent: 20,
                color: AppColors.border,
              ),
              _buildSwitchTile(
                title: 'Pesan Chat Baru',
                subtitle: 'Notifikasi pesan baru dari driver, penjual, atau AI',
                value: _chatMessages,
                onChanged: (val) => setState(() => _chatMessages = val),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSettingsGroup(
            title: 'Pembaruan',
            children: [
              _buildSwitchTile(
                title: 'Pembaruan Aplikasi',
                subtitle: 'Informasi fitur baru dan peningkatan aplikasi',
                value: _appUpdates,
                onChanged: (val) => setState(() => _appUpdates = val),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: _buildBackNavigationGuard(),
    );
  }

  Widget _buildSettingsGroup({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ),
      value: value,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      onChanged: onChanged,
    );
  }
}
