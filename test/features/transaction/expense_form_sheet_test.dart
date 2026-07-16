import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togethertrip/features/post/service/post_service.dart';
import 'package:togethertrip/features/transaction/screen/expense_form_sheet.dart';
import 'package:togethertrip/features/transaction/service/transaction_service.dart';
import 'package:togethertrip/features/trip/service/trip_service.dart';

void main() {
  testWidgets('소비 날짜가 여행 기간 밖이면 저장하지 않는다', (tester) async {
    var submitCallCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExpenseFormSheet(
            trip: _trip(),
            currentParticipantId: 100,
            initialPost: _post(),
            initialTransaction: _transaction(),
            onSubmit: ({required transactionInput, required postInput}) async {
              submitCallCount += 1;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final saveButton = find.byKey(const ValueKey('saveExpenseButton'));
    await tester.scrollUntilVisible(
      saveButton,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text('소비 날짜는 여행 기간 내로 선택해주세요.'), findsOneWidget);
    expect(submitCallCount, 0);
  });

  testWidgets('기존 장소 좌표를 소비 수정 폼에서 유지해 전송한다', (tester) async {
    PostFormInput? submitted;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExpenseFormSheet(
            trip: _trip(),
            currentParticipantId: 100,
            initialPost: _post(
              occurredAt: '2026-07-02T03:00:00Z',
              placeName: '도쿄역',
              latitude: 35.681236,
              longitude: 139.767125,
            ),
            initialTransaction: _transaction(
              occurredAt: '2026-07-02T03:00:00Z',
            ),
            onSubmit: ({required transactionInput, required postInput}) async {
              submitted = postInput;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final saveButton = find.byKey(const ValueKey('saveExpenseButton'));
    await tester.scrollUntilVisible(
      saveButton,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(submitted?.placeName, '도쿄역');
    expect(submitted?.latitude, 35.681236);
    expect(submitted?.longitude, 139.767125);
  });
}

TripDetail _trip() {
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
        id: 100,
        userId: 1,
        displayName: '재완',
        profileImageUrl: null,
        participantRole: 'LEADER',
        participantStatus: 'ACTIVE',
        joinedAt: '2026-06-01T00:00:00Z',
      ),
    ],
  );
}

PostDetail _post({
  String occurredAt = '2026-06-09T03:00:00Z',
  String? placeName,
  double? latitude,
  double? longitude,
}) {
  return PostDetail(
    id: 2,
    tripId: 10,
    transactionId: 200,
    authorParticipantId: 100,
    authorDisplayName: '재완',
    postType: 'EXPENSE',
    title: '라멘',
    category: '식비',
    content: '내용',
    occurredAt: occurredAt,
    placeName: placeName,
    latitude: latitude,
    longitude: longitude,
    commentCount: 0,
    attachments: [],
    createdAt: '2026-06-09T03:00:00Z',
    updatedAt: '2026-06-09T03:00:00Z',
  );
}

TransactionDetail _transaction({String occurredAt = '2026-06-09T03:00:00Z'}) {
  return TransactionDetail(
    summary: TransactionSummary(
      id: 200,
      tripId: 10,
      transactionType: 'EXPENSE',
      amount: 12000,
      currency: 'JPY',
      exchangeRate: 9.5,
      baseCurrency: 'KRW',
      baseAmount: 114000,
      category: '식비',
      occurredAt: occurredAt,
      status: 'ACTIVE',
      createdByUserId: 1,
      createdAt: null,
      updatedAt: null,
    ),
    payments: [
      TransactionPayment(
        id: 1,
        participantId: 100,
        participantDisplayName: '재완',
        amount: 12000,
      ),
    ],
    shares: [
      TransactionShare(
        id: 2,
        participantId: 100,
        participantDisplayName: '재완',
        shareAmount: 12000,
        shareRatio: 1,
      ),
    ],
  );
}
