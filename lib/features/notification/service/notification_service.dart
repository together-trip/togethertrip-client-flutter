import '../../../core/network/api_client.dart';
import '../../auth/service/auth_service.dart';

class NotificationService {
  final ApiClient _apiClient;
  final AuthService _authService;

  NotificationService({ApiClient? apiClient, AuthService? authService})
    : _apiClient = apiClient ?? ApiClient(),
      _authService = authService ?? AuthService();

  Future<List<AppNotification>> getNotifications({int limit = 100}) async {
    final data = await _authService.runWithAccessToken(
      (accessToken) => _apiClient.getList(
        '/notification/api/notifications',
        queryParameters: {'limit': limit.toString()},
        accessToken: accessToken,
      ),
    );

    return data
        .whereType<Map<String, dynamic>>()
        .map(AppNotification.fromJson)
        .toList();
  }

  Future<AppNotification> markAsRead(int notificationId) async {
    final data = await _authService.runWithAccessToken(
      (accessToken) => _apiClient.patch(
        '/notification/api/notifications/$notificationId/read',
        const {},
        accessToken: accessToken,
      ),
    );
    if (data == null) {
      throw const ApiException(statusCode: 500, message: '알림 읽음 응답이 비어 있습니다.');
    }

    return AppNotification.fromJson(data);
  }

  Future<MarkAllNotificationsReadResult> markAllAsRead() async {
    final data = await _authService.runWithAccessToken(
      (accessToken) => _apiClient.patch(
        '/notification/api/notifications/read-all',
        const {},
        accessToken: accessToken,
      ),
    );
    if (data == null) {
      throw const ApiException(
        statusCode: 500,
        message: '전체 알림 읽음 응답이 비어 있습니다.',
      );
    }

    return MarkAllNotificationsReadResult.fromJson(data);
  }

  Future<PushTokenRegistration> registerPushToken(
    PushTokenRegisterInput input,
  ) async {
    final data = await _authService.runWithAccessToken(
      (accessToken) => registerPushTokenWithAccessToken(input, accessToken),
    );
    if (data == null) {
      throw const ApiException(
        statusCode: 500,
        message: '푸시 토큰 등록 응답이 비어 있습니다.',
      );
    }

    return PushTokenRegistration.fromJson(data);
  }

  Future<Map<String, dynamic>?> registerPushTokenWithAccessToken(
    PushTokenRegisterInput input,
    String accessToken,
  ) {
    return _apiClient.post(
      '/notification/api/push-tokens',
      input.toJson(),
      accessToken: accessToken,
    );
  }

  Future<void> deactivatePushToken(String token) async {
    await _authService.runWithAccessToken(
      (accessToken) => deactivatePushTokenWithAccessToken(token, accessToken),
    );
  }

  Future<Map<String, dynamic>?> deactivatePushTokenWithAccessToken(
    String token,
    String accessToken,
  ) {
    return _apiClient.delete(
      '/notification/api/push-tokens',
      accessToken: accessToken,
      body: {'token': token},
    );
  }
}

class AppNotification {
  final int id;
  final int sourceEventId;
  final String eventType;
  final String aggregateType;
  final int aggregateId;
  final String title;
  final String body;
  final String? deeplink;
  final String? occurredAt;
  final String? readAt;
  final String createdAt;

  const AppNotification({
    required this.id,
    required this.sourceEventId,
    required this.eventType,
    required this.aggregateType,
    required this.aggregateId,
    required this.title,
    required this.body,
    required this.deeplink,
    required this.occurredAt,
    required this.readAt,
    required this.createdAt,
  });

  bool get isRead => readAt != null && readAt!.isNotEmpty;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: (json['id'] as num).toInt(),
      sourceEventId: (json['sourceEventId'] as num).toInt(),
      eventType: json['eventType'] as String,
      aggregateType: json['aggregateType'] as String,
      aggregateId: (json['aggregateId'] as num).toInt(),
      title: json['title'] as String,
      body: json['body'] as String,
      deeplink: json['deeplink'] as String?,
      occurredAt: json['occurredAt'] as String?,
      readAt: json['readAt'] as String?,
      createdAt: json['createdAt'] as String,
    );
  }

  AppNotification copyWith({String? readAt}) {
    return AppNotification(
      id: id,
      sourceEventId: sourceEventId,
      eventType: eventType,
      aggregateType: aggregateType,
      aggregateId: aggregateId,
      title: title,
      body: body,
      deeplink: deeplink,
      occurredAt: occurredAt,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
    );
  }
}

class MarkAllNotificationsReadResult {
  final int updatedCount;

  const MarkAllNotificationsReadResult({required this.updatedCount});

  factory MarkAllNotificationsReadResult.fromJson(Map<String, dynamic> json) {
    return MarkAllNotificationsReadResult(
      updatedCount: (json['updatedCount'] as num).toInt(),
    );
  }
}

class PushTokenRegisterInput {
  final String token;
  final String platform;
  final String? deviceId;

  const PushTokenRegisterInput({
    required this.token,
    required this.platform,
    this.deviceId,
  });

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'platform': platform,
      if (deviceId != null && deviceId!.isNotEmpty) 'deviceId': deviceId,
    };
  }
}

class PushTokenRegistration {
  final int id;
  final String platform;
  final String? deviceId;
  final bool active;
  final String lastRegisteredAt;

  const PushTokenRegistration({
    required this.id,
    required this.platform,
    required this.deviceId,
    required this.active,
    required this.lastRegisteredAt,
  });

  factory PushTokenRegistration.fromJson(Map<String, dynamic> json) {
    return PushTokenRegistration(
      id: (json['id'] as num).toInt(),
      platform: json['platform'] as String,
      deviceId: json['deviceId'] as String?,
      active: json['active'] as bool,
      lastRegisteredAt: json['lastRegisteredAt'] as String,
    );
  }
}
