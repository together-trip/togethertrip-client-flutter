import 'package:flutter/material.dart';

import 'core/widget/app_design.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'core/env/env.dart';
import 'features/auth/screen/onboarding_screen.dart';
import 'features/auth/service/auth_service.dart';
import 'features/auth/service/terms_agreement_service.dart';
import 'features/trip/service/trip_service.dart';

void main() {
  if (Env.kakaoNativeAppKey.isNotEmpty) {
    KakaoSdk.init(nativeAppKey: Env.kakaoNativeAppKey);
  }
  runApp(const TogetherTripApp());
}

class TogetherTripApp extends StatelessWidget {
  final AuthService? authService;
  final TripService? tripService;
  final TermsAgreementService? termsAgreementService;

  const TogetherTripApp({
    super.key,
    this.authService,
    this.tripService,
    this.termsAgreementService,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TogetherTrip',
      locale: const Locale('ko'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('ko'), Locale('en')],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.ink),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: OnboardingScreen(
        authService: authService ?? AuthService(),
        tripService: tripService,
        termsAgreementService: termsAgreementService,
      ),
    );
  }
}
