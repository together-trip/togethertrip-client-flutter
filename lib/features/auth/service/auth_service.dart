import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';

class AuthService {
  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;
  final AuthTokenLifecycle? _tokenLifecycle;
  final AppleSignInGateway _appleSignInGateway;

  AuthService({
    ApiClient? apiClient,
    TokenStorage? tokenStorage,
    AuthTokenLifecycle? tokenLifecycle,
    AppleSignInGateway? appleSignInGateway,
  }) : _apiClient = apiClient ?? ApiClient(),
       _tokenStorage = tokenStorage ?? TokenStorage(),
       _tokenLifecycle = tokenLifecycle,
       _appleSignInGateway = appleSignInGateway ?? NativeAppleSignInGateway();

  Future<AuthLoginResult> loginWithKakao() async {
    final kakaoToken = await _getKakaoToken();
    final data = await _apiClient.post('/api/auth/oauth/kakao', {
      'accessToken': kakaoToken,
    });

    if (data == null) {
      throw const ApiException(statusCode: 500, message: '로그인 응답이 비어 있습니다.');
    }

    return _completeLogin(data);
  }

  Future<AuthLoginResult> loginWithApple() async {
    final rawNonce = _generateNonce();
    final credential = await _appleSignInGateway.authorize(
      hashedNonce: sha256.convert(utf8.encode(rawNonce)).toString(),
    );
    if (credential.identityToken == null || credential.identityToken!.isEmpty) {
      throw const ApiException(
        statusCode: 401,
        message: 'Apple identity token을 받지 못했습니다.',
      );
    }

    final data = await _apiClient.post('/api/auth/oauth/apple', {
      'authorizationCode': credential.authorizationCode,
      'identityToken': credential.identityToken,
      'rawNonce': rawNonce,
      'givenName': credential.givenName,
      'familyName': credential.familyName,
    });
    if (data == null) {
      throw const ApiException(statusCode: 500, message: '로그인 응답이 비어 있습니다.');
    }

    return _completeLogin(data);
  }

  Future<AuthLoginResult> _completeLogin(Map<String, dynamic> data) async {
    final result = AuthLoginResult.fromJson(data);
    if (result.hasToken) {
      await _saveTokens(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
      );
    } else {
      await _tokenStorage.clear();
    }

    return result;
  }

  Future<void> updateMyProfile({
    required String nickname,
    String? profileImageUrl,
    ProfileImageInput? profileImage,
  }) async {
    await runWithAccessToken((accessToken) {
      if (profileImage != null) {
        return _apiClient.multipart(
          'PATCH',
          '/api/users/me',
          fields: {'nickname': nickname},
          files: [
            MultipartFileInput(
              fieldName: 'profileImage',
              path: profileImage.path,
              filename: profileImage.filename,
              mimeType: profileImage.mimeType,
            ),
          ],
          accessToken: accessToken,
        );
      }

      return _apiClient.patch('/api/users/me', {
        'nickname': nickname,
        'profileImageUrl': profileImageUrl,
      }, accessToken: accessToken);
    });
  }

  Future<UserProfile> getMe() async {
    final data = await runWithAccessToken(
      (accessToken) =>
          _apiClient.get('/api/users/me', accessToken: accessToken),
    );
    if (data == null) {
      throw const ApiException(statusCode: 500, message: '내 정보 응답이 비어 있습니다.');
    }

    return UserProfile.fromJson(data);
  }

  Future<void> deleteAccount() async {
    final accessToken = await _tokenStorage.getAccessToken();
    await runWithAccessToken(
      (accessToken) =>
          _apiClient.delete('/api/users/me', accessToken: accessToken),
    );

    await _notifyWillClearTokens(accessToken);
    try {
      await UserApi.instance.logout();
    } catch (_) {}
    await _appleSignInGateway.clearLocalState();
    await _tokenStorage.clear();
  }

  Future<bool> checkNicknameAvailability(String nickname) async {
    final normalizedNickname = nickname.trim();
    if (normalizedNickname.isEmpty) {
      throw const ApiException(statusCode: 400, message: '닉네임을 입력해주세요.');
    }

    final data = await _apiClient.get(
      '/api/users/nicknames/availability',
      queryParameters: {'nickname': normalizedNickname},
    );

    if (data == null || data['available'] is! bool) {
      throw const ApiException(
        statusCode: 500,
        message: '닉네임 확인 응답이 올바르지 않습니다.',
      );
    }

    return data['available'] as bool;
  }

  Future<void> refreshToken() async {
    final refreshToken = await _tokenStorage.getRefreshToken();
    if (refreshToken == null) {
      throw const ApiException(statusCode: 401, message: '저장된 토큰이 없습니다.');
    }

    final data = await _apiClient.post('/api/auth/refresh', {
      'refreshToken': refreshToken,
    });
    await _saveTokens(
      accessToken: data?['accessToken'] as String?,
      refreshToken: data?['refreshToken'] as String?,
    );
  }

