import 'package:flutter/material.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_text_styles.dart';

/// Three-dot typing indicator with a static fallback when animations are off.
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key, this.name});

  final String? name;

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final label = widget.name == null ? 'Typing' : '${widget.name} is typing';
    final color = AppColors.accentText(context);

    return Semantics(
      liveRegion: true,
      label: '$label…',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'typing',
            style: AppTextStyles.regularText.copyWith(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          if (reduceMotion)
            Text(
              '...',
              style: AppTextStyles.regularText.copyWith(
                color: color,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            for (var index = 0; index < 3; index++)
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final phase = (_controller.value + index / 3) % 1.0;
                  final opacity = 0.25 + 0.75 * (1 - (phase - 0.5).abs() * 2);
                  return Padding(
                    padding: const EdgeInsets.only(left: 1.5),
                    child: Opacity(
                      opacity: opacity.clamp(0.0, 1.0),
                      child: Text(
                        '.',
                        style: AppTextStyles.regularText.copyWith(
                          color: color,
                          fontSize: 12,
                          height: 1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                },
              ),
        ],
      ),
    );
  }
}
