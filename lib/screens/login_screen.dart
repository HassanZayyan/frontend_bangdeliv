import 'package:flutter/material.dart';
import '../config/app_routes.dart';
import 'package:go_router/go_router.dart';
import '../config/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _waController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        bottom: false, // Card putih sampai bawah
        child: Column(
          children: [
            // Top Header (Orange)
            Expanded(
              flex: 3,
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
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            '🛵',
            style: TextStyle(fontSize: 40),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'BangDeliv',
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Pesan makanan lokal, cepat & terjangkau',
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
          'Masuk ke Akun',
          style: Theme.of(context).textTheme.displayMedium,
        ),
        const SizedBox(height: 24),
        
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
        
        // Lupa Password
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              context.push(AppRoutes.forgotPassword);
            },
            child: const Text(
              'Lupa password?',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Tombol Masuk
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              // Navigasi ke halaman Home (simulasi login berhasil)
              context.go(AppRoutes.home);
            },
            child: const Text('Masuk ->'),
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
                'atau lanjutkan dengan',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const Expanded(child: Divider(color: AppColors.border)),
          ],
        ),
        
        const SizedBox(height: 24),
        
        // Tombol Google
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Text('G', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
            label: Text(
              'Masuk dengan Google',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),

        const SizedBox(height: 32),
        
        // Belum punya akun
        Center(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Belum punya akun? ',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              InkWell(
                onTap: () {
                  context.push(AppRoutes.register);
                },
                child: Text(
                  'Daftar Sekarang',
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
    _waController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
