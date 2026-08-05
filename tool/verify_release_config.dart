import 'dart:convert';
import 'dart:io';

import 'release_config_validator.dart';

void main(List<String> arguments) {
  final platformOnly = arguments.contains('--platform-only');
  final dartDefinePath = _argumentValue(arguments, '--dart-define-file');
  final signingPath = _argumentValue(arguments, '--android-key-properties');
  if (!platformOnly && (dartDefinePath == null || signingPath == null)) {
    stderr.writeln(
      '사용법: dart run tool/verify_release_config.dart '
      '--dart-define-file=config/release.json '
      '--android-key-properties=android/key.properties',
    );
    exitCode = 64;
    return;
  }

  final root = Directory.current;
  final dartDefineFile = dartDefinePath == null
      ? null
      : File(_absolutePath(root, dartDefinePath));
  final signingFile = signingPath == null
      ? null
      : File(_absolutePath(root, signingPath));
  final issues = <String>[];

  if (dartDefineFile != null && !dartDefineFile.existsSync()) {
    issues.add('dart-define 파일을 찾을 수 없습니다: ${dartDefineFile.path}');
  }
  if (signingFile != null && !signingFile.existsSync()) {
    issues.add('Android signing 파일을 찾을 수 없습니다: ${signingFile.path}');
  }

  if (dartDefineFile?.existsSync() ?? false) {
    try {
      final decoded = jsonDecode(dartDefineFile!.readAsStringSync());
      if (decoded is! Map<String, dynamic>) {
        issues.add('dart-define 파일 최상위 값은 JSON object여야 합니다.');
      } else {
        issues.addAll(validateReleaseDartDefines(decoded));
      }
    } on FormatException catch (error) {
      issues.add('dart-define JSON 형식이 올바르지 않습니다: $error');
    }
  }

  if (signingFile?.existsSync() ?? false) {
    final properties = parseProperties(signingFile!.readAsStringSync());
    final storeFileValue = properties['storeFile'] ?? '';
    final storeFile = File(
      File(storeFileValue).isAbsolute
          ? storeFileValue
          : _absolutePath(Directory('${root.path}/android'), storeFileValue),
    );
    issues.addAll(
      validateAndroidSigningProperties(
        properties,
        keystoreExists: storeFile.existsSync(),
      ),
    );
  }

  if (!platformOnly) {
    for (final path in [
      'android/app/google-services.json',
      'ios/Runner/GoogleService-Info.plist',
    ]) {
      if (!File('${root.path}/$path').existsSync()) {
        issues.add('Firebase release 설정 파일이 없습니다: $path');
      }
    }
  }

  const platformPaths = [
    'android/app/build.gradle.kts',
    'android/app/src/main/AndroidManifest.xml',
    'android/app/src/debug/AndroidManifest.xml',
    'android/app/src/profile/AndroidManifest.xml',
    'ios/Runner/Runner.entitlements',
    'ios/Runner/RunnerRelease.entitlements',
    'ios/Runner/PrivacyInfo.xcprivacy',
    'ios/Runner.xcodeproj/project.pbxproj',
  ];
  final platformFiles = <String, String>{};
  for (final path in platformPaths) {
    final file = File('${root.path}/$path');
    if (!file.existsSync()) {
      issues.add('필수 release 설정 파일이 없습니다: $path');
    } else {
      platformFiles[path] = file.readAsStringSync();
    }
  }
  issues.addAll(validatePlatformReleaseFiles(platformFiles));

  if (issues.isNotEmpty) {
    stderr.writeln('Release 설정 검증 실패:');
    for (final issue in issues.toSet()) {
      stderr.writeln('- $issue');
    }
    exitCode = 1;
    return;
  }
  stdout.writeln('Release 설정 정적 검증을 통과했습니다.');
}

String? _argumentValue(List<String> arguments, String name) {
  final prefix = '$name=';
  for (final argument in arguments) {
    if (argument.startsWith(prefix)) return argument.substring(prefix.length);
  }
  return null;
}

String _absolutePath(Directory base, String path) =>
    File(path).isAbsolute ? path : '${base.path}/$path';
