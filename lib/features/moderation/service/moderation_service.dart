import '../../../core/network/api_client.dart';
import '../../auth/service/auth_service.dart';
import '../model/moderation_models.dart';

class ModerationService {
  ModerationService({ApiClient? apiClient, AuthService? authService})
    : _apiClient = apiClient ?? ApiClient(),
      _authService = authService ?? AuthService();

  final ApiClient _apiClient;
  final AuthService _authService;

  Future<ReportResult> createReport(int tripId, ReportRequest request) async {
    final data = await _authService.runWithAccessToken(
      (accessToken) => _apiClient.post(
        '/api/trips/$tripId/reports',
        request.toJson(),
        accessToken: accessToken,
      ),
    );
    if (data == null) {
      throw const ApiException(statusCode: 500, message: '신고 응답이 비어 있습니다.');
    }
    return ReportResult.fromJson(data);
  }

  Future<void> blockUser(int userId) async {
    await _authService.runWithAccessToken(
      (accessToken) => _apiClient.post(
        '/api/users/$userId/blocks',
        const {},
        accessToken: accessToken,
      ),
    );
  }

  Future<void> unblockUser(int userId) async {
    await _authService.runWithAccessToken(
      (accessToken) => _apiClient.delete(
        '/api/users/$userId/blocks',
        accessToken: accessToken,
      ),
    );
  }

  Future<List<BlockedUser>> getBlockedUsers() async {
    final data = await _authService.runWithAccessToken(
      (accessToken) =>
          _apiClient.get('/api/users/me/blocks', accessToken: accessToken),
    );
    if (data == null) return const [];
    final items = data['items'] as List<dynamic>? ?? const [];
    return items
        .map((item) => BlockedUser.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
