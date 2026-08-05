import 'package:flutter_test/flutter_test.dart';

import '../../tool/release_config_validator.dart';

void main() {
  test('필수 운영 값과 HTTPS URL이 모두 유효하면 통과한다', () {
    final values = <String, Object?>{
      'API_BASE_URL': 'https://api.togethertrip.co.kr',
      'SUPPORT_EMAIL': 'support@togethertrip.co.kr',
      'KAKAO_NATIVE_APP_KEY': 'production-kakao-key',
      'GOOGLE_MAPS_API_KEY': 'production-google-maps-key',
      'PRIVACY_POLICY_URL': 'https://togethertrip.co.kr/privacy',
      'TERMS_OF_SERVICE_URL': 'https://togethertrip.co.kr/terms',
      'COMMUNITY_POLICY_URL': 'https://togethertrip.co.kr/community-policy',
      'CUSTOMER_SUPPORT_URL': 'https://togethertrip.co.kr/support',
      'ACCOUNT_DELETION_URL': 'https://togethertrip.co.kr/account-deletion',
    };

    expect(validateReleaseDartDefines(values), isEmpty);
  });

  test('필수 운영 값 누락, placeholder와 HTTP URL을 거부한다', () {
    final issues = validateReleaseDartDefines({
      'API_BASE_URL': 'http://10.0.2.2:8080',
      'SUPPORT_EMAIL': '',
      'KAKAO_NATIVE_APP_KEY': 'replace-with-key',
    });

    expect(issues, contains('SUPPORT_EMAIL 값이 없습니다.'));
    expect(issues, contains('KAKAO_NATIVE_APP_KEY 값이 예시 placeholder입니다.'));
    expect(issues, contains('API_BASE_URL 값은 유효한 HTTPS URL이어야 합니다.'));
    expect(issues, contains('ACCOUNT_DELETION_URL 값이 없습니다.'));
  });

  test('Android signing 값과 실제 keystore 파일을 요구한다', () {
    final properties = parseProperties('''
# upload signing
storeFile=/secure/upload.jks
storePassword=secret
keyAlias=upload
keyPassword=secret
''');

    expect(
      validateAndroidSigningProperties(properties, keystoreExists: true),
      isEmpty,
    );
    expect(
      validateAndroidSigningProperties(properties, keystoreExists: false),
      contains('storeFile 경로에 upload keystore가 없습니다.'),
    );
  });

  test('플랫폼 release 보안 설정 누락을 탐지한다', () {
    final issues = validatePlatformReleaseFiles({
      'android/app/build.gradle.kts':
          'signingConfig = signingConfigs.getByName("debug")',
      'android/app/src/main/AndroidManifest.xml':
          'android:usesCleartextTraffic="true"',
    });

    expect(issues, contains('Android release 설정에 debug signing이 남아 있습니다.'));
    expect(issues, contains('Android main manifest가 cleartext를 차단하지 않습니다.'));
    expect(issues, contains('iOS release APNs entitlement가 production이 아닙니다.'));
  });
}
