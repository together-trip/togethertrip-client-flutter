import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/widget/app_design.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'core/env/env.dart';
import 'core/network/api_client.dart';
import 'features/auth/screen/onboarding_screen.dart';
import 'features/auth/service/auth_service.dart';
import 'features/auth/service/terms_agreement_service.dart';
import 'features/notification/service/notification_push_message_handler.dart';
import 'features/notification/service/notification_push_token_lifecycle.dart';
import 'features/notification/service/notification_service.dart';
import 'features/trip/service/trip_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (_) {}

  if (Env.kakaoNativeAppKey.isNotEmpty) {
    KakaoSdk.init(nativeAppKey: Env.kakaoNativeAppKey);
  }
  runApp(const TogetherTripApp());
}

class TogetherTripApp extends StatefulWidget {
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
  State<TogetherTripApp> createState() => _TogetherTripAppState();
}

class _TogetherTripAppState extends State<TogetherTripApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final AuthService _authService;
  late final TermsAgreementService _termsAgreementService;
  NotificationPushTokenLifecycle? _pushTokenLifecycle;
  NotificationPushMessageHandler? _pushMessageHandler;

  @override
  void initState() {
    super.initState();

    if (widget.authService != null) {
      _authService = widget.authService!;
    } else {
      final apiClient = ApiClient();
      final notificationService = NotificationService(apiClient: apiClient);
      final pushTokenLifecycle = NotificationPushTokenLifecycle(
        notificationService: notificationService,
      );
      final pushMessageHandler = NotificationPushMessageHandler(
        navigatorKey: _navigatorKey,
        notificationService: notificationService,
      );
      _authService = AuthService(
        apiClient: apiClient,
        tokenLifecycle: pushTokenLifecycle,
      );
      pushMessageHandler.initialize();
      pushTokenLifecycle.bindTokenRefresh(_authService);
      _pushTokenLifecycle = pushTokenLifecycle;
      _pushMessageHandler = pushMessageHandler;
    }

    _termsAgreementService =
        widget.termsAgreementService ??
        TermsAgreementService(authService: _authService);
  }

  @override
  void dispose() {
    _pushMessageHandler?.dispose();
    _pushTokenLifecycle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
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
        authService: _authService,
        tripService: widget.tripService,
        termsAgreementService: _termsAgreementService,
      ),
    );
  }
}
