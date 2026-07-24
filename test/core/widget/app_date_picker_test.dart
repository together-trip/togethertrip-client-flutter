import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togethertrip/core/widget/app_date_picker.dart';
import 'package:togethertrip/core/widget/app_design.dart';

void main() {
  testWidgets('단일 날짜는 브랜드 바텀시트에서 선택한다', (tester) async {
    DateTime? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showTogetherTripDatePicker(
                  context: context,
                  initialDate: DateTime(2026, 7, 14),
                  firstDate: DateTime(2026, 7, 1),
                  lastDate: DateTime(2026, 7, 31),
                  helpText: '기록 날짜',
                );
              },
              child: const Text('날짜 열기'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('날짜 열기'));
    await tester.pumpAndSettle();

    expect(find.text('기록 날짜'), findsOneWidget);
    expect(find.text('2026년 7월 14일 (화)'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('datePicker-2026-07-16')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirmSingleDateButton')));
    await tester.pumpAndSettle();

    expect(result, DateTime(2026, 7, 16));
  });

  testWidgets('기간은 전체 화면에서 출발일과 도착일을 다시 선택한다', (tester) async {
    DateTimeRange? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showTogetherTripDateRangePicker(
                  context: context,
                  initialDateRange: DateTimeRange(
                    start: DateTime(2026, 7, 10),
                    end: DateTime(2026, 7, 12),
                  ),
                  firstDate: DateTime(2026, 7, 1),
                  lastDate: DateTime(2026, 7, 31),
                  title: '여행 기간',
                  helpText: '여행 일정을 선택해 주세요',
                  confirmText: '일정 적용',
                  showDurationInConfirm: true,
                  startLabel: '출발',
                  endLabel: '도착',
                  pendingEndText: '도착일을 선택해 주세요',
                );
              },
              child: const Text('기간 열기'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('기간 열기'));
    await tester.pumpAndSettle();

    expect(find.text('여행 기간'), findsOneWidget);
    expect(find.text('2박 3일 일정 적용'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('dateRangePicker-2026-07-15')));
    await tester.pumpAndSettle();
    expect(find.text('도착일을 선택해 주세요'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('dateRangePicker-2026-07-18')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirmDateRangeButton')));
    await tester.pumpAndSettle();

    expect(result?.start, DateTime(2026, 7, 15));
    expect(result?.end, DateTime(2026, 7, 18));
  });
}
