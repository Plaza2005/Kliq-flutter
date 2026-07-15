import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'sticker_library.dart';

/// Toggle button that flips an emoji panel open/closed. Factored out of
/// [KliqComposer] so other composers (e.g. comments_sheet.dart's
/// `CommentComposer`) can add emoji support without pulling in this file's
/// sticker/attach buttons too.
class EmojiToggleButton extends StatelessWidget {
  const EmojiToggleButton({
    super.key,
    required this.expanded,
    required this.onPressed,
  });

  final bool expanded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        expanded ? Icons.keyboard_outlined : Icons.tag_faces_outlined,
        color: KliqColors.textSecondary,
      ),
      onPressed: onPressed,
    );
  }
}

/// Collapsible emoji-picker panel. Wire [controller] to the same
/// `TextEditingController` as the composer's text field — `emoji_picker_flutter`
/// inserts the picked emoji directly at the cursor position for us.
class EmojiPanel extends StatelessWidget {
  const EmojiPanel({super.key, required this.controller, this.height = 260});

  final TextEditingController controller;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: EmojiPicker(
        textEditingController: controller,
        config: Config(height: height),
      ),
    );
  }
}

/// Shared message/comment composer bar: a text field plus an emoji-picker
/// toggle ([EmojiToggleButton] + [EmojiPanel]), a sticker-picker button
/// (backed by [StickerPickerGrid] from sticker_library.dart), and a generic
/// attach button. Deliberately a plain flexible `Row` — no fixed button
/// count is assumed anywhere — so a future mic/voice-record button can be
/// slotted in without a rewrite.
///
/// Callbacks are the entire public surface: callers don't need to know
/// anything about emoji-picker or sticker-library internals. A sticker is
/// sent as its own message (`onStickerSelected`) rather than inserted into
/// the text field.
class KliqComposer extends StatefulWidget {
  const KliqComposer({
    super.key,
    required this.onSend,
    this.onStickerSelected,
    this.onAttach,
    this.hintText = 'Message…',
    this.leading,
    this.sending = false,
  });

  /// Called with the trimmed text when the user taps send or submits the
  /// field with non-empty text. The composer clears its own field
  /// afterwards.
  final ValueChanged<String> onSend;

  /// Called with a sticker's media URL when one is picked from the sticker
  /// library. Null hides the sticker button.
  final ValueChanged<String>? onStickerSelected;

  /// Called when the attach button is tapped. Null hides the attach button.
  /// What "attach" does (pick + upload an image, etc.) is entirely up to the
  /// caller, keeping this widget agnostic of upload plumbing.
  final VoidCallback? onAttach;

  final String hintText;

  /// Optional leading widget shown before the action buttons (e.g. an
  /// avatar).
  final Widget? leading;

  /// Shows a spinner in place of the send icon while true.
  final bool sending;

  @override
  State<KliqComposer> createState() => _KliqComposerState();
}

class _KliqComposerState extends State<KliqComposer> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _showEmoji = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _toggleEmoji() {
    final opening = !_showEmoji;
    if (opening) {
      _focusNode.unfocus();
    } else {
      _focusNode.requestFocus();
    }
    setState(() => _showEmoji = opening);
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
  }

  Future<void> _pickSticker() async {
    final url = await showStickerPickerSheet(context);
    if (url != null) widget.onStickerSelected?.call(url);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (widget.leading != null) widget.leading!,
            if (widget.onAttach != null)
              IconButton(
                icon: const Icon(Icons.image_outlined,
                    color: KliqColors.textSecondary),
                onPressed: widget.onAttach,
              ),
            EmojiToggleButton(expanded: _showEmoji, onPressed: _toggleEmoji),
            if (widget.onStickerSelected != null)
              IconButton(
                icon: const Icon(Icons.emoji_emotions_outlined,
                    color: KliqColors.textSecondary),
                onPressed: _pickSticker,
              ),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(hintText: widget.hintText),
                onTap: () {
                  if (_showEmoji) setState(() => _showEmoji = false);
                },
                onSubmitted: (_) => _submit(),
              ),
            ),
            IconButton(
              icon: widget.sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send, color: KliqColors.cyan),
              onPressed: widget.sending ? null : _submit,
            ),
          ],
        ),
        if (_showEmoji) EmojiPanel(controller: _controller),
      ],
    );
  }
}
