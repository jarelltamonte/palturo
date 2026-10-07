import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'login.dart';

class ScratchWidget extends StatefulWidget {
  final String? email;
  final bool isConfirmedInitial;

  const ScratchWidget({super.key, this.email, this.isConfirmedInitial = false});

  @override
  State<ScratchWidget> createState() => _ScratchWidgetState();
}

class _ScratchWidgetState extends State<ScratchWidget> {
  late final StreamSubscription<AuthState> _authSubscription;
  late bool _emailConfirmed;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _emailConfirmed = widget.isConfirmedInitial;

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        if (!mounted) return;

        final event = data.event;
        final user = data.session?.user;

        if (event == AuthChangeEvent.signedOut) {
          return;
        }

        if (event == AuthChangeEvent.userUpdated) {
          if (user != null && user.emailConfirmedAt != null) {
            if (widget.email == null ||
                widget.email!.trim().toLowerCase() ==
                    user.email?.toLowerCase()) {
              setState(() {
                _emailConfirmed = true;
              });
            }
          }
        }
      },
      onError: (error) {
        debugPrint('Auth listener error: $error');
      },
    );
  }

  Future<void> _checkVerificationStatus({bool silent = false}) async {
    if (_isChecking || _emailConfirmed) return;
    setState(() => _isChecking = true);

    try {
      final response = await Supabase.instance.client.auth.getUser();
      final user = response.user;

      final isMatch =
          widget.email == null ||
          widget.email!.trim().toLowerCase() ==
              user?.email?.trim().toLowerCase();

      if (user != null && user.emailConfirmedAt != null && isMatch) {
        if (mounted) {
          setState(() {
            _emailConfirmed = true;
          });
        }
      } else {
        if (!silent && mounted) {
          _showNotVerifiedDialog();
        }
      }
    } catch (_) {
      if (!silent && mounted) {
        _showNotVerifiedDialog();
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  void _showNotVerifiedDialog() {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Not Verified Yet',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text(
              'We haven\'t detected your confirmation yet.\n\nPlease open the link sent to ${widget.email ?? "your email"} first, then try again.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emailText = widget.email;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Lottie.asset(
                  'assets/lottie/lottie_finished.json',
                  width: 300,
                  repeat: !_emailConfirmed,
                  animate: true,
                ),
                const SizedBox(height: 24),
                Text(
                  _emailConfirmed ? "You're all set!" : 'Check your email!',
                  style: AppTextStyles.headingText.copyWith(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  _emailConfirmed
                      ? 'Your account setup is complete.\nLet’s get started.'
                      : 'We sent a verification link${emailText != null && emailText.isNotEmpty ? ' to\n$emailText' : ''}.\nPlease verify to continue.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.regularText.copyWith(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_emailConfirmed)
                ElevatedButton(
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    await Supabase.instance.client.auth.signOut(
                      scope: SignOutScope.local,
                    );
                    if (!mounted) return;
                    navigator.pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const LoginPage(),
                      ),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    textStyle: AppTextStyles.boldText,
                    foregroundColor: AppColors.textSecondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text('Continue to Login'),
                )
              else ...[
                OutlinedButton(
                  onPressed: _isChecking ? null : _checkVerificationStatus,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    backgroundColor: AppColors.primary,
                    textStyle: AppTextStyles.boldText,
                    foregroundColor: AppColors.textSecondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child:
                      _isChecking
                          ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Text('I already confirmed my email'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginPage(),
                      ),
                      (route) => false,
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.secondary,
                    textStyle: AppTextStyles.regularText,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Back to Login'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
