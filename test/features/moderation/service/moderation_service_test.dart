import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:togethertrip/core/network/api_client.dart';
import 'package:togethertrip/features/auth/service/auth_service.dart';
import 'package:togethertrip/features/moderation/model/moderation_models.dart';
import 'package:togethertrip/features/moderation/service/moderation_service.dart';

void main() {
  test('신고 요청은 확정 계약의 경로와 target/reason/description을 전송한다', () async {
    late http.Request captured;
    final service = ModerationService(
      authService: _FakeAuthService(),
      apiClient: ApiClient(
        client: MockClient((request) async {
          captured = request;
          return _response({
            'id': 9,
            'status': 'RECEIVED',
            'createdAt': '2026-07-25T00:00:00Z',
          });
        }),
      ),
    );

    final result = await service.createReport(
      10,
      const ReportRequest(
        targetType: ReportTargetType.comment,
        targetId: 7,
        reason: ReportReason.harassment,
        description: '  반복적인 모욕  ',
      ),
    );

    expect(captured.method, 'POST');
    expect(captured.url.path, '/api/trips/10/reports');
    expect(captured.headers['Authorization'], 'Bearer access-token');
    expect(jsonDecode(captured.body), {
      'targetType': 'COMMENT',
      'targetId': 7,
      'reason': 'HARASSMENT',
      'description': '반복적인 모욕',
    });
    expect(result.id, 9);
  });

  test('차단 목록 조회와 차단·해제는 global userId 경로를 사용한다', () async {
    final requests = <String>[];
    final service = ModerationService(
      authService: _FakeAuthService(),
      apiClient: ApiClient(
        client: MockClient((request) async {
          requests.add('${request.method} ${request.url.path}');
          if (request.method == 'GET') {
            return _response({
              'items': [
                {
                  'blockedUserId': 22,
                  'displayName': '민수',
                  'blockedAt': '2026-07-25T00:00:00Z',
                },
              ],
            });
          }
          return _response({});
        }),
      ),
    );

    final users = await service.getBlockedUsers();
    await service.blockUser(22);
    await service.unblockUser(22);

    expect(users.single.blockedUserId, 22);
    expect(requests, [
      'GET /api/users/me/blocks',
      'POST /api/users/22/blocks',
      'DELETE /api/users/22/blocks',
    ]);
  });
}

http.Response _response(dynamic data) => http.Response(
  jsonEncode({'success': true, 'data': data, 'message': null}),
  200,
  headers: {'content-type': 'application/json'},
);

class _FakeAuthService extends AuthService {
  @override
  Future<T> runWithAccessToken<T>(
    Future<T> Function(String accessToken) request,
  ) {
    return request('access-token');
  }
}
