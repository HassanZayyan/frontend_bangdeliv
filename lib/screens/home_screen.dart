import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/app_routes.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header Orange & Search Bar
            _buildHeader(context),
            
            // Konten scrollable
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.white,
                onRefresh: () async {
                  // TODO: Panggil fungsi load data API di sini nantinya
                  await Future.delayed(const Duration(seconds: 1, milliseconds: 500));
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner Chatbot
                    _buildChatbotBanner(context),
                    
                    const SizedBox(height: 24),
                    
                    // Kategori Makanan
                    _buildSectionTitle('Kategori'),
                    const SizedBox(height: 12),
                    _buildCategories(),
                    
                    const SizedBox(height: 24),
                    
                    // Menu Populer
                    _buildSectionTitle('Menu Populer'),
                    const SizedBox(height: 12),
                    _buildPopularMenus(),

                    const SizedBox(height: 24),

                    // Merchant Terdekat
                    _buildSectionTitle('Merchant Terdekat'),
                    const SizedBox(height: 12),
                    _buildNearbyMerchants(),
                    const SizedBox(height: 100), // Spacing for bottom navbar
                  ],
                ),
              ),
            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Selamat siang, 👋', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14)),
                  const Text('Hassan!', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              IconButton(
                onPressed: () {
                  context.push(AppRoutes.notifications); 
                },
                icon: const Icon(Icons.notifications_outlined, color: Colors.white),
              )
            ],
          ),
          const SizedBox(height: 20),
          // Search Bar
          TextField(
            decoration: InputDecoration(
              hintText: 'Cari restoran atau menu...',
              prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatbotBanner(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.chatbot),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.darkBlue,
          borderRadius: BorderRadius.circular(16),
        ),
      child: Row(
        children: [
          // Icon Bintang AI
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Text('✨', style: TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 16),
          // Texts
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pesan via AI Chatbot', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text('Ketik pesanan, AI yang urus semua!', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.white),
        ],
      ),
    ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildCategories() {
    return const SizedBox.shrink();
  }

  Widget _buildPopularMenus() {
    return const SizedBox.shrink();
  }

  Widget _buildNearbyMerchants() {
    return const SizedBox.shrink();
  }
}
