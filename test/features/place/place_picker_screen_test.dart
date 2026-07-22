import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:togethertrip/features/place/model/place_models.dart';
import 'package:togethertrip/features/place/screen/place_picker_screen.dart';
import 'package:togethertrip/features/place/service/place_location_provider.dart';
import 'package:togethertrip/features/place/service/place_service.dart';

void main() {
  testWidgets('검색 결과를 선택해 좌표가 있는 장소를 반환한다', (tester) async {
    final service = _FakePlaceService();
    PlaceSelection? result;
    await _pumpHarness(
      tester,
      service: service,
      onResult: (value) => result = value,
    );

    await tester.enterText(
      find.byKey(const ValueKey('placeSearchField')),
      '도쿄역',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('placeSuggestion_place-1')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('placeSuggestion_place-1')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('confirmPlaceButton')));
    await tester.pumpAndSettle();

    expect(result?.name, '도쿄역');
    expect(result?.latitude, 35.681236);
  });

  testWidgets('직접 입력은 오래된 좌표 없이 장소명만 반환한다', (tester) async {
    PlaceSelection? result;
    await _pumpHarness(
      tester,
      service: _FakePlaceService(),
      initialSelection: _selection,
      onResult: (value) => result = value,
    );

    await tester.tap(find.byKey(const ValueKey('manualPlaceButton')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('manualPlaceField')),
      '새 장소',
    );
    await tester.tap(find.byKey(const ValueKey('confirmPlaceButton')));
    await tester.pumpAndSettle();

    expect(result?.name, '새 장소');
    expect(result?.hasCoordinates, false);
  });

  testWidgets('직접 입력한 장소명에 지도에서 새로 선택한 좌표를 함께 반환한다', (tester) async {
    PlaceSelection? result;
    await _pumpHarness(
      tester,
      service: _FakePlaceService(),
      initialSelection: _selection,
      onResult: (value) => result = value,
    );

    await tester.tap(find.byKey(const ValueKey('manualPlaceButton')));
    await tester.pump();

    expect(find.byKey(const ValueKey('fakeMapCoordinate')), findsOneWidget);
    expect(find.text('지도에서 위치를 누르면 핀도 함께 저장돼요.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('manualPlaceField')),
      '우리 숙소',
    );
    await tester.tap(find.byKey(const ValueKey('fakeMapCoordinate')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('confirmPlaceButton')));
    await tester.pumpAndSettle();

    expect(result?.name, '우리 숙소');
    expect(result?.placeId, isNull);
    expect(result?.latitude, 34.6937);
    expect(result?.longitude, 135.5023);
  });

  testWidgets('현재 위치를 선택하면 역지오코딩한다', (tester) async {
    final service = _FakePlaceService();
    PlaceSelection? result;
    await _pumpHarness(
      tester,
      service: service,
      locationProvider: const _FakeLocationProvider(),
      onResult: (value) => result = value,
    );

    await tester.tap(find.byKey(const ValueKey('currentLocationButton')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('confirmPlaceButton')));
    await tester.pumpAndSettle();

    expect(service.reverseLatitude, 35.681236);
    expect(result?.name, '도쿄역');
  });

  testWidgets('지도 좌표를 누르면 핀 위치를 역지오코딩한다', (tester) async {
    final service = _FakePlaceService();
    await _pumpHarness(tester, service: service, onResult: (_) {});

    await tester.tap(find.byKey(const ValueKey('fakeMapCoordinate')));
    await tester.pump();

    expect(service.reverseLatitude, 34.6937);
    expect(find.text('도쿄역'), findsOneWidget);
  });

  testWidgets('역지오코딩이 실패해도 지도에서 선택한 좌표는 유지한다', (tester) async {
    final service = _FakePlaceService(shouldFailReverse: true);
    PlaceSelection? result;
    await _pumpHarness(
      tester,
      service: service,
      onResult: (value) => result = value,
    );

    await tester.tap(find.byKey(const ValueKey('fakeMapCoordinate')));
    await tester.pump();

    expect(find.text('선택한 위치'), findsOneWidget);
    expect(find.text('장소명은 확인하지 못했지만 선택한 위치는 표시했어요.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('confirmPlaceButton')));
    await tester.pumpAndSettle();

    expect(result?.latitude, 34.6937);
    expect(result?.longitude, 135.5023);
  });

  testWidgets('검색 실패 후에도 직접 입력을 사용할 수 있다', (tester) async {
    final service = _FakePlaceService(shouldFailSearch: true);
    await _pumpHarness(tester, service: service, onResult: (_) {});

    await tester.enterText(
      find.byKey(const ValueKey('placeSearchField')),
      '없는 장소',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(find.text('장소를 검색하지 못했습니다. 직접 입력할 수 있어요.'), findsOneWidget);
    expect(find.byKey(const ValueKey('manualPlaceButton')), findsOneWidget);
  });

  testWidgets('검색 결과의 장소 상세 조회가 실패하면 오류를 표시한다', (tester) async {
    await _pumpHarness(
      tester,
      service: _FakePlaceService(shouldFailDetail: true),
      onResult: (_) {},
    );

    await tester.enterText(
      find.byKey(const ValueKey('placeSearchField')),
      '도쿄역',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('placeSuggestion_place-1')));
    await tester.pump();

    expect(find.text('선택한 장소 정보를 불러오지 못했습니다.'), findsOneWidget);
  });

  testWidgets('현재 위치 조회가 실패하면 provider 오류를 표시한다', (tester) async {
    await _pumpHarness(
      tester,
      service: _FakePlaceService(),
      locationProvider: const _FailingLocationProvider(),
      onResult: (_) {},
    );

    await tester.tap(find.byKey(const ValueKey('currentLocationButton')));
    await tester.pump();

    expect(find.text('현재 위치 조회 실패'), findsOneWidget);
  });

  testWidgets('장소 선택 없이 확인하면 선택 안내를 표시한다', (tester) async {
    await _pumpHarness(tester, service: _FakePlaceService(), onResult: (_) {});

    await tester.tap(find.byKey(const ValueKey('confirmPlaceButton')));
    await tester.pump();

    expect(find.text('장소를 선택하거나 직접 입력해주세요.'), findsOneWidget);
  });

  testWidgets('직접 입력 장소명이 비어 있으면 입력 안내를 표시한다', (tester) async {
    await _pumpHarness(tester, service: _FakePlaceService(), onResult: (_) {});

    await tester.tap(find.byKey(const ValueKey('manualPlaceButton')));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('manualPlaceField')), '');
    await tester.tap(find.byKey(const ValueKey('confirmPlaceButton')));
    await tester.pump();

    expect(find.text('장소명을 입력해주세요.'), findsOneWidget);
  });

  testWidgets('직접 입력에서 이름보다 좌표를 먼저 선택해도 나중에 작성한 이름을 반환한다', (tester) async {
    PlaceSelection? result;
    await _pumpHarness(
      tester,
      service: _FakePlaceService(),
      onResult: (value) => result = value,
    );

    await tester.tap(find.byKey(const ValueKey('manualPlaceButton')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('fakeMapCoordinate')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('manualPlaceField')),
      '우리 숙소',
    );
    await tester.tap(find.byKey(const ValueKey('confirmPlaceButton')));
    await tester.pumpAndSettle();

    expect(result?.name, '우리 숙소');
    expect(result?.latitude, 34.6937);
  });

  testWidgets('Google 지도 생성 시 초기 핀을 표시하고 선택 위치로 카메라를 이동한다', (tester) async {
    final originalPlatform = GoogleMapsFlutterPlatform.instance;
    final mapPlatform = _FakeGoogleMapsFlutterPlatform();
    GoogleMapsFlutterPlatform.instance = mapPlatform;
    addTearDown(() => GoogleMapsFlutterPlatform.instance = originalPlatform);

    await tester.pumpWidget(
      MaterialApp(
        home: PlacePickerScreen(
          tripId: 10,
          initialSelection: _selection,
          placeService: _FakePlaceService(),
          locationProvider: const _FakeLocationProvider(),
        ),
      ),
    );
    await tester.pump();

    expect(mapPlatform.initialCameraPosition?.target.latitude, 35.681236);
    expect(mapPlatform.markers.single.position.latitude, 35.681236);
    expect(mapPlatform.initializedMapIds, isNotEmpty);

    final googleMap = tester.widget<GoogleMap>(find.byType(GoogleMap));
    googleMap.onTap!(const LatLng(34.6937, 135.5023));
    await tester.pump();

    expect(mapPlatform.animateCameraCalls, 1);

    await tester.tap(find.byKey(const ValueKey('currentLocationButton')));
    await tester.pump();

    expect(mapPlatform.animateCameraCalls, 3);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<void> _pumpHarness(
  WidgetTester tester, {
  required _FakePlaceService service,
  required ValueChanged<PlaceSelection> onResult,
  PlaceSelection? initialSelection,
  PlaceLocationProvider? locationProvider,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            onPressed: () async {
              final result = await Navigator.of(context).push<PlaceSelection>(
                MaterialPageRoute(
                  builder: (_) => PlacePickerScreen(
                    tripId: 10,
                    initialSelection: initialSelection,
                    placeService: service,
                    locationProvider: locationProvider,
                    mapBuilder: (selection, onCoordinateSelected) {
                      return Center(
                        child: FilledButton(
                          key: const ValueKey('fakeMapCoordinate'),
                          onPressed: () => onCoordinateSelected(
                            const LatLng(34.6937, 135.5023),
                          ),
                          child: const Text('지도 좌표 선택'),
                        ),
                      );
                    },
                  ),
                ),
              );
              if (result != null) onResult(result);
            },
            child: const Text('장소 열기'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('장소 열기'));
  await tester.pumpAndSettle();
}

class _FakePlaceService extends PlaceService {
  final bool shouldFailSearch;
  final bool shouldFailDetail;
  final bool shouldFailReverse;
  double? reverseLatitude;

  _FakePlaceService({
    this.shouldFailSearch = false,
    this.shouldFailDetail = false,
    this.shouldFailReverse = false,
  });

  @override
  Future<List<PlaceSuggestion>> autocomplete(
    int tripId, {
    required String query,
    required String sessionToken,
    String languageCode = 'ko',
  }) async {
    if (shouldFailSearch) throw Exception('search failed');
    return const [
      PlaceSuggestion(placeId: 'place-1', name: '도쿄역', address: '일본 도쿄도'),
    ];
  }

  @override
  Future<PlaceSelection> getPlace(
    int tripId, {
    required String placeId,
    required String sessionToken,
    String languageCode = 'ko',
  }) async {
    if (shouldFailDetail) throw Exception('place detail failed');
    return _selection;
  }

  @override
  Future<PlaceSelection> reverseGeocode(
    int tripId, {
    required double latitude,
    required double longitude,
    String languageCode = 'ko',
  }) async {
    reverseLatitude = latitude;
    if (shouldFailReverse) throw Exception('reverse geocode failed');
    return _selection;
  }
}

class _FakeLocationProvider implements PlaceLocationProvider {
  const _FakeLocationProvider();

  @override
  Future<PlaceDeviceLocation> getCurrentLocation() async {
    return const PlaceDeviceLocation(
      latitude: 35.681236,
      longitude: 139.767125,
    );
  }
}

class _FailingLocationProvider implements PlaceLocationProvider {
  const _FailingLocationProvider();

  @override
  Future<PlaceDeviceLocation> getCurrentLocation() async {
    throw const PlaceLocationException('현재 위치 조회 실패');
  }
}

const _selection = PlaceSelection(
  placeId: 'place-1',
  name: '도쿄역',
  address: '일본 도쿄도',
  latitude: 35.681236,
  longitude: 139.767125,
);

class _FakeGoogleMapsFlutterPlatform extends GoogleMapsFlutterPlatform
    with MockPlatformInterfaceMixin {
  final initializedMapIds = <int>[];
  final _createdMapIds = <int>{};
  CameraPosition? initialCameraPosition;
  Set<Marker> markers = const {};
  int animateCameraCalls = 0;

  @override
  Widget buildViewWithConfiguration(
    int creationId,
    PlatformViewCreatedCallback onPlatformViewCreated, {
    required MapWidgetConfiguration widgetConfiguration,
    MapConfiguration mapConfiguration = const MapConfiguration(),
    MapObjects mapObjects = const MapObjects(),
  }) {
    initialCameraPosition = widgetConfiguration.initialCameraPosition;
    markers = mapObjects.markers;
    if (_createdMapIds.add(creationId)) {
      onPlatformViewCreated(creationId);
    }
    return const ColoredBox(color: Colors.transparent);
  }

  @override
  Future<void> init(int mapId) async {
    initializedMapIds.add(mapId);
  }

  @override
  Future<void> animateCamera(
    CameraUpdate cameraUpdate, {
    required int mapId,
  }) async {
    animateCameraCalls += 1;
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
  Future<void> updateTileOverlays({
    required Set<TileOverlay> newTileOverlays,
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
  Stream<MarkerTapEvent> onMarkerTap({required int mapId}) =>
      const Stream.empty();

  @override
  Stream<MarkerDragStartEvent> onMarkerDragStart({required int mapId}) =>
      const Stream.empty();

  @override
  Stream<MarkerDragEvent> onMarkerDrag({required int mapId}) =>
      const Stream.empty();

  @override
  Stream<MarkerDragEndEvent> onMarkerDragEnd({required int mapId}) =>
      const Stream.empty();

  @override
  Stream<InfoWindowTapEvent> onInfoWindowTap({required int mapId}) =>
      const Stream.empty();

  @override
  Stream<PolylineTapEvent> onPolylineTap({required int mapId}) =>
      const Stream.empty();

  @override
  Stream<PolygonTapEvent> onPolygonTap({required int mapId}) =>
      const Stream.empty();

  @override
  Stream<CircleTapEvent> onCircleTap({required int mapId}) =>
      const Stream.empty();

  @override
  Stream<MapTapEvent> onTap({required int mapId}) => const Stream.empty();

  @override
  Stream<MapLongPressEvent> onLongPress({required int mapId}) =>
      const Stream.empty();

  @override
  Stream<ClusterTapEvent> onClusterTap({required int mapId}) =>
      const Stream.empty();

  @override
  void dispose({required int mapId}) {}
}
