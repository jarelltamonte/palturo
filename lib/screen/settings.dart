import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:palturo/main.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/services/activity_service.dart';
import 'package:palturo/services/match_api.dart';
import 'package:palturo/services/preferences_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:palturo/authentication/legal_dialogs.dart';
import 'package:palturo/screen/account/account_settings_page.dart';
import 'package:palturo/services/profile_service.dart';
import 'package:palturo/screen/action_dialogs.dart';
import 'package:palturo/screen/profile_data.dart';
import 'package:palturo/widgets/user_avatar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  bool _userChangedSettings = false;
  String _version = '…';
  ProfileData? _profile;
  String? _email;
  String? _authName;

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
    _loadAccountSummary();
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

  Future<void> _loadAccountSummary() async {
    final user = Supabase.instance.client.auth.currentUser;
    final first = user?.userMetadata?['first_name']?.toString().trim() ?? '';
    final last = user?.userMetadata?['last_name']?.toString().trim() ?? '';
    final authName = [first, last].where((part) => part.isNotEmpty).join(' ');
    if (mounted) {
      setState(() {
        _email = user?.email;
        _authName = authName.isEmpty ? null : authName;
      });
    }
    ProfileData? profile;
    try {
      profile = await ProfileService().getCurrentUserProfile();
    } catch (_) {
      // Identity is optional; the account page still exposes auth details.
    }
    if (!mounted) return;
    setState(() => _profile = profile);
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
    final Set<int> preferNot = {};
    final ScrollController surveyScroll = ScrollController();
    final GlobalKey commentFieldKey = GlobalKey();
    var submitting = false;

    _feedbackController.clear();

    showAdaptiveDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final textTheme = Theme.of(context).colorScheme.secondary;

            final bool isCommentStep =
                currentStep == _feedbackStatements.length;
            final int selectedRating = ratings[currentStep] ?? 0;
            final bool preferNotSelected = preferNot.contains(currentStep);
            final bool canAdvance =
                isCommentStep || selectedRating > 0 || preferNotSelected;

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
                        preferNot.remove(currentStep);
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

            var confirming = false;

            void previousStep() {
              if (submitting || currentStep == 0) return;
              if (surveyScroll.hasClients) surveyScroll.jumpTo(0);
              setDialogState(() => currentStep--);
            }

            Future<void> confirmCancel() async {
              if (submitting || confirming) return;
              confirming = true;
              final discard = await showConfirmDialog(
                dialogContext,
                title: 'Discard feedback?',
                message: 'Your answers will be lost.',
                confirmLabel: 'Discard',
                cancelLabel: 'Keep writing',
              );
              confirming = false;
              if (discard && dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
            }

            Widget guard(Widget child) {
              return PopScope(
                canPop: false,
                onPopInvokedWithResult: (didPop, _) {
                  if (!didPop) confirmCancel();
                },
                child: child,
              );
            }

            final Widget ratingContent = Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (currentStep > 0)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: submitting ? null : previousStep,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(44, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: Text(
                        'Back',
                        style: AppTextStyles.regularText.copyWith(
                          color: AppColors.accentText(context),
                        ),
                      ),
                    ),
                  ),
                Text(
                  'Step ${currentStep + 1} of ${_feedbackStatements.length + 1}',
                  style: AppTextStyles.regularText.copyWith(
                    color: AppColors.mutedText(context),
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
                    color: AppColors.mutedText(context),
                    fontSize: 12,
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
                  TextButton(
                    onPressed: () {
                      setDialogState(() {
                        if (preferNot.contains(currentStep)) {
                          preferNot.remove(currentStep);
                        } else {
                          preferNot.add(currentStep);
                          ratings.remove(currentStep);
                        }
                      });
                    },
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 44),
                    ),
                    child: Text(
                      'Prefer not to answer',
                      style: AppTextStyles.regularText.copyWith(
                        color:
                            preferNotSelected
                                ? AppColors.accentText(context)
                                : AppColors.mutedText(context),
                        decoration:
                            preferNotSelected
                                ? TextDecoration.underline
                                : TextDecoration.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 12),
                  TextField(
                    key: commentFieldKey,
                    controller: _feedbackController,
                    minLines: 1,
                    maxLines: 3,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 180),
                    onTap: () {
                      Future<void>.delayed(
                        const Duration(milliseconds: 250),
                        () {
                          final target = commentFieldKey.currentContext;
                          if (target != null && target.mounted) {
                            Scrollable.ensureVisible(
                              target,
                              alignment: 0.15,
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOut,
                            );
                          }
                        },
                      );
                    },
                    style: AppTextStyles.regularText.copyWith(
                      color: textTheme,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Write your feedback here...',
                      hintStyle: AppTextStyles.regularText.copyWith(
                        color: AppColors.mutedText(context),
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
                  const SizedBox(height: 8),
                  Text(
                    'Tell us about your experience or how we can improve.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.regularText.copyWith(
                      color: AppColors.mutedText(context),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            );

            Future<void> nextOrSubmit() async {
              if (submitting) return;
              if (!isCommentStep) {
                if (surveyScroll.hasClients) surveyScroll.jumpTo(0);
                setDialogState(() {
                  currentStep++;
                });
                return;
              }

              final Map<String, dynamic> feedbackData = {
                'ratings': {
                  for (int i = 0; i < _feedbackStatements.length; i++)
                    _feedbackStatements[i]:
                        preferNot.contains(i) ? null : ratings[i],
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

            if (isIOS && MediaQuery.viewInsetsOf(context).bottom == 0) {
              return guard(
                CupertinoTheme(
                  data: CupertinoThemeData(
                    brightness: Theme.of(context).brightness,
                  ),
                  child: CupertinoAlertDialog(
                    scrollController: surveyScroll,
                    title: Center(
                      child: Text(
                        'Send Feedback',
                        style: AppTextStyles.regularText.copyWith(
                          color: textTheme,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    content: Material(
                      color: Colors.transparent,
                      child: ratingContent,
                    ),
                    actions: [
                      CupertinoDialogAction(
                        onPressed: submitting ? null : confirmCancel,
                        child: Text(
                          'Cancel',
                          style: AppTextStyles.regularText.copyWith(
                            color:
                                submitting
                                    ? textTheme.withValues(alpha: 0.38)
                                    : textTheme,
                          ),
                        ),
                      ),
                      CupertinoDialogAction(
                        onPressed:
                            submitting || !canAdvance ? null : nextOrSubmit,
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
                  ),
                ),
              );
            }

            return guard(
              AlertDialog(
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
                  child: SingleChildScrollView(
                    controller: surveyScroll,
                    child: ratingContent,
                  ),
                ),
                actions: [
                  TextButton(
                    style: _noSplashButtonStyle,
                    onPressed: submitting ? null : confirmCancel,
                    child: Text(
                      'Cancel',
                      style: AppTextStyles.regularText.copyWith(
                        color:
                            submitting
                                ? textTheme.withValues(alpha: 0.38)
                                : textTheme,
                      ),
                    ),
                  ),
                  TextButton(
                    style: _noSplashButtonStyle,
                    onPressed: submitting || !canAdvance ? null : nextOrSubmit,
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
              ),
            );
          },
        );
      },
    ).whenComplete(surveyScroll.dispose);
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

  void _openAccount() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AccountSettingsPage()),
    );
    if (mounted) _loadAccountSummary();
  }

  void _showHelpDialog() {
    final textTheme = Theme.of(context).colorScheme.secondary;
    showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            backgroundColor: AppColors.elevatedSurface(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Text(
              'Help',
              style: AppTextStyles.boldText.copyWith(
                color: textTheme,
                fontSize: 18,
              ),
            ),
            content: Text(
              'Use Report a Problem to send an issue to the PalTuro team. For account access problems, include the email address on your account so the team can identify you.',
              style: AppTextStyles.regularText.copyWith(
                color: textTheme.withValues(alpha: 0.8),
                fontSize: 14,
                height: 1.45,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
                  'Close',
                  style: AppTextStyles.boldText.copyWith(
                    color: AppColors.accentText(context),
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 4),
    child: Semantics(
      header: true,
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.regularText.copyWith(
          color: AppColors.mutedText(context),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    ),
  );

  Widget _settingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? color,
  }) {
    final textTheme = Theme.of(context).colorScheme.secondary;
    final c = color ?? textTheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: c),
      title: Text(title, style: AppTextStyles.regularText.copyWith(color: c)),
      subtitle:
          subtitle == null
              ? null
              : Text(
                subtitle,
                style: AppTextStyles.regularText.copyWith(
                  color: AppColors.mutedText(context),
                  fontSize: 12,
                ),
              ),
      trailing: trailing ?? Icon(Icons.chevron_right, color: c),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;
    final adaptiveHeight =
        defaultTargetPlatform == TargetPlatform.iOS ? 44.0 : 56.0;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final accountName = _profile?.name ?? _authName ?? _email ?? 'Your account';
    final accountSubtitle =
        _profile == null
            ? (_email ?? 'Account & security')
            : (_email ?? 'Password, blocked users, privacy');

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        toolbarHeight: adaptiveHeight,
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        leadingWidth: 46,
        leading: Padding(
          padding: const EdgeInsets.only(left: 2),
          child: IconButton(
            tooltip: 'Back',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_ios_new, color: textTheme, size: 16),
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
        data: Theme.of(context).copyWith(splashFactory: NoSplash.splashFactory),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          children: [
            _sectionLabel('Preferences'),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Notifications',
                style: AppTextStyles.regularText.copyWith(color: textTheme),
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
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Sound',
                style: AppTextStyles.regularText.copyWith(color: textTheme),
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
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Vibration',
                style: AppTextStyles.regularText.copyWith(color: textTheme),
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
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Dark Mode',
                style: AppTextStyles.regularText.copyWith(color: textTheme),
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

            _sectionLabel('Account & security'),
            Semantics(
              container: true,
              button: true,
              label:
                  'Account and security, $accountName'
                  '${_email == null ? '' : ', $_email'}',
              excludeSemantics: true,
              onTap: _openAccount,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: UserAvatar(
                  name: accountName,
                  image:
                      _profile?.avatarUrl != null
                          ? NetworkImage(_profile!.avatarUrl!)
                          : null,
                  size: 44,
                ),
                title: Text(
                  accountName,
                  style: AppTextStyles.boldText.copyWith(color: textTheme),
                ),
                subtitle: Text(
                  accountSubtitle,
                  style: AppTextStyles.regularText.copyWith(
                    color: AppColors.mutedText(context),
                    fontSize: 12,
                  ),
                ),
                trailing: Icon(Icons.chevron_right, color: textTheme),
                onTap: _openAccount,
              ),
            ),

            _sectionLabel('Support'),
            _settingsTile(
              icon: Icons.feedback_outlined,
              title: 'Send feedback',
              onTap: _showFeedbackDialog,
            ),
            _settingsTile(
              icon: Icons.report_problem_outlined,
              title: 'Report a problem',
              onTap: _showReportDialog,
            ),
            _settingsTile(
              icon: Icons.help_outline,
              title: 'Help',
              onTap: _showHelpDialog,
            ),

            _sectionLabel('Legal & about'),
            _settingsTile(
              icon: Icons.description_outlined,
              title: 'Terms of Service',
              onTap: () => LegalDialogs.showTermsOfService(context),
            ),
            _settingsTile(
              icon: Icons.shield_outlined,
              title: 'Data Policy',
              onTap: () => LegalDialogs.showDataPolicy(context),
            ),
            _settingsTile(
              icon: Icons.cookie_outlined,
              title: 'Cookies Policy',
              onTap: () => LegalDialogs.showCookiesPolicy(context),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.info_outline, color: textTheme),
              title: Text(
                'Version',
                style: AppTextStyles.regularText.copyWith(color: textTheme),
              ),
              trailing: Text(
                _version,
                style: AppTextStyles.regularText.copyWith(
                  color: AppColors.mutedText(context),
                  fontSize: 12,
                ),
              ),
            ),
            SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom),
          ],
        ),
      ),
    );
  }
}
