import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:palturo/services/auth_service.dart';
import 'package:palturo/services/profile_service.dart';
import 'package:palturo/screen/action_dialogs.dart';
import 'package:palturo/screen/account/change_password_page.dart';
import 'package:palturo/screen/account/delete_account_page.dart';
import 'package:palturo/screen/account/privacy_page.dart';
import 'package:palturo/screen/block_list.dart';
import 'package:palturo/screen/profile_data.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/widgets/user_avatar.dart';

/// The account destination that Settings previously tried to contain inline.
///
/// Identity, security, privacy, session/logout and destructive actions live on
/// this one surface so routine preferences never sit next to irreversible work.
class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({super.key});

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  ProfileData? _profile;
  String? _email;
  String? _authName;
  bool _verified = false;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _loadAccount();
  }

  Future<void> _loadAccount() async {
    final user = Supabase.instance.client.auth.currentUser;
    final first = user?.userMetadata?['first_name']?.toString().trim() ?? '';
    final last = user?.userMetadata?['last_name']?.toString().trim() ?? '';
    final authName = [first, last].where((part) => part.isNotEmpty).join(' ');
    if (mounted) {
      setState(() {
        _email = user?.email;
        _authName = authName.isEmpty ? null : authName;
        _verified = user?.emailConfirmedAt != null;
      });
    }
    ProfileData? profile;
    try {
      profile = await ProfileService().getCurrentUserProfile();
    } catch (_) {
      // The auth record still provides enough identity to render the page.
    }
    if (!mounted) return;
    setState(() => _profile = profile);
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Log out',
      message: 'Are you sure you want to log out of PalTuro?',
      confirmLabel: 'Log out',
      destructive: false,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isLoggingOut = true);
    try {
      await AuthService().logout();
      if (!mounted) return;
      Navigator.of(
        context,
        rootNavigator: true,
      ).popUntil((route) => route.isFirst);
    } catch (e) {
      debugPrint('[Account] logout failed: $e');
      if (!mounted) return;
      setState(() => _isLoggingOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t log out. Please try again.')),
      );
    }
  }

  void _open(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Widget _section(String label) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 2),
    child: Semantics(
      header: true,
      child: Text(
        label,
        style: AppTextStyles.regularText.copyWith(
          color: AppColors.mutedText(context),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    ),
  );

  Widget _identity() {
    final textTheme = Theme.of(context).colorScheme.secondary;
    final name = _profile?.name ?? _authName ?? _email ?? 'PalTuro user';
    final avatar = _profile?.avatarUrl;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        children: [
          UserAvatar(
            name: name,
            image: avatar == null ? null : NetworkImage(avatar),
            size: 58,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.boldText.copyWith(
                    color: textTheme,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _email ?? 'Not set',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.regularText.copyWith(
                    color: AppColors.mutedText(context),
                    fontSize: 13,
                  ),
                ),
                if (_verified) ...[
                  const SizedBox(height: 7),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_outlined,
                        size: 14,
                        color: AppColors.accentText(context),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Verified email',
                        style: AppTextStyles.regularText.copyWith(
                          color: AppColors.accentText(context),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? color,
    bool showChevron = true,
  }) {
    final textTheme = Theme.of(context).colorScheme.secondary;
    final textColor = color ?? textTheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: textColor),
      title: Text(
        title,
        style: AppTextStyles.regularText.copyWith(color: textColor),
      ),
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
      trailing:
          trailing ??
          (showChevron
              ? Icon(Icons.chevron_right, color: textColor)
              : const SizedBox.shrink()),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;
    final adaptiveHeight =
        defaultTargetPlatform == TargetPlatform.iOS ? 44.0 : 56.0;

    return PopScope(
      canPop: !_isLoggingOut,
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
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
                'Account & security',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.headingText.copyWith(
                  color: textTheme,
                  fontSize: 20,
                ),
              ),
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                _identity(),

                _section('IDENTITY'),
                _tile(
                  icon: Icons.mail_outline,
                  title: 'Email',
                  subtitle: _email ?? 'Not set',
                  trailing:
                      _verified
                          ? null
                          : Text(
                            'Unverified',
                            style: AppTextStyles.regularText.copyWith(
                              color: AppColors.mutedText(context),
                              fontSize: 11,
                            ),
                          ),
                  showChevron: false,
                ),

                _section('SECURITY'),
                _tile(
                  icon: Icons.password_outlined,
                  title: 'Change password',
                  onTap: () => _open(const ChangePasswordPage()),
                ),
                _tile(
                  icon: Icons.devices_outlined,
                  title: 'This device',
                  subtitle: 'Signed in on this device.',
                  showChevron: false,
                ),

                _section('PRIVACY'),
                _tile(
                  icon: Icons.block,
                  title: 'Blocked users',
                  onTap: () => _open(const BlockListPage()),
                ),
                _tile(
                  icon: Icons.shield_outlined,
                  title: 'Data & privacy',
                  onTap: () => _open(const PrivacyPage()),
                ),

                _section('ACCOUNT'),
                Semantics(
                  button: true,
                  label: 'Log out',
                  excludeSemantics: true,
                  onTap: _isLoggingOut ? null : _logout,
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isLoggingOut ? null : _logout,
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Log out'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textTheme,
                        minimumSize: const Size(0, 48),
                        side: BorderSide(color: AppColors.border(context)),
                        backgroundColor: AppColors.mutedSurface(context),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                    ),
                  ),
                ),

                _section('DANGER ZONE'),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.18),
                    ),
                  ),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
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
                            : () => _open(const DeleteAccountPage()),
                  ),
                ),
                SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom),
              ],
            ),
          ),
          if (_isLoggingOut)
            Positioned.fill(
              child: Semantics(
                liveRegion: true,
                label: 'Logging out',
                child: Container(
                  color: Colors.black.withValues(alpha: 0.5),
                  alignment: Alignment.center,
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
