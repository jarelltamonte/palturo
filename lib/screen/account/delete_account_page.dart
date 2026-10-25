import 'package:flutter/material.dart';
import 'package:palturo/services/auth_service.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_text_styles.dart';

/// A dedicated destructive destination. Kept out of the routine account list
/// so Delete Account is never the next tap after Log Out.
class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  static const String _keyword = 'DELETE';
  final TextEditingController _controller = TextEditingController();
  bool _deleting = false;

  bool get _canDelete =>
      _controller.text.trim().toUpperCase() == _keyword && !_deleting;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (!_canDelete) return;
    setState(() => _deleting = true);
    try {
      await AuthService().deleteAccount();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.secondary;
    final muted = AppColors.mutedText(context);

    return PopScope(
      canPop: !_deleting,
      child: Stack(
        children: [
          Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: IconButton(
                tooltip: 'Back',
                onPressed: _deleting ? null : () => Navigator.pop(context),
                icon: Icon(
                  Icons.arrow_back_ios_new,
                  size: 16,
                  color: textColor,
                ),
              ),
              title: Text(
                'Delete Account',
                style: AppTextStyles.headingText.copyWith(
                  color: textColor,
                  fontSize: 20,
                ),
              ),
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.danger,
                        size: 30,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'This permanently deletes your account',
                        style: AppTextStyles.boldText.copyWith(
                          color: textColor,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your profile, photos, matches, requests, and chat history will be removed. This cannot be undone.',
                        style: AppTextStyles.regularText.copyWith(
                          color: muted,
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Type $_keyword to confirm',
                  style: AppTextStyles.boldText.copyWith(
                    color: textColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _controller,
                  enabled: !_deleting,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  style: AppTextStyles.regularText.copyWith(color: textColor),
                  decoration: InputDecoration(
                    hintText: _keyword,
                    filled: true,
                    fillColor: AppColors.mutedSurface(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: AppColors.danger.withValues(alpha: 0.25),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: AppColors.danger,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _canDelete ? _delete : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.danger.withValues(
                        alpha: 0.2,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text('Delete my account permanently'),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'You will be signed out on this device. If you need help, contact support before continuing.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.regularText.copyWith(
                    color: muted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (_deleting)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black54,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 24,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.elevatedSurface(context),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Deleting account…',
                          style: AppTextStyles.boldText.copyWith(
                            color: textColor,
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
