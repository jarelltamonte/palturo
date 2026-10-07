import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_text_styles.dart';

class LegalDialogs {
  LegalDialogs._();

  static void showTermsOfService(BuildContext context) {
    _showLegalDialog(
      context,
      title: 'Terms of Service',
      content: '''
By using PalTuro, you agree to use the application responsibly and respectfully for its intended purpose of connecting people who want to learn and share Filipino cultural and practical skills. Users are expected to provide accurate information, respect other users, and avoid harassment, impersonation, false claims, or any activity that may harm the community. PalTuro may use the information provided in user profiles to recommend potentially compatible learners and mentors, but recommendations are only suggestions and do not guarantee a successful learning or mentoring relationship. Direct messaging is available only after both users mutually accept a connection, and users may report or block others when necessary. PalTuro may modify, improve, or discontinue features of the application as part of its ongoing development.
''',
    );
  }

  static void showDataPolicy(BuildContext context) {
    _showLegalDialog(
      context,
      title: 'Data Policy',
      content: '''
PalTuro collects and processes information necessary to operate the application and support learner-mentor matching, including account information, profile details, skills to learn or teach, interests, availability, learning preferences, language preferences, profile content, mentor skill showcase media, connection activity, and in-app messages. Information provided through profiles may be processed by PalTuro's AI-powered recommendation system to identify potentially compatible users. Data is used to provide matching, communication, profile management, moderation, and other core application functions. PalTuro is designed to collect only information necessary for these purposes, and profile information and messages should only be accessible to authorized parties. Users are responsible for keeping their account information accurate and should understand that the quality of recommendations may depend on the completeness and accuracy of the information they provide.
''',
    );
  }

  static void showCookiesPolicy(BuildContext context) {
    _showLegalDialog(
      context,
      title: 'Cookies Policy',
      content: '''
PalTuro is primarily designed as a mobile application and does not rely on browser cookies as a core part of its learner-mentor matching, messaging, or skill-sharing features. If cookies or similar technologies are used in supporting web pages or connected services, they may be used for essential purposes such as maintaining sessions, remembering preferences, improving security, and supporting basic service functionality. PalTuro does not intend to use such technologies to interfere with the community-based learning experience or to collect information unrelated to the operation of the application. Any future changes to the use of cookies or similar technologies may be reflected in an updated policy.
''',
    );
  }

  static void _showLegalDialog(
    BuildContext context, {
    required String title,
    required String content,
  }) {
    final textColor = Theme.of(context).colorScheme.secondary;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    if (isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (context) {
          return CupertinoAlertDialog(
            title: Text(
              title,
              style: AppTextStyles.regularText.copyWith(
                color: textColor,
                fontSize: 18,
              ),
            ),
            content: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Material(
                color: Colors.transparent,
                child: SingleChildScrollView(
                  child: Text(
                    content,
                    style: AppTextStyles.regularText.copyWith(
                      color: textColor,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Close',
                  style: AppTextStyles.regularText.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          );
        },
      );

      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            title,
            style: AppTextStyles.regularText.copyWith(
              color: textColor,
              fontSize: 18,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Text(
                content,
                style: AppTextStyles.regularText.copyWith(
                  color: textColor,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Close',
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
}
