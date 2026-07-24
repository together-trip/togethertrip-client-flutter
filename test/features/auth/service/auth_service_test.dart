import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:togethertrip/core/network/api_client.dart';
import 'package:togethertrip/core/storage/token_storage.dart';
import 'package:togethertrip/features/auth/service/auth_service.dart';

Map<String, dynamic> _apiResponse(dynamic data) => {
  'success': true,
  'data': data,
  'message': null,
};

Map<String, dynamic> _apiError(String message) => {
  'success': false,
  'code': 'ERROR',
  'message': message,
};

class _FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _store = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _store.remove(key);
    } else {
      _store[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _store[key];

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _store.remove(key);
  }
}

void main() {
  group('AuthService', () {
    test('로그인 응답은 인증 완료와 프로필 입력 필요 상태만 해석한다', () {
      final authenticated = AuthLoginResult.fromJson({
        'status': 'AUTHENTICATED',
        'accessToken': 'access-token',
        'refreshToken': 'refresh-token',
      });
      final profileRequired = AuthLoginResult.fromJson({
        'status': 'PROFILE_REQUIRED',
        'accessToken': 'access-token',
        'refreshToken': 'refresh-token',
      });

      expect(authenticated.isAuthenticated, isTrue);
      expect(authenticated.hasToken, isTrue);
      expect(profileRequired.isProfileRequired, isTrue);
      expect(profileRequired.hasToken, isTrue);
    });

    test('내 정보 응답의 기본 프로필을 파싱한다', () async {
      final tokenStorage = TokenStorage(storage: _FakeSecureStorage());
      await tokenStorage.save(accessToken: 'access-token', refreshToken: 'rt');
      final service = AuthService(
        tokenStorage: tokenStorage,
        apiClient: ApiClient(
          client: MockClient((request) async {
            return http.Response(
              jsonEncode(
                _apiResponse({
                  'id': 1,
                  'nickname': '재완',
                  'profileImageUrl': '/uploads/user-profile-images/a.jpg',
                }),
              ),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );

      final profile = await service.getMe();

      expect(profile.nickname, '재완');
      expect(profile.profileImageUrl, '/uploads/user-profile-images/a.jpg');
    });

    test('프로필 이미지가 있으면 multipart PATCH로 profileImage를 전송한다', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'profile-image-test',
      );
      final file = File('${tempDir.path}/profile.jpg');
      await file.writeAsBytes([0xFF, 0xD8, 0xFF, 0xD9]);
      addTearDown(() async {
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      });

      final tokenStorage = TokenStorage(storage: _FakeSecureStorage());
      await tokenStorage.save(accessToken: 'access-token', refreshToken: 'rt');
      String? capturedMethod;
      String? capturedContentType;
      String? capturedBody;

      final service = AuthService(
        tokenStorage: tokenStorage,
        apiClient: ApiClient(
          client: MockClient((request) async {
            capturedMethod = request.method;
            capturedContentType = request.headers['content-type'];
            capturedBody = utf8.decode(request.bodyBytes, allowMalformed: true);
            return http.Response(
              jsonEncode(_apiResponse({})),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );

      await service.updateMyProfile(
        nickname: '새닉네임',
        profileImage: ProfileImageInput(
          path: file.path,
          filename: 'profile.jpg',
          mimeType: 'image/jpeg',
        ),
      );

      expect(capturedMethod, 'PATCH');
      expect(capturedContentType, startsWith('multipart/form-data;'));
      expect(capturedBody, contains('name="nickname"'));
      expect(capturedBody, contains('새닉네임'));
      expect(capturedBody, contains('name="profileImage"'));
      expect(capturedBody, contains('filename="profile.jpg"'));
    });

    test('프로필 이미지가 없으면 JSON PATCH로 프로필 정보를 전송한다', () async {
      final tokenStorage = TokenStorage(storage: _FakeSecureStorage());
      await tokenStorage.save(accessToken: 'access-token', refreshToken: 'rt');
      String? capturedMethod;
      String? capturedContentType;
      String? capturedAuth;
      Map<String, dynamic>? capturedBody;

      final service = AuthService(
        tokenStorage: tokenStorage,
        apiClient: ApiClient(
          client: MockClient((request) async {
            capturedMethod = request.method;
            capturedContentType = request.headers['content-type'];
            capturedAuth = request.headers['Authorization'];
            capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode(_apiResponse({})),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );

      await service.updateMyProfile(
        nickname: '새닉네임',
        profileImageUrl: '/uploads/user-profile-images/current.jpg',
      );

      expect(capturedMethod, 'PATCH');
      expect(capturedContentType, 'application/json');
      expect(capturedAuth, 'Bearer access-token');
      expect(capturedBody, {
        'nickname': '새닉네임',
        'profileImageUrl': '/uploads/user-profile-images/current.jpg',
      });
    });

    test('인증 API가 401이면 refresh 후 한 번 재시도한다', () async {
      final tokenStorage = TokenStorage(storage: _FakeSecureStorage());
      await tokenStorage.save(
        accessToken: 'old-access-token',
        refreshToken: 'old-refresh-token',
      );
      final capturedAuthHeaders = <String?>[];

      final service = AuthService(
        tokenStorage: tokenStorage,
        apiClient: ApiClient(
          client: MockClient((request) async {
            if (request.url.path == '/api/auth/refresh') {
              return http.Response(
                jsonEncode(
                  _apiResponse({
                    'accessToken': 'new-access-token',
                    'refreshToken': 'new-refresh-token',
                  }),
                ),
                200,
                headers: {'content-type': 'application/json'},
              );
            }

            capturedAuthHeaders.add(request.headers['Authorization']);
            if (capturedAuthHeaders.length == 1) {
              return http.Response(
                jsonEncode(_apiError('인증 실패')),
                401,
                headers: {'content-type': 'application/json'},
              );
            }

            return http.Response(
              jsonEncode(
                _apiResponse({
                  'id': 1,
                  'nickname': '재완',
                  'profileImageUrl': null,
                }),
              ),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );

      final profile = await service.getMe();

      expect(profile.nickname, '재완');
      expect(capturedAuthHeaders, [
        'Bearer old-access-token',
        'Bearer new-access-token',
      ]);
      expect(await tokenStorage.getRefreshToken(), 'new-refresh-token');
    });

    test('토큰 저장과 삭제 시 lifecycle hook을 호출한다', () async {
      final lifecycle = _RecordingTokenLifecycle();
      final tokenStorage = TokenStorage(storage: _FakeSecureStorage());
      final service = AuthService(
        tokenStorage: tokenStorage,
        tokenLifecycle: lifecycle,
        apiClient: ApiClient(
          client: MockClient((request) async {
            if (request.url.path == '/api/auth/refresh') {
              return http.Response(
                jsonEncode(
                  _apiResponse({
                    'accessToken': 'new-access-token',
                    'refreshToken': 'new-refresh-token',
                  }),
                ),
                200,
                headers: {'content-type': 'application/json'},
              );
            }

            return http.Response(
              jsonEncode(_apiResponse(null)),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );

      await tokenStorage.save(
        accessToken: 'old-access-token',
        refreshToken: 'old-refresh-token',
      );

      await service.refreshToken();
      await service.logout();

      expect(lifecycle.savedAccessTokens, ['new-access-token']);
      expect(lifecycle.clearedAccessTokens, ['new-access-token']);
    });
  });
}

class _RecordingTokenLifecycle implements AuthTokenLifecycle {
  final savedAccessTokens = <String>[];
  final clearedAccessTokens = <String?>[];

  @override
  Future<void> didSaveTokens(String accessToken) async {
    savedAccessTokens.add(accessToken);
  }

  @override
  Future<void> willClearTokens(String? accessToken) async {
    clearedAccessTokens.add(accessToken);
  }
}
