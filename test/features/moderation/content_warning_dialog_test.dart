import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togethertrip/features/moderation/widget/content_warning_dialog.dart';

void main() {
  testWidgets('정상 내용은 확인창 없이 등록을 허용한다', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await confirmPotentiallyOffensiveContent(context, [
                '즐거운 여행',
              ]);
            },
            child: const Text('확인'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('확인'));
    await tester.pump();

    expect(result, isTrue);
    expect(find.text('표현을 한 번 확인해주세요'), findsNothing);
  });

  testWidgets('감지된 내용은 사용자가 수정하거나 그대로 등록할 수 있다', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await confirmPotentiallyOffensiveContent(context, [
                '씨발',
              ]);
            },
            child: const Text('확인'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(find.text('표현을 한 번 확인해주세요'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('editPotentiallyOffensiveContentButton')),
    );
    await tester.pumpAndSettle();
    expect(result, isFalse);

    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('submitPotentiallyOffensiveContentButton')),
    );
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
