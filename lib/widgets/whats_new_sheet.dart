import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:palturo/services/preferences_service.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_text_styles.dart';

const List<String> whatsNewBullets = [
  'Drafts, mute, mark unread, and in-chat search are here.',
  'Activity now has filters, day groups, and clear-read.',
  'New privacy controls for online status, typing, and receipts.',
];

/// Shows the one-time "what's new" sheet once per app version.
bool _whatsNewShowing = false;

Future<void> maybeShowWhatsNew(BuildContext context) async {
  if (_whatsNewShowing) return;
  String version;
  try {
    final info = await PackageInfo.fromPlatform();
    version = '${info.version}+${info.buildNumber}';
  } catch (_) {
    return;
  }
  final seen = await PreferencesService.instance.getString(
    'whats_new_seen_version',
  );
  if (seen == version || !context.mounted) return;

  _whatsNewShowing = true;
  await PreferencesService.instance.setString(
    'whats_new_seen_version',
    version,
  );
  try {
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.elevatedSurface(context),
      isScrollControlled: true,
      builder: (_) => const WhatsNewSheet(),
    );
  } finally {
    _whatsNewShowing = false;
  }
}

class WhatsNewSheet extends StatelessWidget {
  const WhatsNewSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.secondary;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "What's new",
                style: AppTextStyles.headingText.copyWith(
                  color: textColor,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 12),
              for (final bullet in whatsNewBullets)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppColors.accentText(context),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          bullet,
                          style: AppTextStyles.regularText.copyWith(
                            color: textColor,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
