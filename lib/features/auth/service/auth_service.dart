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
    final data = await _apiClient.post(
      '/api/auth/oauth/kakao',
      {'accessToken': kakaoToken},
    );
    await _tokenStorage.save(
      accessToken: data!['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
  }

  Future<void> refreshToken() async {
    final refreshToken = await _tokenStorage.getRefreshToken();
    if (refreshToken == null) throw ApiException(statusCode: 401, message: '저장된 토큰이 없습니다.');

    final data = await _apiClient.post(
      '/api/auth/refresh',
      {'refreshToken': refreshToken},
    );
    await _tokenStorage.save(
      accessToken: data!['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
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
