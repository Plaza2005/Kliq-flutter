import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'backend/firebase_service.dart';
import 'backend/supabase_service.dart';
import 'ws_service.dart';

/// Current signed-in user + auth actions. Authenticates against the Node API
/// and boots Firebase/Supabase.
class Session extends ChangeNotifier {
  Session();

  Map<String, dynamic>? user;
  bool _restoring = false;

  bool get isAuthed => user != null;
  bool get isRestoring => _restoring;
  String get userId => user?['id'] as String? ?? '';
  String get username => user?['username'] as String? ?? '';

  /// Called on cold start: boot real backends and restore any stored session.
  Future<void> boot() async {
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

  Future<void> login(String identifier, String password) async {
    final res = await Api.instance.post('/auth/login',
        body: {'identifier': identifier, 'password': password});
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

  void updateUser(Map<String, dynamic> patch) {
    user = {...?user, ...patch};
    notifyListeners();
  }
}
