import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togethertrip/features/auth/screen/terms_agreement_screen.dart';
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

    expect(find.text('프로필 설정'), findsOneWidget);
    expect(find.text('프로필 이미지'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('pickProfileImageButton')),
      findsOneWidget,
    );
    expect(find.text('이미지 선택'), findsOneWidget);
    expect(find.text('약관 동의'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('agreeAllTermsCheckbox')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('nicknameField')), '여행자');
    await tester.enterText(
      find.byKey(const ValueKey('birthDateField')),
      '1990.01.01',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('checkNicknameButton')),
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

  testWidgets('선택 약관을 선택하지 않아도 필수 약관만 동의하면 가입을 완료한다', (
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

    expect(find.text('프로필 설정'), findsOneWidget);
    expect(find.text('약관 동의'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('termsCheckbox_SERVICE_TERMS')),
    );
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('termsCheckbox_SERVICE_TERMS')),
        matching: find.byType(Checkbox),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('termsCheckbox_PRIVACY_POLICY')),
    );
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('termsCheckbox_PRIVACY_POLICY')),
        matching: find.byType(Checkbox),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('termsCheckbox_LOCATION_INFO_TERMS')),
    );
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('termsCheckbox_LOCATION_INFO_TERMS')),
        matching: find.byType(Checkbox),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('nicknameField')), '여행자');
    await tester.enterText(
      find.byKey(const ValueKey('birthDateField')),
      '1990.01.01',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('checkNicknameButton')),
    );
    await tester.tap(find.byKey(const ValueKey('checkNicknameButton')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('submitButton')));
    await tester.tap(find.byKey(const ValueKey('submitButton')));
    await tester.pumpAndSettle();

    expect(find.text('여행'), findsWidgets);
  });

  testWidgets('닉네임이 비어 있으면 중복확인 요청을 보내지 않는다', (WidgetTester tester) async {
    final authService = _FakeAuthService(confirmStatus: 'PROFILE_REQUIRED');
    await tester.pumpWidget(
      TogetherTripApp(
        authService: authService,
        tripService: _FakeTripService(),
      ),
    );

    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('checkNicknameButton')));
    await tester.pumpAndSettle();

    expect(find.text('닉네임을 입력해주세요.'), findsOneWidget);
    expect(authService.checkedNickname, isNull);
  });

  testWidgets('닉네임 입력 후 중복확인에 성공하면 이전 입력 오류가 사라진다', (
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

    await tester.tap(find.byKey(const ValueKey('checkNicknameButton')));
    await tester.pumpAndSettle();
    expect(find.text('닉네임을 입력해주세요.'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('nicknameField')), '여행자');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('checkNicknameButton')));
    await tester.pumpAndSettle();

    expect(find.text('닉네임을 입력해주세요.'), findsNothing);
    expect(find.text('사용 가능한 닉네임입니다.'), findsOneWidget);
  });

  testWidgets('중복확인 후 닉네임을 바꾸면 다시 확인하기 전에는 가입하지 않는다', (
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
    await tester.tap(find.byKey(const ValueKey('agreeAllTermsCheckbox')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('nicknameField')), '여행자');
    await tester.enterText(
      find.byKey(const ValueKey('birthDateField')),
      '1990.01.01',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('checkNicknameButton')),
    );
    await tester.tap(find.byKey(const ValueKey('checkNicknameButton')));
    await tester.pumpAndSettle();
    expect(find.text('사용 가능한 닉네임입니다.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('nicknameField')),
      '다른여행자',
    );
    await tester.pumpAndSettle();
    expect(find.text('사용 가능한 닉네임입니다.'), findsNothing);

    await tester.ensureVisible(find.byKey(const ValueKey('submitButton')));
    await tester.tap(find.byKey(const ValueKey('submitButton')));
    await tester.pumpAndSettle();

    expect(find.text('닉네임 중복 확인을 완료해주세요.'), findsOneWidget);
    expect(find.text('프로필 설정'), findsOneWidget);
    expect(authService.updatedNickname, isNull);
  });

  testWidgets('존재하지 않는 생년월일이면 가입 저장을 요청하지 않는다', (WidgetTester tester) async {
    final authService = _FakeAuthService(profileRequired: true);
    await tester.pumpWidget(
      TogetherTripApp(
        authService: authService,
        tripService: _FakeTripService(),
      ),
    );

    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('agreeAllTermsCheckbox')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('nicknameField')), '여행자');
    await tester.enterText(
      find.byKey(const ValueKey('birthDateField')),
      '1990.99.99',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('checkNicknameButton')),
    );
    await tester.tap(find.byKey(const ValueKey('checkNicknameButton')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('submitButton')));
    await tester.tap(find.byKey(const ValueKey('submitButton')));
    await tester.pumpAndSettle();

    expect(find.text('올바른 생년월일을 입력해주세요.'), findsOneWidget);
    expect(find.text('프로필 설정'), findsOneWidget);
    expect(authService.updatedNickname, isNull);
  });

  testWidgets('미래 생년월일이면 가입 저장을 요청하지 않는다', (WidgetTester tester) async {
    final authService = _FakeAuthService(profileRequired: true);
    await tester.pumpWidget(
      TogetherTripApp(
        authService: authService,
        tripService: _FakeTripService(),
      ),
    );

    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('agreeAllTermsCheckbox')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('nicknameField')), '여행자');
    await tester.enterText(
      find.byKey(const ValueKey('birthDateField')),
      '2999.01.01',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('checkNicknameButton')),
    );
    await tester.tap(find.byKey(const ValueKey('checkNicknameButton')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('submitButton')));
    await tester.tap(find.byKey(const ValueKey('submitButton')));
    await tester.pumpAndSettle();

    expect(find.text('생년월일은 오늘 또는 이전 날짜로 입력해주세요.'), findsOneWidget);
    expect(find.text('프로필 설정'), findsOneWidget);
    expect(authService.updatedNickname, isNull);
  });

  testWidgets('회원가입 화면에서 약관 내용을 확인할 수 있다', (WidgetTester tester) async {
    final authService = _FakeAuthService(confirmStatus: 'PROFILE_REQUIRED');
    await tester.pumpWidget(
      TogetherTripApp(
        authService: authService,
        tripService: _FakeTripService(),
      ),
    );

    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('termsDetailButton_서비스 이용약관')),
    );
    await tester.tap(find.byKey(const ValueKey('termsDetailButton_서비스 이용약관')));
    await tester.pumpAndSettle();

    expect(find.textContaining('여행방, 동행자 관리'), findsOneWidget);
  });

  testWidgets('회원가입 약관 행을 누르면 상세 대신 동의 상태를 변경한다', (WidgetTester tester) async {
    await tester.pumpWidget(
      TogetherTripApp(
        authService: _FakeAuthService(confirmStatus: 'PROFILE_REQUIRED'),
        tripService: _FakeTripService(),
      ),
    );

    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('서비스 이용약관'));
    await tester.tap(find.text('서비스 이용약관'));
    await tester.pumpAndSettle();

    expect(find.textContaining('여행방, 동행자 관리'), findsNothing);
    final checkbox = tester.widget<Checkbox>(
      find.descendant(
        of: find.byKey(const ValueKey('termsCheckbox_SERVICE_TERMS')),
        matching: find.byType(Checkbox),
      ),
    );
    expect(checkbox.value, isTrue);
  });

  testWidgets('약관 상세를 확인한 뒤에도 닉네임 중복확인을 진행할 수 있다', (WidgetTester tester) async {
    final authService = _FakeAuthService(confirmStatus: 'PROFILE_REQUIRED');
    await tester.pumpWidget(
      TogetherTripApp(
        authService: authService,
        tripService: _FakeTripService(),
      ),
    );

    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('termsDetailButton_서비스 이용약관')),
    );
    await tester.tap(find.byKey(const ValueKey('termsDetailButton_서비스 이용약관')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('nicknameField')));
    await tester.enterText(find.byKey(const ValueKey('nicknameField')), '여행자');
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('checkNicknameButton')),
    );
    await tester.tap(find.byKey(const ValueKey('checkNicknameButton')));
    await tester.pumpAndSettle();

    expect(authService.checkedNickname, '여행자');
    expect(find.text('사용 가능한 닉네임입니다.'), findsOneWidget);
  });

  testWidgets('프로필 작성 중 전화번호 인증이 완료돼도 필수 약관 미동의면 가입하지 않는다', (
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

    await tester.enterText(find.byKey(const ValueKey('nicknameField')), '여행자');
    await tester.enterText(
      find.byKey(const ValueKey('birthDateField')),
      '1990.01.01',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('checkNicknameButton')),
    );
    await tester.tap(find.byKey(const ValueKey('checkNicknameButton')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('termsCheckbox_SERVICE_TERMS')),
    );
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('termsCheckbox_SERVICE_TERMS')),
        matching: find.byType(Checkbox),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('termsCheckbox_LOCATION_INFO_TERMS')),
    );
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('termsCheckbox_LOCATION_INFO_TERMS')),
        matching: find.byType(Checkbox),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('phoneField')));
    await tester.enterText(
      find.byKey(const ValueKey('phoneField')),
      '010-1234-5678',
    );
    await tester.tap(find.byKey(const ValueKey('requestCodeButton')));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('codeField')), '123456');
    await tester.tap(find.byKey(const ValueKey('confirmCodeButton')));
    await tester.pumpAndSettle();

    expect(find.text('프로필 설정'), findsOneWidget);
    expect(find.text('여행'), findsNothing);
    expect(find.textContaining('인증완료'), findsOneWidget);
    expect(authService.updatedNickname, isNull);

    await tester.ensureVisible(find.byKey(const ValueKey('submitButton')));
    await tester.tap(find.byKey(const ValueKey('submitButton')));
    await tester.pumpAndSettle();

    expect(find.text('필수 약관에 동의해주세요.'), findsOneWidget);
    expect(find.text('프로필 설정'), findsOneWidget);
    expect(authService.updatedNickname, isNull);
  });

  testWidgets('약관 목록이 비어 있으면 가입하지 않는다', (WidgetTester tester) async {
    final authService = _FakeAuthService(profileRequired: true);
    await tester.pumpWidget(
      TogetherTripApp(
        authService: authService,
        tripService: _FakeTripService(),
        termsAgreementService: _EmptyTermsAgreementService(),
      ),
    );

    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pumpAndSettle();

    expect(find.text('프로필 설정'), findsOneWidget);
    expect(find.text('필수 약관에 모두 동의해야 가입할 수 있어요.'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('nicknameField')), '여행자');
    await tester.enterText(
      find.byKey(const ValueKey('birthDateField')),
      '1990.01.01',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('checkNicknameButton')),
    );
    await tester.tap(find.byKey(const ValueKey('checkNicknameButton')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('submitButton')));
    await tester.tap(find.byKey(const ValueKey('submitButton')));
    await tester.pumpAndSettle();

    expect(find.text('필수 약관에 동의해주세요.'), findsOneWidget);
    expect(find.text('프로필 설정'), findsOneWidget);
    expect(authService.updatedNickname, isNull);
  });

  testWidgets('약관 전용 화면에서도 약관 목록이 비어 있으면 프로필 설정으로 이동하지 않는다', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TermsAgreementScreen(
          authService: _FakeAuthService(),
          tripService: _FakeTripService(),
          termsAgreementService: _EmptyTermsAgreementService(),
          loginResult: const AuthLoginResult(
            status: 'PROFILE_REQUIRED',
            temporaryToken: 'temporary-token',
            accessToken: null,
            refreshToken: null,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('약관 동의'), findsOneWidget);
    expect(find.text('약관 목록을 확인할 수 없어 가입을 진행할 수 없습니다.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('continueTermsButton')),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const ValueKey('continueTermsButton')));
    await tester.pumpAndSettle();

    expect(find.text('프로필 설정'), findsNothing);
  });

  testWidgets('약관 전용 화면은 전화번호 인증 전이면 약관 저장 없이 체크 상태만 넘긴다', (
    WidgetTester tester,
  ) async {
    final termsAgreementService = _ThrowingSaveTermsAgreementService();
    await tester.pumpWidget(
      MaterialApp(
        home: TermsAgreementScreen(
          authService: _FakeAuthService(),
          tripService: _FakeTripService(),
          termsAgreementService: termsAgreementService,
          loginResult: const AuthLoginResult(
            status: 'PHONE_VERIFICATION_REQUIRED',
            temporaryToken: 'temporary-token',
            accessToken: null,
            refreshToken: null,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('agreeAllTermsCheckbox')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('continueTermsButton')));
    await tester.pumpAndSettle();

    expect(termsAgreementService.saveCalled, isFalse);
    expect(find.text('프로필 설정'), findsOneWidget);
    expect(
      tester
          .widget<Checkbox>(
            find.descendant(
              of: find.byKey(const ValueKey('termsCheckbox_SERVICE_TERMS')),
              matching: find.byType(Checkbox),
            ),
          )
          .value,
      isTrue,
    );
  });

  testWidgets('약관 전용 화면에서 넘긴 동의 상태는 최종 회원가입 때 저장된다', (
    WidgetTester tester,
  ) async {
    final authService = _FakeAuthService();
    final termsAgreementService = _RecordingTermsAgreementService();
    await tester.pumpWidget(
      MaterialApp(
        home: TermsAgreementScreen(
          authService: authService,
          tripService: _FakeTripService(),
          termsAgreementService: termsAgreementService,
          loginResult: const AuthLoginResult(
            status: 'PHONE_VERIFICATION_REQUIRED',
            temporaryToken: 'temporary-token',
            accessToken: null,
            refreshToken: null,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('agreeAllTermsCheckbox')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('continueTermsButton')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('nicknameField')), '여행자');
    await tester.enterText(
      find.byKey(const ValueKey('birthDateField')),
      '1990.01.01',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('checkNicknameButton')),
    );
    await tester.tap(find.byKey(const ValueKey('checkNicknameButton')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('phoneField')));
    await tester.enterText(
      find.byKey(const ValueKey('phoneField')),
      '010-1234-5678',
    );
    await tester.tap(find.byKey(const ValueKey('requestCodeButton')));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('codeField')), '123456');
    await tester.tap(find.byKey(const ValueKey('confirmCodeButton')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('submitButton')));
    await tester.tap(find.byKey(const ValueKey('submitButton')));
    await tester.pumpAndSettle();

    expect(find.text('여행'), findsWidgets);
    expect(authService.updatedNickname, '여행자');
    expect(
      termsAgreementService.savedCodes,
      containsAll(['SERVICE_TERMS', 'PRIVACY_POLICY', 'LOCATION_INFO_TERMS']),
    );
  });

  testWidgets('좁은 화면에서도 회원가입 약관과 제출 버튼을 스크롤로 접근할 수 있다', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      TogetherTripApp(
        authService: _FakeAuthService(profileRequired: true),
        tripService: _FakeTripService(),
      ),
    );

    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pumpAndSettle();

    expect(find.text('프로필 설정'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('agreeAllTermsCheckbox')),
    );
    expect(find.byKey(const ValueKey('agreeAllTermsCheckbox')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('submitButton')));
    expect(find.byKey(const ValueKey('submitButton')), findsOneWidget);
  });

  testWidgets('완료 버튼을 연타해도 회원가입 저장은 한 번만 요청한다', (WidgetTester tester) async {
    final authService = _FakeAuthService(
      profileRequired: true,
      updateProfileDelay: const Duration(milliseconds: 100),
    );
    await tester.pumpWidget(
      TogetherTripApp(
        authService: authService,
        tripService: _FakeTripService(),
      ),
    );

    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('agreeAllTermsCheckbox')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('nicknameField')), '여행자');
    await tester.enterText(
      find.byKey(const ValueKey('birthDateField')),
      '1990.01.01',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('checkNicknameButton')),
    );
    await tester.tap(find.byKey(const ValueKey('checkNicknameButton')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('submitButton')));
    await tester.tap(find.byKey(const ValueKey('submitButton')));
    await tester.tap(find.byKey(const ValueKey('submitButton')));
    await tester.pumpAndSettle();

    expect(find.text('여행'), findsWidgets);
    expect(authService.updateProfileCallCount, 1);
  });

  testWidgets('약관 저장에 실패하면 프로필 저장을 요청하지 않고 약관 오류를 표시한다', (
    WidgetTester tester,
  ) async {
    final authService = _FakeAuthService(profileRequired: true);
    await tester.pumpWidget(
      TogetherTripApp(
        authService: authService,
        tripService: _FakeTripService(),
        termsAgreementService: _FailingSaveTermsAgreementService(),
      ),
    );

    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('agreeAllTermsCheckbox')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('nicknameField')), '여행자');
    await tester.enterText(
      find.byKey(const ValueKey('birthDateField')),
      '1990.01.01',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('checkNicknameButton')),
    );
    await tester.tap(find.byKey(const ValueKey('checkNicknameButton')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('submitButton')));
    await tester.tap(find.byKey(const ValueKey('submitButton')));
    await tester.pumpAndSettle();

    expect(find.textContaining('약관 동의 저장에 실패했습니다'), findsOneWidget);
    expect(find.textContaining('프로필 저장에 실패했습니다'), findsNothing);
    expect(find.text('프로필 설정'), findsOneWidget);
    expect(authService.updatedNickname, isNull);
  });

  testWidgets('전화번호 인증이 완료돼도 약관과 프로필 저장 전에는 메인으로 이동하지 않는다', (
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

    expect(find.text('프로필 설정'), findsOneWidget);
    expect(find.text('여행'), findsNothing);
    expect(find.textContaining('인증완료'), findsOneWidget);
    expect(find.byKey(const ValueKey('nicknameField')), findsOneWidget);
    expect(authService.updatedNickname, isNull);
  });

  testWidgets('인증번호 요청 후 전화번호를 바꾸면 기존 인증번호 입력을 초기화한다', (
    WidgetTester tester,
  ) async {
    final authService = _FakeAuthService();
    await tester.pumpWidget(
      TogetherTripApp(
        authService: authService,
        tripService: _FakeTripService(),
      ),
    );

    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('phoneField')));
    await tester.enterText(
      find.byKey(const ValueKey('phoneField')),
      '010-1234-5678',
    );
    await tester.tap(find.byKey(const ValueKey('requestCodeButton')));
    await tester.pump();

    expect(find.byKey(const ValueKey('codeField')), findsOneWidget);
    expect(authService.requestedPhoneNumber, '01012345678');

    await tester.enterText(
      find.byKey(const ValueKey('phoneField')),
      '010-9999-0000',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('codeField')), findsNothing);
    expect(find.byKey(const ValueKey('confirmCodeButton')), findsNothing);
    expect(authService.confirmedPhoneNumber, isNull);
  });

  testWidgets('인증번호 요청 중 전화번호를 바꾸면 늦은 응답으로 코드 입력을 열지 않는다', (
    WidgetTester tester,
  ) async {
    final authService = _FakeAuthService(
      requestPhoneDelay: const Duration(milliseconds: 100),
    );
    await tester.pumpWidget(
      TogetherTripApp(
        authService: authService,
        tripService: _FakeTripService(),
      ),
    );

    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('phoneField')));
    await tester.enterText(
      find.byKey(const ValueKey('phoneField')),
      '010-1234-5678',
    );
    await tester.tap(find.byKey(const ValueKey('requestCodeButton')));
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('phoneField')),
      '010-9999-0000',
    );
    await tester.pumpAndSettle();

    expect(find.text('전화번호가 변경되었습니다. 인증번호를 다시 요청해주세요.'), findsOneWidget);
    expect(find.byKey(const ValueKey('codeField')), findsNothing);
    expect(authService.requestedPhoneNumber, '01012345678');
    expect(authService.confirmedPhoneNumber, isNull);
  });

  testWidgets('인증번호 확인 중 전화번호를 바꾸면 늦은 응답으로 인증 완료 처리하지 않는다', (
    WidgetTester tester,
  ) async {
    final authService = _FakeAuthService(
      confirmPhoneDelay: const Duration(milliseconds: 100),
    );
    await tester.pumpWidget(
      TogetherTripApp(
        authService: authService,
        tripService: _FakeTripService(),
      ),
    );

    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('phoneField')));
    await tester.enterText(
      find.byKey(const ValueKey('phoneField')),
      '010-1234-5678',
    );
    await tester.tap(find.byKey(const ValueKey('requestCodeButton')));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('codeField')), '123456');
    await tester.tap(find.byKey(const ValueKey('confirmCodeButton')));
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('phoneField')),
      '010-9999-0000',
    );
    await tester.pumpAndSettle();

    expect(find.text('전화번호가 변경되었습니다. 인증번호를 다시 요청해주세요.'), findsOneWidget);
    expect(find.textContaining('인증완료'), findsNothing);
    expect(authService.confirmedPhoneNumber, '01012345678');
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

    expect(find.text('프로필 설정'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('agreeAllTermsCheckbox')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('phoneField')), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('nicknameField')), '여행자');
    await tester.enterText(
      find.byKey(const ValueKey('birthDateField')),
      '1990.01.01',
    );
    await tester.tap(find.byKey(const ValueKey('checkNicknameButton')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('submitButton')));
    await tester.tap(find.byKey(const ValueKey('submitButton')));
    await tester.pumpAndSettle();

    expect(find.text('여행'), findsWidgets);
  });

  testWidgets('인증된 사용자도 필수 약관이나 프로필이 비어 있으면 가입 화면으로 복구한다', (
    WidgetTester tester,
  ) async {
    final authService = _FakeAuthService(
      authenticatedLogin: true,
      profile: const UserProfile(
        id: 1,
        nickname: '카카오 사용자',
        gender: null,
        birthDate: null,
        profileImageUrl: null,
        phoneNumberMasked: '010-****-5678',
        phoneVerifiedAt: '2026-06-24T00:00:00Z',
        phoneVerified: true,
      ),
    );

    await tester.pumpWidget(
      TogetherTripApp(
        authService: authService,
        tripService: _FakeTripService(),
        termsAgreementService: _NoAgreedTermsAgreementService(),
      ),
    );

    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pumpAndSettle();

    expect(find.text('프로필 설정'), findsOneWidget);
    expect(find.text('약관 동의'), findsOneWidget);
    expect(find.byKey(const ValueKey('phoneField')), findsNothing);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('nicknameField')))
          .controller
          ?.text,
      '카카오 사용자',
    );
    expect(find.text('확인됨'), findsOneWidget);
    expect(find.text('여행'), findsNothing);
  });

  testWidgets('약관만 미완료인 인증 사용자는 기존 프로필 값으로 가입 화면을 복구한다', (
    WidgetTester tester,
  ) async {
    final authService = _FakeAuthService(
      authenticatedLogin: true,
      profile: const UserProfile(
        id: 1,
        nickname: '기존여행자',
        gender: 'FEMALE',
        birthDate: '1995-03-04',
        profileImageUrl: '/uploads/user-profile-images/current.jpg',
        phoneNumberMasked: '010-****-5678',
        phoneVerifiedAt: '2026-06-24T00:00:00Z',
        phoneVerified: true,
      ),
    );

    await tester.pumpWidget(
      TogetherTripApp(
        authService: authService,
        tripService: _FakeTripService(),
        termsAgreementService: _NoAgreedTermsAgreementService(),
      ),
    );

    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pumpAndSettle();

    expect(find.text('프로필 설정'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('nicknameField')))
          .controller
          ?.text,
      '기존여행자',
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('birthDateField')))
          .controller
          ?.text,
      '1995.03.04',
    );
    expect(find.text('확인됨'), findsOneWidget);
    expect(find.text('전화번호'), findsNothing);
  });

  testWidgets('이미 동의한 필수 약관은 가입 복구 화면에서 체크 상태로 표시한다', (
    WidgetTester tester,
  ) async {
    final authService = _FakeAuthService(
      authenticatedLogin: true,
      profile: const UserProfile(
        id: 1,
        nickname: '카카오 사용자',
        gender: null,
        birthDate: null,
        profileImageUrl: null,
        phoneNumberMasked: '010-****-5678',
        phoneVerifiedAt: '2026-06-24T00:00:00Z',
        phoneVerified: true,
      ),
    );

    await tester.pumpWidget(
      TogetherTripApp(
        authService: authService,
        tripService: _FakeTripService(),
        termsAgreementService: TermsAgreementService(),
      ),
    );

    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pumpAndSettle();

    expect(find.text('프로필 설정'), findsOneWidget);
    expect(find.text('필수 약관 동의 완료'), findsOneWidget);
    expect(
      tester
          .widget<Checkbox>(
            find.descendant(
              of: find.byKey(const ValueKey('termsCheckbox_SERVICE_TERMS')),
              matching: find.byType(Checkbox),
            ),
          )
          .value,
      isTrue,
    );
    expect(
      tester
          .widget<Checkbox>(
            find.descendant(
              of: find.byKey(const ValueKey('termsCheckbox_MARKETING_CONSENT')),
              matching: find.byType(Checkbox),
            ),
          )
          .value,
      isFalse,
    );
  });

  testWidgets('인증 응답인데 전화번호 미인증 상태면 가입 화면으로 우회하지 않는다', (
    WidgetTester tester,
  ) async {
    final authService = _FakeAuthService(
      authenticatedLogin: true,
      profile: const UserProfile(
        id: 1,
        nickname: '카카오 사용자',
        gender: null,
        birthDate: null,
        profileImageUrl: null,
        phoneNumberMasked: null,
        phoneVerifiedAt: null,
        phoneVerified: false,
      ),
    );

    await tester.pumpWidget(
      TogetherTripApp(
        authService: authService,
        tripService: _FakeTripService(),
      ),
    );

    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pumpAndSettle();

    expect(find.text('전화번호 인증 상태를 확인할 수 없습니다. 다시 로그인해주세요.'), findsOneWidget);
    expect(find.text('프로필 설정'), findsNothing);
    expect(find.text('여행'), findsNothing);
    expect(authService.updatedNickname, isNull);
  });

  testWidgets('카카오 로그인 취소는 화면 오류로 표시하지 않는다', (WidgetTester tester) async {
    await tester.pumpWidget(
      TogetherTripApp(authService: _CancelLoginAuthService()),
    );

    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pumpAndSettle();

    expect(find.textContaining('PlatformException'), findsNothing);
    expect(find.textContaining('오류가 발생했습니다'), findsNothing);
    expect(find.textContaining('카카오 SDK 오류'), findsNothing);
    expect(find.text('카카오로 시작하기'), findsOneWidget);
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

  testWidgets('마이페이지 약관 목록이 비어 있으면 빈 상태를 표시한다', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MyPlaceholderScreen(
          authService: _FakeAuthService(),
          termsAgreementService: _EmptyTermsAgreementService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('약관'));
    await tester.pumpAndSettle();

    expect(find.text('약관 목록을 확인할 수 없습니다.'), findsOneWidget);
    expect(find.text('서비스 이용약관'), findsNothing);
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
    expect(find.textContaining('미동의'), findsOneWidget);

    await tester.tap(marketingSwitch);
    await tester.pumpAndSettle();
    expect(
      await termsAgreementService.getAgreedTermCodes(),
      contains('MARKETING_CONSENT'),
    );
    expect(find.textContaining('동의함'), findsOneWidget);
    expect(find.text('확인'), findsNothing);

    await tester.tap(marketingSwitch);
    await tester.pumpAndSettle();
    expect(
      await termsAgreementService.getAgreedTermCodes(),
      isNot(contains('MARKETING_CONSENT')),
    );
    expect(find.textContaining('미동의'), findsOneWidget);
  });
}

