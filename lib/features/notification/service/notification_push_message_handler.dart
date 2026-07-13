import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../trip/screen/trip_detail_screen.dart';
import '../../trip/screen/trip_recap_screen.dart';
import '../../trip/service/trip_service.dart';
import '../screen/notification_list_screen.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (_) {}
}

class NotificationPushMessageHandler {
  final GlobalKey<NavigatorState> _navigatorKey;
  final NotificationService _notificationService;
  final TripService _tripService;
  final FirebaseMessaging? _messaging;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  bool _initialized = false;

  NotificationPushMessageHandler({
    required GlobalKey<NavigatorState> navigatorKey,
    NotificationService? notificationService,
    TripService? tripService,
    FirebaseMessaging? messaging,
  }) : _navigatorKey = navigatorKey,
       _notificationService = notificationService ?? NotificationService(),
       _tripService = tripService ?? TripService(),
       _messaging = messaging;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      _foregroundSubscription = FirebaseMessaging.onMessage.listen(
        _handleForegroundMessage,
      );
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        _openFromRemoteMessage,
      );
      final initialMessage = await (_messaging ?? FirebaseMessaging.instance)
          .getInitialMessage();
      if (initialMessage != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _openFromRemoteMessage(initialMessage);
        });
      }
    } catch (_) {
      _initialized = false;
    }
  }

  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    _foregroundSubscription = null;
    _openedSubscription = null;
    _initialized = false;
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final pushMessage = NotificationPushMessage.fromRemoteMessage(message);
    final context = _navigatorKey.currentContext;
    if (context == null) return;

    final title = pushMessage.title ?? '새 알림이 도착했습니다';
    final body = pushMessage.body;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(body == null || body.isEmpty ? title : '$title\n$body'),
        action: pushMessage.deepLink == null
            ? null
            : SnackBarAction(
                label: '열기',
                onPressed: () => _openPushMessage(pushMessage),
              ),
      ),
    );
  }

  Future<void> _openFromRemoteMessage(RemoteMessage message) async {
    await _openPushMessage(NotificationPushMessage.fromRemoteMessage(message));
  }

  Future<void> _openPushMessage(NotificationPushMessage message) async {
    final target = NotificationDeepLinkTarget.parse(message.deepLink);
    if (target == null) return;

    final notificationId = message.notificationId;
    if (notificationId != null) {
      try {
        await _notificationService.markAsRead(notificationId);
      } on ApiException {
        // Push click navigation should still work even if read sync fails.
      } catch (_) {
        // Push click navigation should still work even if read sync fails.
      }
    }

    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;

    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => target.isRecap
            ? TripRecapScreen(
                tripId: target.tripId,
                tripRecapId: target.recapId,
                tripService: _tripService,
              )
            : TripDetailScreen(
                tripId: target.tripId,
                tripService: _tripService,
                onClose: (_) => navigator.pop(),
              ),
      ),
    );
  }
}

class NotificationPushMessage {
  final int? notificationId;
  final String? deepLink;
  final String? title;
  final String? body;

  const NotificationPushMessage({
    required this.notificationId,
    required this.deepLink,
    required this.title,
    required this.body,
  });

  factory NotificationPushMessage.fromRemoteMessage(RemoteMessage message) {
    return NotificationPushMessage.fromParts(
      data: message.data,
      title: message.notification?.title,
      body: message.notification?.body,
    );
  }

  factory NotificationPushMessage.fromParts({
    required Map<String, dynamic> data,
    String? title,
    String? body,
  }) {
    return NotificationPushMessage(
      notificationId: _parseInt(data['notificationId']),
      deepLink:
          _parseString(data['deeplink']) ?? _parseString(data['deepLink']),
      title: title,
      body: body,
    );
  }

  static int? _parseInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static String? _parseString(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return value.trim();
  }
}
