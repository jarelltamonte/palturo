import 'package:flutter/material.dart';
import 'package:palturo/theme/app_text_styles.dart';

/// One popup-menu row. The label wraps/ellipsizes inside the menu's 280px cap
/// so long actions survive 200% text.
class ChatMenuRow extends StatelessWidget {
  const ChatMenuRow({
    super.key,
    required this.label,
    required this.icon,
    this.color,
  });

  final String label;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Theme.of(context).colorScheme.secondary;
    return Row(
      children: [
        Icon(icon, color: tint, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            softWrap: true,
            style: AppTextStyles.regularText.copyWith(color: tint),
          ),
        ),
      ],
    );
  }
}
