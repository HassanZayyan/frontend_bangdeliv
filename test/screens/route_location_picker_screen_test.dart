import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
// Imported directly to provide a fake Google Maps platform for this widget test.
// ignore: depend_on_referenced_packages
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:frontend_bangdeliv/features/addresses/presentation/screens/route_location_picker_screen.dart';
import 'package:frontend_bangdeliv/models/route_location_picker_result.dart';

void main() {
  late _FakeGoogleMapsFlutterPlatform fakeMaps;

  setUp(() {
    fakeMaps = _FakeGoogleMapsFlutterPlatform();
    GoogleMapsFlutterPlatform.instance = fakeMaps;
  });

  testWidgets('pickup prefill starts destination flow directly on map', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: RouteLocationPickerScreen(args: _courierArgs)),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Pilih Peta'), findsNothing);
    expect(find.text('Tujuan'), findsOneWidget);
    expect(find.byType(GoogleMap), findsOneWidget);
    expect(_primaryButton(tester, 'Simpan').onPressed, isNotNull);
  });

  testWidgets('saved pickup disables save until map moves again', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: RouteLocationPickerScreen(args: _courierArgs)),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Ambil').first);
    await tester.pump();

    expect(_primaryButton(tester, 'Simpan').onPressed, isNull);

    fakeMaps.emitCameraMove(const LatLng(-7.322, 110.472));
    await tester.pump();

    expect(_primaryButton(tester, 'Simpan').onPressed, isNotNull);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
    await tester.pump();
    await tester.pump();

    expect(_primaryButton(tester, 'Simpan').onPressed, isNull);

    fakeMaps.emitCameraMove(const LatLng(-7.323, 110.473));
    await tester.pump();

    expect(_primaryButton(tester, 'Simpan').onPressed, isNotNull);
  });

  testWidgets('destination save enables confirmation dialog', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: RouteLocationPickerScreen(args: _courierArgs)),
    );
    await tester.pump();
    await tester.pump();

    fakeMaps.emitCameraMove(const LatLng(-7.3312, 110.5077));
    await tester.pump();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
    await tester.pump();
    await tester.pump();

    expect(find.widgetWithText(ElevatedButton, 'Konfirmasi'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Konfirmasi'));
    await tester.pump();

    expect(find.text('Konfirmasi lokasi'), findsOneWidget);
    expect(find.text('Ambil'), findsWidgets);
    expect(find.text('Tujuan'), findsWidgets);
    expect(find.widgetWithText(OutlinedButton, 'Ubah'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Konfirmasi'), findsOneWidget);
  });

  testWidgets(
    'confirm returns only destination when pickup default is unchanged',
    (WidgetTester tester) async {
      RouteLocationPickerResult? result;
      final router = _routerForResult((value) => result = value);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(find.text('Open picker'));
      await tester.pump();
      await tester.pump();

      fakeMaps.emitCameraMove(const LatLng(-7.3312, 110.5077));
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Konfirmasi'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Konfirmasi'));
      await tester.pump();
      await tester.pump();

      expect(result, isNotNull);
      expect(result!.locations.map((location) => location.target), ['dropoff']);
    },
  );

  testWidgets('confirm returns pickup when pickup was changed', (
    WidgetTester tester,
  ) async {
    RouteLocationPickerResult? result;
    final router = _routerForResult((value) => result = value);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Open picker'));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Ambil').first);
    await tester.pump();
    fakeMaps.emitCameraMove(const LatLng(-7.322, 110.472));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Tujuan').first);
    await tester.pump();
    fakeMaps.emitCameraMove(const LatLng(-7.3312, 110.5077));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Konfirmasi'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Konfirmasi'));
    await tester.pump();
    await tester.pump();

    expect(result, isNotNull);
    expect(result!.locations.map((location) => location.target), [
      'pickup',
      'dropoff',
    ]);
  });

  testWidgets('destination save rejects point that overlaps pickup', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: RouteLocationPickerScreen(args: _courierArgs)),
    );
    await tester.pump();
    await tester.pump();

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

