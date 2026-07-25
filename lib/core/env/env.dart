class Env {
  static const kakaoNativeAppKey = String.fromEnvironment(
    'KAKAO_NATIVE_APP_KEY',
  );

  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static const supportEmail = String.fromEnvironment('SUPPORT_EMAIL');
}
