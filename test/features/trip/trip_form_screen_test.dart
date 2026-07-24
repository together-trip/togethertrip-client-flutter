import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('여행 날짜는 숫자 입력을 yyyy-MM-dd 형식으로 자동 포맷한다', (
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
      '20260701',
    );
    await tester.enterText(
      find.byKey(const ValueKey('tripEndDateField')),
      '20260705',
    );
    await tester.pumpAndSettle();

    expect(find.text('2026-07-01'), findsOneWidget);
    expect(find.text('2026-07-05'), findsOneWidget);
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
    expect(tripService.createInviteLinkCallCount, 0);
  });

  testWidgets('여행을 먼저 만들고 동행은 생성 후 추가한다', (WidgetTester tester) async {
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

    expect(find.byKey(const ValueKey('tripCompanionsField')), findsNothing);
    expect(find.byKey(const ValueKey('tripTitleField')), findsOneWidget);
    expect(find.text('여행 만들기'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('tripTitleField')),
      '오사카 여행',
    );
    await tester.tap(find.byKey(const ValueKey('saveTripButton')));
    await tester.pumpAndSettle();

    expect(tripService.createdInput!.participants, isEmpty);
    expect(find.text('여행을 만들었어요'), findsOneWidget);
    expect(find.text('초대 링크 보내기'), findsOneWidget);
    expect(find.text('나중에'), findsOneWidget);

    await tester.tap(find.text('비회원 동행 추가'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('guestParticipantNameField')),
      findsOneWidget,
    );
  });
}

class _FakeTripService extends TripService {
  TripFormInput? createdInput;
  int createInviteLinkCallCount = 0;

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
  Future<TripInvite> createInviteLink(int tripId, {int? participantId}) async {
    createInviteLinkCallCount++;
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
