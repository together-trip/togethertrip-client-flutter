import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:togethertrip/core/network/api_client.dart';
import 'package:togethertrip/features/auth/service/auth_service.dart';
import 'package:togethertrip/features/transaction/service/transaction_service.dart';

Map<String, dynamic> _apiResponse(dynamic data) => {
  'success': true,
  'data': data,
  'message': null,
};

void main() {
  group('TransactionService', () {
    test('거래 상세를 조회하고 원화 금액 필드를 파싱한다', () async {
      Uri? capturedUrl;
      String? capturedAuth;
      final service = TransactionService(
        apiClient: ApiClient(
          client: MockClient((request) async {
            capturedUrl = request.url;
            capturedAuth = request.headers['Authorization'];
            return http.Response(
              jsonEncode(
                _apiResponse({
                  'summary': {
                    'id': 5,
                    'tripId': 10,
                    'transactionType': 'EXPENSE',
                    'amount': 12000,
                    'currency': 'JPY',
                    'exchangeRate': 9.5,
                    'baseCurrency': 'KRW',
                    'baseAmount': 114000,
                    'status': 'ACTIVE',
                    'createdByUserId': 1,
                    'createdAt': null,
                    'updatedAt': null,
                  },
                  'payments': [],
                  'shares': [],
                }),
              ),
              200,
            );
          }),
        ),
        authService: _FakeAuthService(),
      );

      final detail = await service.getTransaction(10, 5);

      expect(capturedUrl!.path, '/api/trips/10/transactions/5');
      expect(capturedAuth, 'Bearer access-token');
      expect(detail.summary.amount, 12000);
      expect(detail.summary.currency, 'JPY');
    });
  });
}

class _FakeAuthService extends AuthService {
  @override
  Future<String?> getAccessToken() async => 'access-token';
}
