import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// Imported directly to provide a fake Google Maps platform for this widget test.
// ignore: depend_on_referenced_packages
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:frontend_bangdeliv/models/route_location_picker_result.dart';
import 'package:frontend_bangdeliv/features/addresses/presentation/screens/route_location_picker_screen.dart';

void main() {
  setUpAll(() {
    GoogleMapsFlutterPlatform.instance = _FakeGoogleMapsFlutterPlatform();
  });

  testWidgets('pickup prefill starts destination flow with hidden map', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RouteLocationPickerScreen(
          args: RouteLocationPickerArgs(
            serviceType: 'kurir',
            pickupTarget: 'pickup',
            destinationTarget: 'dropoff',
            pickupLabel: 'Ambil',
            destinationLabel: 'Tujuan',
            title: 'Atur Rute Kurir',
            confirmLabel: 'Simpan Rute Kurir',
            defaultPickupAddress:
                'Jalan Mawar No 1, Sraten, Kabupaten Semarang',
            defaultPickupLatitude: -7.32006,
            defaultPickupLongitude: 110.47065,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Pilih Peta'), findsOneWidget);
    expect(find.text('Tujuan'), findsOneWidget);
    expect(find.byType(GoogleMap), findsNothing);
    expect(
      find.text('Jalan Mawar No 1, Sraten, Kabupaten Semarang'),
      findsNothing,
    );

    await tester.tap(find.text('Ambil').first);
    await tester.pump();

    expect(
      find.text('Jalan Mawar No 1, Sraten, Kabupaten Semarang'),
      findsOneWidget,
    );
    expect(find.text('Lokasi Saya'), findsOneWidget);
  });

  testWidgets('destination map selection rejects point that overlaps pickup', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RouteLocationPickerScreen(
          args: RouteLocationPickerArgs(
            serviceType: 'kurir',
            pickupTarget: 'pickup',
            destinationTarget: 'dropoff',
            pickupLabel: 'Ambil',
            destinationLabel: 'Tujuan',
            title: 'Atur Rute Kurir',
            confirmLabel: 'Simpan Rute Kurir',
            defaultPickupAddress:
                'Jalan Mawar No 1, Sraten, Kabupaten Semarang',
            defaultPickupLatitude: -7.32006,
            defaultPickupLongitude: 110.47065,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Pilih Peta'));
    await tester.pump();

    expect(find.byType(GoogleMap), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
    await tester.pump();
    await tester.pump();

    expect(
      find.text(
        'Titik tujuan terlalu dekat dengan titik jemput. Pilih titik tujuan yang berbeda.',
      ),
      findsOneWidget,
    );
    expect(find.byType(RouteLocationPickerScreen), findsOneWidget);
  });
}

class _FakeGoogleMapsFlutterPlatform extends GoogleMapsFlutterPlatform {
  @override
  Future<void> init(int mapId) async {}

  @override
  Widget buildViewWithConfiguration(
    int creationId,
    PlatformViewCreatedCallback onPlatformViewCreated, {
    required MapWidgetConfiguration widgetConfiguration,
    MapConfiguration mapConfiguration = const MapConfiguration(),
    MapObjects mapObjects = const MapObjects(),
  }) {
    return _FakeGoogleMapView(
      creationId: creationId,
      onPlatformViewCreated: onPlatformViewCreated,
    );
  }

  @override
  Future<void> updateMapConfiguration(
    MapConfiguration configuration, {
    required int mapId,
  }) async {}

  @override
  Future<void> updateMarkers(
    MarkerUpdates markerUpdates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updatePolygons(
    PolygonUpdates polygonUpdates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updatePolylines(
    PolylineUpdates polylineUpdates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updateCircles(
    CircleUpdates circleUpdates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updateHeatmaps(
    HeatmapUpdates heatmapUpdates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updateClusterManagers(
    ClusterManagerUpdates clusterManagerUpdates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updateGroundOverlays(
    GroundOverlayUpdates groundOverlayUpdates, {
    required int mapId,
  }) async {}

  @override
  Future<void> updateTileOverlays({
    required Set<TileOverlay> newTileOverlays,
    required int mapId,
  }) async {}

  @override
  Future<void> animateCamera(
    CameraUpdate cameraUpdate, {
    required int mapId,
  }) async {}

  @override
  Future<void> moveCamera(
    CameraUpdate cameraUpdate, {
    required int mapId,
  }) async {}

  @override
  Stream<CameraMoveStartedEvent> onCameraMoveStarted({required int mapId}) {
    return const Stream<CameraMoveStartedEvent>.empty();
  }

  @override
  Stream<CameraMoveEvent> onCameraMove({required int mapId}) {
    return const Stream<CameraMoveEvent>.empty();
  }

  @override
  Stream<CameraIdleEvent> onCameraIdle({required int mapId}) {
    return const Stream<CameraIdleEvent>.empty();
  }

  @override
  Stream<MarkerTapEvent> onMarkerTap({required int mapId}) {
    return const Stream<MarkerTapEvent>.empty();
  }

  @override
  Stream<MarkerDragStartEvent> onMarkerDragStart({required int mapId}) {
    return const Stream<MarkerDragStartEvent>.empty();
  }

  @override
  Stream<MarkerDragEvent> onMarkerDrag({required int mapId}) {
    return const Stream<MarkerDragEvent>.empty();
  }

  @override
  Stream<MarkerDragEndEvent> onMarkerDragEnd({required int mapId}) {
    return const Stream<MarkerDragEndEvent>.empty();
  }

  @override
  Stream<InfoWindowTapEvent> onInfoWindowTap({required int mapId}) {
    return const Stream<InfoWindowTapEvent>.empty();
  }

  @override
  Stream<PolylineTapEvent> onPolylineTap({required int mapId}) {
    return const Stream<PolylineTapEvent>.empty();
  }

  @override
  Stream<PolygonTapEvent> onPolygonTap({required int mapId}) {
    return const Stream<PolygonTapEvent>.empty();
  }

  @override
  Stream<CircleTapEvent> onCircleTap({required int mapId}) {
    return const Stream<CircleTapEvent>.empty();
  }

  @override
  Stream<MapTapEvent> onTap({required int mapId}) {
    return const Stream<MapTapEvent>.empty();
  }

  @override
  Stream<MapLongPressEvent> onLongPress({required int mapId}) {
    return const Stream<MapLongPressEvent>.empty();
  }

  @override
  Stream<ClusterTapEvent> onClusterTap({required int mapId}) {
    return const Stream<ClusterTapEvent>.empty();
  }

  @override
  void dispose({required int mapId}) {}
}

class _FakeGoogleMapView extends StatefulWidget {
  const _FakeGoogleMapView({
    required this.creationId,
    required this.onPlatformViewCreated,
  });

  final int creationId;
  final PlatformViewCreatedCallback onPlatformViewCreated;

  @override
  State<_FakeGoogleMapView> createState() => _FakeGoogleMapViewState();
}

class _FakeGoogleMapViewState extends State<_FakeGoogleMapView> {
  bool _created = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_created && mounted) {
        _created = true;
        widget.onPlatformViewCreated(widget.creationId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(color: Colors.grey.shade200);
  }
}
