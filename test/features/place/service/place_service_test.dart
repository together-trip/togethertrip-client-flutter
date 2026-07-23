import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:togethertrip/core/network/api_client.dart';
import 'package:togethertrip/features/auth/service/auth_service.dart';
import 'package:togethertrip/features/place/service/place_service.dart';

void main() {
  group('PlaceService', () {
    test('자동완성 요청과 응답을 변환한다', () async {
      Uri? capturedUrl;
      String? authorization;
      final service = PlaceService(
        apiClient: ApiClient(
          client: MockClient((request) async {
            capturedUrl = request.url;
            authorization = request.headers['Authorization'];
            return _response([
              {'placeId': 'place-1', 'name': '도쿄역', 'address': '일본 도쿄도'},
            ]);
          }),
        ),
        authService: _FakeAuthService(),
      );

      final result = await service.autocomplete(
        10,
        query: '도쿄역',
        sessionToken: 'session-1',
      );

      expect(capturedUrl!.path, '/api/trips/10/places/autocomplete');
      expect(capturedUrl!.queryParameters['query'], '도쿄역');
      expect(capturedUrl!.queryParameters['sessionToken'], 'session-1');
      expect(authorization, 'Bearer access-token');
      expect(result.single.name, '도쿄역');
    });

    test('장소 상세와 역지오코딩 응답을 변환한다', () async {
      final paths = <String>[];
      final service = PlaceService(
        apiClient: ApiClient(
          client: MockClient((request) async {
            paths.add(request.url.path);
            return _response({
              'placeId': 'place-1',
              'name': '도쿄역',
              'address': '일본 도쿄도',
              'latitude': 35.681236,
              'longitude': 139.767125,
            });
          }),
        ),
        authService: _FakeAuthService(),
      );

      final detail = await service.getPlace(
        10,
        placeId: 'place-1',
        sessionToken: 'session-1',
      );
      final reverse = await service.reverseGeocode(
        10,
        latitude: 35.681236,
        longitude: 139.767125,
      );

      expect(paths, [
        '/api/trips/10/places/place-1',
        '/api/trips/10/places/reverse',
      ]);
      expect(detail.hasCoordinates, true);
      expect(reverse.longitude, 139.767125);
    });

    test('장소 상세 data가 비면 예외를 반환한다', () async {
      final service = PlaceService(
        apiClient: ApiClient(
          client: MockClient((request) async => _response(null)),
        ),
        authService: _FakeAuthService(),
      );

      expect(
        () =>
            service.getPlace(10, placeId: 'place-1', sessionToken: 'session-1'),
        throwsA(isA<ApiException>()),
      );
      expect(
        () => service.reverseGeocode(10, latitude: 0, longitude: 0),
        throwsA(isA<ApiException>()),
      );
    });
  });
}

http.Response _response(dynamic data) {
  return http.Response.bytes(
    utf8.encode(jsonEncode({'success': true, 'data': data, 'message': null})),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

class _FakeAuthService extends AuthService {
  @override
  Future<T> runWithAccessToken<T>(
    Future<T> Function(String accessToken) request,
  ) {
    return request('access-token');
  }
}
