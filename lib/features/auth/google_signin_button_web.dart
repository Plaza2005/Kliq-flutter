import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

/// Web: Google's officially-rendered sign-in button. Clicking it runs the GIS
/// flow, which returns an ID token; `Session`'s onCurrentUserChanged listener
/// finishes the sign-in. [onPressed]/[busy] are unused on web.
Widget buildGoogleButton({required VoidCallback onPressed, required bool busy}) {
  return Align(child: web.renderButton());
}
