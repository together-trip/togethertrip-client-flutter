import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togethertrip/features/moderation/model/moderation_models.dart';
import 'package:togethertrip/features/moderation/service/moderation_service.dart';
import 'package:togethertrip/features/moderation/widget/report_sheet.dart';

void main() {
  testWidgets('신고 사유와 선택 설명을 확인한 뒤 완료 상태를 표시한다', (tester) async {
    _setLargeSurface(tester);
    final service = _FakeModerationService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReportSheet(
            tripId: 10,
            targetType: ReportTargetType.post,
            targetId: 20,
            targetLabel: '게시글',
            moderationService: service,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('reportReason-SPAM')));
    await tester.enterText(
      find.byKey(const ValueKey('reportDescriptionField')),
      '반복 광고',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('reportSubmitButton')),
    );
    await tester.tap(find.byKey(const ValueKey('reportSubmitButton')));
    await tester.pumpAndSettle();
    expect(
      find.text('선택한 내용으로 신고할까요? 신고 내용은 운영 정책에 따라 검토됩니다.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('confirmReportButton')));
    await tester.pumpAndSettle();

    expect(service.requests, hasLength(1));
    expect(service.requests.single.reason, ReportReason.spam);
    expect(service.requests.single.description, '반복 광고');
    expect(find.text('신고가 접수됐어요'), findsOneWidget);
  });

  testWidgets('접수 중에는 신고 버튼을 비활성화해 중복 제출을 막는다', (tester) async {
    _setLargeSurface(tester);
    final service = _FakeModerationService(waitForCompletion: true);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReportSheet(
            tripId: 10,
            targetType: ReportTargetType.user,
            targetId: 22,
            targetLabel: '사용자',
            moderationService: service,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('reportReason-SPAM')));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('reportSubmitButton')),
    );
    await tester.tap(find.byKey(const ValueKey('reportSubmitButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirmReportButton')));
    await tester.pump();

    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('reportSubmitButton')),
    );
    expect(button.onPressed, isNull);
    expect(service.requests, hasLength(1));

    service.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('신고 실패 시 오류를 표시하고 같은 내용으로 다시 시도할 수 있다', (tester) async {
    _setLargeSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReportSheet(
            tripId: 10,
            targetType: ReportTargetType.post,
            targetId: 20,
            targetLabel: '게시글',
            moderationService: _FailModerationService(),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('reportReason-SPAM')));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('reportSubmitButton')),
    );
    await tester.tap(find.byKey(const ValueKey('reportSubmitButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirmReportButton')));
    await tester.pumpAndSettle();

    expect(find.text('신고를 접수하지 못했습니다. 잠시 후 다시 시도해 주세요.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('reportSubmitButton')),
          )
          .onPressed,
      isNotNull,
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

class _FakeModerationService extends ModerationService {
  _FakeModerationService({this.waitForCompletion = false});

  final bool waitForCompletion;
  final requests = <ReportRequest>[];
  final Completer<void> _completer = Completer<void>();

  void complete() {
    if (!_completer.isCompleted) _completer.complete();
  }

  @override
  Future<ReportResult> createReport(int tripId, ReportRequest request) async {
    requests.add(request);
    if (waitForCompletion) await _completer.future;
    return const ReportResult(id: 1, status: 'RECEIVED', createdAt: null);
  }
}

class _FailModerationService extends ModerationService {
  @override
  Future<ReportResult> createReport(int tripId, ReportRequest request) {
    throw Exception('network failure');
  }
}
