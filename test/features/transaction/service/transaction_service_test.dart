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

http.Response _jsonResponse(dynamic data) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(data)),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

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
            return _jsonResponse(
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
                  'category': '식비',
                  'occurredAt': '2026-06-09T03:00:00Z',
                  'status': 'ACTIVE',
                  'createdByUserId': 1,
                  'createdAt': null,
                  'updatedAt': null,
                },
                'payments': [],
                'shares': [],
              }),
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
      expect(detail.summary.category, '식비');
      expect(detail.summary.occurredAt, '2026-06-09T03:00:00Z');
    });

    test('거래 생성 요청을 서버 DTO 형태로 전송한다', () async {
      Uri? capturedUrl;
      String? capturedAuth;
      Map<String, dynamic>? capturedBody;
      final service = TransactionService(
        apiClient: ApiClient(
          client: MockClient((request) async {
            capturedUrl = request.url;
            capturedAuth = request.headers['Authorization'];
            capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
            return _jsonResponse(
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
                  'category': '식비',
                  'occurredAt': '2026-06-09T03:00:00Z',
                  'status': 'ACTIVE',
                  'createdByUserId': 1,
                  'createdAt': null,
                  'updatedAt': null,
                },
                'payments': [
                  {'id': 1, 'participantId': 100, 'amount': 12000},
                ],
                'shares': [
                  {
                    'id': 2,
                    'participantId': 100,
                    'shareAmount': 6000,
                    'shareRatio': 0.5,
                  },
                  {
                    'id': 3,
                    'participantId': 101,
                    'shareAmount': 6000,
                    'shareRatio': 0.5,
                  },
                ],
              }),
            );
          }),
        ),
        authService: _FakeAuthService(),
      );

      final detail = await service.createTransaction(
        10,
        const TransactionFormInput(
          transactionType: 'EXPENSE',
          amount: 12000,
          currency: 'JPY',
          category: '식비',
          occurredAt: '2026-06-09T03:00:00Z',
          payments: [
            TransactionPaymentInput(participantId: 100, amount: 12000),
          ],
          shares: [
            TransactionShareInput(
              participantId: 100,
              shareAmount: 6000,
              shareRatio: 0.5,
            ),
            TransactionShareInput(
              participantId: 101,
              shareAmount: 6000,
              shareRatio: 0.5,
            ),
          ],
        ),
      );

      expect(capturedUrl!.path, '/api/trips/10/transactions');
      expect(capturedAuth, 'Bearer access-token');
      expect(capturedBody!['transactionType'], 'EXPENSE');
      expect(capturedBody!['amount'], 12000);
      expect(capturedBody!['currency'], 'JPY');
      expect(capturedBody!['category'], '식비');
      expect(capturedBody!['occurredAt'], '2026-06-09T03:00:00Z');
      expect(capturedBody!['payments'], isA<List<dynamic>>());
      expect(capturedBody!['shares'], isA<List<dynamic>>());
      expect(detail.payments.single.participantId, 100);
      expect(detail.shares.length, 2);
    });

    test('거래 수정 요청을 PATCH로 전송한다', () async {
      Uri? capturedUrl;
      String? capturedMethod;
      Map<String, dynamic>? capturedBody;
      final service = TransactionService(
        apiClient: ApiClient(
          client: MockClient((request) async {
            capturedUrl = request.url;
            capturedMethod = request.method;
            capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
            return _jsonResponse(
              _apiResponse({
                'summary': {
                  'id': 5,
                  'tripId': 10,
                  'transactionType': 'EXPENSE',
                  'amount': 15000,
                  'currency': 'JPY',
                  'exchangeRate': 9.5,
                  'baseCurrency': 'KRW',
                  'baseAmount': 142500,
                  'category': '교통',
                  'occurredAt': '2026-06-10T03:00:00Z',
                  'status': 'ACTIVE',
                  'createdByUserId': 1,
                  'createdAt': null,
                  'updatedAt': null,
                },
                'payments': [
                  {'id': 1, 'participantId': 100, 'amount': 15000},
                ],
                'shares': [
                  {
                    'id': 2,
                    'participantId': 100,
                    'shareAmount': 15000,
                    'shareRatio': 1,
                  },
                ],
              }),
            );
          }),
        ),
        authService: _FakeAuthService(),
      );

      final detail = await service.updateTransaction(
        10,
        5,
        const TransactionFormInput(
          transactionType: 'EXPENSE',
          amount: 15000,
          currency: 'JPY',
          category: '교통',
          occurredAt: '2026-06-10T03:00:00Z',
          payments: [
            TransactionPaymentInput(participantId: 100, amount: 15000),
          ],
          shares: [
            TransactionShareInput(
              participantId: 100,
              shareAmount: 15000,
              shareRatio: 1,
            ),
          ],
        ),
      );

      expect(capturedUrl!.path, '/api/trips/10/transactions/5');
      expect(capturedMethod, 'PATCH');
      expect(capturedBody!['category'], '교통');
      expect(capturedBody!['occurredAt'], '2026-06-10T03:00:00Z');
      expect(detail.summary.amount, 15000);
    });
  });
}

class _FakeAuthService extends AuthService {
  @override
  Future<String?> getAccessToken() async => 'access-token';

  @override
  Future<T> runWithAccessToken<T>(
    Future<T> Function(String accessToken) request,
  ) {
    return request('access-token');
  }
}
