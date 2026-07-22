import '../../../core/network/api_client.dart';
import '../../auth/service/auth_service.dart';
import '../model/place_models.dart';

class PlaceService {
  final ApiClient _apiClient;
  final AuthService _authService;

  PlaceService({ApiClient? apiClient, AuthService? authService})
    : _apiClient = apiClient ?? ApiClient(),
      _authService = authService ?? AuthService();

  Future<List<PlaceSuggestion>> autocomplete(
    int tripId, {
    required String query,
    required String sessionToken,
    String languageCode = 'ko',
  }) async {
    final items = await _authService.runWithAccessToken(
      (accessToken) => _apiClient.getList(
        '/api/trips/$tripId/places/autocomplete',
        queryParameters: {
          'query': query,
          'sessionToken': sessionToken,
          'languageCode': languageCode,
        },
        accessToken: accessToken,
      ),
    );
    return items
        .whereType<Map<String, dynamic>>()
        .map(PlaceSuggestion.fromJson)
        .toList();
  }

  Future<PlaceSelection> getPlace(
    int tripId, {
    required String placeId,
    required String sessionToken,
    String languageCode = 'ko',
  }) async {
    final data = await _authService.runWithAccessToken(
      (accessToken) => _apiClient.get(
        '/api/trips/$tripId/places/${Uri.encodeComponent(placeId)}',
        queryParameters: {
          'sessionToken': sessionToken,
          'languageCode': languageCode,
        },
        accessToken: accessToken,
      ),
    );
    if (data == null) {
      throw const ApiException(statusCode: 500, message: '장소 상세 응답이 비어 있습니다.');
    }
    return PlaceSelection.fromJson(data);
  }

  Future<PlaceSelection> reverseGeocode(
    int tripId, {
    required double latitude,
    required double longitude,
    String languageCode = 'ko',
  }) async {
    final data = await _authService.runWithAccessToken(
      (accessToken) => _apiClient.get(
        '/api/trips/$tripId/places/reverse',
        queryParameters: {
          'latitude': latitude.toString(),
          'longitude': longitude.toString(),
          'languageCode': languageCode,
        },
        accessToken: accessToken,
      ),
    );
    if (data == null) {
      throw const ApiException(statusCode: 500, message: '위치 확인 응답이 비어 있습니다.');
    }
    return PlaceSelection.fromJson(data);
  }
}
