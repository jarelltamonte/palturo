import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:palturo/services/haptics.dart';
import 'package:palturo/services/local_notification_service.dart';
import 'package:palturo/services/notification_service.dart';
import 'package:palturo/services/preferences_service.dart';
import 'package:palturo/services/sound_service.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_text_styles.dart';

class NotificationPreferencesPage extends StatelessWidget {
  const NotificationPreferencesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.secondary;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_new, size: 16, color: textColor),
        ),
        title: Text(
          'Notifications',
          style: AppTextStyles.headingText.copyWith(
            color: textColor,
            fontSize: 20,
          ),
        ),
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          PreferencesService.instance,
          LocalNotificationService.instance,
        ]),
        builder: (context, _) {
          final prefs = PreferencesService.instance;
          final master = prefs.notificationsEnabled;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            children: [
              _sectionLabel(context, 'Delivery'),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Notifications',
                  style: AppTextStyles.regularText.copyWith(color: textColor),
                ),
                subtitle: Text(
                  master
                      ? 'Badges and alerts are on.'
                      : 'Badges and alerts are off.',
                  style: AppTextStyles.regularText.copyWith(
                    color: AppColors.mutedText(context),
                    fontSize: 12,
                  ),
                ),
                activeTrackColor: AppColors.primary,
                activeThumbColor: AppColors.white,
                inactiveTrackColor: AppColors.switchOffTrack(context),
                inactiveThumbColor: AppColors.white,
                value: master,
                onChanged: (value) async {
                  Haptics.selection();
                  await prefs.setNotificationsEnabled(value);
                  if (value) {
                    final granted =
                        await LocalNotificationService.instance
                            .requestPermission();
                    if (!granted && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'System notifications are off. PalTuro will still show in-app banners.',
                          ),
                        ),
                      );
                    }
                  }
                  NotificationService.instance.refresh();
                  NotificationService.instance.notifyPreferenceChanged();
                },
              ),
              _permissionRow(context),
              const SizedBox(height: 8),
              _sectionLabel(context, 'Notify me about'),
              _categorySwitch(
                context,
                title: 'Messages',
                subtitle: 'New chat messages from your Pals.',
                value: prefs.messageNotificationsEnabled,
                enabled: master,
                onChanged: (value) async {
                  Haptics.selection();
                  await prefs.setMessageNotificationsEnabled(value);
                },
              ),
              _categorySwitch(
                context,
                title: 'Requests & matches',
                subtitle: 'New requests, accepted requests, and declines.',
                value: prefs.requestNotificationsEnabled,
                enabled: master,
                onChanged: (value) async {
                  Haptics.selection();
                  await prefs.setRequestNotificationsEnabled(value);
                },
              ),
              _categorySwitch(
                context,
                title: 'Activity updates',
                subtitle: 'Feedback reminders and skill moderation updates.',
                value: prefs.activityNotificationsEnabled,
                enabled: master,
                onChanged: (value) async {
                  Haptics.selection();
                  await prefs.setActivityNotificationsEnabled(value);
                },
              ),
              const SizedBox(height: 8),
              _sectionLabel(context, 'Message previews'),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Show message text',
                  style: AppTextStyles.regularText.copyWith(color: textColor),
                ),
                subtitle: Text(
                  master
                      ? 'When off, banners show only the sender.'
                      : 'Turn on notifications to use this.',
                  style: AppTextStyles.regularText.copyWith(
                    color: AppColors.mutedText(context),
                    fontSize: 12,
                  ),
                ),
                activeTrackColor: AppColors.primary,
                activeThumbColor: AppColors.white,
                inactiveTrackColor: AppColors.switchOffTrack(context),
                inactiveThumbColor: AppColors.white,
                value: prefs.messagePreviewsEnabled,
                onChanged:
                    master
                        ? (value) async {
                          Haptics.selection();
                          await prefs.setMessagePreviewsEnabled(value);
                        }
                        : null,
              ),
              _previewExample(
                context,
                enabled: master,
                showText: prefs.messagePreviewsEnabled,
              ),
              const SizedBox(height: 8),
              _sectionLabel(context, 'Sound & vibration'),
              _feedbackTile(
                context,
                title: 'Sound',
                subtitle: 'Short tones for messages and matches.',
                icon: Icons.volume_up_outlined,
                value: prefs.soundEnabled,
                onChanged: (value) async {
                  await prefs.setSoundEnabled(value);
                  if (value) await SoundService.instance.preview();
                },
                onPreview:
                    prefs.soundEnabled
                        ? () => SoundService.instance.preview()
                        : null,
              ),
              _feedbackTile(
                context,
                title: 'Vibration',
                subtitle: 'Haptic feedback for swipes, confirms, and matches.',
                icon: Icons.vibration,
                value: prefs.vibrationEnabled,
                onChanged: (value) async {
                  await prefs.setVibrationEnabled(value);
                  if (value) await Haptics.preview();
                },
                onPreview:
                    prefs.vibrationEnabled ? () => Haptics.preview() : null,
              ),
              const SizedBox(height: 8),
              _sectionLabel(context, 'Quiet hours'),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Quiet hours',
                  style: AppTextStyles.regularText.copyWith(color: textColor),
                ),
                subtitle: Text(
                  master
                      ? 'Silence notification sounds and haptics during this window. Banners still appear.'
                      : 'Turn on notifications to use this.',
                  style: AppTextStyles.regularText.copyWith(
                    color: AppColors.mutedText(context),
                    fontSize: 12,
                  ),
                ),
                activeTrackColor: AppColors.primary,
                activeThumbColor: AppColors.white,
                inactiveTrackColor: AppColors.switchOffTrack(context),
                inactiveThumbColor: AppColors.white,
                value: prefs.quietHoursEnabled,
                onChanged:
                    master
                        ? (value) async {
                          Haptics.selection();
                          await prefs.setQuietHoursEnabled(value);
                        }
                        : null,
              ),
              if (master && prefs.quietHoursEnabled) ...[
                _timeRow(
                  context,
                  label: 'From',
                  minutes: prefs.quietStartMinutes,
                  onChanged:
                      (minutes) => prefs.setQuietWindow(
                        startMinutes: minutes,
                        endMinutes: prefs.quietEndMinutes,
                      ),
                ),
                _timeRow(
                  context,
                  label: 'To',
                  minutes: prefs.quietEndMinutes,
                  onChanged:
                      (minutes) => prefs.setQuietWindow(
                        startMinutes: prefs.quietStartMinutes,
                        endMinutes: minutes,
                      ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'Changes apply immediately.',
                style: AppTextStyles.regularText.copyWith(
                  color: AppColors.mutedText(context),
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _permissionRow(BuildContext context) {
    final service = LocalNotificationService.instance;
    final status = service.permissionStatus;
    final String subtitle;
    final Widget? trailing;
    switch (status) {
      case NotificationPermissionStatus.granted:
        subtitle = 'On. PalTuro can show system alerts.';
        trailing = Icon(
          Icons.check_circle_outline,
          size: 18,
          color: AppColors.accentText(context),
        );
      case NotificationPermissionStatus.denied:
        subtitle = 'Blocked in device settings. In-app banners still work.';
        trailing = TextButton(
          onPressed: () async {
            await service.requestPermission();
          },
          child: const Text('Request'),
        );
      case NotificationPermissionStatus.unknown:
        subtitle = 'Not requested yet. In-app banners work without it.';
        trailing = TextButton(
          onPressed: () async {
            await service.requestPermission();
          },
          child: const Text('Allow'),
        );
      case NotificationPermissionStatus.unsupported:
        subtitle = 'System notifications are not available on this device.';
        trailing = null;
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        'System permission',
        style: AppTextStyles.regularText.copyWith(
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.regularText.copyWith(
          color: AppColors.mutedText(context),
          fontSize: 12,
        ),
      ),
      trailing: trailing,
    );
  }

  Widget _categorySwitch(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool value,
    required bool enabled,
    required ValueChanged<bool> onChanged,
  }) {
    final textColor = Theme.of(context).colorScheme.secondary;
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: AppTextStyles.regularText.copyWith(color: textColor),
      ),
      subtitle: Text(
        enabled ? subtitle : 'Turn on notifications to use this.',
        style: AppTextStyles.regularText.copyWith(
          color: AppColors.mutedText(context),
          fontSize: 12,
        ),
      ),
      activeTrackColor: AppColors.primary,
      activeThumbColor: AppColors.white,
      inactiveTrackColor: AppColors.switchOffTrack(context),
      inactiveThumbColor: AppColors.white,
      value: value,
      onChanged: enabled ? onChanged : null,
    );
  }

  Widget _feedbackTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    required VoidCallback? onPreview,
  }) {
    final textColor = Theme.of(context).colorScheme.secondary;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: AppTextStyles.regularText.copyWith(color: textColor),
      ),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.regularText.copyWith(
          color: AppColors.mutedText(context),
          fontSize: 12,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Preview $title',
            onPressed: onPreview,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: Icon(
              icon,
              size: 20,
              color:
                  onPreview == null
                      ? AppColors.mutedText(context)
                      : AppColors.accentText(context),
            ),
          ),
          Switch.adaptive(
            value: value,
            activeTrackColor: AppColors.primary,
            activeThumbColor: AppColors.white,
            inactiveTrackColor: AppColors.switchOffTrack(context),
            inactiveThumbColor: AppColors.white,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _timeRow(
    BuildContext context, {
    required String label,
    required int minutes,
    required ValueChanged<int> onChanged,
  }) {
    final time = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: AppTextStyles.regularText.copyWith(
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
      trailing: Text(
        time.format(context),
        style: AppTextStyles.boldText.copyWith(
          color: AppColors.accentText(context),
          fontSize: 14,
        ),
      ),
      onTap: () => _pickTime(context, time, onChanged),
    );
  }

  Future<void> _pickTime(
    BuildContext context,
    TimeOfDay initial,
    ValueChanged<int> onChanged,
  ) async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      var selected = initial;
      final result = await showModalBottomSheet<TimeOfDay>(
        context: context,
        backgroundColor: AppColors.elevatedSurface(context),
        builder:
            (sheetContext) => SafeArea(
              child: SizedBox(
                height: 320,
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pop(sheetContext, selected),
                        child: const Text('Done'),
                      ),
                    ),
                    Expanded(
                      child: CupertinoDatePicker(
                        mode: CupertinoDatePickerMode.time,
                        use24hFormat: MediaQuery.alwaysUse24HourFormatOf(
                          sheetContext,
                        ),
                        initialDateTime: DateTime(
                          2026,
                          1,
                          1,
                          initial.hour,
                          initial.minute,
                        ),
                        onDateTimeChanged: (value) {
                          selected = TimeOfDay(
                            hour: value.hour,
                            minute: value.minute,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
      );
      if (result != null) {
        onChanged(result.hour * 60 + result.minute);
      }
      return;
    }

    final result = await showTimePicker(context: context, initialTime: initial);
    if (result != null) {
      onChanged(result.hour * 60 + result.minute);
    }
  }

  Widget _previewExample(
    BuildContext context, {
    required bool enabled,
    required bool showText,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.mutedSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary.withValues(alpha: 0.2),
            child: Icon(
              Icons.person_outline,
              size: 16,
              color: AppColors.accentText(context),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Grace',
                  style: AppTextStyles.boldText.copyWith(
                    color: Theme.of(context).colorScheme.secondary,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  !enabled
                      ? 'Notifications are off'
                      : showText
                      ? 'Kumusta! Gusto mo bang mag-exchange ng adobo recipe?'
                      : 'New message',
                  style: AppTextStyles.regularText.copyWith(
                    color: AppColors.mutedText(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 2),
      child: Text(
        label,
        style: AppTextStyles.regularText.copyWith(
          color: AppColors.mutedText(context),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}
