import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'package:palturo/authentication/legal_dialogs.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_text_styles.dart';

/// A truthful privacy destination. It links to the policies that already
/// exist and explains what is stored; it does not promise an export flow that
/// is not implemented.
class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;
    final adaptiveHeight =
        defaultTargetPlatform == TargetPlatform.iOS ? 44.0 : 56.0;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        toolbarHeight: adaptiveHeight,
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_new, size: 16, color: textTheme),
        ),
        title: Text(
          'Data & privacy',
          style: AppTextStyles.headingText.copyWith(
            color: textTheme,
            fontSize: 20,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Semantics(
            header: true,
            child: Text(
              'Your data',
              style: AppTextStyles.boldText.copyWith(
                color: textTheme,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'PalTuro stores the profile details, skills, requests, messages, '
            'and feedback needed to run matching, chat, safety, and account '
            'features. Your profile and activity are visible only where the '
            'product needs them.',
            style: AppTextStyles.regularText.copyWith(
              color: textTheme.withValues(alpha: 0.8),
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          _PolicyRow(
            icon: Icons.shield_outlined,
            title: 'Data Policy',
            onTap: () => LegalDialogs.showDataPolicy(context),
          ),
          _PolicyRow(
            icon: Icons.cookie_outlined,
            title: 'Cookies Policy',
            onTap: () => LegalDialogs.showCookiesPolicy(context),
          ),
          _PolicyRow(
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            onTap: () => LegalDialogs.showTermsOfService(context),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.mutedSurface(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Deleting your account',
                  style: AppTextStyles.boldText.copyWith(
                    color: textTheme,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Account deletion is permanent and removes your profile, '
                  'photos, Pals, requests, and chat history. Use the Delete '
                  'account action in Account & security.',
                  style: AppTextStyles.regularText.copyWith(
                    color: AppColors.mutedText(context),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('Back to Account & security'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _PolicyRow({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: textTheme),
      title: Text(
        title,
        style: AppTextStyles.regularText.copyWith(color: textTheme),
      ),
      trailing: Icon(Icons.chevron_right, color: textTheme),
      onTap: onTap,
    );
  }
}
