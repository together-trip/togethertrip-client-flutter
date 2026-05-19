import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';

class AuthService {
  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  AuthService({
    ApiClient? apiClient,
    TokenStorage? tokenStorage,
  })  : _apiClient = apiClient ?? ApiClient(),
        _tokenStorage = tokenStorage ?? TokenStorage();

  Future<void> loginWithKakao() async {
    final kakaoToken = await _getKakaoToken();
    final response = await _apiClient.post(
      '/api/auth/oauth/kakao',
      {'accessToken': kakaoToken},
    );
    await _tokenStorage.save(
      accessToken: response['accessToken'] as String,
      refreshToken: response['refreshToken'] as String,
    );
  }

  Future<void> logout() async {
    try {
      await UserApi.instance.logout();
    } catch (_) {
      // 카카오 로그아웃 실패해도 로컬 토큰은 삭제
    }
    await _tokenStorage.clear();
  }

  Future<bool> isLoggedIn() => _tokenStorage.hasToken();

  Future<String?> getAccessToken() => _tokenStorage.getAccessToken();

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
