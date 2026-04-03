import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/app_colors.dart';

class ChatbotScreen extends StatelessWidget {
  const ChatbotScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141624), // Sesuai dengan referensi layar chatbot (sangat gelap)
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B1E30),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: AppColors.white),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BangBot AI',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Online & Siap Membantu',
                      style: TextStyle(color: Colors.greenAccent, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz, color: AppColors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(right: 50, bottom: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2138),
                      borderRadius: BorderRadius.circular(16).copyWith(topLeft: const Radius.circular(4)),
                    ),
                    child: const Text(
                      'Halo! Saya BangBot 🤖\nMau pesan apa hari ini? Ketik pesananmu secara natural, saya yang mengurus sisanya!',
                      style: TextStyle(color: Colors.white, height: 1.5),
                    ),
                  ),
                ),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('09:39', style: TextStyle(color: Colors.white54, fontSize: 12)),
                ),
              ],
            ),
          ),
          
          // Suggestions and Input Bottom Fixed
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: const BoxDecoration(
              color: Color(0xFF1B1E30),
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Suggestions Row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildSuggestionChip('🍜 Mie Ayam'),
                        const SizedBox(width: 8),
                        _buildSuggestionChip('🍗 Geprek'),
                        const SizedBox(width: 8),
                        _buildSuggestionChip('🥤 Minuman'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Input Box
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: const TextField(
                            style: TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Color(0xFF141624),
                              hintText: 'Ketik pesanan...',
                              hintStyle: TextStyle(color: Colors.white54, fontSize: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(25)),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(25)),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(25)),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 50,
                        height: 50,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.send, color: Colors.white),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF20202F), // Darker background
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.primary, width: 1.2), // Solid orange border
      ),
      child: Text(
        label,
        style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.normal),
      ),
    );
  }
}
