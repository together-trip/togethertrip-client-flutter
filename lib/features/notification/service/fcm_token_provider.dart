import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

abstract class FcmRegistrationTokenProvider {
  Future<String?> getToken();

  Stream<String> get onTokenRefresh;
}

class FirebaseMessagingTokenProvider implements FcmRegistrationTokenProvider {
  final FirebaseMessaging? _messaging;

  FirebaseMessagingTokenProvider({FirebaseMessaging? messaging})
    : _messaging = messaging;

  @override
  Future<String?> getToken() async {
    try {
      await _ensureFirebaseInitialized();
      final messaging = _messaging ?? FirebaseMessaging.instance;
      await messaging.requestPermission();
      return messaging.getToken();
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<String> get onTokenRefresh {
    try {
      return (_messaging ?? FirebaseMessaging.instance).onTokenRefresh
          .handleError((_) {});
    } catch (_) {
      return const Stream.empty();
    }
  }

  Future<void> _ensureFirebaseInitialized() async {
    if (Firebase.apps.isNotEmpty) return;
    await Firebase.initializeApp();
  }
}

String currentPushTokenPlatform() {
  if (kIsWeb) return 'WEB';

  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'ANDROID',
    TargetPlatform.iOS => 'IOS',
    TargetPlatform.macOS => 'IOS',
    _ => 'UNKNOWN',
  };
}
