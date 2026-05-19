import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:togethertrip/core/network/api_client.dart';

void main() {
  group('ApiClient', () {
    test('post 성공 시 응답 맵을 반환한다', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'accessToken': 'at', 'refreshToken': 'rt'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockClient);
      final result = await apiClient.post('/api/auth/oauth/kakao', {
        'accessToken': 'kakao_token',
      });

      expect(result['accessToken'], 'at');
      expect(result['refreshToken'], 'rt');
    });

    test('서버 오류 시 ApiException을 던진다', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': '서버 오류'}),
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
          jsonEncode({'message': '인증 실패'}),
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
  });
}
