import 'package:flutter/material.dart';

import '../widgets/tracking_map_section.dart';

class PrivacyMapScreen extends StatelessWidget {
  const PrivacyMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Map Privasi (Sementara)')),
      body: Column(
        children: [
          const Expanded(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: TrackingMapSection(
                dropoffAddress: 'BangDeliv Demo Office',
                pickupLatitude: -7.0522,
                pickupLongitude: 110.4350,
                dropoffLatitude: -7.0503,
                dropoffLongitude: 110.4370,
                driverLatitude: -7.0513,
                driverLongitude: 110.4361,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: const Text(
              'Ini screen sementara untuk preview integrasi Google Maps API.\n'
              'Jika area map masih abu-abu: cek MAPS_API_KEY, Billing aktif, dan Maps SDK for Android aktif.',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
