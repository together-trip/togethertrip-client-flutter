import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:togethertrip/features/place/service/place_location_provider.dart';

void main() {
  late GeolocatorPlatform originalPlatform;
  late _FakeGeolocatorPlatform platform;

  setUp(() {
    originalPlatform = GeolocatorPlatform.instance;
    platform = _FakeGeolocatorPlatform();
    GeolocatorPlatform.instance = platform;
  });

  tearDown(() {
    GeolocatorPlatform.instance = originalPlatform;
  });

  test('위치 서비스가 꺼져 있으면 설정 안내 오류를 반환한다', () async {
    platform.serviceEnabled = false;

    await expectLater(
      DevicePlaceLocationProvider().getCurrentLocation(),
      throwsA(
        isA<PlaceLocationException>().having(
          (error) => error.toString(),
          'message',
          '기기의 위치 서비스를 켜주세요.',
        ),
      ),
    );

    expect(platform.checkPermissionCalls, 0);
  });

  test('거부된 권한을 요청한 뒤에도 거부되면 권한 안내 오류를 반환한다', () async {
    platform.permission = LocationPermission.denied;
    platform.requestedPermission = LocationPermission.denied;

    await expectLater(
      DevicePlaceLocationProvider().getCurrentLocation(),
      throwsA(
        isA<PlaceLocationException>().having(
          (error) => error.message,
          'message',
          '현재 위치를 사용하려면 위치 권한이 필요합니다.',
        ),
      ),
    );

    expect(platform.requestPermissionCalls, 1);
    expect(platform.positionCalls, 0);
  });

  test('영구 거부된 권한은 앱 설정 안내 오류를 반환한다', () async {
    platform.permission = LocationPermission.deniedForever;

    await expectLater(
      DevicePlaceLocationProvider().getCurrentLocation(),
      throwsA(
        isA<PlaceLocationException>().having(
          (error) => error.message,
          'message',
          '설정에서 TogetherTrip의 위치 권한을 허용해주세요.',
        ),
      ),
    );

    expect(platform.requestPermissionCalls, 0);
    expect(platform.positionCalls, 0);
  });

  test('권한 요청이 승인되면 고정밀 현재 좌표를 반환한다', () async {
    platform.permission = LocationPermission.denied;
    platform.requestedPermission = LocationPermission.whileInUse;
    platform.position = _position;

    final result = await DevicePlaceLocationProvider().getCurrentLocation();

    expect(result.latitude, 35.681236);
    expect(result.longitude, 139.767125);
    expect(platform.requestPermissionCalls, 1);
    expect(platform.positionCalls, 1);
    expect(platform.locationSettings?.accuracy, LocationAccuracy.high);
  });

  test('이미 허용된 권한은 재요청하지 않고 현재 좌표를 반환한다', () async {
    platform.permission = LocationPermission.always;
    platform.position = _position;

    final result = await DevicePlaceLocationProvider().getCurrentLocation();

    expect(result.latitude, 35.681236);
    expect(platform.requestPermissionCalls, 0);
    expect(platform.positionCalls, 1);
  });
}

class _FakeGeolocatorPlatform extends GeolocatorPlatform
    with MockPlatformInterfaceMixin {
  bool serviceEnabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  LocationPermission requestedPermission = LocationPermission.whileInUse;
  Position position = _position;
  int checkPermissionCalls = 0;
  int requestPermissionCalls = 0;
  int positionCalls = 0;
  LocationSettings? locationSettings;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async {
    checkPermissionCalls += 1;
    return permission;
  }

  @override
  Future<LocationPermission> requestPermission() async {
    requestPermissionCalls += 1;
    return requestedPermission;
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    positionCalls += 1;
    this.locationSettings = locationSettings;
    return position;
  }
}

final _position = Position(
  longitude: 139.767125,
  latitude: 35.681236,
  timestamp: DateTime.utc(2026, 7, 16),
  accuracy: 1,
  altitude: 0,
  altitudeAccuracy: 1,
  heading: 0,
  headingAccuracy: 1,
  speed: 0,
  speedAccuracy: 1,
);
