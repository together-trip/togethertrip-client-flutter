import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togethertrip/features/auth/service/auth_service.dart';
import 'package:togethertrip/features/trip/screen/trip_form_screen.dart';
import 'package:togethertrip/features/trip/service/trip_service.dart';

void main() {
  testWidgets('여행 일정은 시작일이 종료일보다 늦으면 다음 단계로 진행하지 않는다', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: TripFormScreen(tripService: _FakeTripService())),
    );

    await tester.tap(find.text('일본'));
    await tester.tap(find.byKey(const ValueKey('saveTripButton')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('tripStartDateField')),
      '2026-07-05',
    );
    await tester.enterText(
      find.byKey(const ValueKey('tripEndDateField')),
      '2026-07-01',
    );
    await tester.tap(find.byKey(const ValueKey('saveTripButton')));
    await tester.pumpAndSettle();

    expect(find.text('시작일과 종료일을 올바른 순서로 입력해 주세요.'), findsOneWidget);
    expect(find.byKey(const ValueKey('tripCompanionsField')), findsNothing);
  });

  testWidgets('국가 선택 순서를 보존해 생성 요청에 반영한다', (WidgetTester tester) async {
    final tripService = _FakeTripService();
    await tester.pumpWidget(
      MaterialApp(home: TripFormScreen(tripService: tripService)),
    );

    await tester.tap(find.text('미국'));
    await tester.tap(find.text('일본'));
    await tester.tap(find.byKey(const ValueKey('saveTripButton')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('tripStartDateField')),
      '2026-07-01',
    );
    await tester.enterText(
      find.byKey(const ValueKey('tripEndDateField')),
      '2026-07-05',
    );
    await tester.tap(find.byKey(const ValueKey('saveTripButton')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('saveTripButton')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('tripTitleField')),
      '여름 여행',
    );
    await tester.tap(find.byKey(const ValueKey('saveTripButton')));
    await tester.pumpAndSettle();

    final input = tripService.createdInput!;
    expect(input.defaultCurrency, 'USD');
    expect(input.countries.map((country) => country.countryCode), ['US', 'JP']);
    expect(input.countries.map((country) => country.sortOrder), [0, 1]);
  });

  testWidgets('닉네임 검색 결과를 클릭하면 실제 사용자 동행자로 추가한다', (WidgetTester tester) async {
    final tripService = _FakeTripService();
    await tester.pumpWidget(
      MaterialApp(home: TripFormScreen(tripService: tripService)),
    );

    await tester.tap(find.text('일본'));
    await tester.tap(find.byKey(const ValueKey('saveTripButton')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('tripStartDateField')),
      '2026-07-01',
    );
    await tester.enterText(
      find.byKey(const ValueKey('tripEndDateField')),
      '2026-07-05',
    );
    await tester.tap(find.byKey(const ValueKey('saveTripButton')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('tripCompanionsField')),
      '홍길동',
    );
    await tester.tap(find.text('사용자 검색'));
    await tester.pumpAndSettle();

    expect(find.text('홍길동'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('tripUserSearchResult-2')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('saveTripButton')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('tripTitleField')),
      '오사카 여행',
    );
    await tester.tap(find.byKey(const ValueKey('saveTripButton')));
    await tester.pumpAndSettle();

    final participant = tripService.createdInput!.participants.single;
    expect(participant.displayName, '홍길동');
    expect(participant.userId, 2);
    expect(
      participant.profileImageUrl,
      '/uploads/user-profile-images/user.png',
    );
  });

  testWidgets('비회원 동행은 기본 이름으로 추가하고 이름을 수정해 생성 요청에 반영한다', (
    WidgetTester tester,
  ) async {
    final tripService = _FakeTripService();
    await tester.pumpWidget(
      MaterialApp(home: TripFormScreen(tripService: tripService)),
    );

    await tester.tap(find.text('일본'));
    await tester.tap(find.byKey(const ValueKey('saveTripButton')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('tripStartDateField')),
      '2026-07-01',
    );
    await tester.enterText(
      find.byKey(const ValueKey('tripEndDateField')),
      '2026-07-05',
    );
    await tester.tap(find.byKey(const ValueKey('saveTripButton')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('addGuestCompanionButton')));
    await tester.pumpAndSettle();

    expect(find.text('동행자 1'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('guestCompanionNameField')),
      '민수',
    );
    await tester.pumpAndSettle();

    expect(find.text('민수'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('saveTripButton')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('tripTitleField')),
      '오사카 여행',
    );
    await tester.tap(find.byKey(const ValueKey('saveTripButton')));
    await tester.pumpAndSettle();

    final participant = tripService.createdInput!.participants.single;
    expect(participant.displayName, '민수');
    expect(participant.userId, isNull);
  });

  testWidgets('비회원 동행을 삭제하면 생성 요청에서 제외한다', (WidgetTester tester) async {
    final tripService = _FakeTripService();
    await tester.pumpWidget(
      MaterialApp(home: TripFormScreen(tripService: tripService)),
    );

    await tester.tap(find.text('일본'));
    await tester.tap(find.byKey(const ValueKey('saveTripButton')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('tripStartDateField')),
      '2026-07-01',
    );
    await tester.enterText(
      find.byKey(const ValueKey('tripEndDateField')),
      '2026-07-05',
    );
    await tester.tap(find.byKey(const ValueKey('saveTripButton')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('addGuestCompanionButton')));
    await tester.pumpAndSettle();
    expect(find.text('동행자 1'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('removeCompanionButton')));
    await tester.pumpAndSettle();
    expect(find.text('동행자 1'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('saveTripButton')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('tripTitleField')),
      '오사카 여행',
    );
    await tester.tap(find.byKey(const ValueKey('saveTripButton')));
    await tester.pumpAndSettle();

    expect(tripService.createdInput!.participants, isEmpty);
  });

  testWidgets('본인 닉네임 검색 결과는 동행자로 추가하지 못하게 안내한다', (WidgetTester tester) async {
    final tripService = _FakeTripService(searchUserId: 1);
    await tester.pumpWidget(
      MaterialApp(home: TripFormScreen(tripService: tripService)),
    );

    await tester.tap(find.text('일본'));
    await tester.tap(find.byKey(const ValueKey('saveTripButton')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('tripStartDateField')),
      '2026-07-01',
    );
    await tester.enterText(
      find.byKey(const ValueKey('tripEndDateField')),
      '2026-07-05',
    );
    await tester.tap(find.byKey(const ValueKey('saveTripButton')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('tripCompanionsField')),
      '여행자',
    );
    await tester.tap(find.text('사용자 검색'));
    await tester.pumpAndSettle();

    expect(find.text('본인은 동행자로 추가할 수 없습니다.'), findsOneWidget);
    expect(find.byKey(const ValueKey('tripUserSearchResult-1')), findsNothing);
  });
}

