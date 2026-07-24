import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togethertrip/features/trip/screen/trip_list_screen.dart';
import 'package:togethertrip/features/trip/service/trip_service.dart';

void main() {
  testWidgets('여행 홈은 진행 중 여행을 표지로 보여주고 다음 여행을 목록으로 구분한다', (tester) async {
    final tripService = _FakeTripService(
      trips: const [
        TripSummary(
          id: 1,
          title: '오사카 3박 4일',
          defaultCurrency: 'JPY',
          startDate: '2026-07-23',
          endDate: '2026-07-26',
          tripStatus: 'ONGOING',
          settlementStatus: 'NOT_STARTED',
          ownerUserId: 1,
        ),
        TripSummary(
          id: 2,
          title: '제주도 여름휴가',
          defaultCurrency: 'KRW',
          startDate: '2026-08-14',
          endDate: '2026-08-17',
          tripStatus: 'PLANNED',
          settlementStatus: 'NOT_STARTED',
          ownerUserId: 1,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(home: TripListScreen(tripService: tripService)),
    );
    await tester.pumpAndSettle();

    expect(find.text('오사카 3박 4일'), findsOneWidget);
    expect(find.text('다음 여행'), findsOneWidget);
    expect(find.text('제주도 여름휴가'), findsOneWidget);
    expect(find.text('전체'), findsNothing);
  });

  testWidgets('초대 링크 입력 시 토큰과 참여자 ID로 여행에 참여한다', (tester) async {
    final tripService = _FakeTripService();
    TripSummary? openedTrip;

    await tester.pumpWidget(
      MaterialApp(
        home: TripListScreen(
          tripService: tripService,
          onOpenTripDetail: (trip) => openedTrip = trip,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('joinTripByInviteCodeButton')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('inviteCodeOrLinkField')),
      'https://togethertrip.app/invites?token=invite-token&participantId=31',
    );
    await tester.tap(find.text('참여'));
    await tester.pumpAndSettle();

    expect(tripService.inviteInfoCode, isNull);
    expect(tripService.inviteInfoToken, 'invite-token');
    expect(tripService.joinCode, isNull);
    expect(tripService.joinToken, 'invite-token');
    expect(tripService.joinParticipantId, 31);
    expect(openedTrip?.id, 10);
  });
}

class _FakeTripService extends TripService {
  final List<TripSummary> trips;
  String? inviteInfoCode;
  String? inviteInfoToken;
  String? joinCode;
  String? joinToken;
  int? joinParticipantId;

  _FakeTripService({this.trips = const []});

  @override
  Future<TripListPage> getTrips({
    String? status,
    String? cursor,
    int size = 20,
  }) async {
    return TripListPage(
      items: trips,
      size: trips.length,
      nextCursor: null,
      hasNext: false,
    );
  }

  @override
  Future<TripInviteInfo> getInviteInfo({String? code, String? token}) async {
    inviteInfoCode = code;
    inviteInfoToken = token;
    return TripInviteInfo(
      invitationId: 5,
      type: 'LINK',
      code: null,
      invitationStatus: 'ACTIVE',
      expiresAt: null,
      trip: _tripSummary(),
      alreadyJoined: false,
    );
  }

  @override
  Future<JoinTripResult> joinTrip({
    String? code,
    String? token,
    int? participantId,
  }) async {
    joinCode = code;
    joinToken = token;
    joinParticipantId = participantId;
    return const JoinTripResult(
      tripId: 10,
      invitationId: 5,
      participant: TripParticipant(
        id: 31,
        userId: 2,
        displayName: '민수',
        profileImageUrl: null,
        participantRole: 'MEMBER',
        participantStatus: 'ACTIVE',
        joinedAt: '2026-06-17T00:00:00Z',
      ),
    );
  }

  TripSummary _tripSummary() {
    return const TripSummary(
      id: 10,
      title: '오사카 여행',
      defaultCurrency: 'JPY',
      startDate: '2026-07-01',
      endDate: '2026-07-05',
      tripStatus: 'PLANNED',
      settlementStatus: 'NOT_STARTED',
      ownerUserId: 1,
    );
  }
}
