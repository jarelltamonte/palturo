import 'dart:async';

import 'package:flutter/material.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_motion.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/theme/theme.dart';
import 'package:palturo/widgets/user_avatar.dart';

enum AppBannerVariant { standard, match }

/// One transient in-app banner. The controller owns timing and queueing; the
/// data object only describes content and actions.
class AppBannerData {
  const AppBannerData({
    required this.id,
    required this.title,
    required this.body,
    required this.icon,
    this.groupKey,
    this.avatarUrl,
    this.actorName,
    this.actionLabel,
    this.onTap,
    this.onAction,
    this.duration = const Duration(seconds: 4),
    this.variant = AppBannerVariant.standard,
  });

  final String id;
  final String title;
  final String body;
  final IconData icon;
  final String? groupKey;
  final String? avatarUrl;
  final String? actorName;
  final String? actionLabel;
  final VoidCallback? onTap;
  final VoidCallback? onAction;
  final Duration duration;
  final AppBannerVariant variant;

  bool get isMatch => variant == AppBannerVariant.match;
}

/// Global banner queue. Only one banner is visible at a time; a match banner
/// preempts a normal banner and the displaced item returns to the queue.
class AppBannerController {
  AppBannerController._();

  static final AppBannerController instance = AppBannerController._();

  final ValueNotifier<AppBannerData?> current = ValueNotifier<AppBannerData?>(
    null,
  );
  final List<AppBannerData> _queue = <AppBannerData>[];

  Timer? _timer;
  Timer? _transitionTimer;

  void show(AppBannerData data, {bool preempt = false}) {
    final visible = current.value;
    if (visible?.id == data.id) return;

    if (preempt) {
      if (visible != null) {
        _queue.insert(0, visible);
      }
      _present(data);
      return;
    }

    if (visible == null) {
      _present(data);
      return;
    }

    if (visible.groupKey != null && visible.groupKey == data.groupKey) {
      _present(data);
      return;
    }

    final queued = _queue.indexWhere(
      (item) => item.groupKey != null && item.groupKey == data.groupKey,
    );
    if (queued != -1) {
      _queue[queued] = data;
      return;
    }

    if (_queue.length >= 3) _queue.removeAt(0);
    _queue.add(data);
  }

  /// Updates a visible banner for the same conversation (message coalescing)
  /// or queues it if it is already waiting.
  void showOrUpdate(AppBannerData data) {
    if (current.value?.groupKey == data.groupKey) {
      _present(data);
      return;
    }
    final queued = _queue.indexWhere(
      (item) => item.groupKey != null && item.groupKey == data.groupKey,
    );
    if (queued != -1) {
      _queue[queued] = data;
      return;
    }
    show(data);
  }

  void dismiss([String? id]) {
    if (id != null && current.value?.id != id) return;
    _timer?.cancel();
    _timer = null;
    current.value = null;
    _transitionTimer?.cancel();
    _transitionTimer = Timer(const Duration(milliseconds: 180), _next);
  }

  void clear() {
    _timer?.cancel();
    _transitionTimer?.cancel();
    _timer = null;
    _queue.clear();
    current.value = null;
  }

  void _present(AppBannerData data) {
    _timer?.cancel();
    current.value = data;
    _timer = Timer(data.duration, () => dismiss(data.id));
  }

  void _next() {
    if (current.value != null || _queue.isEmpty) return;
    _present(_queue.removeAt(0));
  }
}

/// Hosts the banner above the app shell. Place this inside the responsive
/// shell so banners align with the 480px mobile surface on desktop/web.
class AppBannerHost extends StatelessWidget {
  const AppBannerHost({super.key, required this.child, this.isDark = false});

  final Widget child;

  /// Explicit because the host sits above the Navigator, where the inherited
  /// Theme can still be the root light theme on first frame.
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: isDark ? darkMode : lightMode,
      child: ValueListenableBuilder<AppBannerData?>(
        valueListenable: AppBannerController.instance.current,
        builder: (context, data, _) {
          final reduceMotion = MediaQuery.disableAnimationsOf(context);
          return Stack(
            fit: StackFit.expand,
            children: [
              child,
              if (data != null)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: AnimatedSwitcher(
                        duration: reduceMotion ? Duration.zero : AppMotion.base,
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, animation) {
                          if (reduceMotion) return child;
                          return SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, -0.18),
                              end: Offset.zero,
                            ).animate(animation),
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          );
                        },
                        child: _BannerCard(key: ValueKey(data.id), data: data),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({super.key, required this.data});

  final AppBannerData data;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.secondary;
    final accent = AppColors.accentText(context);
    final border =
        data.isMatch
            ? accent.withValues(alpha: 0.65)
            : AppColors.border(context);
    final semanticLabel =
        '${data.title}. ${data.body}'
        '${data.actionLabel == null ? '' : '. ${data.actionLabel}'}';

    return GestureDetector(
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) < -250) {
          AppBannerController.instance.dismiss(data.id);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.elevatedSurface(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border, width: data.isMatch ? 1.4 : 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  container: true,
                  label: semanticLabel,
                  button: data.onTap != null,
                  onTap: data.onTap,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap:
                        data.onTap == null
                            ? null
                            : () {
                              data.onTap?.call();
                              AppBannerController.instance.dismiss(data.id);
                            },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _BannerLeading(data: data),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  data.title,
                                  maxLines: data.isMatch ? 2 : 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.boldText.copyWith(
                                    color: textColor,
                                    fontSize: 13.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  data.body,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.regularText.copyWith(
                                    color: textColor.withValues(alpha: 0.72),
                                    fontSize: 12,
                                    height: 1.3,
                                  ),
                                ),
                                if (data.actionLabel != null) ...[
                                  const SizedBox(height: 4),
                                  SizedBox(
                                    height: 44,
                                    child: TextButton(
                                      onPressed: () {
                                        data.onAction?.call();
                                        AppBannerController.instance.dismiss(
                                          data.id,
                                        );
                                      },
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        minimumSize: const Size(44, 44),
                                        foregroundColor: accent,
                                      ),
                                      child: Text(
                                        data.actionLabel!,
                                        style: AppTextStyles.boldText.copyWith(
                                          color: accent,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Dismiss notification',
                onPressed: () => AppBannerController.instance.dismiss(data.id),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                icon: Icon(
                  Icons.close,
                  size: 18,
                  color: AppColors.mutedText(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BannerLeading extends StatelessWidget {
  const _BannerLeading({required this.data});

  final AppBannerData data;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = data.avatarUrl?.trim();
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return UserAvatar(
        name: data.actorName ?? data.title,
        image: NetworkImage(avatarUrl),
        size: 38,
      );
    }
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      child: Icon(
        data.isMatch ? Icons.celebration_outlined : data.icon,
        size: 19,
        color: AppColors.accentText(context),
      ),
    );
  }
}
