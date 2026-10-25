import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_text_styles.dart';

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  static const String supportEmail = 'support@palturo.app';

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.secondary;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Support',
          style: AppTextStyles.headingText.copyWith(
            color: textColor,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Text(
              'We can help',
              style: AppTextStyles.headingText.copyWith(
                color: textColor,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Contact us before deleting your account if you need help with access, safety, or your data.',
              style: AppTextStyles.regularText.copyWith(
                color: AppColors.mutedText(context),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.elevatedSurface(context),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border(context)),
              ),
              child: SelectableText(
                supportEmail,
                style: AppTextStyles.boldText.copyWith(
                  color: AppColors.accentText(context),
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                  const ClipboardData(text: supportEmail),
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Support email copied')),
                );
              },
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copy support email'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                minimumSize: const Size(44, 48),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Include the email address on your account and a short description of the issue.',
              style: AppTextStyles.regularText.copyWith(
                color: AppColors.mutedText(context),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
