import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:palturo/services/haptics.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_motion.dart';
import 'package:palturo/theme/app_text_styles.dart';

/// One-card decision deck. There is no preview layer: the next card pops in
/// only after the current card has clearly exited.
class SwipeDeck extends StatefulWidget {
  const SwipeDeck({
    super.key,
    required this.cardKey,
    required this.child,
    required this.onSwiped,
    this.rightLabel = 'Send request',
    this.leftLabel = 'Skip',
    this.enabled = true,
    this.hintEnabled = true,
    this.busy = false,
  });

  final String cardKey;
  final Widget child;
  final ValueChanged<bool> onSwiped;
  final String rightLabel;
  final String leftLabel;
  final bool enabled;
  final bool hintEnabled;
  final bool busy;

  @override
  State<SwipeDeck> createState() => SwipeDeckState();
}

class SwipeDeckState extends State<SwipeDeck> with TickerProviderStateMixin {
  static const double _threshold = 0.35;
  static const double _maxAngle = 0.22;

  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: AppMotion.exit,
  )..addListener(_tick);
  late final AnimationController _entry = AnimationController(
    vsync: this,
    duration: AppMotion.base,
    value: 1,
  )..addListener(_tick);
  late final AnimationController _hint = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..addListener(_tick);
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: AppMotion.micro,
  )..addListener(_settleTick);

  double _dx = 0;
  double _settleFrom = 0;
  double _width = 1;
  bool _exiting = false;
  bool _exitRight = true;
  bool _armed = false;
  int _hintCards = 0;
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scheduleHint();
    });
  }

  @override
  void didUpdateWidget(covariant SwipeDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cardKey != widget.cardKey) {
      _hintCards++;
      _exit.stop();
      _settle.stop();
      _cancelHint();
      _dx = 0;
      _exiting = false;
      _armed = false;
      _entry.forward(from: 0);
      _scheduleHint();
    }
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _exit.dispose();
    _entry.dispose();
    _hint.dispose();
    _settle.dispose();
    super.dispose();
  }

  void _tick() => setState(() {});

  void _settleTick() {
    final t = Curves.easeOutCubic.transform(_settle.value);
    setState(() => _dx = _settleFrom * (1 - t));
  }

  void _cancelHint() {
    _hintTimer?.cancel();
    _hint.stop();
    if (_hint.value != 0) _hint.value = 0;
  }

  void _scheduleHint() {
    _hintTimer?.cancel();
    if (!widget.hintEnabled || _hintCards >= 3) return;
    if (MediaQuery.disableAnimationsOf(context)) return;
    _hintTimer = Timer(const Duration(milliseconds: 1900), () {
      if (!mounted || _exiting || _dx.abs() > 2) return;
      _hint.forward(from: 0);
    });
  }

  void dismiss({bool right = false}) {
    if (!widget.enabled || _exiting) return;
    _cancelHint();
    _exitRight = right;
    _exiting = true;
    // A long drag can leave the card past the edge. Finish without waiting for
    // another exit animation, otherwise the card stays outside the viewport.
    if (_dx.abs() >= _width) {
      _finishExit();
      return;
    }
    _exit.forward(from: 0).whenComplete(_finishExit);
  }

  void _finishExit() {
    if (!mounted || !_exiting) return;
    setState(() {
      _exiting = false;
      _dx = (_exitRight ? 1 : -1) * _width * 1.2;
    });
    widget.onSwiped(_exitRight);
  }

  void reset() {
    _cancelHint();
    _exit.stop();
    _settle.stop();
    setState(() {
      _dx = 0;
      _exiting = false;
      _armed = false;
      _entry.forward(from: 0);
    });
    _scheduleHint();
  }

  void _onDragStart(DragStartDetails details) {
    if (!widget.enabled || _exiting) return;
    _cancelHint();
    _settle.stop();
    _exit.stop();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!widget.enabled || _exiting) return;
    final next = (_dx + details.delta.dx).clamp(
      -_width * 1.2,
      _width * 1.2,
    );
    setState(() => _dx = next);
    final nextArmed = _dx.abs() > _width * _threshold;
    if (nextArmed && !_armed) Haptics.impact();
    _armed = nextArmed;
  }

  void _onDragCancel() {
    if (!widget.enabled || _exiting) return;
    _settleFrom = _dx;
    _settle.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      setState(() {
        _dx = 0;
        _armed = false;
      });
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (!widget.enabled || _exiting) return;
    final velocity = details.velocity.pixelsPerSecond.dx;
    final flung = velocity.abs() > 800 && velocity.sign == _dx.sign;
    final passed = _dx.abs() > _width * _threshold || flung;
    if (!passed) {
      _settleFrom = _dx;
      _settle.forward(from: 0).whenComplete(() {
        if (!mounted) return;
        setState(() {
          _dx = 0;
          _armed = false;
        });
      });
      return;
    }
    dismiss(right: _dx > 0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _width = constraints.maxWidth;
        final entry = Curves.easeOutCubic.transform(_entry.value);
        final exit = Curves.easeOutCubic.transform(_exit.value);
        final hint = math.sin(_hint.value * math.pi);
        final displayDx =
            _dx + (_exiting ? (_exitRight ? 1 : -1) * _width * 1.2 * exit : 0);
        final angle = (displayDx / (_width * 0.7)) * _maxAngle;
        final drift = displayDx.abs() * 0.12;
        final hintDx = 6 * hint;
        final hintAngle = 0.012 * hint;
        final showSurface = displayDx.abs() > 4 || _exiting;
        final goingRight = displayDx >= 0;
        final foreground =
            goingRight ? AppColors.textSecondary : Colors.white;
        final surfaceColor =
            widget.busy
                ? AppColors.elevatedSurface(context)
                : goingRight
                ? AppColors.primary
                : AppColors.danger;

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: _onDragStart,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          onHorizontalDragCancel: _onDragCancel,
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              if (showSurface)
                Positioned.fill(
                  child: ExcludeSemantics(
                    child: Container(
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      alignment:
                          goingRight
                              ? Alignment.centerLeft
                              : Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child:
                          widget.busy
                              ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Sending request…',
                                      style: AppTextStyles.boldText.copyWith(
                                        color: AppColors.mutedText(context),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              : Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment:
                                    goingRight
                                        ? CrossAxisAlignment.start
                                        : CrossAxisAlignment.end,
                                children: [
                                  Icon(
                                    goingRight
                                        ? Icons.check_rounded
                                        : Icons.close_rounded,
                                    size: 56,
                                    color: foreground,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    goingRight
                                        ? widget.rightLabel
                                        : widget.leftLabel,
                                    style: AppTextStyles.boldText.copyWith(
                                      color: foreground,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                    ),
                  ),
                ),
              Transform.translate(
                offset: Offset(displayDx + hintDx, drift + (1 - entry) * 8),
                child: Transform.rotate(
                  angle: angle + hintAngle,
                  child: Transform.scale(
                    scale: 0.98 + (0.02 * entry),
                    child: IgnorePointer(
                      ignoring: _exiting,
                      child: widget.child,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
