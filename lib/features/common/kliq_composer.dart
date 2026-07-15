import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

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
/// (backed by [StickerPickerGrid] from sticker_library.dart), a generic
/// attach button, and a hold-to-record mic button that swaps in for the
/// send button when the text field is empty. Deliberately a plain flexible
/// `Row` — no fixed button count is assumed anywhere — which is what let
/// the mic button slot in without a rewrite.
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
    this.onVoiceMessage,
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

  /// Called with the local file path of a finished voice recording (a
  /// `.m4a` file) when the user releases a press-and-hold on the mic
  /// button. Null hides the mic button. Recording start/stop is handled
  /// entirely inside this widget — the caller only receives the finished
  /// file to upload and send as its own message. Voice messages are
  /// mobile-only (hidden on web) since recording relies on a real
  /// filesystem path.
  final ValueChanged<String>? onVoiceMessage;

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

  final _recorder = AudioRecorder();
  bool _recording = false;

  @override
  void initState() {
    super.initState();
    // Rebuild so the trailing button swaps between mic (empty field) and
    // send (non-empty field), WhatsApp/Instagram-style.
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    _recorder.dispose();
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

  /// Starts capturing to a temp `.m4a` file. Voice messages only run on
  /// mobile/desktop (real filesystem) — the mic button itself is hidden on
  /// web, but this guards against ever calling it there too.
  Future<void> _startRecording() async {
    if (kIsWeb || _recording) return;
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) return;
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/kliq_voice_${DateTime.now().microsecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path);
      if (mounted) setState(() => _recording = true);
    } catch (_) {
      if (mounted) setState(() => _recording = false);
    }
  }

  /// Stops recording and hands the finished file path to [KliqComposer.onVoiceMessage].
  Future<void> _stopRecording() async {
    if (!_recording) return;
    if (mounted) setState(() => _recording = false);
    try {
      final path = await _recorder.stop();
      if (path != null) widget.onVoiceMessage?.call(path);
    } catch (_) {}
  }

  /// Aborts a recording without sending (e.g. the tap gesture is cancelled).
  Future<void> _cancelRecording() async {
    if (!_recording) return;
    if (mounted) setState(() => _recording = false);
    try {
      await _recorder.cancel();
    } catch (_) {}
  }

  Widget _trailingButton() {
    final showMic = widget.onVoiceMessage != null &&
        !kIsWeb &&
        _controller.text.trim().isEmpty;
    if (showMic) {
      return GestureDetector(
        onTapDown: (_) => _startRecording(),
        onTapUp: (_) => _stopRecording(),
        onTapCancel: _cancelRecording,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _recording
                ? Colors.redAccent.withValues(alpha: 0.15)
                : Colors.transparent,
          ),
          child: Icon(
            _recording ? Icons.mic : Icons.mic_none_outlined,
            color: _recording ? Colors.redAccent : KliqColors.textSecondary,
          ),
        ),
      );
    }
    return IconButton(
      icon: widget.sending
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.send, color: KliqColors.cyan),
      onPressed: widget.sending ? null : _submit,
    );
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
              child: _recording
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: const [
                          Icon(Icons.fiber_manual_record,
                              color: Colors.redAccent, size: 14),
                          SizedBox(width: 6),
                          Text('Recording… release to send',
                              style:
                                  TextStyle(color: KliqColors.textSecondary)),
                        ],
                      ),
                    )
                  : TextField(
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
            _trailingButton(),
          ],
        ),
        if (_showEmoji) EmojiPanel(controller: _controller),
      ],
    );
  }
}
