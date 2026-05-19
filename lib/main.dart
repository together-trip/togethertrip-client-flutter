import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'features/auth/screen/kakao_login_test_screen.dart';
import 'features/auth/service/auth_service.dart';

const _kakaoNativeAppKey = String.fromEnvironment('KAKAO_NATIVE_APP_KEY');

void main() {
  assert(
    _kakaoNativeAppKey.isNotEmpty,
    '--dart-define=KAKAO_NATIVE_APP_KEY 가 설정되지 않았습니다.',
  );
  KakaoSdk.init(nativeAppKey: _kakaoNativeAppKey);
  runApp(const TogetherTripApp());
}

class TogetherTripApp extends StatelessWidget {
  const TogetherTripApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TogetherTrip',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: KakaoLoginTestScreen(authService: AuthService()),
    );
  }
}
