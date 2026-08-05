import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togethertrip/features/auth/service/auth_service.dart';
import 'package:togethertrip/features/my/screen/my_placeholder_screen.dart';
import 'package:togethertrip/features/my/service/public_site_link_service.dart';

void main() {
  test('공개 사이트 링크는 주입된 URL을 페이지별로 반환한다', () {
    final privacy = Uri.parse('https://example.com/privacy');
    final links = PublicSiteLinks(
      links: {PublicSitePage.privacyPolicy: privacy},
    );

    expect(links.get(PublicSitePage.privacyPolicy), privacy);
  });

  testWidgets('회원 탈퇴 확인은 삭제 보관 재가입 영향을 안내하고 취소할 수 있다', (tester) async {
    final authService = _AccountDeletionAuthService();
    await tester.pumpWidget(
      MaterialApp(home: MyPlaceholderScreen(authService: authService)),
    );
    await tester.pumpAndSettle();

    await _scrollToWithdrawButton(tester);
    await tester.tap(find.byKey(const ValueKey('withdrawButton')));
    await tester.pumpAndSettle();

    expect(find.textContaining('프로필, OAuth 연결'), findsOneWidget);
    expect(find.textContaining('익명화한 상태로 보관'), findsOneWidget);
    expect(find.textContaining('새로운 계정으로 처리'), findsOneWidget);

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(authService.deleteAccountCalls, 0);
  });

  testWidgets('마이 화면의 계정 삭제 안내에서 공개 URL을 연다', (tester) async {
    final launcher = _RecordingLinkLauncher(opened: true);
    final accountDeletion = Uri.parse(
      'https://example.com/account-deletion',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MyPlaceholderScreen(
          authService: _AccountDeletionAuthService(),
          publicSiteLinks: PublicSiteLinks(
            links: {PublicSitePage.accountDeletion: accountDeletion},
          ),
          externalLinkLauncher: launcher,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('accountDeletionLink')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('accountDeletionLink')));
    await tester.pumpAndSettle();

    expect(launcher.openedUris, [accountDeletion]);
  });

  testWidgets('출시 화면에는 준비 중인 알림 설정 메뉴를 노출하지 않는다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MyPlaceholderScreen(authService: _AccountDeletionAuthService()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('알림 설정'), findsNothing);
    expect(find.textContaining('기능은 아직 준비 중입니다.'), findsNothing);
  });

  testWidgets('회원 탈퇴 처리 중 중복 요청을 막는다', (tester) async {
    final authService = _AccountDeletionAuthService(
      deleteDelay: const Duration(milliseconds: 100),
    );
    await tester.pumpWidget(
      MaterialApp(home: MyPlaceholderScreen(authService: authService)),
    );
    await tester.pumpAndSettle();

    await _scrollToWithdrawButton(tester);
    await tester.tap(find.byKey(const ValueKey('withdrawButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirmWithdrawButton')));
    await tester.pump();

    expect(find.text('탈퇴 처리 중…'), findsOneWidget);
    expect(authService.deleteAccountCalls, 1);

    await tester.pump(const Duration(milliseconds: 120));
  });

  testWidgets('정책 링크 실행 실패는 탈퇴 상태를 바꾸지 않고 오류를 표시한다', (tester) async {
    final launcher = _RecordingLinkLauncher(opened: false);
    final privacy = Uri.parse('https://example.com/privacy');
    await tester.pumpWidget(
      MaterialApp(
        home: MyPlaceholderScreen(
          authService: _AccountDeletionAuthService(),
          publicSiteLinks: PublicSiteLinks(
            links: {PublicSitePage.privacyPolicy: privacy},
          ),
          externalLinkLauncher: launcher,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('privacyPolicyLink')));
    await tester.tap(find.byKey(const ValueKey('privacyPolicyLink')));
    await tester.pumpAndSettle();

    expect(launcher.openedUris, [privacy]);
    expect(find.text('개인정보처리방침 링크를 열지 못했습니다.'), findsWidgets);
    expect(find.text('회원 탈퇴'), findsOneWidget);
  });
}

Future<void> _scrollToWithdrawButton(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, -1200));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('withdrawButton')), findsOneWidget);
}

class _AccountDeletionAuthService extends AuthService {
  final Duration deleteDelay;
  int deleteAccountCalls = 0;

  _AccountDeletionAuthService({this.deleteDelay = Duration.zero});

  @override
  Future<UserProfile> getMe() async =>
      const UserProfile(id: 7, nickname: '여행자', profileImageUrl: null);

  @override
  Future<String?> getAccessToken() async => 'access-token';

  @override
  Future<T> runWithAccessToken<T>(
    Future<T> Function(String accessToken) request,
  ) {
    return request('access-token');
  }

  @override
  Future<void> deleteAccount() async {
    deleteAccountCalls += 1;
    if (deleteDelay > Duration.zero) {
      await Future<void>.delayed(deleteDelay);
    }
  }
}

class _RecordingLinkLauncher implements ExternalLinkLauncher {
  final bool opened;
  final openedUris = <Uri>[];

  _RecordingLinkLauncher({required this.opened});

  @override
  Future<bool> open(Uri uri) async {
    openedUris.add(uri);
    return opened;
  }
}
