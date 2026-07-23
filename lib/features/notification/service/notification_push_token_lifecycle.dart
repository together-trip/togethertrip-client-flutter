import 'dart:async';

import '../../auth/service/auth_service.dart';
import 'fcm_token_provider.dart';
import 'notification_service.dart';

class NotificationPushTokenLifecycle implements AuthTokenLifecycle {
  final NotificationService _notificationService;
  final FcmRegistrationTokenProvider _tokenProvider;
  final String? _deviceId;
  StreamSubscription<String>? _tokenRefreshSubscription;

  NotificationPushTokenLifecycle({
    NotificationService? notificationService,
    FcmRegistrationTokenProvider? tokenProvider,
    String? deviceId,
  }) : _notificationService = notificationService ?? NotificationService(),
       _tokenProvider = tokenProvider ?? FirebaseMessagingTokenProvider(),
       _deviceId = deviceId;

  void bindTokenRefresh(AuthService authService) {
    _tokenRefreshSubscription ??= _tokenProvider.onTokenRefresh.listen((
      token,
    ) async {
      final accessToken = await authService.getAccessToken();
      if (accessToken == null || accessToken.isEmpty) return;
      await _registerToken(token, accessToken);
    });
  }

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;
  }

  @override
  Future<void> didSaveTokens(String accessToken) async {
    final token = await _tokenProvider.getToken();
    if (token == null || token.isEmpty) return;
    await _registerToken(token, accessToken);
  }

  @override
  Future<void> willClearTokens(String? accessToken) async {
    if (accessToken == null || accessToken.isEmpty) return;
    final token = await _tokenProvider.getToken();
    if (token == null || token.isEmpty) return;

    await _notificationService.deactivatePushTokenWithAccessToken(
      token,
      accessToken,
    );
  }

  Future<void> _registerToken(String token, String accessToken) async {
    await _notificationService.registerPushTokenWithAccessToken(
      PushTokenRegisterInput(
        token: token,
        platform: currentPushTokenPlatform(),
        deviceId: _deviceId,
      ),
      accessToken,
    );
  }
}
