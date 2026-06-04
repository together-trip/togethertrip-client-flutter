import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';

class AuthService {
  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  AuthService({ApiClient? apiClient, TokenStorage? tokenStorage})
    : _apiClient = apiClient ?? ApiClient(),
      _tokenStorage = tokenStorage ?? TokenStorage();

  Future<AuthLoginResult> loginWithKakao() async {
    final kakaoToken = await _getKakaoToken();
    final data = await _apiClient.post('/api/auth/oauth/kakao', {
      'accessToken': kakaoToken,
    });

    if (data == null) {
      throw const ApiException(statusCode: 500, message: '로그인 응답이 비어 있습니다.');
    }

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

  Future<PhoneVerificationCodeSent> requestPhoneVerification({
    required String temporaryToken,
    required String phoneNumber,
  }) async {
    final data = await _apiClient.post('/api/auth/phone/request', {
      'temporaryToken': temporaryToken,
      'phoneNumber': phoneNumber,
    });

    if (data == null) {
      throw const ApiException(
        statusCode: 500,
        message: '인증번호 요청 응답이 비어 있습니다.',
      );
    }

    return PhoneVerificationCodeSent.fromJson(data);
  }

  Future<AuthLoginResult> confirmPhoneVerification({
    required String temporaryToken,
    required String phoneNumber,
    required String code,
  }) async {
    final data = await _apiClient.post('/api/auth/phone/confirm', {
      'temporaryToken': temporaryToken,
      'phoneNumber': phoneNumber,
      'code': code,
    });

    if (data == null) {
      throw const ApiException(
        statusCode: 500,
        message: '전화번호 인증 응답이 비어 있습니다.',
      );
    }

    final result = AuthLoginResult.fromJson(data);
    await _saveTokens(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
    );

    return result;
  }

  Future<void> updateMyProfile({
    required String nickname,
    required String gender,
    required String birthDate,
    String? profileImageUrl,
  }) async {
    final accessToken = await _tokenStorage.getAccessToken();
    if (accessToken == null) {
      throw const ApiException(statusCode: 401, message: '저장된 토큰이 없습니다.');
    }

    await _apiClient.patch('/api/users/me', {
      'nickname': nickname,
      'gender': gender,
      'birthDate': birthDate,
      'profileImageUrl': profileImageUrl,
    }, accessToken: accessToken);
  }

  Future<UserProfile> getMe() async {
    final accessToken = await _tokenStorage.getAccessToken();
    if (accessToken == null) {
      throw const ApiException(statusCode: 401, message: '저장된 토큰이 없습니다.');
    }

    final data = await _apiClient.get(
      '/api/users/me',
      accessToken: accessToken,
    );
    if (data == null) {
      throw const ApiException(statusCode: 500, message: '내 정보 응답이 비어 있습니다.');
    }

    return UserProfile.fromJson(data);
  }

  Future<void> deleteAccount() async {
    final accessToken = await _tokenStorage.getAccessToken();
    if (accessToken == null) {
      throw const ApiException(statusCode: 401, message: '저장된 토큰이 없습니다.');
    }

    await _apiClient.delete('/api/users/me', accessToken: accessToken);

    try {
      await UserApi.instance.logout();
    } catch (_) {}
    await _tokenStorage.clear();
  }

  Future<bool> checkNicknameAvailability(String nickname) async {
    final data = await _apiClient.get(
      '/api/users/nicknames/availability',
      queryParameters: {'nickname': nickname},
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
    try {
      await UserApi.instance.logout();
    } catch (_) {}
    await _tokenStorage.clear();
  }

  Future<bool> isLoggedIn() => _tokenStorage.hasToken();

  Future<String?> getAccessToken() => _tokenStorage.getAccessToken();

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
}

class AuthLoginResult {
  final String status;
  final String? temporaryToken;
  final String? accessToken;
  final String? refreshToken;

  const AuthLoginResult({
    required this.status,
    required this.temporaryToken,
    required this.accessToken,
    required this.refreshToken,
  });

  bool get isAuthenticated => status == 'AUTHENTICATED';

  bool get isProfileRequired => status == 'PROFILE_REQUIRED';

  bool get hasToken => isAuthenticated || isProfileRequired;

  bool get isPhoneVerificationRequired =>
      status == 'PHONE_VERIFICATION_REQUIRED';

  factory AuthLoginResult.fromJson(Map<String, dynamic> json) {
    return AuthLoginResult(
      status: json['status'] as String,
      temporaryToken: json['temporaryToken'] as String?,
      accessToken: json['accessToken'] as String?,
      refreshToken: json['refreshToken'] as String?,
    );
  }
}

class PhoneVerificationCodeSent {
  final String phoneNumber;
  final int expiresInSeconds;

  const PhoneVerificationCodeSent({
    required this.phoneNumber,
    required this.expiresInSeconds,
  });

  factory PhoneVerificationCodeSent.fromJson(Map<String, dynamic> json) {
    return PhoneVerificationCodeSent(
      phoneNumber: json['phoneNumber'] as String,
      expiresInSeconds: json['expiresInSeconds'] as int,
    );
  }
}

class UserProfile {
  final int id;
  final String nickname;
  final String? gender;
  final String? birthDate; // yyyy-MM-dd
  final String? profileImageUrl;
  final String? phoneNumber;

  const UserProfile({
    required this.id,
    required this.nickname,
    required this.gender,
    required this.birthDate,
    required this.profileImageUrl,
    required this.phoneNumber,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: (json['id'] as num).toInt(),
      nickname: json['nickname'] as String,
      gender: json['gender'] as String?,
      birthDate: json['birthDate'] as String?,
      profileImageUrl: json['profileImageUrl'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
    );
  }
}
