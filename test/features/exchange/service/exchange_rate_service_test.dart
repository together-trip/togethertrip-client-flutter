import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:togethertrip/core/network/api_client.dart';
import 'package:togethertrip/features/auth/service/auth_service.dart';
import 'package:togethertrip/features/exchange/service/exchange_rate_service.dart';

Map<String, dynamic> _apiResponse(dynamic data) => {
  'success': true,
  'data': data,
  'message': null,
};

void main() {
  group('ExchangeRateService', () {
    test('전역 환율 조회 API를 호출하고 기간 응답을 파싱한다', () async {
      Uri? capturedUrl;
      String? capturedAuth;
      final service = ExchangeRateService(
        apiClient: ApiClient(
          client: MockClient((request) async {
            capturedUrl = request.url;
            capturedAuth = request.headers['Authorization'];
            return http.Response(
              jsonEncode(
                _apiResponse({
                  'baseCurrency': 'KRW',
                  'date': null,
                  'from': '2026-06-10',
                  'to': '2026-06-17',
                  'rates': [
                    {
                      'targetCurrency': 'JPY',
                      'rate': 9.5123,
                      'rateDate': '2026-06-17',
                      'source': 'KOREA_EXIM',
                    },
                    {
                      'targetCurrency': 'JPY',
                      'rate': 9.4811,
                      'rateDate': '2026-06-16',
                      'source': 'KOREA_EXIM',
                    },
                  ],
                }),
              ),
              200,
            );
          }),
        ),
        authService: _FakeAuthService(),
      );

      final result = await service.getExchangeRates(
        targetCurrencies: ['jpy'],
        from: '2026-06-10',
        to: '2026-06-17',
      );

      expect(capturedUrl!.path, '/api/exchange-rates');
      expect(capturedUrl!.queryParameters['baseCurrency'], 'KRW');
      expect(capturedUrl!.queryParameters['targetCurrencies'], 'JPY');
      expect(capturedUrl!.queryParameters['from'], '2026-06-10');
      expect(capturedUrl!.queryParameters['to'], '2026-06-17');
      expect(capturedAuth, 'Bearer access-token');
      expect(result.baseCurrency, 'KRW');
      expect(result.from, '2026-06-10');
      expect(result.to, '2026-06-17');
      expect(result.rates, hasLength(2));
      expect(result.rates.first.targetCurrency, 'JPY');
      expect(result.rates.first.rate, 9.5123);
      expect(result.rates.first.rateDate, '2026-06-17');
      expect(result.rates.first.source, 'KOREA_EXIM');
    });

    test('거래 환율 미리보기 API를 호출하고 응답을 파싱한다', () async {
      Uri? capturedUrl;
      String? capturedAuth;
      final service = ExchangeRateService(
        apiClient: ApiClient(
          client: MockClient((request) async {
            capturedUrl = request.url;
            capturedAuth = request.headers['Authorization'];
            return http.Response(
              jsonEncode(
                _apiResponse({
                  'baseCurrency': 'KRW',
                  'targetCurrency': 'JPY',
                  'rate': 9.5123,
                  'rateDate': '2026-06-15',
                  'source': 'KOREA_EXIM',
                }),
              ),
              200,
            );
          }),
        ),
        authService: _FakeAuthService(),
      );

      final preview = await service.getTransactionExchangeRatePreview(
        tripId: 10,
        currency: 'jpy',
        spendingDate: '2026-06-16',
      );

      expect(capturedUrl!.path, '/api/trips/10/transactions/exchange-rate');
      expect(capturedUrl!.queryParameters['currency'], 'JPY');
      expect(capturedUrl!.queryParameters['spendingDate'], '2026-06-16');
      expect(capturedAuth, 'Bearer access-token');
      expect(preview.baseCurrency, 'KRW');
      expect(preview.targetCurrency, 'JPY');
      expect(preview.rate, 9.5123);
      expect(preview.rateDate, '2026-06-15');
      expect(preview.source, 'KOREA_EXIM');
    });
  });
}

class _FakeAuthService extends AuthService {
  @override
  Future<String?> getAccessToken() async => 'access-token';
}
