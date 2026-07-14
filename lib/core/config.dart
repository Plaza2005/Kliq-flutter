import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Link shared by the contacts-invite flow (SMS/email/WhatsApp/share sheet).
// TODO: set real store link
const kInviteUrl = 'https://kliq.app';

/// Central configuration for backends.
///
/// Values can be overridden at build time:
///   flutter run --dart-define=API_URL=http://192.168.1.50:4000
class AppConfig {
  AppConfig._();

  /// Node/Fastify API server (Prisma -> Supabase Postgres).
  static String get apiUrl {
    const fromEnv = String.fromEnvironment('API_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (kIsWeb) {
      // Talk to the API on whatever host the app was loaded from, so the same
      // web build works at http://localhost:8080 AND http://<lan-ip>:8080
      // (e.g. from a phone) without rebuilding. Falls back to localhost.
      final host = Uri.base.host.isEmpty ? 'localhost' : Uri.base.host;
      return 'http://$host:4000';
    }
    // Android emulator maps host loopback to 10.0.2.2.
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:4000';
    } catch (_) {}
    return 'http://localhost:4000';
  }

  static String get wsUrl =>
      '${apiUrl.replaceFirst('http', 'ws')}/ws';

  // ── Supabase ────────────────────────────────────────────────────────────
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://rrkfhfddwpaqwbfcqhtu.supabase.co',
  );

  /// Anon (public) key. Provide via --dart-define=SUPABASE_ANON_KEY=...
  /// When empty, Supabase init is skipped gracefully.
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  // ── Firebase (mirrors prot_3 web client config) ─────────────────────────
  static const firebaseApiKey = 'AIzaSyBXb-EELRMyGMCqE3MdsIqRHb-vfBFFlbc';
  static const firebaseAuthDomain = 'kliq-9a57f.firebaseapp.com';
  static const firebaseProjectId = 'kliq-9a57f';
  static const firebaseStorageBucket = 'kliq-9a57f.firebasestorage.app';
  static const firebaseMessagingSenderId = '241767590512';
  static const firebaseAppId = '1:241767590512:web:d700ce1876e879e4cc62b5';
  static const firebaseVapidKey =
      'BEQLB5InzW4UIPQLu2nMnFJMhrwyTJN_q6-UYix5IqNtA-CgS1S_JHeVe1v-tRIIgwjJMl8SEJ7j_nCMXMCWotU';
}
