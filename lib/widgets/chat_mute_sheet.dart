import 'dart:async';

import 'package:flutter/material.dart';
import 'package:palturo/services/chat_state_service.dart';
import 'package:palturo/services/haptics.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/widgets/app_feedback.dart';

/// Shared mute chooser for the chat room and the chat list.
Future<void> showChatMuteSheet(
  BuildContext context,
  String connectionId,
) async {
  final muted = ChatStateService.instance.isMuted(connectionId);
  final choice = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.elevatedSurface(context),
    builder: (sheetContext) {
      final sheetText = Theme.of(sheetContext).colorScheme.secondary;
      Widget row(String value, String label, IconData icon) {
        return ListTile(
          leading: Icon(icon, size: 20, color: sheetText),
          title: Text(
            label,
            style: AppTextStyles.regularText.copyWith(color: sheetText),
          ),
          onTap: () => Navigator.pop(sheetContext, value),
        );
      }

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (muted)
              row('off', 'Unmute', Icons.notifications_active_outlined)
            else ...[
              row('1h', 'Mute for 1 hour', Icons.schedule),
              row('8h', 'Mute for 8 hours', Icons.schedule),
              row('1d', 'Mute for 1 day', Icons.schedule),
              row('1w', 'Mute for 1 week', Icons.schedule),
              row('always', 'Mute until I turn it back on', Icons.schedule),
            ],
          ],
        ),
      );
    },
  );
  if (choice == null || !context.mounted) return;

  DateTime? until;
  switch (choice) {
    case '1h':
      until = DateTime.now().add(const Duration(hours: 1));
    case '8h':
      until = DateTime.now().add(const Duration(hours: 8));
    case '1d':
      until = DateTime.now().add(const Duration(days: 1));
    case '1w':
      until = DateTime.now().add(const Duration(days: 7));
    case 'always':
      until = DateTime(9999);
    case 'off':
      until = null;
  }
  await ChatStateService.instance.setMuted(connectionId, until);
  if (!context.mounted) return;
  unawaited(Haptics.selection());
  showAppSnackBar(
    context,
    until == null ? 'Notifications unmuted' : 'Chat muted',
  );
}
