import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togethertrip/features/moderation/model/moderation_models.dart';
import 'package:togethertrip/features/moderation/screen/blocked_users_screen.dart';
import 'package:togethertrip/features/moderation/service/moderation_service.dart';

void main() {
  testWidgets('차단 목록은 정산 보존 안내와 확인 후 해제 경로를 제공한다', (tester) async {
    final service = _FakeModerationService();
    await tester.pumpWidget(
      MaterialApp(home: BlockedUsersScreen(moderationService: service)),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('지출·정산 정보는 정확한 금액 계산을 위해 계속 표시'),
      findsOneWidget,
    );
    expect(find.text('민수'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('unblockUser-22')));
    await tester.pumpAndSettle();
    expect(find.text('민수님의 일반 기록과 댓글을 다시 표시할까요?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '차단 해제'));
    await tester.pumpAndSettle();
    expect(service.unblockedIds, [22]);
    expect(find.text('차단한 사용자가 없습니다.'), findsOneWidget);
  });

  testWidgets('차단을 해제한 뒤 화면을 닫으면 변경 여부 true를 반환한다', (tester) async {
    final service = _FakeModerationService();
    await tester.pumpWidget(
      MaterialApp(home: _BlockedUsersHost(service: service)),
    );

    await tester.tap(find.text('차단 목록 열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('unblockUser-22')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '차단 해제'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('changed: true'), findsOneWidget);
  });
}

class _BlockedUsersHost extends StatefulWidget {
  const _BlockedUsersHost({required this.service});
  final ModerationService service;

  @override
  State<_BlockedUsersHost> createState() => _BlockedUsersHostState();
}

class _BlockedUsersHostState extends State<_BlockedUsersHost> {
  bool? changed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TextButton(
            onPressed: () async {
              final result = await Navigator.of(context).push<bool>(
                MaterialPageRoute<bool>(
                  builder: (_) =>
                      BlockedUsersScreen(moderationService: widget.service),
                ),
              );
              if (mounted) setState(() => changed = result);
            },
            child: const Text('차단 목록 열기'),
          ),
          Text('changed: $changed'),
        ],
      ),
    );
  }
}

class _FakeModerationService extends ModerationService {
  final unblockedIds = <int>[];

  @override
  Future<List<BlockedUser>> getBlockedUsers() async => const [
    BlockedUser(blockedUserId: 22, displayName: '민수', blockedAt: null),
  ];

  @override
  Future<void> unblockUser(int userId) async {
    unblockedIds.add(userId);
  }
}
