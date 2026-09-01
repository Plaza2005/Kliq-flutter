import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

/// Web: Google's officially-rendered sign-in button, styled to match the app's
/// buttons (large, pill, filled, full-width). Clicking it runs the GIS flow,
/// which returns an ID token; `Session`'s onCurrentUserChanged listener finishes
/// the sign-in. [onPressed]/[busy] are unused on web.
Widget buildGoogleButton({required VoidCallback onPressed, required bool busy}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      // Google caps the rendered button at 400px wide; fill the auth card.
      final width = constraints.maxWidth.isFinite
          ? constraints.maxWidth.clamp(200.0, 400.0)
          : 320.0;
      return Center(
        child: web.renderButton(
          configuration: web.GSIButtonConfiguration(
            theme: web.GSIButtonTheme.filledBlue,
            size: web.GSIButtonSize.large,
            shape: web.GSIButtonShape.pill,
            text: web.GSIButtonText.continueWith,
            logoAlignment: web.GSIButtonLogoAlignment.left,
            minimumWidth: width,
          ),
        ),
      );
    },
  );
}
