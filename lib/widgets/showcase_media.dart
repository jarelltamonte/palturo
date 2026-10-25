import 'package:flutter/material.dart';
import 'package:palturo/theme/app_colors.dart';
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

  const ShowcaseMedia({
    super.key,
    required this.url,
    required this.fallback,
    this.fit = BoxFit.cover,
  });

  @override
  State<ShowcaseMedia> createState() => _ShowcaseMediaState();
}

class _ShowcaseMediaState extends State<ShowcaseMedia> {
  VideoPlayerController? _controller;
  bool _failed = false;

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
      if (_isVideo) _openVideo();
    }
  }

  Future<void> _openVideo() async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _disposeVideo() {
    final controller = _controller;
    _controller = null;
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
            duration: const Duration(milliseconds: 220),
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
    if (_failed) return widget.fallback;
    if (controller == null || !controller.value.isInitialized) {
      return _MediaLoading(fallback: widget.fallback);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        if (controller.value.isPlaying) {
          await controller.pause();
        } else {
          await controller.play();
        }
        if (mounted) setState(() {});
      },
      child: Stack(
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
          Center(
            child: AnimatedOpacity(
              opacity: controller.value.isPlaying ? 0 : 1,
              duration: const Duration(milliseconds: 160),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          ),
        ],
      ),
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
