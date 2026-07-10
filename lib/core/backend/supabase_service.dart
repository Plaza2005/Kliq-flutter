import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';

/// Supabase client. Initialised ONLY in live mode — demo mode never touches
/// this class. The primary data path goes through the Node API (which owns
/// the Supabase Postgres database via Prisma); this client is available for
/// direct storage/realtime features.
class SupabaseService {
  SupabaseService._();
  static final instance = SupabaseService._();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  SupabaseClient? get client =>
      _initialized ? Supabase.instance.client : null;

  Future<void> init() async {
    if (_initialized) return;
    if (AppConfig.supabaseAnonKey.isEmpty) {
      debugPrint('[supabase] no anon key provided '
          '(--dart-define=SUPABASE_ANON_KEY=...) — skipping init');
      return;
    }
    try {
      // ignore: deprecated_member_use
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: AppConfig.supabaseAnonKey,
      );
      _initialized = true;
      debugPrint('[supabase] initialised');
    } catch (e) {
      debugPrint('[supabase] init failed: $e');
    }
  }
}
