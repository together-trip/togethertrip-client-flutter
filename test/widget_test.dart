import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togethertrip/features/auth/service/auth_service.dart';
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
      TogetherTripApp(authService: authService, tripService: _FakeTripService()),
    );

    await tester.tap(find.text('카카오로 시작하기'));
    await tester.pumpAndSettle();

    expect(find.text('프로필 설정'), findsOneWidget);

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

    await tester.tap(find.byKey(const ValueKey('submitButton')));
    await tester.pumpAndSettle();

    expect(find.text('여행'), findsWidgets);
    expect(authService.checkedNickname, '여행자');
    expect(authService.requestedPhoneNumber, '01012345678');
    expect(authService.updatedNickname, '여행자');
    expect(authService.updatedGender, 'MALE');
    expect(authService.updatedBirthDate, '1990-01-01');
  });

  testWidgets('재가입자는 전화번호 인증 후 프로필 입력 없이 메인으로 이동한다', (
    WidgetTester tester,
  ) async {
    final authService = _FakeAuthService(confirmStatus: 'AUTHENTICATED');
    await tester.pumpWidget(
      TogetherTripApp(authService: authService, tripService: _FakeTripService()),
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

    expect(find.text('여행'), findsWidgets);
    expect(find.byKey(const ValueKey('nicknameField')), findsNothing);
    expect(authService.updatedNickname, isNull);
  });

  testWidgets('프로필 미완료 로그인은 전화번호 인증 없이 프로필 입력으로 이동한다', (
    WidgetTester tester,
  ) async {
    final authService = _FakeAuthService(profileRequired: true);
    await tester.pumpWidget(
      TogetherTripApp(authService: authService, tripService: _FakeTripService()),
    );

    await tester.tap(find.text('카카오로 시작하기'));
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
}

class _FakeAuthService extends AuthService {
  final bool profileRequired;
  final String confirmStatus;
  String? checkedNickname;
  String? requestedPhoneNumber;
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
    return const PhoneVerificationCodeSent(
      phoneNumber: '01012345678',
      expiresInSeconds: 180,
    );
  }

  @override
  Future<AuthLoginResult> confirmPhoneVerification({
    required String temporaryToken,
    required String phoneNumber,
    required String code,
  }) async {
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
  }) async {
    updatedNickname = nickname;
    updatedGender = gender;
    updatedBirthDate = birthDate;
  }

  @override
  Future<String?> getAccessToken() async => 'access-token';
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
