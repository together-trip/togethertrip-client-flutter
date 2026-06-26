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

Map<String, dynamic> _participantJson({
  int id = 30,
  int? userId,
  String displayName = '홍길동',
}) => {
  'id': id,
  'userId': userId,
  'displayName': displayName,
  'profileImageUrl': null,
  'participantRole': 'MEMBER',
  'participantStatus': 'ACTIVE',
  'joinedAt': '2026-06-17T00:00:00Z',
};

Map<String, dynamic> _tripSummaryJson() => {
  'id': 10,
  'title': '오사카 여행',
  'defaultCurrency': 'JPY',
  'startDate': '2026-07-01',
  'endDate': '2026-07-05',
  'tripStatus': 'PLANNED',
  'settlementStatus': 'NOT_STARTED',
  'ownerUserId': 1,
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
                    'settlementDisplayStatus': 'IN_PROGRESS',
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
      expect(page.items.single.effectiveSettlementDisplayStatus, 'IN_PROGRESS');
      expect(page.nextCursor, 'cursor');
      expect(page.hasNext, true);
    });

    test('여행 목록 응답에 표시 정산 상태가 없으면 기존 정산 상태로 보정한다', () {
      final trip = TripSummary.fromJson({
        ..._tripSummaryJson(),
        'settlementStatus': 'SETTLED',
      });

      expect(trip.settlementDisplayStatus, isNull);
      expect(trip.effectiveSettlementDisplayStatus, 'COMPLETED');
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
            TripCompanionInput(
              displayName: '홍길동',
              profileImageUrl: '/uploads/user-profile-images/user.png',
              userId: 2,
            ),
          ],
        ),
      );

      expect(capturedBody!['title'], '오사카 여행');
      expect(capturedBody!['defaultCurrency'], 'JPY');
      expect(capturedBody!['countries'], isA<List<dynamic>>());
      expect(capturedBody!['participants'], isA<List<dynamic>>());
      expect(capturedBody!['participants'], [
        {'displayName': '민수', 'profileImageUrl': null},
        {
          'displayName': '홍길동',
          'profileImageUrl': '/uploads/user-profile-images/user.png',
          'userId': 2,
        },
      ]);
      expect(trip.countries.single.countryCode, 'JP');
    });

    test('닉네임으로 사용자를 검색한다', () async {
      Uri? capturedUrl;
      Map<String, dynamic>? capturedBody;
      final apiClient = ApiClient(
        client: MockClient((request) async {
          capturedUrl = request.url;
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode(
              _apiResponse({
                'found': true,
                'user': {
                  'userId': 2,
                  'nickname': '홍길동',
                  'profileImageUrl': '/uploads/user-profile-images/user.png',
                },
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

      final result = await tripService.searchUserByNickname('홍길동');

      expect(capturedUrl!.path, '/api/users/search/nickname');
      expect(capturedBody, {'nickname': '홍길동'});
      expect(result.found, true);
      expect(result.user!.userId, 2);
      expect(result.user!.nickname, '홍길동');
    });

    test('초대 링크를 생성한다', () async {
      Uri? capturedUrl;
      final apiClient = ApiClient(
        client: MockClient((request) async {
          capturedUrl = request.url;
          return http.Response(
            jsonEncode(
              _apiResponse({
                'id': 5,
                'tripId': 10,
                'type': 'LINK',
                'code': null,
                'token': 'invite-token',
                'inviteUrl': 'https://togethertrip.app/invites/invite-token',
                'invitationStatus': 'ACTIVE',
                'expiresAt': null,
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

      final invite = await tripService.createInviteLink(10);

      expect(capturedUrl!.path, '/api/trips/10/invite-links');
      expect(invite.inviteUrl, 'https://togethertrip.app/invites/invite-token');
      expect(invite.type, 'LINK');
    });

    test('비회원 동행 초대 링크에는 참여자 ID를 추가한다', () async {
      final apiClient = ApiClient(
        client: MockClient((request) async {
          return http.Response(
            jsonEncode(
              _apiResponse({
                'id': 5,
                'tripId': 10,
                'type': 'LINK',
                'code': null,
                'token': 'invite-token',
                'inviteUrl':
                    'https://togethertrip.app/invites?token=invite-token',
                'invitationStatus': 'ACTIVE',
                'expiresAt': null,
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

      final invite = await tripService.createInviteLink(10, participantId: 31);

      expect(
        invite.inviteUrl,
        'https://togethertrip.app/invites?token=invite-token&participantId=31',
      );
    });

    test('초대 코드를 생성한다', () async {
      Uri? capturedUrl;
      final apiClient = ApiClient(
        client: MockClient((request) async {
          capturedUrl = request.url;
          return http.Response(
            jsonEncode(
              _apiResponse({
                'id': 6,
                'tripId': 10,
                'type': 'CODE',
                'code': 'ABC123',
                'token': 'invite-token',
                'inviteUrl': 'https://togethertrip.app/invites/invite-token',
                'invitationStatus': 'ACTIVE',
                'expiresAt': null,
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

      final invite = await tripService.createInviteCode(10);

      expect(capturedUrl!.path, '/api/trips/10/invite-codes');
      expect(invite.code, 'ABC123');
      expect(invite.type, 'CODE');
    });

    test('초대 코드 정보를 조회한다', () async {
      Uri? capturedUrl;
      final apiClient = ApiClient(
        client: MockClient((request) async {
          capturedUrl = request.url;
          return http.Response(
            jsonEncode(
              _apiResponse({
                'invitationId': 5,
                'type': 'CODE',
                'code': 'ABC123',
                'invitationStatus': 'ACTIVE',
                'expiresAt': null,
                'trip': _tripSummaryJson(),
                'alreadyJoined': false,
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

      final info = await tripService.getInviteInfo(code: ' ABC123 ');

      expect(capturedUrl!.path, '/api/trip-invites');
      expect(capturedUrl!.queryParameters, {'code': 'ABC123'});
      expect(info.trip.title, '오사카 여행');
      expect(info.alreadyJoined, false);
    });

    test('비회원 동행을 추가한다', () async {
      Uri? capturedUrl;
      Map<String, dynamic>? capturedBody;
      final apiClient = ApiClient(
        client: MockClient((request) async {
          capturedUrl = request.url;
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode(
              _apiResponse(_participantJson(id: 31, displayName: '민수')),
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

      final participant = await tripService.addTemporaryParticipant(
        10,
        const TripCompanionInput(displayName: '민수', profileImageUrl: null),
      );

      expect(capturedUrl!.path, '/api/trips/10/participants');
      expect(capturedBody, {'displayName': '민수', 'profileImageUrl': null});
      expect(participant.userId, isNull);
      expect(participant.displayName, '민수');
    });

    test('비회원 동행을 실제 사용자와 연결한다', () async {
      Uri? capturedUrl;
      Map<String, dynamic>? capturedBody;
      final apiClient = ApiClient(
        client: MockClient((request) async {
          capturedUrl = request.url;
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode(
              _apiResponse(
                _participantJson(id: 31, userId: 2, displayName: '홍길동'),
              ),
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

      final participant = await tripService.linkParticipant(
        10,
        participantId: 31,
        userId: 2,
      );

      expect(capturedUrl!.path, '/api/trips/10/participant-connections');
      expect(capturedBody, {'participantId': 31, 'userId': 2});
      expect(participant.userId, 2);
    });

    test('참여자를 제거한다', () async {
      Uri? capturedUrl;
      String? capturedMethod;
      final apiClient = ApiClient(
        client: MockClient((request) async {
          capturedUrl = request.url;
          capturedMethod = request.method;
          return http.Response(
            jsonEncode(_apiResponse({})),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final tripService = TripService(
        apiClient: apiClient,
        authService: _FakeAuthService(),
      );

      await tripService.removeParticipant(10, 31);

      expect(capturedMethod, 'DELETE');
      expect(capturedUrl!.path, '/api/trips/10/participants/31');
    });

    test('초대 코드로 여행에 참여한다', () async {
      Uri? capturedUrl;
      Map<String, dynamic>? capturedBody;
      final apiClient = ApiClient(
        client: MockClient((request) async {
          capturedUrl = request.url;
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode(
              _apiResponse({
                'tripId': 10,
                'invitationId': 5,
                'participant': _participantJson(userId: 2),
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

      final joined = await tripService.joinTrip(
        code: 'ABC123',
        participantId: 31,
      );

      expect(capturedUrl!.path, '/api/trip-invite-joins');
      expect(capturedBody, {'code': 'ABC123', 'participantId': 31});
      expect(joined.tripId, 10);
      expect(joined.participant.displayName, '홍길동');
    });
  });
}

class _FakeAuthService extends AuthService {
  @override
  Future<String?> getAccessToken() async => 'access-token';

  @override
  Future<T> runWithAccessToken<T>(
    Future<T> Function(String accessToken) request,
  ) {
    return request('access-token');
  }
}