const _courierArgs = RouteLocationPickerArgs(
  serviceType: 'kurir',
  pickupTarget: 'pickup',
  destinationTarget: 'dropoff',
  pickupLabel: 'Ambil',
  destinationLabel: 'Tujuan',
  title: 'Atur Rute Kurir',
  confirmLabel: 'Konfirmasi',
  defaultPickupAddress: 'Jalan Mawar No 1, Sraten, Kabupaten Semarang',
  defaultPickupLatitude: -7.32006,
  defaultPickupLongitude: 110.47065,
);

ElevatedButton _primaryButton(WidgetTester tester, String text) {
  return tester.widget<ElevatedButton>(
    find.widgetWithText(ElevatedButton, text),
  );
}

GoRouter _routerForResult(ValueChanged<RouteLocationPickerResult> onResult) {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) {
          return Material(
            child: Center(
              child: ElevatedButton(
                onPressed: () async {
                  final result = await context.push<RouteLocationPickerResult>(
                    '/picker',
                  );
                  if (result != null) {
                    onResult(result);
                  }
                },
                child: const Text('Open picker'),
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: '/picker',
        builder: (context, state) {
          return const RouteLocationPickerScreen(args: _courierArgs);
        },
      ),
    ],
  );
}

class _FakeGoogleMapsFlutterPlatform extends GoogleMapsFlutterPlatform {
  final Map<int, StreamController<CameraMoveStartedEvent>>
  _cameraMoveStartedControllers = {};
  final Map<int, StreamController<CameraMoveEvent>> _cameraMoveControllers = {};
  final Map<int, StreamController<CameraIdleEvent>> _cameraIdleControllers = {};
  int? _lastMapId;

  @override
  Future<void> init(int mapId) async {}

  void emitCameraMove(LatLng target) {
    final mapId = _lastMapId;
    if (mapId == null) {
      return;
    }

    _cameraMoveStartedController(mapId).add(CameraMoveStartedEvent(mapId));
    _cameraMoveController(
      mapId,
    ).add(CameraMoveEvent(mapId, CameraPosition(target: target, zoom: 17)));
    _cameraIdleController(mapId).add(CameraIdleEvent(mapId));
  }

  @override
  Widget buildViewWithConfiguration(
    int creationId,
    PlatformViewCreatedCallback onPlatformViewCreated, {
    required MapWidgetConfiguration widgetConfiguration,
    MapConfiguration mapConfiguration = const MapConfiguration(),
    MapObjects mapObjects = const MapObjects(),
  }) {
    _lastMapId = creationId;
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
    return _cameraMoveStartedController(mapId).stream;
  }

  @override
  Stream<CameraMoveEvent> onCameraMove({required int mapId}) {
    return _cameraMoveController(mapId).stream;
  }

  @override
  Stream<CameraIdleEvent> onCameraIdle({required int mapId}) {
    return _cameraIdleController(mapId).stream;
  }

  StreamController<CameraMoveStartedEvent> _cameraMoveStartedController(
    int mapId,
  ) {
    return _cameraMoveStartedControllers.putIfAbsent(
      mapId,
      StreamController<CameraMoveStartedEvent>.broadcast,
    );
  }

  StreamController<CameraMoveEvent> _cameraMoveController(int mapId) {
    return _cameraMoveControllers.putIfAbsent(
      mapId,
      StreamController<CameraMoveEvent>.broadcast,
    );
  }

  StreamController<CameraIdleEvent> _cameraIdleController(int mapId) {
    return _cameraIdleControllers.putIfAbsent(
      mapId,
      StreamController<CameraIdleEvent>.broadcast,
    );
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
  void dispose({required int mapId}) {
    _cameraMoveStartedControllers.remove(mapId)?.close();
    _cameraMoveControllers.remove(mapId)?.close();
    _cameraIdleControllers.remove(mapId)?.close();
  }
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
