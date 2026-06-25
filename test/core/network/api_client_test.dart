import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:togethertrip/core/network/api_client.dart';

Map<String, dynamic> _apiResponse(dynamic data) => {
  'success': true,
  'data': data,
  'message': null,
};

Map<String, dynamic> _apiError(String message) => {
  'success': false,
  'code': 'ERROR',
  'message': message,
};

void main() {
  group('ApiClient', () {
    test('post 성공 시 data 필드를 반환한다', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode(_apiResponse({'accessToken': 'at', 'refreshToken': 'rt'})),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockClient);
      final result = await apiClient.post('/api/auth/oauth/kakao', {
        'accessToken': 'kakao_token',
      });

      expect(result!['accessToken'], 'at');
      expect(result['refreshToken'], 'rt');
    });

    test('accessToken 전달 시 Authorization 헤더가 포함된다', () async {
      String? capturedAuth;
      final mockClient = MockClient((request) async {
        capturedAuth = request.headers['Authorization'];
        return http.Response(
          jsonEncode(_apiResponse(null)),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockClient);
      await apiClient.post('/api/auth/logout', {}, accessToken: 'my_token');

      expect(capturedAuth, 'Bearer my_token');
    });

    test('get 요청 시 query와 Authorization 헤더가 포함된다', () async {
      Uri? capturedUrl;
      String? capturedAuth;
      final mockClient = MockClient((request) async {
        capturedUrl = request.url;
        capturedAuth = request.headers['Authorization'];
        return http.Response(
          jsonEncode(_apiResponse({'available': true})),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockClient);
      final result = await apiClient.get(
        '/api/users/nicknames/availability',
        queryParameters: {'nickname': '여행자'},
        accessToken: 'my_token',
      );

      expect(capturedUrl!.path, '/api/users/nicknames/availability');
      expect(capturedUrl!.queryParameters['nickname'], '여행자');
      expect(capturedAuth, 'Bearer my_token');
      expect(result!['available'], true);
    });

    test('서버 오류 시 ApiException을 던진다', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode(_apiError('서버 오류')),
          500,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockClient);
      expect(
        () => apiClient.post('/api/auth/oauth/kakao', {}),
        throwsA(isA<ApiException>()),
      );
    });

    test('ApiException은 statusCode와 message를 가진다', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode(_apiError('인증 실패')),
          401,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockClient);
      try {
        await apiClient.post('/api/auth/oauth/kakao', {});
        fail('예외가 발생해야 합니다');
      } on ApiException catch (e) {
        expect(e.statusCode, 401);
        expect(e.message, '인증 실패');
      }
    });

    test('data가 null이면 null을 반환한다', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode(_apiResponse(null)),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockClient);
      final result = await apiClient.post('/api/auth/logout', {});
      expect(result, isNull);
    });

    test('put 요청 시 body와 Authorization 헤더가 포함된다', () async {
      String? capturedAuth;
      Map<String, dynamic>? capturedBody;
      final mockClient = MockClient((request) async {
        capturedAuth = request.headers['Authorization'];
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode(_apiResponse({'tripId': 10, 'countries': []})),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockClient);
      final result = await apiClient.put('/api/trips/10/countries', {
        'countries': [
          {'countryCode': 'JP', 'countryName': '일본', 'sortOrder': 0},
        ],
      }, accessToken: 'my_token');

      expect(capturedAuth, 'Bearer my_token');
      expect(capturedBody!['countries'], isA<List<dynamic>>());
      expect(result!['tripId'], 10);
    });

    test('getList 성공 시 data 배열을 반환한다', () async {
      Uri? capturedUrl;
      String? capturedAuth;
      final mockClient = MockClient((request) async {
        capturedUrl = request.url;
        capturedAuth = request.headers['Authorization'];
        return http.Response(
          jsonEncode(
            _apiResponse([
              {'id': 1},
              {'id': 2},
            ]),
          ),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockClient);
      final result = await apiClient.getList(
        '/api/trips/10/settlement-transfers',
        queryParameters: {'participantId': '100'},
        accessToken: 'my_token',
      );

      expect(capturedUrl!.path, '/api/trips/10/settlement-transfers');
      expect(capturedUrl!.queryParameters['participantId'], '100');
      expect(capturedAuth, 'Bearer my_token');
      expect(result, hasLength(2));
    });

    test('delete 요청 시 JSON body와 Authorization 헤더가 포함된다', () async {
      String? capturedAuth;
      Map<String, dynamic>? capturedBody;
      final mockClient = MockClient((request) async {
        capturedAuth = request.headers['Authorization'];
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode(_apiResponse({})),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockClient);
      await apiClient.delete(
        '/notification/api/push-tokens',
        accessToken: 'my_token',
        body: {'token': 'fcm-token'},
      );

      expect(capturedAuth, 'Bearer my_token');
      expect(capturedBody, {'token': 'fcm-token'});
    });
  });
}
