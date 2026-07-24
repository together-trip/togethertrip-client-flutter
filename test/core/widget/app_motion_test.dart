import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togethertrip/core/widget/app_design.dart';

void main() {
  testWidgets('콘텐츠가 바뀌면 이전 화면을 즉시 제거하지 않고 전환한다', (tester) async {
    var showSecond = false;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              body: Column(
                children: [
                  AppMotionSwitcher(
                    child: Text(
                      showSecond ? '두 번째 화면' : '첫 번째 화면',
                      key: ValueKey(showSecond),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => showSecond = true),
                    child: const Text('전환'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('전환'));
    await tester.pump();

    expect(find.text('첫 번째 화면'), findsOneWidget);
    expect(find.text('두 번째 화면'), findsOneWidget);

    await tester.pump(AppMotion.standard);
    await tester.pump();

    expect(find.text('첫 번째 화면'), findsNothing);
    expect(find.text('두 번째 화면'), findsOneWidget);
  });

  testWidgets('애니메이션 비활성 설정에서는 콘텐츠를 즉시 교체한다', (tester) async {
    var showSecond = false;

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: [
                  AppMotionSwitcher(
                    child: Text(
                      showSecond ? '두 번째 화면' : '첫 번째 화면',
                      key: ValueKey(showSecond),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => showSecond = true),
                    child: const Text('전환'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('전환'));
    await tester.pump();

    expect(find.text('첫 번째 화면'), findsNothing);
    expect(find.text('두 번째 화면'), findsOneWidget);
  });

  test('앱 테마는 모든 플랫폼에서 같은 페이지 전환을 사용한다', () {
    final builders = AppTheme.light().pageTransitionsTheme.builders;

    expect(builders.values, everyElement(isA<AppPageTransitionsBuilder>()));
  });
}
