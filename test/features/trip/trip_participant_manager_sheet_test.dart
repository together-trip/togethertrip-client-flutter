import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togethertrip/features/trip/service/trip_service.dart';
import 'package:togethertrip/features/trip/widget/trip_invite_participant_sheets.dart';

void main() {
  testWidgets('참여자 관리에서 비회원 동행을 추가하면 즉시 화면에 표시한다', (WidgetTester tester) async {
    _setLargeSurface(tester);
    final tripService = _FakeTripService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripParticipantManagerSheet(
            trip: _tripDetail(),
            tripService: tripService,
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('toggleParticipantAddPanelButton')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('guestParticipantNameField')),
      '민수',
    );
    await tester.tap(find.byKey(const ValueKey('addGuestParticipantButton')));
    await tester.pumpAndSettle();

    expect(tripService.addedName, '민수');
    expect(find.text('비회원 동행을 추가했습니다.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('recentlyAddedGuestParticipant')),
      findsOneWidget,
    );
    expect(find.text('방금 추가한 비회원 동행'), findsOneWidget);
  });

  testWidgets('참여자 관리에서 본인 검색 결과는 연결 후보로 표시하지 않는다', (
    WidgetTester tester,
  ) async {
    _setLargeSurface(tester);
    final tripService = _FakeTripService(searchUserId: 1);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripParticipantManagerSheet(
            trip: _tripDetail(),
            tripService: tripService,
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('toggleParticipantAddPanelButton')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('participantManagerNicknameField')),
      '나나',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('participantManagerSearchUserButton')),
    );
    await tester.tap(
      find.byKey(const ValueKey('participantManagerSearchUserButton')),
    );
    await tester.pumpAndSettle();

    expect(find.text('본인은 동행자로 추가할 수 없습니다.'), findsOneWidget);
    expect(find.text('검색된 사용자'), findsNothing);
  });

  testWidgets('비회원 동행별 초대 링크를 생성한다', (WidgetTester tester) async {
    _setLargeSurface(tester);
    final tripService = _FakeTripService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripParticipantManagerSheet(
            trip: _tripDetailWithGuest(),
            tripService: tripService,
          ),
        ),
      ),
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('guestInviteLinkButton-2')),
    );
    await tester.tap(find.byKey(const ValueKey('guestInviteLinkButton-2')));
    await tester.pumpAndSettle();

    expect(tripService.inviteTripId, 10);
    expect(tripService.inviteParticipantId, 2);
    expect(find.text('민수 초대 링크'), findsOneWidget);
    expect(
      find.text('https://togethertrip.app/invites?token=token&participantId=2'),
      findsOneWidget,
    );
  });
}

void _setLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

TripDetail _tripDetail() {
  return const TripDetail(
    id: 10,
    ownerUserId: 1,
    title: '오사카 여행',
    defaultCurrency: 'JPY',
    exchangeRateBaseDate: null,
    startDate: '2026-07-01',
    endDate: '2026-07-05',
    tripStatus: 'PLANNED',
    settlementStatus: 'NOT_STARTED',
    settledAt: null,
    countries: [],
    participants: [
      TripParticipant(
        id: 1,
        userId: 1,
        displayName: '나',
        profileImageUrl: null,
        participantRole: 'LEADER',
        participantStatus: 'ACTIVE',
        joinedAt: '2026-06-17T00:00:00Z',
      ),
    ],
  );
}

TripDetail _tripDetailWithGuest() {
  return const TripDetail(
    id: 10,
    ownerUserId: 1,
    title: '오사카 여행',
    defaultCurrency: 'JPY',
    exchangeRateBaseDate: null,
    startDate: '2026-07-01',
    endDate: '2026-07-05',
    tripStatus: 'PLANNED',
    settlementStatus: 'NOT_STARTED',
    settledAt: null,
    countries: [],
    participants: [
      TripParticipant(
        id: 1,
        userId: 1,
        displayName: '나',
        profileImageUrl: null,
        participantRole: 'LEADER',
        participantStatus: 'ACTIVE',
        joinedAt: '2026-06-17T00:00:00Z',
      ),
      TripParticipant(
        id: 2,
        userId: null,
        displayName: '민수',
        profileImageUrl: null,
        participantRole: 'MEMBER',
        participantStatus: 'ACTIVE',
        joinedAt: null,
      ),
    ],
  );
}

class _FakeTripService extends TripService {
  final int searchUserId;
  String? addedName;
  int? inviteTripId;
  int? inviteParticipantId;

  _FakeTripService({this.searchUserId = 2});

  @override
  Future<TripParticipant> addTemporaryParticipant(
    int tripId,
    TripCompanionInput input,
  ) async {
    addedName = input.displayName;
    return TripParticipant(
      id: 2,
      userId: null,
      displayName: input.displayName,
      profileImageUrl: null,
      participantRole: 'MEMBER',
      participantStatus: 'ACTIVE',
      joinedAt: null,
    );
  }

  @override
  Future<UserSearchResult> searchUserByNickname(String nickname) async {
    return UserSearchResult(
      found: true,
      user: UserSearchUser(
        userId: searchUserId,
        nickname: searchUserId == 1 ? '나나' : '민수',
        profileImageUrl: null,
      ),
    );
  }

  @override
  Future<TripInvite> createInviteLink(int tripId, {int? participantId}) async {
    inviteTripId = tripId;
    inviteParticipantId = participantId;
    return TripInvite(
      id: 5,
      tripId: tripId,
      type: 'LINK',
      code: null,
      token: 'token',
      inviteUrl:
          'https://togethertrip.app/invites?token=token&participantId=$participantId',
      invitationStatus: 'ACTIVE',
      expiresAt: null,
    );
  }
}
