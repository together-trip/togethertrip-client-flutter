import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togethertrip/features/settlement/screen/settlement_screen.dart';
import 'package:togethertrip/features/settlement/service/settlement_service.dart';

void main() {
  testWidgets('정산 mock 화면에서 미리보기, 확정, 수금 확인 흐름을 표시한다', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettlementScreen(
          tripId: 1,
          tripTitle: '오사카 여행',
          isOwner: true,
          currentParticipantId: 11,
          settlementService: SettlementMockService(),
          showMockCases: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('정산'), findsOneWidget);
    expect(find.text('정산 미시작'), findsOneWidget);
    expect(find.text('정산 미리보기'), findsOneWidget);
    expect(find.text('내 정산 요약'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('settlementHelpButton')));
    await tester.pumpAndSettle();

    expect(find.text('정산은 어떻게 계산되나요?'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, '확인'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('settlementPrimaryButton')));
    await tester.pumpAndSettle();

    expect(find.text('미리보기 완료'), findsOneWidget);
    expect(find.text('정산하기'), findsOneWidget);
    expect(find.text('받을 돈'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('settlementPrimaryButton')));
    await tester.pumpAndSettle();

    expect(find.textContaining('되돌릴 수 없고'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirmSettlementButton')));
    await tester.pumpAndSettle();

    expect(find.text('송금 확인 중'), findsOneWidget);
    expect(find.text('공유'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('settlementTabreceived')));
    await tester.pumpAndSettle();

    expect(find.text('민지에게서'), findsOneWidget);
    expect(find.text('수금 완료'), findsOneWidget);

    await tester.tap(find.text('수금 완료'));
    await tester.pumpAndSettle();

    expect(find.textContaining('상대 확인 대기'), findsOneWidget);
  });

  testWidgets('정산 mock 케이스를 전환해 송금, 정산 없음, 완료 상태를 확인한다', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SettlementScreen(
          tripId: 1,
          tripTitle: '오사카 여행',
          isOwner: true,
          currentParticipantId: 11,
          settlementService: SettlementMockService(),
          showMockCases: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('settlementMockCasememberNeedsToSend')),
    );
    await tester.pumpAndSettle();

    expect(find.text('송금 확인 중'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('settlementTabsent')));
    await tester.pumpAndSettle();

    expect(find.text('민지에게'), findsOneWidget);
    expect(find.text('송금 완료'), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('settlementMockCaseList')),
      const Offset(-520, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('settlementMockCasenoTransfers')),
    );
    await tester.pumpAndSettle();

    expect(find.text('정산 완료'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('settlementTabsent')));
    await tester.pumpAndSettle();

    expect(find.text('보낼 정산이 없어요.'), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('settlementMockCaseList')),
      const Offset(-220, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('settlementMockCaseallCompleted')),
    );
    await tester.pumpAndSettle();

    expect(find.text('공유됨'), findsOneWidget);
    expect(find.text('정산 완료'), findsOneWidget);
  });
}
