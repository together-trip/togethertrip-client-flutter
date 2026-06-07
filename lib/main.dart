import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'features/auth/screen/onboarding_screen.dart';
import 'features/auth/service/auth_service.dart';
import 'features/trip/service/trip_service.dart';

const _kakaoNativeAppKey = String.fromEnvironment('KAKAO_NATIVE_APP_KEY');

void main() {
  if (_kakaoNativeAppKey.isNotEmpty) {
    KakaoSdk.init(nativeAppKey: _kakaoNativeAppKey);
  }
  runApp(const TogetherTripApp());
}

class TogetherTripApp extends StatelessWidget {
  final AuthService? authService;
  final TripService? tripService;

  const TogetherTripApp({super.key, this.authService, this.tripService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TogetherTrip',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A1A1A)),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: OnboardingScreen(
        authService: authService ?? AuthService(),
        tripService: tripService,
      ),
    );
  }
}
