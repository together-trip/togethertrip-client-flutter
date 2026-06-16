import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:togethertrip/features/auth/service/profile_image_input_helper.dart';

void main() {
  group('profile image helper', () {
    test('JPEG와 PNG 파일 시그니처를 허용한다', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'profile-image-helper-test',
      );
      addTearDown(() async {
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      });
      final jpg = File('${tempDir.path}/profile.jpg');
      final png = File('${tempDir.path}/profile.png');
      await jpg.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
      await png.writeAsBytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

      expect(await hasSupportedProfileImageSignature(jpg.path), isTrue);
      expect(await hasSupportedProfileImageSignature(png.path), isTrue);
    });

    test('이미지 확장자를 가진 텍스트 파일은 거부한다', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'profile-image-helper-test',
      );
      addTearDown(() async {
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      });
      final file = File('${tempDir.path}/profile.jpg');
      await file.writeAsString('not an image');

      expect(await hasSupportedProfileImageSignature(file.path), isFalse);
    });
  });
}
