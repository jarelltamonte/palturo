import 'package:flutter/material.dart';

class LegalDialogs {
  LegalDialogs._();

  static void showTermsOfService(BuildContext context) {
    _showLegalDialog(
      context,
      title: 'Terms of Service',
      content: 'Your Terms of Service text goes here...',
    );
  }

  static void showDataPolicy(BuildContext context) {
    _showLegalDialog(
      context,
      title: 'Data Policy',
      content: 'Your Data Policy text goes here...',
    );
  }

  static void showCookiesPolicy(BuildContext context) {
    _showLegalDialog(
      context,
      title: 'Cookies Policy',
      content: 'Your Cookies Policy text goes here...',
    );
  }

  static void _showLegalDialog(
    BuildContext context, {
    required String title,
    required String content,
  }) {
    showAdaptiveDialog(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(content),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}