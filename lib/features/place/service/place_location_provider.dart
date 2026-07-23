import 'package:geolocator/geolocator.dart';

abstract class PlaceLocationProvider {
  Future<PlaceDeviceLocation> getCurrentLocation();
}

class DevicePlaceLocationProvider implements PlaceLocationProvider {
  @override
  Future<PlaceDeviceLocation> getCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const PlaceLocationException('기기의 위치 서비스를 켜주세요.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const PlaceLocationException('현재 위치를 사용하려면 위치 권한이 필요합니다.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const PlaceLocationException('설정에서 TogetherTrip의 위치 권한을 허용해주세요.');
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    return PlaceDeviceLocation(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }
}

class PlaceDeviceLocation {
  final double latitude;
  final double longitude;

  const PlaceDeviceLocation({required this.latitude, required this.longitude});
}

class PlaceLocationException implements Exception {
  final String message;

  const PlaceLocationException(this.message);

  @override
  String toString() => message;
}
