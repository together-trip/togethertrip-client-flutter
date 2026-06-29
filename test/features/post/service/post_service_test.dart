import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:togethertrip/core/network/api_client.dart';
import 'package:togethertrip/features/auth/service/auth_service.dart';
import 'package:togethertrip/features/post/service/post_service.dart';
import 'package:togethertrip/features/transaction/service/transaction_service.dart';

Map<String, dynamic> _apiResponse(dynamic data) => {
  'success': true,
  'data': data,
  'message': null,
};

http.Response _jsonResponse(dynamic data) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(_apiResponse(data))),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  group('PostService', () {
    test('게시글 목록 요청에 필터와 커서를 포함한다', () async {
      Uri? capturedUrl;
      String? capturedAuth;
      final service = PostService(
        apiClient: ApiClient(
          client: MockClient((request) async {
            capturedUrl = request.url;
            capturedAuth = request.headers['Authorization'];
            return _jsonResponse({
              'items': [
                {
                  'id': 1,
                  'tripId': 10,
                  'transactionId': null,
                  'authorParticipantId': 100,
                  'authorDisplayName': '재완',
                  'postType': 'RECORD',
                  'title': '첫날',
                  'category': '관광',
                  'contentPreview': '도착',
                  'occurredAt': '2026-06-09T03:00:00Z',
                  'placeName': '도쿄역',
                  'latitude': null,
                  'longitude': null,
                  'commentCount': 3,
                  'createdAt': '2026-06-09T03:00:00Z',
                  'updatedAt': '2026-06-09T03:00:00Z',
                },
              ],
              'size': 20,
              'nextCursor': 'next',
              'hasNext': true,
            });
          }),
        ),
        authService: _FakeAuthService(),
      );

      final page = await service.getPosts(
        10,
        postType: 'RECORD',
        cursor: 'cursor',
      );

      expect(capturedUrl!.path, '/api/trips/10/posts');
      expect(capturedUrl!.queryParameters['postType'], 'RECORD');
      expect(capturedUrl!.queryParameters['cursor'], 'cursor');
      expect(capturedUrl!.queryParameters['size'], '20');
      expect(capturedAuth, 'Bearer access-token');
      expect(page.items.single.title, '첫날');
      expect(page.hasNext, true);
    });

    test('게시글 작성 요청을 multipart 서버 DTO 형태로 전송한다', () async {
      String? capturedMethod;
      String? capturedContentType;
      String? capturedBody;
      final service = PostService(
        apiClient: ApiClient(
          client: MockClient((request) async {
            capturedMethod = request.method;
            capturedContentType = request.headers['content-type'];
            capturedBody = request.body;
            return _jsonResponse({
              'id': 1,
              'tripId': 10,
              'transactionId': null,
              'authorParticipantId': 100,
              'authorDisplayName': '재완',
              'postType': 'RECORD',
              'title': '점심',
              'category': '식비',
              'content': '라멘',
              'occurredAt': '2026-06-09T03:00:00.000Z',
              'placeName': 'Ichiran',
              'latitude': null,
              'longitude': null,
              'commentCount': 0,
              'attachments': [],
              'createdAt': null,
              'updatedAt': null,
            });
          }),
        ),
        authService: _FakeAuthService(),
      );

      await service.createPost(
        10,
        const PostFormInput(
          transactionId: null,
          title: '점심',
          category: '식비',
          content: '라멘',
          postType: 'RECORD',
          occurredAt: '2026-06-09T03:00:00.000Z',
          placeName: 'Ichiran',
          latitude: null,
          longitude: null,
        ),
      );

      expect(capturedMethod, 'POST');
      expect(capturedContentType, startsWith('multipart/form-data;'));
      expect(capturedBody, contains('name="title"'));
      expect(capturedBody, contains('점심'));
      expect(capturedBody, contains('name="category"'));
      expect(capturedBody, contains('식비'));
      expect(capturedBody, contains('name="postType"'));
      expect(capturedBody, contains('RECORD'));
      expect(capturedBody, contains('name="occurredAt"'));
      expect(capturedBody, contains('2026-06-09T03:00:00.000Z'));
    });

    test('소비 게시글 통합 작성 요청을 multipart 서버 DTO 형태로 전송한다', () async {
      Uri? capturedUrl;
      String? capturedMethod;
      String? capturedContentType;
      String? capturedBody;
      final service = PostService(
        apiClient: ApiClient(
          client: MockClient((request) async {
            capturedUrl = request.url;
            capturedMethod = request.method;
            capturedContentType = request.headers['content-type'];
            capturedBody = request.body;
            return _jsonResponse({
              'post': {
                'id': 1,
                'tripId': 10,
                'transactionId': 5,
                'authorParticipantId': 100,
                'authorDisplayName': '재완',
                'postType': 'EXPENSE',
                'title': '점심',
                'category': '식비',
                'content': '라멘',
                'occurredAt': '2026-06-09T03:00:00.000Z',
                'placeName': 'Ichiran',
                'latitude': null,
                'longitude': null,
                'commentCount': 0,
                'attachments': [],
                'createdAt': null,
                'updatedAt': null,
              },
              'transaction': {
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
                'payments': [
                  {'id': 1, 'participantId': 100, 'amount': 12000},
                ],
                'shares': [
                  {
                    'id': 2,
                    'participantId': 100,
                    'shareAmount': 12000,
                    'shareRatio': 1,
                  },
                ],
              },
            });
          }),
        ),
        authService: _FakeAuthService(),
      );

      final result = await service.createExpensePost(
        10,
        const ExpensePostFormInput(
          transactionInput: TransactionFormInput(
            transactionType: 'EXPENSE',
            amount: 12000,
            currency: 'JPY',
            payments: [
              TransactionPaymentInput(participantId: 100, amount: 12000),
            ],
            shares: [
              TransactionShareInput(
                participantId: 100,
                shareAmount: 12000,
                shareRatio: 1,
              ),
            ],
          ),
          postInput: PostFormInput(
            transactionId: null,
            title: '점심',
            category: '식비',
            content: '라멘',
            postType: 'EXPENSE',
            occurredAt: '2026-06-09T03:00:00.000Z',
            placeName: 'Ichiran',
            latitude: null,
            longitude: null,
          ),
        ),
      );

      expect(capturedUrl!.path, '/api/trips/10/expense-posts');
      expect(capturedMethod, 'POST');
      expect(capturedContentType, startsWith('multipart/form-data;'));
      expect(capturedBody, contains('name="title"'));
      expect(capturedBody, contains('점심'));
      expect(capturedBody, contains('name="transactionType"'));
      expect(capturedBody, contains('EXPENSE'));
      expect(capturedBody, contains('name="amount"'));
      expect(capturedBody, contains('12000'));
      expect(capturedBody, contains('name="payments[0].participantId"'));
      expect(capturedBody, contains('name="payments[0].amount"'));
      expect(capturedBody, contains('name="shares[0].participantId"'));
      expect(capturedBody, contains('name="shares[0].shareAmount"'));
      expect(capturedBody, contains('name="shares[0].shareRatio"'));
      expect(capturedBody, isNot(contains('name="transactionId"')));
      expect(result.post.transactionId, 5);
      expect(result.transaction.summary.id, 5);
    });

    test('소비 게시글 통합 수정 요청을 multipart 서버 DTO 형태로 전송한다', () async {
      Uri? capturedUrl;
      String? capturedMethod;
      String? capturedContentType;
      String? capturedBody;
      final service = PostService(
        apiClient: ApiClient(
          client: MockClient((request) async {
            capturedUrl = request.url;
            capturedMethod = request.method;
            capturedContentType = request.headers['content-type'];
            capturedBody = request.body;
            return _jsonResponse({
              'post': {
                'id': 1,
                'tripId': 10,
                'transactionId': 5,
                'authorParticipantId': 100,
                'authorDisplayName': '재완',
                'postType': 'EXPENSE',
                'title': '저녁',
                'category': '식비',
                'content': '오코노미야키',
                'occurredAt': '2026-06-09T10:00:00.000Z',
                'placeName': 'Okonomiyaki House',
                'latitude': null,
                'longitude': null,
                'commentCount': 0,
                'attachments': [],
                'createdAt': null,
                'updatedAt': null,
              },
              'transaction': {
                'summary': {
                  'id': 5,
                  'tripId': 10,
                  'transactionType': 'EXPENSE',
                  'amount': 18000,
                  'currency': 'JPY',
                  'exchangeRate': 9.5,
                  'baseCurrency': 'KRW',
                  'baseAmount': 171000,
                  'status': 'ACTIVE',
                  'createdByUserId': 1,
                  'createdAt': null,
                  'updatedAt': null,
                },
                'payments': [
                  {'id': 1, 'participantId': 100, 'amount': 18000},
                ],
                'shares': [
                  {
                    'id': 2,
                    'participantId': 100,
                    'shareAmount': 18000,
                    'shareRatio': 1,
                  },
                ],
              },
            });
          }),
        ),
        authService: _FakeAuthService(),
      );

      final result = await service.updateExpensePost(
        10,
        1,
        const ExpensePostFormInput(
          transactionInput: TransactionFormInput(
            transactionType: 'EXPENSE',
            amount: 18000,
            currency: 'JPY',
            payments: [
              TransactionPaymentInput(participantId: 100, amount: 18000),
            ],
            shares: [
              TransactionShareInput(
                participantId: 100,
                shareAmount: 18000,
                shareRatio: 1,
              ),
            ],
          ),
          postInput: PostFormInput(
            transactionId: 5,
            title: '저녁',
            category: '식비',
            content: '오코노미야키',
            postType: 'EXPENSE',
            occurredAt: '2026-06-09T10:00:00.000Z',
            placeName: 'Okonomiyaki House',
            latitude: null,
            longitude: null,
            replaceAttachments: true,
          ),
        ),
      );

      expect(capturedUrl!.path, '/api/trips/10/expense-posts/1');
      expect(capturedMethod, 'PATCH');
      expect(capturedContentType, startsWith('multipart/form-data;'));
      expect(capturedBody, contains('name="title"'));
      expect(capturedBody, contains('저녁'));
      expect(capturedBody, contains('name="replaceAttachments"'));
      expect(capturedBody, contains('true'));
      expect(capturedBody, contains('name="transactionType"'));
      expect(capturedBody, contains('EXPENSE'));
      expect(capturedBody, contains('name="amount"'));
      expect(capturedBody, contains('18000'));
      expect(capturedBody, contains('name="payments[0].participantId"'));
      expect(capturedBody, contains('name="shares[0].shareAmount"'));
      expect(capturedBody, isNot(contains('name="transactionId"')));
      expect(result.post.title, '저녁');
      expect(result.transaction.summary.amount, 18000);
    });

    test('댓글 작성과 삭제 경로를 사용한다', () async {
      final paths = <String>[];
      final service = PostService(
        apiClient: ApiClient(
          client: MockClient((request) async {
            paths.add('${request.method} ${request.url.path}');
            if (request.method == 'POST') {
              return _jsonResponse({
                'id': 7,
                'postId': 1,
                'authorParticipantId': 100,
                'authorDisplayName': '재완',
                'content': '좋다',
                'commentDepth': 0,
                'createdAt': null,
                'updatedAt': null,
              });
            }
            return _jsonResponse({});
          }),
        ),
        authService: _FakeAuthService(),
      );

      final comment = await service.createComment(10, 1, '좋다');
      await service.deleteComment(10, 1, comment.id);

      expect(paths, [
        'POST /api/trips/10/posts/1/comments',
        'DELETE /api/trips/10/posts/1/comments/7',
      ]);
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
