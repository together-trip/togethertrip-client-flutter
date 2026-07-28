class Env {
  static const kakaoNativeAppKey = String.fromEnvironment(
    'KAKAO_NATIVE_APP_KEY',
  );

  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static const supportEmail = String.fromEnvironment('SUPPORT_EMAIL');

  static const privacyPolicyUrl = String.fromEnvironment(
    'PRIVACY_POLICY_URL',
    defaultValue: 'https://togethertrip.co.kr/privacy',
  );

  static const termsOfServiceUrl = String.fromEnvironment(
    'TERMS_OF_SERVICE_URL',
    defaultValue: 'https://togethertrip.co.kr/terms',
  );

  static const communityPolicyUrl = String.fromEnvironment(
    'COMMUNITY_POLICY_URL',
    defaultValue: 'https://togethertrip.co.kr/community-policy',
  );

  static const customerSupportUrl = String.fromEnvironment(
    'CUSTOMER_SUPPORT_URL',
    defaultValue: 'https://togethertrip.co.kr/support',
  );

  static const accountDeletionUrl = String.fromEnvironment(
    'ACCOUNT_DELETION_URL',
    defaultValue: 'https://togethertrip.co.kr/account-deletion',
  );
}
