import 'package:flutter/material.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_motion.dart';
import 'package:video_player/video_player.dart';

bool isVideoUrl(String? url) {
  if (url == null) return false;
  return RegExp(
    r'\.(mp4|webm|mov|m4v)(\?|#|$)',
    caseSensitive: false,
  ).hasMatch(url);
}

class ShowcaseMedia extends StatefulWidget {
  final String url;
  final Widget fallback;
  final BoxFit fit;
  final VoidCallback? onOpenProfile;

  const ShowcaseMedia({
    super.key,
    required this.url,
    required this.fallback,
    this.fit = BoxFit.cover,
    this.onOpenProfile,
  });

  @override
  State<ShowcaseMedia> createState() => _ShowcaseMediaState();
}

class _ShowcaseMediaState extends State<ShowcaseMedia> {
  VideoPlayerController? _controller;
  bool _failed = false;
  bool _lastPlaying = false;
  bool _lastHasError = false;

  bool get _isVideo => isVideoUrl(widget.url);

  @override
  void initState() {
    super.initState();
    if (_isVideo) _openVideo();
  }

  @override
  void didUpdateWidget(covariant ShowcaseMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _disposeVideo();
      _failed = false;
      _lastPlaying = false;
      _lastHasError = false;
      if (_isVideo) _openVideo();
    }
  }

  Future<void> _openVideo() async {
    _failed = false;
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = controller;
    try {
      await controller.initialize();
      if (!identical(_controller, controller)) return;
      await controller.setLooping(true);
      await controller.setVolume(0);
      controller.addListener(_onControllerChanged);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted && identical(_controller, controller)) {
        setState(() => _failed = true);
      }
    }
  }

  void _onControllerChanged() {
    final controller = _controller;
    if (!mounted || controller == null) return;
    final hasError = controller.value.hasError;
    if (hasError) {
      if (!_lastHasError) {
        _lastHasError = true;
        setState(() {});
      }
      return;
    }
    if (!controller.value.isInitialized) return;
    final playing = controller.value.isPlaying;
    if (playing == _lastPlaying && hasError == _lastHasError) return;
    _lastPlaying = playing;
    _lastHasError = hasError;
    setState(() {});
  }

  void _disposeVideo() {
    final controller = _controller;
    _controller = null;
    controller?.removeListener(_onControllerChanged);
    controller?.dispose();
  }

  @override
  void dispose() {
    _disposeVideo();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVideo) {
      return Image.network(
        widget.url,
        fit: widget.fit,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: AppMotion.image,
            curve: Curves.easeOut,
            child: child,
          );
        },
        loadingBuilder:
            (context, child, progress) =>
                progress == null
                    ? child
                    : _MediaLoading(fallback: widget.fallback),
        errorBuilder: (_, __, ___) => widget.fallback,
      );
    }

    final controller = _controller;
    if (_failed || controller?.value.hasError == true) {
      return widget.fallback;
    }
    if (controller == null || !controller.value.isInitialized) {
      return _MediaLoading(fallback: widget.fallback);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: widget.fit,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: controller.value.size.width,
            height: controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        ),
        Positioned(
          top: 12,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Semantics(
                button: true,
                label:
                    controller.value.isPlaying ? 'Pause video' : 'Play video',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () async {
                    if (controller.value.isPlaying) {
                      await controller.pause();
                    } else {
                      await controller.play();
                    }
                    if (mounted) setState(() {});
                  },
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.62),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Icon(
                      controller.value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
              if (widget.onOpenProfile != null) ...[
                const SizedBox(width: 8),
                Semantics(
                  button: true,
                  label: 'View profile',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onOpenProfile,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.62),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                      child: const Icon(
                        Icons.person_outline_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MediaLoading extends StatelessWidget {
  final Widget fallback;

  const _MediaLoading({required this.fallback});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        fallback,
        Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}
