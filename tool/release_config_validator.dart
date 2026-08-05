const requiredReleaseDartDefines = <String>[
  'API_BASE_URL',
  'SUPPORT_EMAIL',
  'KAKAO_NATIVE_APP_KEY',
  'GOOGLE_MAPS_API_KEY',
  'PRIVACY_POLICY_URL',
  'TERMS_OF_SERVICE_URL',
  'COMMUNITY_POLICY_URL',
  'CUSTOMER_SUPPORT_URL',
  'ACCOUNT_DELETION_URL',
];

const _releaseUrlNames = <String>[
  'API_BASE_URL',
  'PRIVACY_POLICY_URL',
  'TERMS_OF_SERVICE_URL',
  'COMMUNITY_POLICY_URL',
  'CUSTOMER_SUPPORT_URL',
  'ACCOUNT_DELETION_URL',
];

const requiredAndroidSigningProperties = <String>[
  'storeFile',
  'storePassword',
  'keyAlias',
  'keyPassword',
];

List<String> validateReleaseDartDefines(Map<String, Object?> values) {
  final issues = <String>[];
  for (final name in requiredReleaseDartDefines) {
    final value = values[name]?.toString().trim() ?? '';
    if (value.isEmpty) {
      issues.add('$name 값이 없습니다.');
    } else if (_looksLikePlaceholder(value)) {
      issues.add('$name 값이 예시 placeholder입니다.');
    }
  }

  for (final name in _releaseUrlNames) {
    final value = values[name]?.toString().trim() ?? '';
    if (value.isEmpty) continue;
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      issues.add('$name 값은 유효한 HTTPS URL이어야 합니다.');
    }
  }

  final supportEmail = values['SUPPORT_EMAIL']?.toString().trim() ?? '';
  if (supportEmail.isNotEmpty &&
      (!supportEmail.contains('@') || supportEmail.contains(' '))) {
    issues.add('SUPPORT_EMAIL 형식이 올바르지 않습니다.');
  }
  return issues;
}

List<String> validateAndroidSigningProperties(
  Map<String, String> values, {
  required bool keystoreExists,
}) {
  final issues = <String>[];
  for (final name in requiredAndroidSigningProperties) {
    final value = values[name]?.trim() ?? '';
    if (value.isEmpty) {
      issues.add('$name 값이 없습니다.');
    } else if (_looksLikePlaceholder(value)) {
      issues.add('$name 값이 예시 placeholder입니다.');
    }
  }
  if ((values['storeFile']?.trim().isNotEmpty ?? false) && !keystoreExists) {
    issues.add('storeFile 경로에 upload keystore가 없습니다.');
  }
  return issues;
}

Map<String, String> parseProperties(String contents) {
  final result = <String, String>{};
  for (final rawLine in contents.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#') || !line.contains('=')) continue;
    final separator = line.indexOf('=');
    result[line.substring(0, separator).trim()] = line
        .substring(separator + 1)
        .trim();
  }
  return result;
}

List<String> validatePlatformReleaseFiles(Map<String, String> files) {
  final issues = <String>[];
  void requireContains(String file, String pattern, String message) {
    if (!(files[file]?.contains(pattern) ?? false)) issues.add(message);
  }

  final gradle = files['android/app/build.gradle.kts'] ?? '';
  requireContains(
    'android/app/build.gradle.kts',
    'signingConfigs.getByName("release")',
    'Android release signingConfig가 release 설정을 사용하지 않습니다.',
  );
  if (gradle.contains('signingConfigs.getByName("debug")')) {
    issues.add('Android release 설정에 debug signing이 남아 있습니다.');
  }
  requireContains(
    'android/app/src/main/AndroidManifest.xml',
    'android:usesCleartextTraffic="false"',
    'Android main manifest가 cleartext를 차단하지 않습니다.',
  );
  requireContains(
    'android/app/src/main/AndroidManifest.xml',
    'android.permission.INTERNET',
    'Android release 앱에 INTERNET 권한이 없습니다.',
  );
  for (final variant in ['debug', 'profile']) {
    requireContains(
      'android/app/src/$variant/AndroidManifest.xml',
      'android:usesCleartextTraffic="true"',
      'Android $variant 개발 manifest가 로컬 cleartext를 허용하지 않습니다.',
    );
  }
  requireContains(
    'ios/Runner/Runner.entitlements',
    '<string>development</string>',
    'iOS development APNs entitlement가 없습니다.',
  );
  requireContains(
    'ios/Runner/RunnerRelease.entitlements',
    '<string>production</string>',
    'iOS release APNs entitlement가 production이 아닙니다.',
  );
  final project = files['ios/Runner.xcodeproj/project.pbxproj'] ?? '';
  if (RegExp(
        r'CODE_SIGN_ENTITLEMENTS = Runner/RunnerRelease\.entitlements;',
      ).allMatches(project).length <
      2) {
    issues.add('iOS Release/Profile에 production entitlement가 모두 연결되지 않았습니다.');
  }
  requireContains(
    'ios/Runner/PrivacyInfo.xcprivacy',
    '<key>NSPrivacyTracking</key>',
    '앱 PrivacyInfo.xcprivacy가 올바르지 않습니다.',
  );
  requireContains(
    'ios/Runner.xcodeproj/project.pbxproj',
    'PrivacyInfo.xcprivacy in Resources',
    'PrivacyInfo.xcprivacy가 Xcode Resources에 포함되지 않았습니다.',
  );
  return issues;
}

bool _looksLikePlaceholder(String value) {
  final normalized = value.toLowerCase();
  return normalized.contains('replace') ||
      normalized.contains('example') ||
      normalized.contains('your-');
}
