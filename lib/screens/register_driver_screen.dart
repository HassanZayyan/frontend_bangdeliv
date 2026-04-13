import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_colors.dart';
import '../config/app_routes.dart';
import '../models/user_profile_model.dart';
import '../providers/auth_session_provider.dart';
import '../services/auth_service.dart';

class RegisterDriverScreen extends ConsumerStatefulWidget {
  const RegisterDriverScreen({super.key});

  @override
  ConsumerState<RegisterDriverScreen> createState() =>
      _RegisterDriverScreenState();
}

class _RegisterDriverScreenState extends ConsumerState<RegisterDriverScreen> {
  final _formKey = GlobalKey<FormState>();
  final _vehiclePlateController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);
    final profile = session.profile;

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(flex: 2, child: _header(context)),
            Expanded(
              flex: 6,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: SingleChildScrollView(child: _form(context, profile)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 16),
        Text(
          'Upgrade Jadi Driver',
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Akun customer Anda akan diaktifkan sebagai driver',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _form(BuildContext context, UserProfileModel? profile) {
    final name = (profile?.name ?? '').toString();
    final email = (profile?.email ?? '').toString();

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lengkapi Data Driver',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Tidak perlu membuat akun baru. Data akun customer Anda akan digunakan.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          _InfoTile(label: 'Nama', value: name.isEmpty ? '-' : name),
          const SizedBox(height: 8),
          _InfoTile(label: 'Email', value: email.isEmpty ? '-' : email),
          const SizedBox(height: 18),
          TextFormField(
            controller: _vehiclePlateController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'Nomor Plat Kendaraan',
              prefixIcon: Icon(
                Icons.directions_car_outlined,
                color: AppColors.textSecondary,
              ),
            ),
            validator: (value) {
              final vehiclePlate = value?.trim() ?? '';
              if (vehiclePlate.isEmpty) {
                return 'Nomor plat wajib diisi';
              }

              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _licenseNumberController,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleUpgrade(),
            decoration: const InputDecoration(
              hintText: 'Nomor SIM',
              prefixIcon: Icon(
                Icons.badge_outlined,
                color: AppColors.textSecondary,
              ),
            ),
            validator: (value) {
              final licenseNumber = value?.trim() ?? '';
              if (licenseNumber.isEmpty) {
                return 'Nomor SIM wajib diisi';
              }

              return null;
            },
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _handleUpgrade,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : const Text('Aktifkan Akun Driver ->'),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: TextButton(
              onPressed: () => context.pop(),
              child: const Text(
                'Kembali ke Profil',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleUpgrade() async {
    if (_isSubmitting) {
      return;
    }

    final currentState = _formKey.currentState;
    if (currentState == null || !currentState.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await AuthService.upgradeToDriver(
        vehiclePlate: _vehiclePlateController.text.trim(),
        licenseNumber: _licenseNumberController.text.trim(),
      );

      await ref.read(authSessionProvider.notifier).refreshSession();

      if (!mounted) {
        return;
      }

      context.go(AppRoutes.driverVerificationStatus);
    } on AuthException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red.shade600,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _vehiclePlateController.dispose();
    _licenseNumberController.dispose();
    super.dispose();
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;

  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
