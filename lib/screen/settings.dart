import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:palturo/main.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/screen/block_list.dart';

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

  final TextEditingController _reportController =
      TextEditingController();

  final TextEditingController _feedbackController =
      TextEditingController();

  final List<String> _feedbackQuestions = [
    'How would you rate your experience with PalTuro?',
    'How easy was PalTuro to use?',
    'How would you rate the app design?',
    'How satisfied are you with the features?',
    'How well did PalTuro’s AI recommendations match your interests and preferences?',
    'How likely are you to recommend PalTuro?',
  ];

  @override
  void dispose() {
    _reportController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  void _showFeedbackDialog() {
    int currentStep = 0;
    final Map<int, int> ratings = {};

    _feedbackController.clear();

    showAdaptiveDialog(
      context: context,
      builder: (dialogContext) {
        final isIOS =
            defaultTargetPlatform == TargetPlatform.iOS;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final textTheme =
                Theme.of(context).colorScheme.secondary;

            final bool isCommentStep =
                currentStep == _feedbackQuestions.length;

            final int selectedRating =
                ratings[currentStep] ?? 0;

            final Widget ratingContent = Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Step ${currentStep + 1} of ${_feedbackQuestions.length + 1}',
                  style: AppTextStyles.regularText.copyWith(
                    color: textTheme.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (currentStep + 1) / (_feedbackQuestions.length + 1),
                    minHeight: 4,
                    backgroundColor:
                        textTheme.withValues(alpha: 0.1),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (!isCommentStep) ...[
                  Text(
                    _feedbackQuestions[currentStep],
                    textAlign: TextAlign.center,
                    style:
                        AppTextStyles.regularText.copyWith(
                      color: textTheme,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      5,
                      (index) {
                        final int rating = index + 1;

                        return IconButton(
                          onPressed: () {
                            setDialogState(() {
                              ratings[currentStep] = rating;
                            });
                          },
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
                          constraints:
                              const BoxConstraints(
                            minWidth: 44,
                            minHeight: 44,
                          ),
                          icon: Icon(
                            rating <= selectedRating
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            size: 34,
                            color: AppColors.primary,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selectedRating == 0
                        ? 'Tap a star to rate'
                        : '$selectedRating out of 5',
                    style:
                        AppTextStyles.regularText.copyWith(
                      color:
                          textTheme.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ] else ...[
                  Text(
                    'Anything else you would like to share?',
                    textAlign: TextAlign.center,
                    style:
                        AppTextStyles.regularText.copyWith(
                      color: textTheme,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tell us about your experience or how we can improve.',
                    textAlign: TextAlign.center,
                    style:
                        AppTextStyles.regularText.copyWith(
                      color:
                          textTheme.withValues(alpha: 0.5),
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
                    style:
                        AppTextStyles.regularText.copyWith(
                      color: textTheme,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          'Write your feedback here...',
                      hintStyle:
                          AppTextStyles.regularText.copyWith(
                        color: textTheme.withValues(
                          alpha: 0.45,
                        ),
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: Theme.of(context)
                          .colorScheme
                          .surface,
                      contentPadding:
                          const EdgeInsets.all(14),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: textTheme.withValues(
                            alpha: 0.2,
                          ),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: textTheme.withValues(
                            alpha: 0.2,
                          ),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(12),
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

            void nextOrSubmit() {
              if (!isCommentStep) {
                setDialogState(() {
                  currentStep++;
                });
                return;
              }

              final Map<String, dynamic> feedbackData = {
                'ratings': {
                  for (int i = 0;
                      i < _feedbackQuestions.length;
                      i++)
                    _feedbackQuestions[i]: ratings[i],
                },
                'comment':
                    _feedbackController.text.trim(),
              };

              debugPrint(
                'Feedback submitted: $feedbackData',
              );

              Navigator.pop(dialogContext);

              ScaffoldMessenger.of(this.context)
                  .showSnackBar(
                const SnackBar(
                  content: Text(
                    'Thank you for your feedback!',
                  ),
                ),
              );
            }

            if (isIOS) {
              return CupertinoAlertDialog(
                title: Center(child: Text(
                  'Submit a Feedback',
                  style:
                      AppTextStyles.regularText.copyWith(
                    color: textTheme,
                    fontSize: 18,
                  ),
                )),
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
                      style:
                          AppTextStyles.regularText.copyWith(
                        color: textTheme,
                      ),
                    ),
                  ),
                  CupertinoDialogAction(
                    onPressed:
                        !isCommentStep &&
                                selectedRating == 0
                            ? null
                            : nextOrSubmit,
                    child: Text(
                      isCommentStep ? 'Submit' : 'Next',
                      style:
                          AppTextStyles.regularText.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              );
            }

            return AlertDialog(
              backgroundColor:
                  Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Center(child: Text(
                'Submit a Feedback',
                style:
                    AppTextStyles.regularText.copyWith(
                  color: textTheme,
                  fontSize: 18,
                ),
              )),
              content: SizedBox(
                width: double.maxFinite,
                child: ratingContent,
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: Text(
                    'Cancel',
                    style:
                        AppTextStyles.regularText.copyWith(
                      color: textTheme,
                    ),
                  ),
                ),
                TextButton(
                  onPressed:
                      !isCommentStep &&
                              selectedRating == 0
                          ? null
                          : nextOrSubmit,
                  child: Text(
                    isCommentStep ? 'Submit' : 'Next',
                    style:
                        AppTextStyles.regularText.copyWith(
                      color: AppColors.primary,
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

  void _showReportDialog() {
    final textTheme =
        Theme.of(context).colorScheme.secondary;

    showAdaptiveDialog(
      context: context,
      builder: (dialogContext) {
        final isIOS =
            defaultTargetPlatform == TargetPlatform.iOS;

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
            hintStyle:
                AppTextStyles.regularText.copyWith(
              color: textTheme.withValues(alpha: 0.45),
              fontSize: 14,
            ),
            filled: true,
            fillColor:
                Theme.of(context).colorScheme.surface,
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color:
                    textTheme.withValues(alpha: 0.2),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color:
                    textTheme.withValues(alpha: 0.2),
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

        void submitReport() {
          final report = _reportController.text.trim();

          if (report.isEmpty) {
            return;
          }

          _reportController.clear();
          Navigator.pop(dialogContext);

          ScaffoldMessenger.of(context)
              .showSnackBar(
            const SnackBar(
              content: Text(
                'Thank you for your report.',
              ),
            ),
          );
        }

        if (isIOS) {
          return CupertinoAlertDialog(
            title: Center(child: Text(
              'Report a Problem',
              style:
                  AppTextStyles.regularText.copyWith(
                color: textTheme,
                fontSize: 18,
              ),
            )),
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
                  style:
                      AppTextStyles.regularText.copyWith(
                    color: textTheme,
                  ),
                ),
              ),
              CupertinoDialogAction(
                onPressed: submitReport,
                child: Text(
                  'Submit',
                  style:
                      AppTextStyles.regularText.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          );
        }

        return AlertDialog(
          backgroundColor:
              Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Center(child: Text(
            'Report a Problem',
            style: AppTextStyles.regularText.copyWith(
              color: textTheme,
              fontSize: 18,
            ),
          )),
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
                style:
                    AppTextStyles.regularText.copyWith(
                  color: textTheme,
                ),
              ),
            ),
            TextButton(
              onPressed: submitReport,
              child: Text(
                'Submit',
                style:
                    AppTextStyles.regularText.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showLogoutDialog() {
    final textTheme =
        Theme.of(context).colorScheme.secondary;

    showAdaptiveDialog(
      context: context,
      builder: (dialogContext) {
        final isIOS =
            defaultTargetPlatform == TargetPlatform.iOS;

        final message = Text(
          'Are you sure you want to log out of PalTuro?',
          textAlign: TextAlign.center,
          style: AppTextStyles.regularText.copyWith(
            color: textTheme,
            fontSize: 14,
          ),
        );

        void confirmLogout() {
          Navigator.pop(dialogContext);

          debugPrint('User logged out');

          ScaffoldMessenger.of(context)
              .showSnackBar(
            const SnackBar(
              content: Text('You have been logged out.'),
            ),
          );
        }

        if (isIOS) {
          return CupertinoAlertDialog(
            title: Center(child: Text(
              'Logout',
              style:
                  AppTextStyles.regularText.copyWith(
                color: textTheme,
                fontSize: 18,
              ),
            )),
            content: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Material(
                color: Colors.transparent,
                child: message,
              ),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: Text(
                  'Cancel',
                  style:
                      AppTextStyles.regularText.copyWith(
                    color: textTheme,
                  ),
                ),
              ),
              CupertinoDialogAction(
                onPressed: confirmLogout,
                child: Text(
                  'Logout',
                  style:
                      AppTextStyles.regularText.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          );
        }

        return AlertDialog(
          backgroundColor:
              Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Center(child: Text(
            'Logout',
            style: AppTextStyles.regularText.copyWith(
              color: textTheme,
              fontSize: 18,
            ),
          )),
          content: SizedBox(
            width: double.maxFinite,
            child: message,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: Text(
                'Cancel',
                style:
                    AppTextStyles.regularText.copyWith(
                  color: textTheme,
                ),
              ),
            ),
            TextButton(
              onPressed: confirmLogout,
              child: Text(
                'Logout',
                style:
                    AppTextStyles.regularText.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteAccountDialog() {
    showAdaptiveDialog(
      context: context,
      builder: (dialogContext) {
        return _DeleteAccountDialog(
          onConfirm: () {
            Navigator.pop(dialogContext);

            debugPrint('Account deleted');

            ScaffoldMessenger.of(context)
                .showSnackBar(
              const SnackBar(
                content: Text(
                  'Your account has been deleted.',
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme =
        Theme.of(context).colorScheme.secondary;

    final adaptiveHeight =
        defaultTargetPlatform == TargetPlatform.iOS
            ? 44.0
            : 56.0;

    final isDarkMode =
        Theme.of(context).brightness == Brightness.dark;

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
          horizontal: 16,
          vertical: 24,
        ),
        children: [
          SwitchListTile.adaptive(
            title: Text(
              'Notifications',
              style:
                  AppTextStyles.regularText.copyWith(
                color: textTheme,
              ),
            ),
            activeTrackColor: AppColors.primary,
            activeThumbColor: AppColors.white,
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() {
                _notificationsEnabled = value;
              });
            },
          ),
          SwitchListTile.adaptive(
            title: Text(
              'Sound',
              style:
                  AppTextStyles.regularText.copyWith(
                color: textTheme,
              ),
            ),
            activeTrackColor: AppColors.primary,
            activeThumbColor: AppColors.white,
            value: _soundEnabled,
            onChanged: (value) {
              setState(() {
                _soundEnabled = value;
              });
            },
          ),
          SwitchListTile.adaptive(
            title: Text(
              'Vibration',
              style:
                  AppTextStyles.regularText.copyWith(
                color: textTheme,
              ),
            ),
            activeTrackColor: AppColors.primary,
            activeThumbColor: AppColors.white,
            value: _vibrationEnabled,
            onChanged: (value) {
              setState(() {
                _vibrationEnabled = value;
              });
            },
          ),
          SwitchListTile.adaptive(
            title: Text(
              'Dark Mode',
              style:
                  AppTextStyles.regularText.copyWith(
                color: textTheme,
              ),
            ),
            activeTrackColor: AppColors.primary,
            activeThumbColor: AppColors.white,
            value: _darkModeEnabled,
            onChanged: (value) {
              setState(() {
                _darkModeEnabled = value;
              });

              MyApp.of(context).setThemeMode(value);
            },
          ),
          Divider(
            height: 20,
            color: AppColors.black.withValues(alpha: 0.2),
          ),
          ListTile(
            leading: Icon(
              Icons.feedback_outlined,
              color: textTheme,
            ),
            title: Text(
              'Submit a Feedback',
              style:
                  AppTextStyles.regularText.copyWith(
                color: textTheme,
              ),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: textTheme,
            ),
            onTap: _showFeedbackDialog,
          ),
          ListTile(
            leading: Icon(
              Icons.report_problem_outlined,
              color: textTheme,
            ),
            title: Text(
              'Report a Problem',
              style:
                  AppTextStyles.regularText.copyWith(
                color: textTheme,
              ),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: textTheme,
            ),
            onTap: _showReportDialog,
          ),
          ListTile(
            leading: Icon(
              Icons.block,
              color: textTheme,
            ),
            title: Text(
              'Blocked Users',
              style:
                  AppTextStyles.regularText.copyWith(
                color: textTheme,
              ),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: textTheme,
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const BlockListPage(),
                ),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(
                    alpha: 0.1,
                  ),
                  borderRadius:
                      BorderRadius.circular(24),
                ),
                child: InkWell(
                  borderRadius:
                      BorderRadius.circular(12),
                  onTap: _showLogoutDialog,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(
                      vertical: 16,
                    ),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.logout_rounded,
                          color: textTheme,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Logout',
                          style: AppTextStyles.regularText
                              .copyWith(
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
                  color:
                      Colors.red.withValues(alpha: 0.1),
                  borderRadius:
                      BorderRadius.circular(24),
                ),
                child: InkWell(
                  borderRadius:
                      BorderRadius.circular(12),
                  onTap: _showDeleteAccountDialog,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(
                      vertical: 16,
                    ),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.delete_forever,
                          color: Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Delete Account',
                          style: AppTextStyles.regularText
                              .copyWith(
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
                style:
                    AppTextStyles.regularText.copyWith(
                  color: textTheme.withValues(alpha: 0.5),
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

class _DeleteAccountDialog extends StatefulWidget {
  final VoidCallback onConfirm;

  const _DeleteAccountDialog({required this.onConfirm});

  @override
  State<_DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState
    extends State<_DeleteAccountDialog> {
  static const String _keyword = 'DELETE';

  final TextEditingController _controller =
      TextEditingController();

  bool get _canConfirm =>
      _controller.text.trim().toUpperCase() == _keyword;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme =
        Theme.of(context).colorScheme.secondary;
    final isIOS =
        defaultTargetPlatform == TargetPlatform.iOS;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'This permanently deletes your profile, matches, and chats. This can’t be undone.',
          textAlign: TextAlign.center,
          style: AppTextStyles.regularText.copyWith(
            color: textTheme,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Type $_keyword to confirm',
          textAlign: TextAlign.center,
          style: AppTextStyles.regularText.copyWith(
            color: textTheme.withValues(alpha: 0.5),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
          style: AppTextStyles.regularText.copyWith(
            color: textTheme,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: _keyword,
            hintStyle:
                AppTextStyles.regularText.copyWith(
              color: textTheme.withValues(alpha: 0.45),
              fontSize: 14,
            ),
            filled: true,
            fillColor:
                Theme.of(context).colorScheme.surface,
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
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Colors.red,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );

    if (isIOS) {
      return CupertinoAlertDialog(
        title: Center(child: Text(
          'Delete Account',
          style: AppTextStyles.regularText.copyWith(
            color: textTheme,
            fontSize: 18,
          ),
        )),
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Material(
            color: Colors.transparent,
            child: content,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(
              'Cancel',
              style: AppTextStyles.regularText.copyWith(
                color: textTheme,
              ),
            ),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: _canConfirm ? widget.onConfirm : null,
            child: Text(
              'I agree',
              style: AppTextStyles.regularText.copyWith(
                color: Colors.red.withValues(
                  alpha: _canConfirm ? 1 : 0.4,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return AlertDialog(
      backgroundColor:
          Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      title: Center(child: Text(
        'Delete Account',
        style: AppTextStyles.regularText.copyWith(
          color: textTheme,
          fontSize: 18,
        ),
      )),
      content: SizedBox(
        width: double.maxFinite,
        child: content,
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: Text(
            'Cancel',
            style: AppTextStyles.regularText.copyWith(
              color: textTheme,
            ),
          ),
        ),
        TextButton(
          onPressed: _canConfirm ? widget.onConfirm : null,
          style: TextButton.styleFrom(
            backgroundColor: Colors.red.withValues(
              alpha: _canConfirm ? 0.12 : 0.06,
            ),
            foregroundColor: Colors.red,
            disabledForegroundColor:
                Colors.red.withValues(alpha: 0.4),
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 10,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: Text(
            'I agree',
            style: AppTextStyles.regularText.copyWith(
              color: Colors.red.withValues(
                alpha: _canConfirm ? 1 : 0.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}