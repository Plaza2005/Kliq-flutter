import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'app_mode.dart';
import 'backend/firebase_service.dart';
import 'backend/supabase_service.dart';
import 'demo/demo_store.dart';
import 'ws_service.dart';

/// Current signed-in user + auth actions. In demo mode the session is
/// automatically the seeded demo creator; in live mode it authenticates
/// against the Node API and boots Firebase/Supabase.
class Session extends ChangeNotifier {
  Session(this._mode);

  final AppModeController _mode;
  Map<String, dynamic>? user;
  bool _restoring = false;

  bool get isAuthed => user != null;
  bool get isRestoring => _restoring;
  String get userId => user?['id'] as String? ?? '';
  String get username => user?['username'] as String? ?? '';

  /// Called after a mode is chosen (or on cold start with a stored mode).
  Future<void> boot() async {
    if (_mode.isDemo) {
      user = DemoStore.instance.me;
      WsService.instance.connect();
      notifyListeners();
      return;
    }
    if (_mode.isLive) {
      // Real backends — initialised here and nowhere else.
      await FirebaseService.instance.init();
      await SupabaseService.instance.init();
      if (Api.instance.hasSession) {
        _restoring = true;
        notifyListeners();
        try {
          final me = await Api.instance.get('/auth/me');
          if (me is Map<String, dynamic>) {
            user = me;
            WsService.instance.connect();
            _registerFcmToken();
          }
        } catch (_) {
          await Api.instance.setToken(null);
        }
        _restoring = false;
        notifyListeners();
      }
    }
  }

  Future<void> login(String email, String password) async {
    final res = await Api.instance
        .post('/auth/login', body: {'email': email, 'password': password});
    await Api.instance.setToken(res['token'] as String?);
    user = (res['user'] as Map?)?.cast<String, dynamic>();
    WsService.instance.connect();
    _registerFcmToken();
    notifyListeners();
  }

  Future<void> register(
      String email, String password, String username) async {
    final res = await Api.instance.post('/auth/register',
        body: {'email': email, 'password': password, 'username': username});
    await Api.instance.setToken(res['token'] as String?);
    user = (res['user'] as Map?)?.cast<String, dynamic>();
    WsService.instance.connect();
    notifyListeners();
  }

  void _registerFcmToken() {
    final token = FirebaseService.instance.fcmToken;
    if (token != null) {
      Api.instance.post('/users/fcm-token', body: {'token': token}).catchError((_) => null);
    }
  }

  Future<void> logout() async {
    WsService.instance.disconnect();
    await Api.instance.setToken(null);
    user = null;
    notifyListeners();
  }

  /// Leave demo mode (or sign out) and return to the entry screen.
  Future<void> exitToEntry() async {
    await logout();
    await _mode.reset();
  }

  void updateUser(Map<String, dynamic> patch) {
    user = {...?user, ...patch};
    notifyListeners();
  }
}
