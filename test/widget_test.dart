import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togethertrip/features/my/screen/my_placeholder_screen.dart';
import 'package:togethertrip/features/auth/service/auth_service.dart';
import 'package:togethertrip/features/auth/service/terms_agreement_service.dart';
import 'package:togethertrip/features/trip/service/trip_service.dart';
import 'package:togethertrip/main.dart';

void main() {
  testWidgets('TogetherTripApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const TogetherTripApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('회원가입 완료 시 메인 더미 페이지로 이동한다', (WidgetTester tester) async {
    final authService = _FakeAuthService(confirmStatus: 'PROFILE_REQUIRED');
    await tester.pumpWidget(
      TogetherTripApp(
        authService: authService,
        tripService: _FakeTripService(),
      ),
    );

    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pumpAndSettle();

    expect(find.text('약관 동의'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('agreeAllTermsCheckbox')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('continueTermsButton')));
    await tester.pumpAndSettle();

    expect(find.text('프로필 설정'), findsOneWidget);
    expect(find.text('프로필 이미지'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('pickProfileImageButton')),
      findsOneWidget,
    );
    expect(find.text('이미지 선택'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('nicknameField')), '여행자');
    await tester.enterText(
      find.byKey(const ValueKey('birthDateField')),
      '1990.01.01',
    );
    await tester.tap(find.byKey(const ValueKey('checkNicknameButton')));
    await tester.pumpAndSettle();

    expect(find.text('사용 가능한 닉네임입니다.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('phoneField')),
      '010-1234-5678',
    );
    await tester.tap(find.byKey(const ValueKey('requestCodeButton')));
    await tester.pump();

    expect(find.text('03:00'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('codeField')), '123456');
    await tester.tap(find.byKey(const ValueKey('confirmCodeButton')));
    await tester.pumpAndSettle();

    expect(find.textContaining('인증완료'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('submitButton')));
    await tester.tap(find.byKey(const ValueKey('submitButton')));
    await tester.pumpAndSettle();

    expect(find.text('여행'), findsWidgets);
    expect(authService.checkedNickname, '여행자');
    expect(authService.requestedPhoneNumber, '01012345678');
    expect(authService.confirmedPhoneNumber, '01012345678');
    expect(authService.updatedNickname, '여행자');
    expect(authService.updatedGender, 'MALE');
    expect(authService.updatedBirthDate, '1990-01-01');
  });

  testWidgets('선택 약관을 선택하지 않아도 필수 약관만 동의하면 다음 단계로 이동한다', (
    WidgetTester tester,
  ) async {
    final authService = _FakeAuthService(confirmStatus: 'PROFILE_REQUIRED');
    await tester.pumpWidget(
      TogetherTripApp(
        authService: authService,
        tripService: _FakeTripService(),
      ),
    );

    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pumpAndSettle();

    expect(find.text('약관 동의'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('termsCheckbox_SERVICE_TERMS')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('termsCheckbox_PRIVACY_POLICY')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('termsCheckbox_LOCATION_INFO_TERMS')),
    );
    await tester.pumpAndSettle();

    final continueButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('continueTermsButton')),
    );
    expect(continueButton.onPressed, isNotNull);

    await tester.tap(find.byKey(const ValueKey('continueTermsButton')));
    await tester.pumpAndSettle();

    expect(find.text('프로필 설정'), findsOneWidget);
  });

  testWidgets('재가입자는 전화번호 인증 후 프로필 입력 없이 메인으로 이동한다', (
    WidgetTester tester,
  ) async {
    final authService = _FakeAuthService(confirmStatus: 'AUTHENTICATED');
    await tester.pumpWidget(
      TogetherTripApp(
        authService: authService,
        tripService: _FakeTripService(),
      ),
    );

    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pumpAndSettle();

    expect(find.text('약관 동의'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('agreeAllTermsCheckbox')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('continueTermsButton')));
    await tester.pumpAndSettle();

    expect(find.text('프로필 설정'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('phoneField')),
      '010-1234-5678',
    );
    await tester.tap(find.byKey(const ValueKey('requestCodeButton')));
    await tester.pump();

    await tester.enterText(find.byKey(const ValueKey('codeField')), '123456');
    await tester.tap(find.byKey(const ValueKey('confirmCodeButton')));
    await tester.pumpAndSettle();

    expect(find.text('여행'), findsWidgets);
    expect(find.byKey(const ValueKey('nicknameField')), findsNothing);
    expect(authService.updatedNickname, isNull);
  });

  testWidgets('프로필 미완료 로그인은 전화번호 인증 없이 프로필 입력으로 이동한다', (
    WidgetTester tester,
  ) async {
    final authService = _FakeAuthService(profileRequired: true);
    await tester.pumpWidget(
      TogetherTripApp(
        authService: authService,
        tripService: _FakeTripService(),
      ),
    );

    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pumpAndSettle();

    expect(find.text('약관 동의'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('agreeAllTermsCheckbox')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('continueTermsButton')));
    await tester.pumpAndSettle();

    expect(find.text('프로필 설정'), findsOneWidget);
    expect(find.byKey(const ValueKey('phoneField')), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('nicknameField')), '여행자');
    await tester.enterText(
      find.byKey(const ValueKey('birthDateField')),
      '1990.01.01',
    );
    await tester.tap(find.byKey(const ValueKey('checkNicknameButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('submitButton')));
    await tester.pumpAndSettle();

    expect(find.text('여행'), findsWidgets);
  });

  testWidgets('개인정보 수정 화면에서 마스킹 전화번호가 표시된다', (WidgetTester tester) async {
    final authService = _FakeAuthService();
    await tester.pumpWidget(
      MaterialApp(home: MyPlaceholderScreen(authService: authService)),
    );
    await tester.pumpAndSettle();

    expect(find.text('여행자'), findsOneWidget);
    expect(find.text('010-****-5678'), findsNothing);

    await tester.tap(find.text('개인정보 수정'));
    await tester.pumpAndSettle();

    expect(find.text('개인정보 수정'), findsOneWidget);
    expect(find.text('전화번호'), findsOneWidget);
    expect(find.text('010-****-5678'), findsOneWidget);
    expect(find.text('인증 완료'), findsOneWidget);
  });

  testWidgets('마이페이지 약관 메뉴에서 약관을 확인한다', (WidgetTester tester) async {
    final authService = _FakeAuthService();
    await tester.pumpWidget(
      MaterialApp(home: MyPlaceholderScreen(authService: authService)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('약관'));
    await tester.pumpAndSettle();

    expect(find.text('서비스 이용약관'), findsOneWidget);
    expect(find.text('개인정보 처리방침'), findsOneWidget);
    expect(find.text('위치기반서비스 이용약관'), findsOneWidget);
    expect(find.text('광고성 정보 수신 동의'), findsOneWidget);

    await tester.tap(find.text('서비스 이용약관'));
    await tester.pumpAndSettle();

    expect(find.textContaining('여행방, 동행자 관리'), findsOneWidget);
  });

  testWidgets('마이페이지에서 선택 약관을 언제든 저장하거나 해제한다', (WidgetTester tester) async {
    final authService = _FakeAuthService();
    final termsAgreementService = TermsAgreementService();
    await tester.pumpWidget(
      MaterialApp(
        home: MyPlaceholderScreen(
          authService: authService,
          termsAgreementService: termsAgreementService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('약관'));
    await tester.pumpAndSettle();

    final marketingSwitch = find.byKey(
      const ValueKey('optionalTermsSwitch_MARKETING_CONSENT'),
    );
    expect(marketingSwitch, findsOneWidget);
    expect(tester.widget<Switch>(marketingSwitch).value, isFalse);

    await tester.tap(marketingSwitch);
    await tester.pumpAndSettle();
    expect(
      await termsAgreementService.getAgreedTermCodes(),
      contains('MARKETING_CONSENT'),
    );
    expect(tester.widget<Switch>(marketingSwitch).value, isTrue);

    await tester.tap(marketingSwitch);
    await tester.pumpAndSettle();
    expect(
      await termsAgreementService.getAgreedTermCodes(),
      isNot(contains('MARKETING_CONSENT')),
    );
    expect(tester.widget<Switch>(marketingSwitch).value, isFalse);
  });
}

class _FakeAuthService extends AuthService {
  final bool profileRequired;
  final String confirmStatus;
  String? checkedNickname;
  String? requestedPhoneNumber;
  String? confirmedPhoneNumber;
  String? updatedNickname;
  String? updatedGender;
  String? updatedBirthDate;

  _FakeAuthService({
    this.profileRequired = false,
    this.confirmStatus = 'AUTHENTICATED',
  });

  @override
  Future<AuthLoginResult> loginWithKakao() async {
    if (profileRequired) {
      return const AuthLoginResult(
        status: 'PROFILE_REQUIRED',
        temporaryToken: null,
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
      );
    }

    return const AuthLoginResult(
      status: 'PHONE_VERIFICATION_REQUIRED',
      temporaryToken: 'temporary-token',
      accessToken: null,
      refreshToken: null,
    );
  }

  @override
  Future<PhoneVerificationCodeSent> requestPhoneVerification({
    required String temporaryToken,
    required String phoneNumber,
  }) async {
    requestedPhoneNumber = phoneNumber;
    return const PhoneVerificationCodeSent(expiresInSeconds: 180);
  }

  @override
  Future<AuthLoginResult> confirmPhoneVerification({
    required String temporaryToken,
    required String phoneNumber,
    required String code,
  }) async {
    confirmedPhoneNumber = phoneNumber;
    return AuthLoginResult(
      status: confirmStatus,
      temporaryToken: null,
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
  Future<void> updateMyProfile({
    required String nickname,
    required String gender,
    required String birthDate,
    String? profileImageUrl,
    ProfileImageInput? profileImage,
  }) async {
    updatedNickname = nickname;
    updatedGender = gender;
    updatedBirthDate = birthDate;
  }

  @override
  Future<String?> getAccessToken() async => 'access-token';

  @override
  Future<UserProfile> getMe() async {
    return const UserProfile(
      id: 1,
      nickname: '여행자',
      gender: 'MALE',
      birthDate: '1990-01-01',
      profileImageUrl: null,
      phoneNumberMasked: '010-****-5678',
      phoneVerifiedAt: '2026-06-12T00:00:00Z',
      phoneVerified: true,
    );
  }

  @override
  Future<T> runWithAccessToken<T>(
    Future<T> Function(String accessToken) request,
  ) {
    return request('access-token');
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
