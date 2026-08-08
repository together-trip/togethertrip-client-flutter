import 'package:flutter/foundation.dart';

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

  /// 정산 공유 링크의 기준 주소. 뒤에 `?token=...`을 붙여 사용한다.
  static const settlementShareBaseUrl = String.fromEnvironment(
    'SETTLEMENT_SHARE_BASE_URL',
    defaultValue: 'https://togethertrip.co.kr/settlements/share',
  );

  /// 여행 Recap 기능 노출 여부. 1차 출시에서는 비활성화한다.
  static const _tripRecapEnabledFromEnvironment = bool.fromEnvironment(
    'TRIP_RECAP_ENABLED',
    defaultValue: false,
  );

  @visibleForTesting
  static bool? tripRecapEnabledOverride;

  static bool get tripRecapEnabled =>
      tripRecapEnabledOverride ?? _tripRecapEnabledFromEnvironment;

  static void ensureReleaseConfiguration() {
    const requiredValues = {
      'API_BASE_URL': apiBaseUrl,
      'SUPPORT_EMAIL': supportEmail,
      'KAKAO_NATIVE_APP_KEY': kakaoNativeAppKey,
      'PRIVACY_POLICY_URL': privacyPolicyUrl,
      'TERMS_OF_SERVICE_URL': termsOfServiceUrl,
      'COMMUNITY_POLICY_URL': communityPolicyUrl,
      'CUSTOMER_SUPPORT_URL': customerSupportUrl,
      'ACCOUNT_DELETION_URL': accountDeletionUrl,
      'SETTLEMENT_SHARE_BASE_URL': settlementShareBaseUrl,
    };
    final missing = requiredValues.entries
        .where((entry) => entry.value.trim().isEmpty)
        .map((entry) => entry.key)
        .toList();
    if (missing.isNotEmpty) {
      throw StateError('필수 release 환경 값이 없습니다: ${missing.join(', ')}');
    }

    const urlValues = {
      'API_BASE_URL': apiBaseUrl,
      'PRIVACY_POLICY_URL': privacyPolicyUrl,
      'TERMS_OF_SERVICE_URL': termsOfServiceUrl,
      'COMMUNITY_POLICY_URL': communityPolicyUrl,
      'CUSTOMER_SUPPORT_URL': customerSupportUrl,
      'ACCOUNT_DELETION_URL': accountDeletionUrl,
      'SETTLEMENT_SHARE_BASE_URL': settlementShareBaseUrl,
    };
    final invalidUrls = urlValues.entries
        .where((entry) {
          final uri = Uri.tryParse(entry.value);
          return uri == null || uri.scheme != 'https' || uri.host.isEmpty;
        })
        .map((entry) => entry.key)
        .toList();
    if (invalidUrls.isNotEmpty) {
      throw StateError(
        'release URL은 유효한 HTTPS여야 합니다: ${invalidUrls.join(', ')}',
      );
    }

    final supportEmailUri = Uri.tryParse('mailto:$supportEmail');
    if (supportEmailUri == null ||
        !supportEmail.contains('@') ||
        supportEmailUri.path.isEmpty) {
      throw StateError('SUPPORT_EMAIL 형식이 올바르지 않습니다.');
    }
  }
}
