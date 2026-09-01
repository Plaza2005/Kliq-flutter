import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';

/// Rich caption: `#hashtags` navigate to /hashtag/:tag and `@mentions`
/// navigate to /user/:username. Optionally prefixes the author username
/// in bold, Instagram-style.
class CaptionText extends StatelessWidget {
  const CaptionText({
    super.key,
    required this.text,
    this.leadingUsername,
    this.maxLines,
    this.style,
  });

  final String text;
  final String? leadingUsername;
  final int? maxLines;
  final TextStyle? style;

  static final _token = RegExp(r'([#@][A-Za-z0-9_]+)');

  @override
  Widget build(BuildContext context) {
    final base = style ??
        const TextStyle(color: KliqColors.textPrimary, fontSize: 14, height: 1.35);
    final spans = <InlineSpan>[];

    if (leadingUsername != null && leadingUsername!.isNotEmpty) {
      spans.add(TextSpan(
        text: '$leadingUsername ',
        style: base.copyWith(fontWeight: FontWeight.w600),
        recognizer: TapGestureRecognizer()
          ..onTap = () => context.push('/user/$leadingUsername'),
      ));
    }

    var start = 0;
    for (final m in _token.allMatches(text)) {
      if (m.start > start) {
        spans.add(TextSpan(text: text.substring(start, m.start), style: base));
      }
      final token = m.group(0)!;
      final value = token.substring(1);
      spans.add(TextSpan(
        text: token,
        style: base.copyWith(color: KliqColors.cyan),
        recognizer: TapGestureRecognizer()
          ..onTap = () => context.push(
              token.startsWith('#') ? '/hashtag/$value' : '/user/$value'),
      ));
      start = m.end;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: base));
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : null,
    );
  }
}
