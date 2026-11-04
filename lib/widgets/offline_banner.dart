import 'package:flutter/material.dart';
import 'package:palturo/services/connectivity_service.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_text_styles.dart';

/// A persistent strip that appears while the device has no connection.
///
/// The strip is laid out above the app content (not over it), so app bars and
/// their buttons stay visible and tappable while offline.
class OfflineBannerHost extends StatelessWidget {
  const OfflineBannerHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ConnectivityService.instance,
      builder: (context, _) {
        final online = ConnectivityService.instance.online;
        if (online) return child;

        // The strip consumes the top inset itself; remove it from the app
        // below so screens do not add the status-bar gap twice.
        final content = MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: child,
        );

        return Column(
          children: [
            Semantics(
              liveRegion: true,
              container: true,
              label: 'You are offline. Changes will sync when you reconnect.',
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surface,
                child: SafeArea(
                  bottom: false,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.elevatedSurface(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.dangerText(
                          context,
                        ).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.wifi_off,
                          size: 18,
                          color: AppColors.dangerText(context),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'You are offline. Changes will sync when you reconnect.',
                            style: AppTextStyles.regularText.copyWith(
                              color: Theme.of(context).colorScheme.secondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: content),
          ],
        );
      },
    );
  }
}
