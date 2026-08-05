import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togethertrip/features/moderation/screen/community_support_screen.dart';

void main() {
  testWidgets('고객지원 주소가 미설정이어도 안전한 안내를 표시한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CommunitySupportScreen(page: CommunitySupportPage.support),
      ),
    );

    expect(find.text('고객지원 연락처를 준비하고 있습니다.'), findsOneWidget);
    expect(find.textContaining('인증 토큰은 보내지 마세요'), findsOneWidget);
  });

  testWidgets('운영정책은 신고·차단과 정산 보존 기준을 안내한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CommunitySupportScreen(page: CommunitySupportPage.policy),
      ),
    );

    expect(find.text('신고와 검토'), findsOneWidget);
    expect(find.text('차단'), findsOneWidget);
    expect(find.textContaining('지출·정산 원장'), findsOneWidget);
  });
}
