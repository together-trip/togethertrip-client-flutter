import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togethertrip/features/auth/screen/sign_up_profile_screen.dart';
import 'package:togethertrip/features/auth/service/auth_service.dart';
import 'package:togethertrip/features/auth/service/terms_agreement_service.dart';
import 'package:togethertrip/features/trip/service/trip_service.dart';
import 'package:togethertrip/main.dart';

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _openSignup(
  WidgetTester tester, {
  required _FakeAuthService authService,
  TermsAgreementService? termsAgreementService,
}) async {
  await tester.pumpWidget(
    TogetherTripApp(
      authService: authService,
      tripService: _FakeTripService(),
      termsAgreementService: termsAgreementService,
    ),
  );
  await tester.tap(find.text('카카오로 시작하기'));
  await tester.pumpAndSettle();
}

Future<void> _completeRequiredProfile(
  WidgetTester tester, {
  String nickname = '여행자',
}) async {
  await _tapVisible(
    tester,
    find.byKey(const ValueKey('agreeAllTermsCheckbox')),
  );
  await tester.enterText(find.byKey(const ValueKey('nicknameField')), nickname);
  await _tapVisible(tester, find.byKey(const ValueKey('checkNicknameButton')));
}

void main() {
  testWidgets('TogetherTripApp smoke test', (tester) async {
    await tester.pumpWidget(const TogetherTripApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('신규 가입은 약관과 닉네임만으로 완료한다', (tester) async {
    final authService = _FakeAuthService();
    await _openSignup(tester, authService: authService);

    expect(find.text('프로필 설정'), findsOneWidget);
    expect(find.byKey(const ValueKey('phoneField')), findsNothing);
    expect(find.byKey(const ValueKey('birthDateField')), findsNothing);
    expect(find.text('성별'), findsNothing);
    expect(
      find.byKey(const ValueKey('pickProfileImageButton')),
      findsOneWidget,
    );

    await _completeRequiredProfile(tester);
    await _tapVisible(tester, find.byKey(const ValueKey('submitButton')));
    await tester.pumpAndSettle();

    expect(find.text('여행'), findsWidgets);
    expect(authService.checkedNickname, '여행자');
    expect(authService.updatedNickname, '여행자');
    expect(authService.updateProfileCallCount, 1);
  });

  testWidgets('선택 약관 없이 필수 약관만 동의해도 가입한다', (tester) async {
    final authService = _FakeAuthService();
    final terms = _RecordingTermsAgreementService();
    await _openSignup(
      tester,
      authService: authService,
      termsAgreementService: terms,
    );

    for (final code in const [
      'SERVICE_TERMS',
      'PRIVACY_POLICY',
      'LOCATION_INFO_TERMS',
    ]) {
      final row = find.byKey(ValueKey('termsCheckbox_$code'));
      await tester.ensureVisible(row);
      await tester.tap(
        find.descendant(of: row, matching: find.byType(Checkbox)),
      );
      await tester.pumpAndSettle();
    }
    await tester.enterText(
      find.byKey(const ValueKey('nicknameField')),
      '필수동의자',
    );
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('checkNicknameButton')),
    );
    await _tapVisible(tester, find.byKey(const ValueKey('submitButton')));
    await tester.pumpAndSettle();

    expect(authService.updateProfileCallCount, 1);
    expect(
      terms.savedCodes,
      containsAll(<String>{
        'SERVICE_TERMS',
        'PRIVACY_POLICY',
        'LOCATION_INFO_TERMS',
      }),
    );
    expect(terms.savedCodes, isNot(contains('MARKETING_CONSENT')));
  });

  testWidgets('빈 닉네임은 중복 확인 API를 호출하지 않는다', (tester) async {
    final authService = _FakeAuthService();
    await _openSignup(tester, authService: authService);

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('checkNicknameButton')),
    );

    expect(find.text('닉네임을 입력해주세요.'), findsOneWidget);
    expect(authService.checkedNickname, isNull);
  });

  testWidgets('중복 확인 후 닉네임을 바꾸면 다시 확인해야 한다', (tester) async {
    final authService = _FakeAuthService();
    await _openSignup(tester, authService: authService);
    await _completeRequiredProfile(tester, nickname: '처음닉네임');

    await tester.enterText(
      find.byKey(const ValueKey('nicknameField')),
      '변경닉네임',
    );
    await _tapVisible(tester, find.byKey(const ValueKey('submitButton')));

    expect(find.text('닉네임 중복 확인을 완료해주세요.'), findsOneWidget);
    expect(authService.updateProfileCallCount, 0);
  });

  testWidgets('약관 목록이 비어 있으면 가입을 중단한다', (tester) async {
    final authService = _FakeAuthService();
    await _openSignup(
      tester,
      authService: authService,
      termsAgreementService: _EmptyTermsAgreementService(),
    );
    await tester.enterText(find.byKey(const ValueKey('nicknameField')), '여행자');
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('checkNicknameButton')),
    );
    await _tapVisible(tester, find.byKey(const ValueKey('submitButton')));

    expect(find.text('필수 약관에 동의해주세요.'), findsWidgets);
    expect(authService.updateProfileCallCount, 0);
  });

  testWidgets('완료 버튼을 연타해도 프로필 저장은 한 번만 요청한다', (tester) async {
    final authService = _FakeAuthService(
      updateProfileDelay: const Duration(milliseconds: 100),
    );
    await _openSignup(tester, authService: authService);
    await _completeRequiredProfile(tester);

    final submit = find.byKey(const ValueKey('submitButton'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.tap(submit);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();

    expect(authService.updateProfileCallCount, 1);
  });

  testWidgets('약관 저장 실패 시 프로필 저장과 화면 이동을 중단한다', (tester) async {
    final authService = _FakeAuthService();
    await _openSignup(
      tester,
      authService: authService,
      termsAgreementService: _FailingSaveTermsAgreementService(),
    );
    await _completeRequiredProfile(tester);
    await _tapVisible(tester, find.byKey(const ValueKey('submitButton')));
    await tester.pumpAndSettle();

    expect(find.textContaining('약관 동의 저장에 실패했습니다'), findsOneWidget);
    expect(authService.updateProfileCallCount, 0);
    expect(find.text('프로필 설정'), findsOneWidget);
  });

  testWidgets('AUTHENTICATED 사용자는 닉네임과 필수 약관 완료 시 메인으로 이동한다', (tester) async {
    final authService = _FakeAuthService(authenticatedLogin: true);
    await tester.pumpWidget(
      TogetherTripApp(
        authService: authService,
        tripService: _FakeTripService(),
        termsAgreementService: TermsAgreementService(),
      ),
    );
    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pumpAndSettle();

    expect(find.text('여행'), findsWidgets);
    expect(find.text('프로필 설정'), findsNothing);
  });

  testWidgets('AUTHENTICATED 응답이어도 닉네임이 비어 있으면 가입 화면을 복구한다', (tester) async {
    final authService = _FakeAuthService(
      authenticatedLogin: true,
      profile: const UserProfile(id: 1, nickname: '', profileImageUrl: null),
    );
    await _openSignup(tester, authService: authService);

    expect(find.text('프로필 설정'), findsOneWidget);
    expect(find.byKey(const ValueKey('phoneField')), findsNothing);
    expect(find.byKey(const ValueKey('nicknameField')), findsOneWidget);
  });

  testWidgets('프로필 수정 화면도 닉네임과 선택 이미지 항목만 표시한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SignUpProfileScreen(
          authService: _FakeAuthService(),
          initialProfile: const UserProfile(
            id: 1,
            nickname: '여행자',
            profileImageUrl: null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('프로필 수정'), findsOneWidget);
    expect(find.byKey(const ValueKey('nicknameField')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('pickProfileImageButton')),
      findsOneWidget,
    );
    expect(find.text('전화번호'), findsNothing);
    expect(find.text('성별'), findsNothing);
    expect(find.text('생년월일'), findsNothing);
  });

  testWidgets('카카오 로그인 취소는 오류로 표시하지 않는다', (tester) async {
    await tester.pumpWidget(
      TogetherTripApp(authService: _CancelLoginAuthService()),
    );
    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pumpAndSettle();

    expect(find.textContaining('카카오 SDK 오류'), findsNothing);
    expect(find.textContaining('오류가 발생했습니다'), findsNothing);
  });
}

