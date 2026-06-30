import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:togethertrip/core/network/api_client.dart';
import 'package:togethertrip/features/auth/service/auth_service.dart';
import 'package:togethertrip/features/notification/screen/notification_list_screen.dart';
import 'package:togethertrip/features/notification/service/fcm_token_provider.dart';
import 'package:togethertrip/features/notification/service/notification_push_message_handler.dart';
import 'package:togethertrip/features/notification/service/notification_push_token_lifecycle.dart';
import 'package:togethertrip/features/notification/service/notification_service.dart';

Map<String, dynamic> _apiResponse(dynamic data) => {
  'success': true,
  'data': data,
  'message': null,
};

http.Response _jsonResponse(dynamic data) {
  return http.Response(
    jsonEncode(_apiResponse(data)),
    200,
    headers: {'content-type': 'application/json'},
  );
}

void main() {
  group('NotificationService', () {
    test('알림 목록을 gateway notification prefix와 bearer token으로 조회한다', () async {
      Uri? capturedUrl;
      Map<String, String>? capturedHeaders;
      final service = NotificationService(
        authService: _FakeAuthService(),
        apiClient: ApiClient(
          client: MockClient((request) async {
            capturedUrl = request.url;
            capturedHeaders = request.headers;
            return _jsonResponse([
              {
                'id': 1,
                'sourceEventId': 201,
                'eventType': 'POST_CREATED',
                'aggregateType': 'POST',
                'aggregateId': 20,
                'title': '제주 여행',
                'body': '지우님이 첫 일정을 작성했습니다.',
                'deeplink': 'togethertrip://trips/10/posts/20',
                'occurredAt': '2026-06-24T00:00:00Z',
                'readAt': null,
                'createdAt': '2026-06-24T00:00:01Z',
              },
            ]);
          }),
        ),
      );

      final notifications = await service.getNotifications(limit: 100);

      expect(capturedUrl!.path, '/notification/api/notifications');
      expect(capturedUrl!.queryParameters['limit'], '100');
      expect(capturedHeaders!['Authorization'], 'Bearer access-token');
      expect(capturedHeaders!.containsKey('X-User-Id'), isFalse);
      expect(notifications.single.title, '제주 여행');
      expect(notifications.single.isRead, isFalse);
    });

    test('단건 읽음과 전체 읽음 API를 호출한다', () async {
      final calls = <String>[];
      final service = NotificationService(
        authService: _FakeAuthService(),
        apiClient: ApiClient(
          client: MockClient((request) async {
            calls.add('${request.method} ${request.url.path}');
            if (request.url.path.endsWith('/read-all')) {
              return _jsonResponse({'updatedCount': 3});
            }

            return _jsonResponse({
              'id': 1,
              'sourceEventId': 201,
              'eventType': 'POST_CREATED',
              'aggregateType': 'POST',
              'aggregateId': 20,
              'title': '제주 여행',
              'body': '읽음',
              'deeplink': null,
              'occurredAt': null,
              'readAt': '2026-06-24T00:10:00Z',
              'createdAt': '2026-06-24T00:00:01Z',
            });
          }),
        ),
      );

      final notification = await service.markAsRead(1);
      final result = await service.markAllAsRead();

      expect(calls, [
        'PATCH /notification/api/notifications/1/read',
        'PATCH /notification/api/notifications/read-all',
      ]);
      expect(notification.isRead, isTrue);
      expect(result.updatedCount, 3);
    });

    test('push token 등록과 비활성화 요청 body를 전송한다', () async {
      final calls = <String>[];
      final bodies = <Map<String, dynamic>>[];
      final service = NotificationService(
        authService: _FakeAuthService(),
        apiClient: ApiClient(
          client: MockClient((request) async {
            calls.add('${request.method} ${request.url.path}');
            bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
            if (request.method == 'POST') {
              return _jsonResponse({
                'id': 1,
                'platform': 'ANDROID',
                'deviceId': 'device-1',
                'active': true,
                'lastRegisteredAt': '2026-06-24T00:00:00Z',
              });
            }
            return _jsonResponse({});
          }),
        ),
      );

      final result = await service.registerPushToken(
        const PushTokenRegisterInput(
          token: 'fcm-token',
          platform: 'ANDROID',
          deviceId: 'device-1',
        ),
      );
      await service.deactivatePushToken('fcm-token');

      expect(calls, [
        'POST /notification/api/push-tokens',
        'DELETE /notification/api/push-tokens',
      ]);
      expect(bodies.first, {
        'token': 'fcm-token',
        'platform': 'ANDROID',
        'deviceId': 'device-1',
      });
      expect(bodies.last, {'token': 'fcm-token'});
      expect(result.active, isTrue);
    });
  });

  group('NotificationPushTokenLifecycle', () {
    test('저장된 access token으로 FCM token을 등록하고 삭제한다', () async {
      final service = _RecordingNotificationService();
      final lifecycle = NotificationPushTokenLifecycle(
        notificationService: service,
        tokenProvider: _FakeFcmTokenProvider('fcm-token'),
        deviceId: 'device-1',
      );

      await lifecycle.didSaveTokens('access-token');
      await lifecycle.willClearTokens('access-token');

      expect(service.registeredAccessTokens, ['access-token']);
      expect(service.registeredInputs.single.token, 'fcm-token');
      expect(service.registeredInputs.single.deviceId, 'device-1');
      expect(service.deactivatedTokens, ['fcm-token']);
      expect(service.deactivatedAccessTokens, ['access-token']);
    });
  });

  group('NotificationDeepLinkTarget', () {
    test('trip deeplink에서 tripId를 파싱한다', () {
      final target = NotificationDeepLinkTarget.parse(
        'togethertrip://trips/10/posts/20',
      );

      expect(target!.tripId, 10);
      expect(NotificationDeepLinkTarget.parse('https://example.com'), isNull);
    });
  });

  group('NotificationPushMessage', () {
    test('FCM data에서 notificationId와 deeplink를 파싱한다', () {
      final message = NotificationPushMessage.fromParts(
        data: {
          'notificationId': '100',
          'deeplink': 'togethertrip://trips/10/posts/20',
        },
        title: '제주 여행',
        body: '새 게시글이 올라왔습니다.',
      );

      expect(message.notificationId, 100);
      expect(message.deepLink, 'togethertrip://trips/10/posts/20');
      expect(message.title, '제주 여행');
      expect(message.body, '새 게시글이 올라왔습니다.');
    });

    test('deepLink camelCase key와 숫자 notificationId도 허용한다', () {
      final message = NotificationPushMessage.fromParts(
        data: {'notificationId': 100, 'deepLink': 'togethertrip://trips/10'},
      );

      expect(message.notificationId, 100);
      expect(message.deepLink, 'togethertrip://trips/10');
    });
  });
}

class _FakeAuthService extends AuthService {
  @override
  Future<T> runWithAccessToken<T>(
    Future<T> Function(String accessToken) request,
  ) {
    return request('access-token');
  }
}

class _FakeFcmTokenProvider implements FcmRegistrationTokenProvider {
  final String? token;
  final _controller = StreamController<String>();

  _FakeFcmTokenProvider(this.token);

  @override
  Future<String?> getToken() async => token;

  @override
  Stream<String> get onTokenRefresh => _controller.stream;
}

class _RecordingNotificationService extends NotificationService {
  final registeredInputs = <PushTokenRegisterInput>[];
  final registeredAccessTokens = <String>[];
  final deactivatedTokens = <String>[];
  final deactivatedAccessTokens = <String>[];

  @override
  Future<Map<String, dynamic>?> registerPushTokenWithAccessToken(
    PushTokenRegisterInput input,
    String accessToken,
  ) async {
    registeredInputs.add(input);
    registeredAccessTokens.add(accessToken);
    return {};
  }

  @override
  Future<Map<String, dynamic>?> deactivatePushTokenWithAccessToken(
    String token,
    String accessToken,
  ) async {
    deactivatedTokens.add(token);
    deactivatedAccessTokens.add(accessToken);
    return {};
  }
}