  Future<void> logout() async {
    final accessToken = await _tokenStorage.getAccessToken();
    try {
      if (accessToken != null) {
        await _apiClient.post('/api/auth/logout', {}, accessToken: accessToken);
      }
    } catch (_) {}
    await _notifyWillClearTokens(accessToken);
    try {
      await UserApi.instance.logout();
    } catch (_) {}
    await _appleSignInGateway.clearLocalState();
    await _tokenStorage.clear();
  }

  Future<bool> isLoggedIn() => _tokenStorage.hasToken();

  Future<String?> getAccessToken() => _tokenStorage.getAccessToken();

  Future<T> runWithAccessToken<T>(
    Future<T> Function(String accessToken) request,
  ) async {
    final accessToken = await _requireStoredAccessToken();
    try {
      return await request(accessToken);
    } on ApiException catch (e) {
      if (e.statusCode != 401) rethrow;

      try {
        await refreshToken();
      } catch (_) {
        await _tokenStorage.clear();
        rethrow;
      }

      final refreshedAccessToken = await _requireStoredAccessToken();
      return request(refreshedAccessToken);
    }
  }

  Future<void> _saveTokens({
    required String? accessToken,
    required String? refreshToken,
  }) async {
    if (accessToken == null || refreshToken == null) {
      throw const ApiException(statusCode: 500, message: '토큰 응답이 올바르지 않습니다.');
    }

    await _tokenStorage.save(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
    await _notifyDidSaveTokens(accessToken);
  }

  Future<String> _requireStoredAccessToken() async {
    final accessToken = await _tokenStorage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw const ApiException(statusCode: 401, message: '저장된 토큰이 없습니다.');
    }
    return accessToken;
  }

  Future<String> _getKakaoToken() async {
    OAuthToken token;
    if (await isKakaoTalkInstalled()) {
      token = await UserApi.instance.loginWithKakaoTalk();
    } else {
      token = await UserApi.instance.loginWithKakaoAccount();
    }
    return token.accessToken;
  }

  String _generateNonce([int length = 32]) {
    const characters =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => characters[random.nextInt(characters.length)],
    ).join();
  }

  Future<void> _notifyDidSaveTokens(String accessToken) async {
    try {
      await _tokenLifecycle?.didSaveTokens(accessToken);
    } catch (_) {}
  }

  Future<void> _notifyWillClearTokens(String? accessToken) async {
    try {
      await _tokenLifecycle?.willClearTokens(accessToken);
    } catch (_) {}
  }
}

abstract class AppleSignInGateway {
  Future<AppleSignInCredential> authorize({required String hashedNonce});

  Future<void> clearLocalState();
}

class NativeAppleSignInGateway implements AppleSignInGateway {
  @override
  Future<AppleSignInCredential> authorize({required String hashedNonce}) async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [AppleIDAuthorizationScopes.fullName],
      nonce: hashedNonce,
    );
    final userIdentifier = credential.userIdentifier;
    if (userIdentifier == null || userIdentifier.isEmpty) {
      throw const AppleCredentialRevokedException();
    }
    final state = await SignInWithApple.getCredentialState(userIdentifier);
    if (state != CredentialState.authorized) {
      throw const AppleCredentialRevokedException();
    }
    return AppleSignInCredential(
      authorizationCode: credential.authorizationCode,
      identityToken: credential.identityToken,
      givenName: credential.givenName,
      familyName: credential.familyName,
    );
  }

  @override
  Future<void> clearLocalState() async {}
}

class AppleSignInCredential {
  final String authorizationCode;
  final String? identityToken;
  final String? givenName;
  final String? familyName;

  const AppleSignInCredential({
    required this.authorizationCode,
    required this.identityToken,
    required this.givenName,
    required this.familyName,
  });
}

class AppleCredentialRevokedException implements Exception {
  const AppleCredentialRevokedException();
}

abstract class AuthTokenLifecycle {
  Future<void> didSaveTokens(String accessToken);

  Future<void> willClearTokens(String? accessToken);
}

class AuthLoginResult {
  final String status;
  final String? accessToken;
  final String? refreshToken;

  const AuthLoginResult({
    required this.status,
    required this.accessToken,
    required this.refreshToken,
  });

  bool get isAuthenticated => status == 'AUTHENTICATED';

  bool get isProfileRequired => status == 'PROFILE_REQUIRED';

  bool get hasToken => isAuthenticated || isProfileRequired;

  factory AuthLoginResult.fromJson(Map<String, dynamic> json) {
    return AuthLoginResult(
      status: json['status'] as String,
      accessToken: json['accessToken'] as String?,
      refreshToken: json['refreshToken'] as String?,
    );
  }
}

class ProfileImageInput {
  final String path;
  final String filename;
  final String? mimeType;

  const ProfileImageInput({
    required this.path,
    required this.filename,
    required this.mimeType,
  });
}

class UserProfile {
  final int id;
  final String nickname;
  final String? profileImageUrl;

  const UserProfile({
    required this.id,
    required this.nickname,
    required this.profileImageUrl,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: (json['id'] as num).toInt(),
      nickname: json['nickname'] as String,
      profileImageUrl: json['profileImageUrl'] as String?,
    );
  }
}
