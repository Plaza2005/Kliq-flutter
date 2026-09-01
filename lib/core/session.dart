import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

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

  /// Shared Google client. On web the rendered Google button drives this and
  /// completion arrives via [onCurrentUserChanged]; on mobile [googleSignIn]
  /// calls signIn() directly.
  final googleClient = GoogleSignIn(scopes: const ['email', 'profile']);
  bool _googleListening = false;

  /// Last Google error (surfaced on web, where sign-in completes async).
  String? googleError;

  /// Called on cold start: boot real backends and restore any stored session.
  Future<void> boot() async {
    _initGoogleListener();
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

  /// Web: the rendered Google button fires [onCurrentUserChanged]; complete the
  /// sign-in from there. On mobile this listener is harmless.
  void _initGoogleListener() {
    if (_googleListening) return;
    _googleListening = true;
    googleClient.onCurrentUserChanged.listen((account) async {
      if (account == null || isAuthed) return;
      try {
        await _completeGoogle(account);
      } catch (e) {
        googleError = e.toString();
        notifyListeners();
      }
    });
    if (kIsWeb) {
      // Primes the button / One Tap without forcing a popup.
      googleClient.signInSilently();
    }
  }

  /// Mobile: run the native Google picker. On web the rendered button handles
  /// this, so [googleSignIn] is a no-op there.
  Future<void> googleSignIn() async {
    if (kIsWeb) return;
    final account = await googleClient.signIn();
    if (account == null) return; // user cancelled the picker
    await _completeGoogle(account);
  }

  /// Exchange a Google account's ID token for our own JWT (find-or-create).
  Future<void> _completeGoogle(GoogleSignInAccount account) async {
    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null) {
      throw Exception('Google did not return an ID token');
    }
    final res = await Api.instance.post('/auth/google', body: {'idToken': idToken});
    await Api.instance.setToken(res['token'] as String?);
    user = (res['user'] as Map?)?.cast<String, dynamic>();
    googleError = null;
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
