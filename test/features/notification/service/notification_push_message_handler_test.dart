import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togethertrip/features/notification/screen/notification_list_screen.dart';
import 'package:togethertrip/features/notification/service/notification_messaging_gateway.dart';
import 'package:togethertrip/features/notification/service/notification_push_message_handler.dart';
import 'package:togethertrip/features/notification/service/notification_service.dart';

void main() {
  group('NotificationPushMessageHandler', () {
    testWidgets('foreground 알림의 열기는 읽음 처리 후 deeplink route를 연다', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fixture = await _pumpHandler(tester);

      fixture.gateway.addForeground(_message(notificationId: 101));
      await tester.pumpAndSettle();

      expect(find.text('제주 여행\n새 게시글이 올라왔습니다.'), findsOneWidget);
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();

      expect(fixture.service.readIds, [101]);
      expect(fixture.openedTargets.single.tripId, 10);
      expect(find.text('notification-target'), findsOneWidget);
      Navigator.of(tester.element(find.text('notification-target'))).pop();
      await tester.pumpAndSettle();
    });

    testWidgets('opened stream 알림은 읽음 처리 후 deeplink route를 연다', (tester) async {
      final fixture = await _pumpHandler(tester);

      fixture.gateway.addOpened(_message(notificationId: 102));
      await tester.pumpAndSettle();

      expect(fixture.service.readIds, [102]);
      expect(fixture.openedTargets.single.tripId, 10);
      expect(find.text('notification-target'), findsOneWidget);
      Navigator.of(tester.element(find.text('notification-target'))).pop();
      await tester.pumpAndSettle();
    });

    testWidgets('initial message는 첫 frame 이후 deeplink route를 연다', (
      tester,
    ) async {
      final fixture = await _pumpHandler(
        tester,
        initialMessage: _message(notificationId: 103),
      );

      await tester.pumpAndSettle();

      expect(
        fixture.gateway.backgroundHandler,
        firebaseMessagingBackgroundHandler,
      );
      expect(fixture.service.readIds, [103]);
      expect(fixture.openedTargets.single.tripId, 10);
      expect(find.text('notification-target'), findsOneWidget);
      Navigator.of(tester.element(find.text('notification-target'))).pop();
      await tester.pumpAndSettle();
    });

    testWidgets('읽음 처리 실패가 deeplink route 이동을 막지 않는다', (tester) async {
      final fixture = await _pumpHandler(tester, failRead: true);

      fixture.gateway.addOpened(_message(notificationId: 104));
      await tester.pumpAndSettle();

      expect(fixture.service.readIds, [104]);
      expect(fixture.openedTargets.single.tripId, 10);
      expect(find.text('notification-target'), findsOneWidget);
      Navigator.of(tester.element(find.text('notification-target'))).pop();
      await tester.pumpAndSettle();
    });

    testWidgets('지원하지 않는 deeplink는 읽음 처리와 route 이동을 하지 않는다', (tester) async {
      final fixture = await _pumpHandler(tester);

      fixture.gateway.addOpened(
        _message(notificationId: 105, deepLink: 'https://example.com'),
      );
      await tester.pumpAndSettle();

      expect(fixture.service.readIds, isEmpty);
      expect(fixture.openedTargets, isEmpty);
      expect(find.text('home'), findsOneWidget);
    });

    test('dispose는 foreground와 opened message 구독을 모두 해제한다', () async {
      final gateway = _FakeNotificationMessagingGateway();
      final service = _RecordingNotificationService(failRead: false);
      final handler = NotificationPushMessageHandler(
        navigatorKey: GlobalKey<NavigatorState>(),
        messagingGateway: gateway,
        notificationService: service,
      );
      await handler.initialize();

      expect(gateway.hasForegroundListener, isTrue);
      expect(gateway.hasOpenedListener, isTrue);
      await handler.dispose();

      gateway.addForeground(_message(notificationId: 106));
      gateway.addOpened(_message(notificationId: 107));
      expect(gateway.hasForegroundListener, isFalse);
      expect(gateway.hasOpenedListener, isFalse);
      expect(service.readIds, isEmpty);
      await gateway.dispose();
    });
  });
}

