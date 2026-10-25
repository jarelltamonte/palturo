import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:palturo/main.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/services/activity_service.dart';
import 'package:palturo/services/auth_service.dart';
import 'package:palturo/services/match_api.dart';
import 'package:palturo/services/preferences_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:palturo/screen/account/change_password_page.dart';
import 'package:palturo/screen/account/delete_account_page.dart';
import 'package:palturo/screen/block_list.dart';

final ButtonStyle _noSplashButtonStyle = TextButton.styleFrom(
  splashFactory: NoSplash.splashFactory,
);

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _isLoggingOut = false;
  bool _userChangedSettings = false;
  String _version = '…';

  static const _notificationsKey = 'notifications_enabled';
  static const _soundKey = 'sound_enabled';
  static const _vibrationKey = 'vibration_enabled';

  final TextEditingController _reportController = TextEditingController();
  final TextEditingController _feedbackController = TextEditingController();

  static const List<String> _agreementLabels = [
    'Strongly agree',
    'Agree',
    'Disagree',
    'Strongly disagree',
  ];

  static const List<String> _feedbackStatements = [
    'Overall, my experience with PalTuro has been good.',
    'PalTuro is easy to use.',
    'I like how the app looks.',
    'I would recommend PalTuro to others.',
    'PalTuro makes it easier to find learners or mentors for Filipino cultural and practical skills.',
    'PalTuro helps me find people whose skills are relevant to what I want to learn or teach.',
    'PalTuro reduces the need to search across multiple online platforms or groups.',
    'The profiles, skill showcases, and recommendations make it easier to evaluate potential learners or mentors than general online platforms.',
    'PalTuro provides a more organized way to search for skill-exchange partners than keyword-based searching.',
    'PalTuro helps me consider relevant factors, such as availability, learning style, language preference, and skill interests, when looking for a learner or mentor.',
    'I would prefer using PalTuro over general social-media platforms when searching for a learner or mentor for Filipino cultural and practical skills.',
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      final build = info.buildNumber.trim();
      setState(() {
        _version = build.isEmpty ? info.version : '${info.version}+$build';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _version = 'unknown');
    }
  }

  Future<void> _loadSettings() async {
    final prefs = PreferencesService.instance;
    final notifications = await prefs.getBool(_notificationsKey);
    final sound = await prefs.getBool(_soundKey);
    final vibration = await prefs.getBool(_vibrationKey);
    if (!mounted || _userChangedSettings) return;
    setState(() {
      _notificationsEnabled = notifications ?? true;
      _soundEnabled = sound ?? true;
      _vibrationEnabled = vibration ?? true;
    });
  }

  void _setToggle(String key, bool value, VoidCallback apply) {
    _userChangedSettings = true;
    setState(apply);
    switch (key) {
      case _notificationsKey:
        PreferencesService.instance.setNotificationsEnabled(value);
        ActivityService.instance.refresh();
        ActivityService.instance.notifyPreferenceChanged();
        break;
      case _soundKey:
        PreferencesService.instance.setSoundEnabled(value);
        break;
      case _vibrationKey:
        PreferencesService.instance.setVibrationEnabled(value);
        break;
      default:
        PreferencesService.instance.setBool(key, value);
    }
  }

  String _deliveryError(Object error) {
    debugPrint('[Settings] delivery failed: $error');
    return "Couldn't send this right now. Please try again.";
  }

  @override
  void dispose() {
    _reportController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  void _showFeedbackDialog() {
    int currentStep = 0;
    final Map<int, int> ratings = {};
    var submitting = false;

    _feedbackController.clear();

    showAdaptiveDialog(
      context: context,
      builder: (dialogContext) {
        final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final textTheme = Theme.of(context).colorScheme.secondary;

            final bool isCommentStep =
                currentStep == _feedbackStatements.length;
            final int selectedRating = ratings[currentStep] ?? 0;
            final bool canAdvance = isCommentStep || selectedRating > 0;

            Widget buildOption(int index) {
              final int value = index + 1;
              final bool selected = selectedRating == value;
              final shape = RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color:
                      selected
                          ? AppColors.primary
                          : textTheme.withValues(alpha: 0.2),
                  width: selected ? 1.5 : 1,
                ),
              );

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color:
                      selected
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : Colors.transparent,
                  shape: shape,
                  child: InkWell(
                    customBorder: shape,
                    hoverColor: Colors.transparent,
                    focusColor: Colors.transparent,
                    splashFactory: NoSplash.splashFactory,
                    onTap: () {
                      setDialogState(() {
                        ratings[currentStep] = value;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _agreementLabels[index],
                              style: AppTextStyles.regularText.copyWith(
                                color: textTheme,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (selected)
                            Icon(
                              Icons.check_circle,
                              size: 18,
                              color: AppColors.accentText(context),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            final Widget ratingContent = Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Step ${currentStep + 1} of ${_feedbackStatements.length + 1}',
                  style: AppTextStyles.regularText.copyWith(
                    color: textTheme.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (currentStep + 1) / (_feedbackStatements.length + 1),
                    minHeight: 4,
                    backgroundColor: textTheme.withValues(alpha: 0.1),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Responses are stored securely with your PalTuro account.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.regularText.copyWith(
                    color: textTheme.withValues(alpha: 0.55),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 18),
                if (!isCommentStep) ...[
                  Text(
                    _feedbackStatements[currentStep],
                    textAlign: TextAlign.center,
                    style: AppTextStyles.regularText.copyWith(
                      color: textTheme,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  for (int i = 0; i < _agreementLabels.length; i++)
                    buildOption(i),
                ] else ...[
                  Text(
                    'Anything else you would like to share?',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.regularText.copyWith(
                      color: textTheme,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tell us about your experience or how we can improve.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.regularText.copyWith(
                      color: textTheme.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _feedbackController,
                    minLines: 4,
                    maxLines: 6,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    style: AppTextStyles.regularText.copyWith(
                      color: textTheme,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Write your feedback here...',
                      hintStyle: AppTextStyles.regularText.copyWith(
                        color: textTheme.withValues(alpha: 0.45),
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: AppColors.mutedSurface(context),
                      contentPadding: const EdgeInsets.all(14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: textTheme.withValues(alpha: 0.2),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: textTheme.withValues(alpha: 0.2),
                        ),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            );

            Future<void> nextOrSubmit() async {
              if (submitting) return;
              if (!isCommentStep) {
                setDialogState(() {
                  currentStep++;
                });
                return;
              }

              final Map<String, dynamic> feedbackData = {
                'ratings': {
                  for (int i = 0; i < _feedbackStatements.length; i++)
                    _feedbackStatements[i]: ratings[i],
                },
                'comment': _feedbackController.text.trim(),
                'submitted_at': DateTime.now().toIso8601String(),
              };

              submitting = true;
              setDialogState(() {});
              try {
                await MatchApi.submitAppFeedback(
                  kind: 'survey',
                  payload: feedbackData,
                );
              } catch (e) {
                if (!mounted) return;
                submitting = false;
                if (dialogContext.mounted) setDialogState(() {});
                ScaffoldMessenger.of(
                  this.context,
                ).showSnackBar(SnackBar(content: Text(_deliveryError(e))));
                return;
              }

              if (!mounted) return;
              if (dialogContext.mounted) Navigator.pop(dialogContext);

              ScaffoldMessenger.of(this.context).showSnackBar(
                const SnackBar(content: Text('Thank you for your feedback!')),
              );
            }

            if (isIOS) {
              return CupertinoAlertDialog(
                title: Center(
                  child: Text(
                    'Send Feedback',
                    style: AppTextStyles.regularText.copyWith(
                      color: textTheme,
                      fontSize: 18,
                    ),
                  ),
                ),
                content: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Material(
                    color: Colors.transparent,
                    child: ratingContent,
                  ),
                ),
                actions: [
                  CupertinoDialogAction(
                    onPressed: () {
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
                    onPressed:
                        submitting || (!isCommentStep && selectedRating == 0)
                            ? null
                            : nextOrSubmit,
                    child: Text(
                      submitting
                          ? 'Sending...'
                          : isCommentStep
                          ? 'Submit'
                          : 'Next',
                      style: AppTextStyles.regularText.copyWith(
                        color:
                            canAdvance
                                ? AppColors.accentText(context)
                                : textTheme.withValues(alpha: 0.38),
                      ),
                    ),
                  ),
                ],
              );
            }

            return AlertDialog(
              backgroundColor: AppColors.elevatedSurface(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Center(
                child: Text(
                  'Send Feedback',
                  style: AppTextStyles.regularText.copyWith(
                    color: textTheme,
                    fontSize: 18,
                  ),
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(child: ratingContent),
              ),
              actions: [
                TextButton(
                  style: _noSplashButtonStyle,
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: Text(
                    'Cancel',
                    style: AppTextStyles.regularText.copyWith(color: textTheme),
                  ),
                ),
                TextButton(
                  style: _noSplashButtonStyle,
                  onPressed:
                      submitting || (!isCommentStep && selectedRating == 0)
                          ? null
                          : nextOrSubmit,
                  child: Text(
                    submitting
                        ? 'Sending...'
                        : isCommentStep
                        ? 'Submit'
                        : 'Next',
                    style: AppTextStyles.regularText.copyWith(
                      color:
                          canAdvance
                              ? AppColors.accentText(context)
                              : textTheme.withValues(alpha: 0.38),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showReportDialog() async {
    final textTheme = Theme.of(context).colorScheme.secondary;
    final submitting = ValueNotifier<bool>(false);
    var dialogOpen = true;

    await showAdaptiveDialog(
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
            helperText: 'Stored securely with your account for review.',
            helperMaxLines: 2,
            hintStyle: AppTextStyles.regularText.copyWith(
              color: textTheme.withValues(alpha: 0.45),
              fontSize: 14,
            ),
            filled: true,
            fillColor: AppColors.mutedSurface(context),
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: textTheme.withValues(alpha: 0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: textTheme.withValues(alpha: 0.2)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        );

        Future<void> submitReport() async {
          if (submitting.value) return;
          final report = _reportController.text.trim();
          if (report.isEmpty) return;

          submitting.value = true;
          try {
            await MatchApi.submitAppFeedback(
              kind: 'problem',
              payload: {
                'text': report,
                'submitted_at': DateTime.now().toIso8601String(),
              },
            );
          } catch (e) {
            if (!dialogOpen) return;
            submitting.value = false;
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(_deliveryError(e))));
            return;
          }

          if (!mounted) return;
          _reportController.clear();
          if (dialogContext.mounted) Navigator.pop(dialogContext);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Thank you for your report.')),
          );
        }

        if (isIOS) {
          return CupertinoAlertDialog(
            title: Center(
              child: Text(
                'Report a Problem',
                style: AppTextStyles.regularText.copyWith(
                  color: textTheme,
                  fontSize: 18,
                ),
              ),
            ),
            content: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Material(color: Colors.transparent, child: textField),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () {
                  if (submitting.value) return;
                  _reportController.clear();
                  Navigator.pop(dialogContext);
                },
                child: Text(
                  'Cancel',
                  style: AppTextStyles.regularText.copyWith(color: textTheme),
                ),
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _reportController,
                builder: (context, value, _) {
                  final canSubmit = value.text.trim().isNotEmpty;
                  return ValueListenableBuilder<bool>(
                    valueListenable: submitting,
                    builder:
                        (context, busy, _) => CupertinoDialogAction(
                          onPressed: canSubmit && !busy ? submitReport : null,
                          child: Text(
                            busy ? 'Sending...' : 'Submit',
                            style: AppTextStyles.regularText.copyWith(
                              color:
                                  canSubmit && !busy
                                      ? AppColors.accentText(context)
                                      : textTheme.withValues(alpha: 0.38),
                            ),
                          ),
                        ),
                  );
                },
              ),
            ],
          );
        }

        return AlertDialog(
          backgroundColor: AppColors.elevatedSurface(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Center(
            child: Text(
              'Report a Problem',
              style: AppTextStyles.regularText.copyWith(
                color: textTheme,
                fontSize: 18,
              ),
            ),
          ),
          content: SizedBox(width: double.maxFinite, child: textField),
          actions: [
            TextButton(
              style: _noSplashButtonStyle,
              onPressed: () {
                if (submitting.value) return;
                _reportController.clear();
                Navigator.pop(dialogContext);
              },
              child: Text(
                'Cancel',
                style: AppTextStyles.regularText.copyWith(color: textTheme),
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _reportController,
              builder: (context, value, _) {
                final canSubmit = value.text.trim().isNotEmpty;
                return ValueListenableBuilder<bool>(
                  valueListenable: submitting,
                  builder:
                      (context, busy, _) => TextButton(
                        style: _noSplashButtonStyle,
                        onPressed: canSubmit && !busy ? submitReport : null,
                        child: Text(
                          busy ? 'Sending...' : 'Submit',
                          style: AppTextStyles.regularText.copyWith(
                            color:
                                canSubmit && !busy
                                    ? AppColors.accentText(context)
                                    : textTheme.withValues(alpha: 0.38),
                          ),
                        ),
                      ),
                );
              },
            ),
          ],
        );
      },
    );
    dialogOpen = false;
    submitting.dispose();
  }

  Future<void> _handleLogout() async {
    setState(() => _isLoggingOut = true);

    try {
      await AuthService().logout();

      if (mounted) {
        Navigator.of(
          context,
          rootNavigator: true,
        ).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoggingOut = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to log out: $e')));
      }
    }
  }

  void _showLogoutDialog() {
    final textTheme = Theme.of(context).colorScheme.secondary;

    showAdaptiveDialog(
      context: context,
      builder: (dialogContext) {
        final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

        final message = Text(
          'Are you sure you want to log out of PalTuro?',
          textAlign: TextAlign.center,
          style: AppTextStyles.regularText.copyWith(
            color: textTheme,
            fontSize: 14,
          ),
        );

        if (isIOS) {
          return CupertinoAlertDialog(
            title: Center(
              child: Text(
                'Log Out',
                style: AppTextStyles.regularText.copyWith(
                  color: textTheme,
                  fontSize: 18,
                ),
              ),
            ),
            content: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Material(color: Colors.transparent, child: message),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
                  'Cancel',
                  style: AppTextStyles.regularText.copyWith(color: textTheme),
                ),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _handleLogout();
                },
                child: Text(
                  'Log Out',
                  style: AppTextStyles.regularText.copyWith(
                    color: AppColors.accentText(context),
                  ),
                ),
              ),
            ],
          );
        }

        return AlertDialog(
          backgroundColor: AppColors.elevatedSurface(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Center(
            child: Text(
              'Log Out',
              style: AppTextStyles.regularText.copyWith(
                color: textTheme,
                fontSize: 18,
              ),
            ),
          ),
          content: SizedBox(width: double.maxFinite, child: message),
          actions: [
            TextButton(
              style: _noSplashButtonStyle,
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: AppTextStyles.regularText.copyWith(color: textTheme),
              ),
            ),
            TextButton(
              style: _noSplashButtonStyle,
              onPressed: () {
                Navigator.pop(dialogContext);
                _handleLogout();
              },
              child: Text(
                'Log Out',
                style: AppTextStyles.regularText.copyWith(
                  color: AppColors.accentText(context),
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
    final surfaceColor = AppColors.elevatedSurface(context);
    final adaptiveHeight =
        defaultTargetPlatform == TargetPlatform.iOS ? 44.0 : 56.0;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: !_isLoggingOut,
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              toolbarHeight: adaptiveHeight,
              backgroundColor: Colors.transparent,
              scrolledUnderElevation: 0,
              elevation: 0,
              automaticallyImplyLeading: false,
              leadingWidth: 56,
              leading: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: IconButton(
                  tooltip: 'Back',
                  onPressed:
                      _isLoggingOut ? null : () => Navigator.pop(context),
                  icon: Icon(
                    Icons.arrow_back_ios_new,
                    color: textTheme,
                    size: 16,
                  ),
                ),
              ),
              title: Text(
                'Settings',
                style: AppTextStyles.headingText.copyWith(
                  color: textTheme,
                  fontSize: 20,
                ),
              ),
            ),
            body: Theme(
              data: Theme.of(
                context,
              ).copyWith(splashFactory: NoSplash.splashFactory),
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 24.0,
                ),
                children: [
                  Text(
                    'Preferences',
                    style: AppTextStyles.regularText.copyWith(
                      color: AppColors.mutedText(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SwitchListTile.adaptive(
                    title: Text(
                      'Notifications',
                      style: AppTextStyles.regularText.copyWith(
                        color: textTheme,
                      ),
                    ),
                    subtitle: Text(
                      'Show activity badges for requests and messages.',
                      style: AppTextStyles.regularText.copyWith(
                        color: AppColors.mutedText(context),
                        fontSize: 12,
                      ),
                    ),
                    activeTrackColor: AppColors.primary,
                    activeThumbColor: AppColors.white,
                    inactiveTrackColor: AppColors.switchOffTrack(context),
                    inactiveThumbColor: AppColors.white,
                    value: _notificationsEnabled,
                    onChanged: (bool value) {
                      _setToggle(
                        _notificationsKey,
                        value,
                        () => _notificationsEnabled = value,
                      );
                    },
                  ),
                  SwitchListTile.adaptive(
                    title: Text(
                      'Sound',
                      style: AppTextStyles.regularText.copyWith(
                        color: textTheme,
                      ),
                    ),
                    subtitle: Text(
                      'Play confirmation sounds on launch and setup.',
                      style: AppTextStyles.regularText.copyWith(
                        color: AppColors.mutedText(context),
                        fontSize: 12,
                      ),
                    ),
                    activeTrackColor: AppColors.primary,
                    activeThumbColor: AppColors.white,
                    inactiveTrackColor: AppColors.switchOffTrack(context),
                    inactiveThumbColor: AppColors.white,
                    value: _soundEnabled,
                    onChanged: (bool value) {
                      _setToggle(_soundKey, value, () => _soundEnabled = value);
                    },
                  ),
                  SwitchListTile.adaptive(
                    title: Text(
                      'Vibration',
                      style: AppTextStyles.regularText.copyWith(
                        color: textTheme,
                      ),
                    ),
                    subtitle: Text(
                      'Use haptic feedback for swipes and confirms.',
                      style: AppTextStyles.regularText.copyWith(
                        color: AppColors.mutedText(context),
                        fontSize: 12,
                      ),
                    ),
                    activeTrackColor: AppColors.primary,
                    activeThumbColor: AppColors.white,
                    inactiveTrackColor: AppColors.switchOffTrack(context),
                    inactiveThumbColor: AppColors.white,
                    value: _vibrationEnabled,
                    onChanged: (bool value) {
                      _setToggle(
                        _vibrationKey,
                        value,
                        () => _vibrationEnabled = value,
                      );
                    },
                  ),
                  SwitchListTile.adaptive(
                    title: Text(
                      'Dark Mode',
                      style: AppTextStyles.regularText.copyWith(
                        color: textTheme,
                      ),
                    ),
                    subtitle: Text(
                      'Switch to the charcoal PalTuro theme.',
                      style: AppTextStyles.regularText.copyWith(
                        color: AppColors.mutedText(context),
                        fontSize: 12,
                      ),
                    ),
                    activeTrackColor: AppColors.primary,
                    activeThumbColor: AppColors.white,
                    inactiveTrackColor: AppColors.switchOffTrack(context),
                    inactiveThumbColor: AppColors.white,
                    value: isDarkMode,
                    onChanged: (bool value) {
                      MyApp.of(context).setThemeMode(value);
                    },
                  ),
                  Divider(height: 20, color: AppColors.border(context)),
                  ListTile(
                    leading: Icon(Icons.feedback_outlined, color: textTheme),
                    title: Text(
                      'Send Feedback',
                      style: AppTextStyles.regularText.copyWith(
                        color: textTheme,
                      ),
                    ),
                    trailing: Icon(Icons.chevron_right, color: textTheme),
                    onTap: _showFeedbackDialog,
                  ),
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
                    trailing: Icon(Icons.chevron_right, color: textTheme),
                    onTap: _showReportDialog,
                  ),
                  ListTile(
                    leading: Icon(Icons.block, color: textTheme),
                    title: Text(
                      'Blocked Users',
                      style: AppTextStyles.regularText.copyWith(
                        color: textTheme,
                      ),
                    ),
                    trailing: Icon(Icons.chevron_right, color: textTheme),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BlockListPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Divider(height: 20, color: AppColors.border(context)),
                  const SizedBox(height: 8),
                  Text(
                    'Account',
                    style: AppTextStyles.regularText.copyWith(
                      color: AppColors.mutedText(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: Icon(Icons.password_outlined, color: textTheme),
                    title: Text(
                      'Change password',
                      style: AppTextStyles.regularText.copyWith(
                        color: textTheme,
                      ),
                    ),
                    trailing: Icon(Icons.chevron_right, color: textTheme),
                    onTap:
                        _isLoggingOut
                            ? null
                            : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ChangePasswordPage(),
                              ),
                            ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      splashFactory: NoSplash.splashFactory,
                      onTap: _showLogoutDialog,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.logout_rounded, color: textTheme),
                            const SizedBox(width: 8),
                            Text(
                              'Log Out',
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
                  const SizedBox(height: 24),
                  Text(
                    'Danger zone',
                    style: AppTextStyles.regularText.copyWith(
                      color: AppColors.dangerText(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.danger.withValues(alpha: 0.18),
                      ),
                    ),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      leading: Icon(
                        Icons.delete_forever_outlined,
                        color: AppColors.dangerText(context),
                      ),
                      title: Text(
                        'Delete account',
                        style: AppTextStyles.regularText.copyWith(
                          color: AppColors.dangerText(context),
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        'Permanently remove your profile, Pals, and chats.',
                        style: AppTextStyles.regularText.copyWith(
                          color: AppColors.mutedText(context),
                          fontSize: 12,
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: AppColors.dangerText(context),
                      ),
                      onTap:
                          _isLoggingOut
                              ? null
                              : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const DeleteAccountPage(),
                                ),
                              ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Version $_version',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.regularText.copyWith(
                      color: AppColors.mutedText(context),
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom),
                ],
              ),
            ),
          ),
          if (_isLoggingOut)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
                alignment: Alignment.center,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 24,
                    ),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                          strokeWidth: 3.5,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Logging out...',
                          style: AppTextStyles.boldText.copyWith(
                            color: textTheme,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
