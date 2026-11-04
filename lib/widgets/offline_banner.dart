import 'package:flutter/material.dart';
import 'package:palturo/services/connectivity_service.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_text_styles.dart';

/// A persistent strip that appears while the device has no connection.
/// It sits above app content but below the transient notification banner.
class OfflineBannerHost extends StatelessWidget {
  const OfflineBannerHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ConnectivityService.instance,
      builder: (context, _) {
        final online = ConnectivityService.instance.online;
        return Stack(
          fit: StackFit.expand,
          children: [
            child,
            if (!online)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Semantics(
                    liveRegion: true,
                    container: true,
                    label: 'You are offline. Changes will sync when you reconnect.',
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.elevatedSurface(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.dangerText(context).withValues(
                            alpha: 0.35,
                          ),
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
                                color: Theme.of(
                                  context,
                                ).colorScheme.secondary,
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
          ],
        );
      },
    );
  }
}
