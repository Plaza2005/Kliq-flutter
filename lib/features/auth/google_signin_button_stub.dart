import 'package:flutter/material.dart';

import 'auth_scaffold.dart';

/// Non-web: our styled "Continue with Google" button that runs the native picker.
Widget buildGoogleButton({required VoidCallback onPressed, required bool busy}) =>
    GoogleButton(onPressed: onPressed, busy: busy);
