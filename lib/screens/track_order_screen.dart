import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/app_colors.dart';

class TrackOrderScreen extends StatefulWidget {
  const TrackOrderScreen({super.key});

  @override
  State<TrackOrderScreen> createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends State<TrackOrderScreen> {
  // Variabel dummy untuk mengontrol apakah ada order atau tidak
  bool _hasActiveOrder = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Lacak Pesanan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home'); // Fallback if no history
            }
          },
        ),
        actions: [
          // Tombol kecil untuk mengontrol state dummy presentasi
          IconButton(
            icon: const Icon(Icons.swap_horiz, color: AppColors.textPrimary),
            tooltip: 'Ganti status dummy order',
            onPressed: () {
              setState(() {
                _hasActiveOrder = !_hasActiveOrder;
              });
            },
          ),
          if (_hasActiveOrder)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.delivery_dining, size: 16, color: AppColors.primary),
                  const SizedBox(width: 4),
                  const Text('Diantar', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            )
        ],
      ),
      body: _hasActiveOrder ? _buildActiveOrderView() : _buildEmptyState(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: const Icon(
                Icons.map_outlined,
                size: 80,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Belum Ada Pesanan',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Pesan makanan lezat sekarang dan pantau perjalanannya di sini.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  context.go('/home');
                },
                child: const Text('Cari Makanan'),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildActiveOrderView() {
    return SingleChildScrollView(
      child: Column(
          children: [
            // 1. Dummy Map Area
            SizedBox(
              height: 280,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Map Grid Pattern Background
                  Container(
                    width: double.infinity,
                    height: 260, // Sightly shorter to allow the card to overlap nicely
                    color: const Color(0xFFD6EADF), // Light greenish map color
                    child: GridPaper(
                      color: Colors.green.withValues(alpha: 0.2),
                      divisions: 1,
                      subdivisions: 1,
                      interval: 60,
                    ),
                  ),
                  
                  // Map Path Dash Decoration (Simulated)
                  Positioned(
                    top: 80,
                    left: 60,
                    right: 120,
                    child: CustomPaint(
                      size: const Size(double.infinity, 80),
                      painter: DashedPathPainter(),
                    ),
                  ),

                  // Map Markers
                  const Positioned(
                    top: 60,
                    left: 40,
                    child: Icon(Icons.location_on, color: Colors.pink, size: 40),
                  ),
                  const Positioned(
                    top: 130,
                    right: 90,
                    child: Icon(Icons.moped, color: AppColors.primary, size: 40),
                  ),
                  const Positioned(
                    top: 50,
                    right: 80,
                    child: Icon(Icons.home, color: AppColors.primary, size: 30),
                  ),
                  
                  // ETA Floater
                  Positioned(
                    bottom: 40,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Text(
                        'ETA ~5 menit',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                  ),
                  
                  // 2. Driver Card Overlap
                  Positioned(
                    bottom: -40,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          // Driver Avatar
                          Container(
                            height: 60,
                            width: 60,
                            decoration: const BoxDecoration(
                              color: AppColors.cardYellow,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(child: Text('👨', style: TextStyle(fontSize: 30))),
                          ),
                          const SizedBox(width: 16),
                          // Driver Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Budi Santoso', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.star, color: Colors.amber, size: 14),
                                    const Text(' 4.9', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    Text(' · Honda Beat', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                  ],
                                ),
                                Text('B 4521 XYZ', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                              ],
                            ),
                          ),
                          // Actions
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              color: AppColors.darkBlue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.chat_bubble, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.pink.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.phone, color: Colors.pink, size: 20),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 50), // Spacing after overlapping card
            
            // 3. Delivery Status Title
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Status Pengiriman', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            
            // 4. Timeline
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _buildTimelineItem(
                    title: 'Pesanan Dikonfirmasi',
                    subtitle: '09:39 · Driver menerima pesanan',
                    isActive: true,
                    isDone: true,
                    isLast: false,
                  ),
                  _buildTimelineItem(
                    title: 'Driver di Warung',
                    subtitle: '09:44 · Mengambil pesananmu',
                    isActive: true,
                    isDone: true,
                    isLast: false,
                  ),
                  _buildTimelineItem(
                    title: 'Sedang Diantar',
                    subtitle: 'Estimasi tiba ~5 menit',
                    isActive: true,
                    isDone: false,
                    isLast: false,
                  ),
                  _buildTimelineItem(
                    title: 'Pesanan Tiba',
                    subtitle: 'Tunggu driver datang',
                    isActive: false,
                    isDone: false,
                    isLast: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
  }

  Widget _buildTimelineItem({
    required String title,
    required String subtitle,
    required bool isActive,
    required bool isDone,
    required bool isLast,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Marker Column
        Column(
          children: [
            Container(
              height: 24,
              width: 24,
              decoration: BoxDecoration(
                color: isActive ? (isDone ? AppColors.primary : AppColors.primary.withValues(alpha: 0.2)) : Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isDone
                    ? const Icon(Icons.check, color: Colors.white, size: 14)
                    : (isActive
                        ? Container(
                            height: 10,
                            width: 10,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          )
                        : const SizedBox.shrink()),
              ),
            ),
            if (!isLast)
              Container(
                height: 40,
                width: 2,
                color: isActive && isDone ? AppColors.primary : Colors.grey.shade300,
              ),
          ],
        ),
        const SizedBox(width: 16),
        // Content Column
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2), // Align text with circular marker
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isActive ? AppColors.textPrimary : Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isActive ? AppColors.textSecondary : Colors.grey.shade400,
                  ),
                ),
                const SizedBox(height: 24), // Spacing below this item text block
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Custom Painter to draw the dashed line on the dummy map
class DashedPathPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
      
    final path = Path();
    path.moveTo(0, 0);
    path.quadraticBezierTo(size.width * 0.2, 0, size.width * 0.4, size.height * 0.5);
    path.quadraticBezierTo(size.width * 0.6, size.height, size.width, size.height * 0.8);

    // Create dashes manually
    double dashWidth = 8, dashSpace = 6;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, size.height/2), Offset(startX + dashWidth, size.height/2), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
