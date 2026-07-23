import '../../../core/network/api_client.dart';
import '../../auth/service/auth_service.dart';
import '../model/exchange_rate_models.dart';

class ExchangeRateService {
  final ApiClient _apiClient;
  final AuthService _authService;

  ExchangeRateService({ApiClient? apiClient, AuthService? authService})
    : _apiClient = apiClient ?? ApiClient(),
      _authService = authService ?? AuthService();

  Future<ExchangeRateSearchResult> getExchangeRates({
    String baseCurrency = 'KRW',
    required List<String> targetCurrencies,
    String? date,
    String? from,
    String? to,
  }) async {
    final accessToken = await _requireAccessToken();
    final queryParameters = <String, String>{
      'baseCurrency': baseCurrency.toUpperCase(),
      if (targetCurrencies.isNotEmpty)
        'targetCurrencies': targetCurrencies
            .map((currency) => currency.toUpperCase())
            .join(','),
    };
    if (date != null && date.isNotEmpty) {
      queryParameters['date'] = date;
    }
    if (from != null && from.isNotEmpty) {
      queryParameters['from'] = from;
    }
    if (to != null && to.isNotEmpty) {
      queryParameters['to'] = to;
    }

    final data = await _apiClient.get(
      '/api/exchange-rates',
      queryParameters: queryParameters,
      accessToken: accessToken,
    );
    if (data == null) {
      throw const ApiException(statusCode: 500, message: '환율 응답이 비어 있습니다.');
    }

    return ExchangeRateSearchResult.fromJson(data);
  }

  Future<ExchangeRatePreview> getTransactionExchangeRatePreview({
    required int tripId,
    required String currency,
    String? spendingDate,
  }) async {
    final accessToken = await _requireAccessToken();
    final queryParameters = <String, String>{
      'currency': currency.toUpperCase(),
    };
    if (spendingDate != null && spendingDate.isNotEmpty) {
      queryParameters['spendingDate'] = spendingDate;
    }

    final data = await _apiClient.get(
      '/api/trips/$tripId/transactions/exchange-rate',
      queryParameters: queryParameters,
      accessToken: accessToken,
    );
    if (data == null) {
      throw const ApiException(statusCode: 500, message: '환율 응답이 비어 있습니다.');
    }

    return ExchangeRatePreview.fromJson(data);
  }

  Future<String> _requireAccessToken() async {
    final accessToken = await _authService.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw const ApiException(statusCode: 401, message: '저장된 토큰이 없습니다.');
    }
    return accessToken;
  }
}
