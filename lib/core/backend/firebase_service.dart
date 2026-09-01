import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../config.dart';

/// Firebase (push notifications). Initialised ONLY in live mode — demo mode
/// never touches this class. Every step is guarded so a missing platform
/// config degrades silently instead of crashing the app.
class FirebaseService {
  FirebaseService._();
  static final instance = FirebaseService._();

  bool _initialized = false;
  bool get isInitialized => _initialized;
  String? fcmToken;

  Future<void> init() async {
    if (_initialized) return;
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: AppConfig.firebaseApiKey,
          authDomain: AppConfig.firebaseAuthDomain,
          projectId: AppConfig.firebaseProjectId,
          storageBucket: AppConfig.firebaseStorageBucket,
          messagingSenderId: AppConfig.firebaseMessagingSenderId,
          appId: AppConfig.firebaseAppId,
        ),
      );
      _initialized = true;
      debugPrint('[firebase] core initialised');
    } catch (e) {
      debugPrint('[firebase] init skipped: $e');
      return;
    }

    // Messaging is not supported on Windows/Linux — guard separately.
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      fcmToken = await messaging.getToken(
        vapidKey: kIsWeb ? AppConfig.firebaseVapidKey : null,
      );
      debugPrint('[firebase] fcm token acquired');
    } catch (e) {
      debugPrint('[firebase] messaging unavailable: $e');
    }
  }
}
