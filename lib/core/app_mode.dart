import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppMode {
  /// Fully offline: Firebase and Supabase are never initialised, the API
  /// client answers from the in-memory demo backend. The whole app flows
  /// end-to-end with seeded data.
  demo,

  /// Real backends: Node API server, Supabase, Firebase push.
  live,
}

/// Chosen on the entry screen ("Try Demo" vs "Sign In"). Persisted so the
/// app reopens in the same mode.
class AppModeController extends ChangeNotifier {
  AppModeController._(this._prefs, this._mode);

  static const _key = 'kliq.appMode';
  final SharedPreferences _prefs;
  AppMode? _mode;

  static Future<AppModeController> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    final mode = switch (stored) {
      'demo' => AppMode.demo,
      'live' => AppMode.live,
      _ => null,
    };
    return AppModeController._(prefs, mode);
  }

  /// Null until the user picks a mode on the entry screen.
  AppMode? get mode => _mode;
  bool get isDemo => _mode == AppMode.demo;
  bool get isLive => _mode == AppMode.live;
  bool get isChosen => _mode != null;

  Future<void> choose(AppMode mode) async {
    _mode = mode;
    await _prefs.setString(_key, mode.name);
    notifyListeners();
  }

  /// Back to the entry screen (e.g. "Exit demo" in settings).
  Future<void> reset() async {
    _mode = null;
    await _prefs.remove(_key);
    notifyListeners();
  }
}