class _FakeAuthService extends AuthService {
  final bool profileRequired;
  final bool authenticatedLogin;
  final String confirmStatus;
  final Duration updateProfileDelay;
  final Duration requestPhoneDelay;
  final Duration confirmPhoneDelay;
  final UserProfile profile;
  String? checkedNickname;
  String? requestedPhoneNumber;
  String? confirmedPhoneNumber;
  String? updatedNickname;
  String? updatedGender;
  String? updatedBirthDate;
  int updateProfileCallCount = 0;

  _FakeAuthService({
    this.profileRequired = false,
    this.authenticatedLogin = false,
    this.confirmStatus = 'AUTHENTICATED',
    this.updateProfileDelay = Duration.zero,
    this.requestPhoneDelay = Duration.zero,
    this.confirmPhoneDelay = Duration.zero,
    this.profile = const UserProfile(
      id: 1,
      nickname: '여행자',
      gender: 'MALE',
      birthDate: '1990-01-01',
      profileImageUrl: null,
      phoneNumberMasked: '010-****-5678',
      phoneVerifiedAt: '2026-06-24T00:00:00Z',
      phoneVerified: true,
    ),
  });

  @override
  Future<AuthLoginResult> loginWithKakao() async {
    if (authenticatedLogin) {
      return const AuthLoginResult(
        status: 'AUTHENTICATED',
        temporaryToken: null,
        accessToken: 'access-token',
        refreshToken: 'refresh-token',
      );
    }

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
    if (requestPhoneDelay > Duration.zero) {
      await Future<void>.delayed(requestPhoneDelay);
    }
    requestedPhoneNumber = phoneNumber;
    return const PhoneVerificationCodeSent(expiresInSeconds: 180);
  }

