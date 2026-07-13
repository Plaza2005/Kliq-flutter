import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/api_client.dart';

/// Shared media_kit-based video player (works on android/ios/web/desktop).
///
/// [controlsEnabled] false gives a chrome-less looping player (reels);
/// true gives full transport controls (KliqTube / KliqStream).
class KliqVideo extends StatefulWidget {
  const KliqVideo({
    super.key,
    required this.url,
    this.controlsEnabled = true,
    this.loop = false,
    this.autoPlay = true,
    this.muted = false,
    this.paused = false,
    this.fit = BoxFit.contain,
  });

  final String url;
  final bool controlsEnabled;
  final bool loop;
  final bool autoPlay;
  final bool muted;

  /// When true the player is paused; toggling it resumes/pauses. Used by reels
  /// to stop playback when the tab isn't visible or the user taps to pause.
  final bool paused;
  final BoxFit fit;

  @override
  State<KliqVideo> createState() => KliqVideoState();
}

class KliqVideoState extends State<KliqVideo> {
  late final Player player = Player();
  late final VideoController controller = VideoController(player);

  @override
  void initState() {
    super.initState();
    player.open(Media(Api.instance.mediaUrl(widget.url)),
        play: widget.autoPlay && !widget.paused);
    player.setPlaylistMode(
        widget.loop ? PlaylistMode.single : PlaylistMode.none);
    if (widget.muted) player.setVolume(0);
  }

  @override
  void didUpdateWidget(KliqVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.paused != oldWidget.paused) {
      widget.paused ? player.pause() : player.play();
    }
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  void togglePlay() {
    player.playOrPause();
  }

  @override
  Widget build(BuildContext context) {
    final video = Video(
      controller: controller,
      fit: widget.fit,
      controls: widget.controlsEnabled ? AdaptiveVideoControls : NoVideoControls,
    );
    return video;
  }
}
