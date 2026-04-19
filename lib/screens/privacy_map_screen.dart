import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class PrivacyMapScreen extends StatelessWidget {
  const PrivacyMapScreen({super.key});

  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(-7.0503, 110.4370),
    zoom: 14,
  );

  static const Marker _officeMarker = Marker(
    markerId: MarkerId('bangdeliv-demo-marker'),
    position: LatLng(-7.0503, 110.4370),
    infoWindow: InfoWindow(
      title: 'BangDeliv Demo Map',
      snippet: 'Screen sementara dari menu Kebijakan Privasi',
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Map Privasi (Sementara)')),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: _initialCameraPosition,
              markers: {_officeMarker},
              myLocationButtonEnabled: false,
              mapToolbarEnabled: true,
              zoomControlsEnabled: true,
              compassEnabled: true,
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