  @override
  Future<AuthLoginResult> confirmPhoneVerification({
    required String temporaryToken,
    required String phoneNumber,
    required String code,
  }) async {
    if (confirmPhoneDelay > Duration.zero) {
      await Future<void>.delayed(confirmPhoneDelay);
    }
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
  Future<UserProfile> getMe() async {
    return profile;
  }

  @override
  Future<void> updateMyProfile({
    required String nickname,
    required String gender,
    required String birthDate,
    String? profileImageUrl,
    ProfileImageInput? profileImage,
  }) async {
    updateProfileCallCount += 1;
    if (updateProfileDelay > Duration.zero) {
      await Future<void>.delayed(updateProfileDelay);
    }
    updatedNickname = nickname;
    updatedGender = gender;
    updatedBirthDate = birthDate;
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
  Future<List<TermsAgreementItem>> getTerms() async {
    return const <TermsAgreementItem>[];
  }

  @override
  Future<List<TermsAgreementItem>> getRequiredTerms() async {
    return const <TermsAgreementItem>[];
  }

  @override
  Future<void> saveAgreements({
    required List<TermsAgreementItem> agreedTerms,
  }) async {
    throw StateError('필수 약관에 동의해주세요.');
  }
}

class _NoAgreedTermsAgreementService extends TermsAgreementService {
  @override
  Future<Set<String>> getAgreedTermCodes() async {
    return const <String>{};
  }
}

class _ThrowingSaveTermsAgreementService extends TermsAgreementService {
  bool saveCalled = false;

  @override
  Future<void> saveAgreements({
    required List<TermsAgreementItem> agreedTerms,
  }) async {
    saveCalled = true;
    throw StateError('약관은 프로필 저장 시점에 저장되어야 합니다.');
  }
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
  Set<String> savedCodes = const <String>{};

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
