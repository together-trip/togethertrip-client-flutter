import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togethertrip/features/exchange/model/exchange_rate_models.dart';
import 'package:togethertrip/features/exchange/screen/exchange_rate_screen.dart';
import 'package:togethertrip/features/exchange/service/exchange_rate_service.dart';

void main() {
  testWidgets('환율 화면은 좁은 화면에서도 입력/계산 영역이 깨지지 않는다', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ExchangeRateScreen(
          exchangeRateService: _FakeExchangeRateService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('exchangeAmountField')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('exchangeSwapDirectionButton')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('exchangeSettlementNoticeButton')),
      findsOneWidget,
    );
    expect(find.text('환산 금액'), findsOneWidget);
    expect(find.text('1,000.00'), findsOneWidget);
    expect(find.text('9,512.30 KRW'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.enterText(
      find.byKey(const ValueKey('exchangeAmountField')),
      '1234567',
    );
    await tester.pumpAndSettle();

    expect(find.text('1,234,567'), findsOneWidget);
    expect(find.text('11,743,571.67 KRW'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('exchangeSwapDirectionButton')));
    await tester.pumpAndSettle();

    expect(find.text('11,743,571.67'), findsOneWidget);
    expect(find.text('1,234,567.00 JPY'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(
      find.byKey(const ValueKey('exchangeSettlementNoticeButton')),
    );
    await tester.pumpAndSettle();

    expect(find.text('정산 환율 안내'), findsOneWidget);
    expect(find.textContaining('카드사 수수료'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeExchangeRateService extends ExchangeRateService {
  @override
  Future<ExchangeRateSearchResult> getExchangeRates({
    String baseCurrency = 'KRW',
    required List<String> targetCurrencies,
    String? date,
    String? from,
    String? to,
  }) async {
    return const ExchangeRateSearchResult(
      baseCurrency: 'KRW',
      date: '2026-06-17',
      from: null,
      to: null,
      rates: [
        ExchangeRateRecord(
          targetCurrency: 'JPY',
          rate: 9.5123,
          rateDate: '2026-06-17',
          source: 'KOREA_EXIM',
        ),
      ],
    );
  }
}
