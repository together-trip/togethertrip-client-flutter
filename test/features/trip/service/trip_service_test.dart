import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:togethertrip/core/network/api_client.dart';
import 'package:togethertrip/features/auth/service/auth_service.dart';
import 'package:togethertrip/features/trip/service/trip_service.dart';

Map<String, dynamic> _apiResponse(dynamic data) => {
  'success': true,
  'data': data,
  'message': null,
};

void main() {
  group('TripService', () {
    test('여행 목록 응답을 모델로 변환한다', () async {
      Uri? capturedUrl;
      String? capturedAuth;
      final apiClient = ApiClient(
        client: MockClient((request) async {
          capturedUrl = request.url;
          capturedAuth = request.headers['Authorization'];
          return http.Response(
            jsonEncode(
              _apiResponse({
                'items': [
                  {
                    'id': 10,
                    'title': '오사카 여행',
                    'defaultCurrency': 'JPY',
                    'startDate': '2026-07-01',
                    'endDate': '2026-07-05',
                    'tripStatus': 'PLANNED',
                    'settlementStatus': 'NOT_STARTED',
                    'ownerUserId': 1,
                  },
                ],
                'size': 20,
                'nextCursor': 'cursor',
                'hasNext': true,
              }),
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final tripService = TripService(
        apiClient: apiClient,
        authService: _FakeAuthService(),
      );

      final page = await tripService.getTrips();

      expect(capturedUrl!.path, '/api/trips');
      expect(capturedUrl!.queryParameters['size'], '20');
      expect(capturedAuth, 'Bearer access-token');
      expect(page.items.single.title, '오사카 여행');
      expect(page.nextCursor, 'cursor');
      expect(page.hasNext, true);
    });

    test('여행 생성 요청을 서버 DTO 형태로 전송한다', () async {
      Map<String, dynamic>? capturedBody;
      final apiClient = ApiClient(
        client: MockClient((request) async {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode(
              _apiResponse({
                'id': 10,
                'ownerUserId': 1,
                'title': '오사카 여행',
                'defaultCurrency': 'JPY',
                'exchangeRateBaseDate': null,
                'startDate': '2026-07-01',
                'endDate': '2026-07-05',
                'tripStatus': 'PLANNED',
                'settlementStatus': 'NOT_STARTED',
                'settledAt': null,
                'countries': [
                  {
                    'id': 100,
                    'countryCode': 'JP',
                    'countryName': '일본',
                    'sortOrder': 0,
                  },
                ],
                'participants': [],
              }),
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final tripService = TripService(
        apiClient: apiClient,
        authService: _FakeAuthService(),
      );

      final trip = await tripService.createTrip(
        const TripFormInput(
          title: '오사카 여행',
          defaultCurrency: 'JPY',
          exchangeRateBaseDate: null,
          startDate: '2026-07-01',
          endDate: '2026-07-05',
          countries: [
            TripCountryInput(
              countryCode: 'JP',
              countryName: '일본',
              sortOrder: 0,
            ),
          ],
          participants: [
            TripCompanionInput(displayName: '민수', profileImageUrl: null),
          ],
        ),
      );

      expect(capturedBody!['title'], '오사카 여행');
      expect(capturedBody!['defaultCurrency'], 'JPY');
      expect(capturedBody!['countries'], isA<List<dynamic>>());
      expect(capturedBody!['participants'], isA<List<dynamic>>());
      expect(trip.countries.single.countryCode, 'JP');
    });
  });
}

class _FakeAuthService extends AuthService {
  @override
  Future<String?> getAccessToken() async => 'access-token';
}
