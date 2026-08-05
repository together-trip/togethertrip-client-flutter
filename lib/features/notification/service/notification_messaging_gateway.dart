import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

typedef NotificationBackgroundMessageHandler =
    Future<void> Function(RemoteMessage message);

abstract interface class NotificationMessagingGateway {
  Future<void> initialize(
    NotificationBackgroundMessageHandler backgroundHandler,
  );

  Stream<RemoteMessage> get foregroundMessages;

  Stream<RemoteMessage> get openedMessages;

  Future<RemoteMessage?> getInitialMessage();
}

class FirebaseNotificationMessagingGateway
    implements NotificationMessagingGateway {
  FirebaseNotificationMessagingGateway({FirebaseMessaging? messaging})
    : _messaging = messaging;

  final FirebaseMessaging? _messaging;

  @override
  Future<void> initialize(
    NotificationBackgroundMessageHandler backgroundHandler,
  ) async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    FirebaseMessaging.onBackgroundMessage(backgroundHandler);
  }

  @override
  Stream<RemoteMessage> get foregroundMessages => FirebaseMessaging.onMessage;

  @override
  Stream<RemoteMessage> get openedMessages =>
      FirebaseMessaging.onMessageOpenedApp;

  @override
  Future<RemoteMessage?> getInitialMessage() =>
      (_messaging ?? FirebaseMessaging.instance).getInitialMessage();
}
