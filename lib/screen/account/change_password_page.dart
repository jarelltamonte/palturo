import 'package:flutter/material.dart';
import 'package:palturo/services/auth_service.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/widgets/top_labeled_field.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await AuthService().updatePassword(_password.text, _confirm.text);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.secondary;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: _busy ? null : () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_new, size: 16, color: textColor),
        ),
        title: Text(
          'Change Password',
          style: AppTextStyles.headingText.copyWith(
            color: textColor,
            fontSize: 20,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? 'Saving…' : 'Save'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          Text(
            'Choose a new password. You will be signed out after saving and can log back in with the new password.',
            style: AppTextStyles.regularText.copyWith(
              color: AppColors.mutedText(context),
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          TopLabeledField(
            label: 'New password',
            controller: _password,
            obscureText: _obscure,
            suffixIcon: IconButton(
              tooltip: _obscure ? 'Show password' : 'Hide password',
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(
                _obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
          const SizedBox(height: 14),
          TopLabeledField(
            label: 'Confirm new password',
            controller: _confirm,
            obscureText: _obscure,
          ),
        ],
      ),
    );
  }
}