class _FakeAuthService extends AuthService {
  final bool authenticatedLogin;
  final Duration updateProfileDelay;
  final UserProfile profile;
  String? checkedNickname;
  String? updatedNickname;
  int updateProfileCallCount = 0;

  _FakeAuthService({
    this.authenticatedLogin = false,
    this.updateProfileDelay = Duration.zero,
    this.profile = const UserProfile(
      id: 1,
      nickname: '여행자',
      profileImageUrl: null,
    ),
  });

  @override
  Future<AuthLoginResult> loginWithKakao() async {
    return AuthLoginResult(
      status: authenticatedLogin ? 'AUTHENTICATED' : 'PROFILE_REQUIRED',
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
    );
  }

  @override
  Future<bool> checkNicknameAvailability(String nickname) async {
    checkedNickname = nickname;
    return true;
  }

  @override
  Future<UserProfile> getMe() async => profile;

  @override
  Future<void> updateMyProfile({
    required String nickname,
    String? profileImageUrl,
    ProfileImageInput? profileImage,
  }) async {
    updateProfileCallCount += 1;
    if (updateProfileDelay > Duration.zero) {
      await Future<void>.delayed(updateProfileDelay);
    }
    updatedNickname = nickname;
  }

  @override
  Future<String?> getAccessToken() async => 'access-token';

  @override
  Future<T> runWithAccessToken<T>(
    Future<T> Function(String accessToken) request,
  ) {
    return request('access-token');
  }
}

class _CancelLoginAuthService extends AuthService {
  @override
  Future<AuthLoginResult> loginWithKakao() async {
    throw PlatformException(code: 'CANCELED', message: 'User canceled login');
  }
}

class _EmptyTermsAgreementService extends TermsAgreementService {
  @override
  Future<List<TermsAgreementItem>> getTerms() async => const [];
}

class _FailingSaveTermsAgreementService extends TermsAgreementService {
  @override
  Future<void> saveAgreements({
    required List<TermsAgreementItem> agreedTerms,
  }) async {
    throw StateError('서버 오류');
  }
}

class _RecordingTermsAgreementService extends TermsAgreementService {
  Set<String> savedCodes = const {};

  @override
  Future<void> saveAgreements({
    required List<TermsAgreementItem> agreedTerms,
  }) async {
    await super.saveAgreements(agreedTerms: agreedTerms);
    savedCodes = agreedTerms.map((term) => term.code).toSet();
  }
}

class _FakeTripService extends TripService {
  @override
  Future<TripListPage> getTrips({
    String? status,
    String? cursor,
    int size = 20,
  }) async {
    return const TripListPage(
      items: [],
      size: 20,
      nextCursor: null,
      hasNext: false,
    );
  }
}