Future<_HandlerFixture> _pumpHandler(
  WidgetTester tester, {
  RemoteMessage? initialMessage,
  bool failRead = false,
}) async {
  final navigatorKey = GlobalKey<NavigatorState>();
  final gateway = _FakeNotificationMessagingGateway(
    initialMessage: initialMessage,
  );
  final service = _RecordingNotificationService(failRead: failRead);
  final openedTargets = <NotificationDeepLinkTarget>[];
  final handler = NotificationPushMessageHandler(
    navigatorKey: navigatorKey,
    messagingGateway: gateway,
    notificationService: service,
    routeFactory: (target, navigator) {
      openedTargets.add(target);
      return MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('notification-target')),
      );
    },
  );

  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('home')),
    ),
  );
  await handler.initialize();

  final fixture = _HandlerFixture(
    handler: handler,
    gateway: gateway,
    service: service,
    openedTargets: openedTargets,
  );
  addTearDown(fixture.dispose);
  return fixture;
}

RemoteMessage _message({required int notificationId, String? deepLink}) {
  return RemoteMessage(
    messageId: 'message-$notificationId',
    data: {
      'notificationId': notificationId.toString(),
      'deeplink': deepLink ?? 'togethertrip://trips/10/posts/20',
    },
    notification: const RemoteNotification(
      title: '제주 여행',
      body: '새 게시글이 올라왔습니다.',
    ),
  );
}

class _HandlerFixture {
  const _HandlerFixture({
    required this.handler,
    required this.gateway,
    required this.service,
    required this.openedTargets,
  });

  final NotificationPushMessageHandler handler;
  final _FakeNotificationMessagingGateway gateway;
  final _RecordingNotificationService service;
  final List<NotificationDeepLinkTarget> openedTargets;

  Future<void> dispose() async {
    await handler.dispose();
    await gateway.dispose();
  }
}

class _FakeNotificationMessagingGateway
    implements NotificationMessagingGateway {
  _FakeNotificationMessagingGateway({this.initialMessage});

  final RemoteMessage? initialMessage;
  final _foregroundController = StreamController<RemoteMessage>.broadcast(
    sync: true,
  );
  final _openedController = StreamController<RemoteMessage>.broadcast(
    sync: true,
  );
  NotificationBackgroundMessageHandler? backgroundHandler;

  @override
  Stream<RemoteMessage> get foregroundMessages => _foregroundController.stream;

  @override
  Stream<RemoteMessage> get openedMessages => _openedController.stream;

  @override
  Future<RemoteMessage?> getInitialMessage() async => initialMessage;

  @override
  Future<void> initialize(
    NotificationBackgroundMessageHandler backgroundHandler,
  ) async {
    this.backgroundHandler = backgroundHandler;
  }

  void addForeground(RemoteMessage message) =>
      _foregroundController.add(message);

  void addOpened(RemoteMessage message) => _openedController.add(message);

  bool get hasForegroundListener => _foregroundController.hasListener;

  bool get hasOpenedListener => _openedController.hasListener;

  Future<void> dispose() async {
    await _foregroundController.close();
    await _openedController.close();
  }
}

class _RecordingNotificationService extends NotificationService {
  _RecordingNotificationService({required this.failRead});

  final bool failRead;
  final List<int> readIds = [];

  @override
  Future<AppNotification> markAsRead(int notificationId) async {
    readIds.add(notificationId);
    if (failRead) throw StateError('read failed');
    return AppNotification(
      id: notificationId,
      sourceEventId: 1,
      eventType: 'POST_CREATED',
      aggregateType: 'POST',
      aggregateId: 20,
      title: '제주 여행',
      body: '새 게시글이 올라왔습니다.',
      deeplink: 'togethertrip://trips/10/posts/20',
      occurredAt: null,
      readAt: '2026-08-05T00:00:00Z',
      createdAt: '2026-08-05T00:00:00Z',
    );
  }
}