class _FakeTripService extends TripService {
  final int searchUserId;
  TripFormInput? createdInput;

  _FakeTripService({this.searchUserId = 2});

  @override
  Future<TripDetail> createTrip(TripFormInput input) async {
    createdInput = input;
    return TripDetail(
      id: 10,
      ownerUserId: 1,
      title: input.title,
      defaultCurrency: input.defaultCurrency,
      exchangeRateBaseDate: input.exchangeRateBaseDate,
      startDate: input.startDate,
      endDate: input.endDate,
      tripStatus: 'PLANNED',
      settlementStatus: 'NOT_STARTED',
      settledAt: null,
      countries: const [],
      participants: const [],
    );
  }

  @override
  Future<UserSearchResult> searchUserByNickname(String nickname) async {
    return UserSearchResult(
      found: true,
      user: UserSearchUser(
        userId: searchUserId,
        nickname: searchUserId == 1 ? '여행자' : '홍길동',
        profileImageUrl: '/uploads/user-profile-images/user.png',
      ),
    );
  }

  @override
  Future<UserProfile> getCurrentUser() async {
    return const UserProfile(
      id: 1,
      nickname: '여행자',
      gender: 'MALE',
      birthDate: '1990-01-01',
      profileImageUrl: null,
      phoneNumberMasked: null,
      phoneVerifiedAt: null,
      phoneVerified: true,
    );
  }

  @override
  Future<TripInvite> createInviteLink(int tripId) async {
    return const TripInvite(
      id: 1,
      tripId: 10,
      type: 'LINK',
      code: null,
      token: 'token',
      inviteUrl: 'https://togethertrip.app/invites/token',
      invitationStatus: 'ACTIVE',
      expiresAt: null,
    );
  }
}
