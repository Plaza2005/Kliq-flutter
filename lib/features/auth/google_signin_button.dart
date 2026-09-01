import 'package:flutter/material.dart';

import 'google_signin_button_stub.dart'
    if (dart.library.js_interop) 'google_signin_button_web.dart' as impl;

/// A Google sign-in button that works on every platform.
///
/// - Mobile/desktop: renders our styled button and calls [onPressed] (which
///   should run `Session.googleSignIn()` — the native picker).
/// - Web: renders Google's official button (the only web flow that returns an
///   ID token); sign-in completes via `Session`'s onCurrentUserChanged listener,
///   and the router redirects to /home once authed.
Widget googleSignInButton({required VoidCallback onPressed, required bool busy}) =>
    impl.buildGoogleButton(onPressed: onPressed, busy: busy);
