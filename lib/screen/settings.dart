import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:palturo/main.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_text_styles.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _darkModeEnabled = false;

  final TextEditingController _reportController = TextEditingController();

  @override
  void dispose() {
    _reportController.dispose();
    super.dispose();
  }

  void _showReportDialog() {
    final textTheme = Theme.of(context).colorScheme.secondary;

    showAdaptiveDialog(
      context: context,
      builder: (dialogContext) {
        final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

        final textField = TextField(
          controller: _reportController,
          minLines: 4,
          maxLines: 6,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          style: AppTextStyles.regularText.copyWith(
            color: textTheme,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: 'Tell us what went wrong...',
            hintStyle: AppTextStyles.regularText.copyWith(
              color: textTheme.withValues(alpha: .45),
              fontSize: 14,
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: textTheme.withValues(alpha: .2),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: textTheme.withValues(alpha: .2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
          ),
        );

        if (isIOS) {
          return CupertinoAlertDialog(
            title: Text(
              'Report a Problem',
              style: AppTextStyles.regularText.copyWith(
                color: textTheme,
                fontSize: 18,
              ),
            ),
            content: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Material(
                color: Colors.transparent,
                child: textField,
              ),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () {
                  _reportController.clear();
                  Navigator.pop(dialogContext);
                },
                child: Text(
                  'Cancel',
                  style: AppTextStyles.regularText.copyWith(
                    color: textTheme,
                  ),
                ),
              ),
              CupertinoDialogAction(
                onPressed: () {
                  final report = _reportController.text.trim();

                  if (report.isEmpty) {
                    return;
                  }

                  _reportController.clear();
                  Navigator.pop(dialogContext);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Thank you for your report.'),
                    ),
                  );
                },
                child: Text(
                  'Submit',
                  style: AppTextStyles.regularText.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          );
        }

        return AlertDialog(
          title: Text(
            'Report a Problem',
            style: AppTextStyles.regularText.copyWith(
              color: textTheme,
              fontSize: 18,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: textField,
          ),
          actions: [
            TextButton(
              onPressed: () {
                _reportController.clear();
                Navigator.pop(dialogContext);
              },
              child: Text(
                'Cancel',
                style: AppTextStyles.regularText.copyWith(
                  color: textTheme,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                final report = _reportController.text.trim();

                if (report.isEmpty) {
                  return;
                }

                _reportController.clear();
                Navigator.pop(dialogContext);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Thank you for your report.'),
                  ),
                );
              },
              child: Text(
                'Submit',
                style: AppTextStyles.regularText.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;
    final adaptiveHeight =
        defaultTargetPlatform == TargetPlatform.iOS ? 44.0 : 56.0;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: adaptiveHeight,
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: Icon(
            Icons.close,
            color: textTheme,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Settings',
          style: AppTextStyles.regularText.copyWith(
            color: textTheme,
            fontSize: 16,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 24.0,
        ),
        children: [
          SwitchListTile.adaptive(
            title: Text(
              'Notifications',
              style: AppTextStyles.regularText.copyWith(
                color: textTheme,
              ),
            ),
            activeTrackColor: AppColors.primary,
            value: _notificationsEnabled,
            onChanged: (bool value) {
              setState(() {
                _notificationsEnabled = value;
              });
            },
          ),
          SwitchListTile.adaptive(
            title: Text(
              'Sound',
              style: AppTextStyles.regularText.copyWith(
                color: textTheme,
              ),
            ),
            activeTrackColor: AppColors.primary,
            value: _soundEnabled,
            onChanged: (bool value) {
              setState(() {
                _soundEnabled = value;
              });
            },
          ),
          SwitchListTile.adaptive(
            title: Text(
              'Vibration',
              style: AppTextStyles.regularText.copyWith(
                color: textTheme,
              ),
            ),
            activeTrackColor: AppColors.primary,
            value: _vibrationEnabled,
            onChanged: (bool value) {
              setState(() {
                _vibrationEnabled = value;
              });
            },
          ),
          SwitchListTile.adaptive(
            title: Text(
              'Dark Mode',
              style: AppTextStyles.regularText.copyWith(
                color: textTheme,
              ),
            ),
            activeTrackColor: AppColors.primary,
            value: _darkModeEnabled,
            onChanged: (bool value) {
              setState(() {
                _darkModeEnabled = value;
              });
              MyApp.of(context).setThemeMode(value);
            },
          ),
          const Divider(height: 32),
          ListTile(
            leading: Icon(
              Icons.report_problem_outlined,
              color: textTheme,
            ),
            title: Text(
              'Report a Problem',
              style: AppTextStyles.regularText.copyWith(
                color: textTheme,
              ),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: textTheme,
            ),
            onTap: _showReportDialog,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {},
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16.0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.logout_rounded,
                          color: textTheme,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Logout',
                          style: AppTextStyles.regularText.copyWith(
                            color: textTheme,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {},
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16.0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.delete_forever,
                          color: Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Delete Account',
                          style: AppTextStyles.regularText.copyWith(
                            color: Colors.red,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Image.asset(
                isDarkMode
                    ? 'assets/images/vlogo_white.png'
                    : 'assets/images/vlogo_black.png',
                height: 60,
              ),
              const SizedBox(height: 8),
              Text(
                'Version 1.0.0',
                style: AppTextStyles.regularText.copyWith(
                  color: textTheme.withValues(alpha: .5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}