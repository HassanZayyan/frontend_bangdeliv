import 'package:flutter/material.dart';
import '../config/app_routes.dart';
import 'package:go_router/go_router.dart';
import '../config/app_colors.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _waController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Header (Orange)
            Expanded(
              flex: 2,
              child: centerHeader(),
            ),
            
            // Bottom Card (White)
            Expanded(
              flex: 6,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: SingleChildScrollView(
                  child: bottomForm(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget centerHeader() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 16),
        Text(
          'Daftar Baru',
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Bergabung dan nikmati kemudahannya',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.white.withValues(alpha: 0.8),
              ),
        ),
      ],
    );
  }

  Widget bottomForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Buat Akun Anda',
          style: Theme.of(context).textTheme.displayMedium,
        ),
        const SizedBox(height: 24),
        
        // Name Input
        TextField(
          controller: _nameController,
          keyboardType: TextInputType.name,
          decoration: const InputDecoration(
            hintText: 'Nama Lengkap',
            prefixIcon: Icon(Icons.person_outline, color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(height: 16),

        // WA Input
        TextField(
          controller: _waController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            hintText: 'Nomor WhatsApp',
            prefixIcon: Icon(Icons.phone_android, color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(height: 16),

        // Password Input
        TextField(
          controller: _passwordController,
          obscureText: !_isPasswordVisible,
          decoration: InputDecoration(
            hintText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textSecondary),
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                color: AppColors.textSecondary,
              ),
              onPressed: () {
                setState(() {
                  _isPasswordVisible = !_isPasswordVisible;
                });
              },
            ),
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Tombol Daftar
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              // TODO: Logic register, sementara arahkan ke Home / pop
              context.go(AppRoutes.home);
            },
            child: const Text('Daftar ->'),
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Divider
        Row(
          children: [
            const Expanded(child: Divider(color: AppColors.border)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'atau',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const Expanded(child: Divider(color: AppColors.border)),
          ],
        ),
        
        const SizedBox(height: 24),
        
        // Sudah punya akun
        Center(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Sudah punya akun? ',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              InkWell(
                onTap: () {
                  context.pop(); // Kembali ke halaman Login
                },
                child: Text(
                  'Masuk Sekarang',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _waController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
