import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:palturo/services/profile_service.dart';
import 'package:palturo/screen/account/change_password_page.dart';
import 'package:palturo/screen/account/delete_account_page.dart';
import 'package:palturo/screen/account/privacy_page.dart';
import 'package:palturo/screen/settings/chat_privacy_page.dart';
import 'package:palturo/screen/block_list.dart';
import 'package:palturo/screen/profile_data.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/utils/friendly_error.dart';
import 'package:palturo/utils/validators.dart';
import 'package:palturo/widgets/user_avatar.dart';

/// The account destination that Settings previously tried to contain inline.
///
/// Identity, security, privacy and destructive actions live on this one
/// surface. Logout stays one level up on the Settings root.
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
  NameChangeStatus? _nameStatus;

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

    NameChangeStatus? nameStatus;
    try {
      nameStatus = await ProfileService().getNameChangeStatus();
    } catch (_) {
      // The name row can still be shown; the RPC will re-check the quota.
    }
    if (!mounted) return;
    setState(() => _nameStatus = nameStatus);
  }

  String get _displayName =>
      _profile?.name ?? _authName ?? _email ?? 'PalTuro user';

  Future<void> _openNameEditor() async {
    final status = _nameStatus;
    if (status != null && !status.canChange) {
      await _showNameLocked(status);
      return;
    }

    final profile = _profile;
    final first = profile?.firstName ?? _authName?.split(' ').first ?? '';
    final last = profile?.lastName ?? '';
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.elevatedSurface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (_) => _ChangeNameSheet(
            initialFirst: first,
            initialLast: last,
            status: status,
          ),
    );
    if (changed == true && mounted) {
      await _loadAccount();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Display name updated.')));
    }
  }

  Future<void> _showNameLocked(NameChangeStatus status) async {
    final next = status.nextChangeAt;
    final date =
        next == null
            ? null
            : MaterialLocalizations.of(
              context,
            ).formatMediumDate(next.toLocal());
    final message =
        status.changesRemaining <= 0
            ? 'You have used both name changes for this account.'
            : date == null
            ? 'Your next name change is not available yet.'
            : 'You can change your name again on $date.';
    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            backgroundColor: AppColors.elevatedSurface(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Text(
              'Display name',
              style: AppTextStyles.boldText.copyWith(
                color: Theme.of(context).colorScheme.secondary,
                fontSize: 18,
              ),
            ),
            content: Text(
              '$message Names can be changed twice in total, with 60 days between changes.',
              style: AppTextStyles.regularText.copyWith(
                color: AppColors.mutedText(context),
                height: 1.4,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('OK'),
              ),
            ],
          ),
    );
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

    return Scaffold(
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
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_ios_new, color: textTheme, size: 16),
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
          _tile(
            icon: Icons.badge_outlined,
            title: 'Display name',
            subtitle: _displayName,
            trailing: Text(
              _nameStatus?.canChange == false ? 'Locked' : 'Change',
              style: AppTextStyles.regularText.copyWith(
                color: AppColors.accentText(context),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: _openNameEditor,
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
          _tile(
            icon: Icons.visibility_outlined,
            title: 'Chat privacy',
            onTap: () => _open(const ChatPrivacyPage()),
          ),

          _section('DANGER ZONE'),
          Material(
            color: AppColors.danger.withValues(alpha: 0.07),
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: AppColors.danger.withValues(alpha: 0.18)),
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
              onTap: () => _open(const DeleteAccountPage()),
            ),
          ),
          SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom),
        ],
      ),
    );
  }
}

class _ChangeNameSheet extends StatefulWidget {
  const _ChangeNameSheet({
    required this.initialFirst,
    required this.initialLast,
    this.status,
  });

  final String initialFirst;
  final String initialLast;
  final NameChangeStatus? status;

  @override
  State<_ChangeNameSheet> createState() => _ChangeNameSheetState();
}

class _ChangeNameSheetState extends State<_ChangeNameSheet> {
  late final TextEditingController _first;
  late final TextEditingController _last;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _first = TextEditingController(text: widget.initialFirst);
    _last = TextEditingController(text: widget.initialLast);
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_dirty) return;
    final firstError = Validators.validateName(_first.text, 'First name');
    if (firstError != null) {
      setState(() => _error = firstError);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ProfileService().changeName(_first.text, _last.text);
      try {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(
            data: {
              'first_name': _first.text.trim(),
              'last_name': _last.text.trim(),
            },
          ),
        );
      } catch (_) {
        // The profile row is the source of truth; metadata sync is best effort.
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error =
            e is PostgrestException
                ? e.message
                : friendlyError(
                  e,
                  fallback: 'Could not change your name. Please try again.',
                );
      });
    }
  }

  bool get _dirty =>
      _first.text.trim() != widget.initialFirst.trim() ||
      _last.text.trim() != widget.initialLast.trim();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;
    final remaining = widget.status?.changesRemaining;
    final copy =
        remaining == null
            ? 'You can change your name twice in total. After a change, the next one is available after 60 days.'
            : '$remaining name change${remaining == 1 ? '' : 's'} remaining. After a change, the next one is available after 60 days.';

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom:
            20 +
            MediaQuery.viewInsetsOf(context).bottom +
            MediaQuery.paddingOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Change display name',
              style: AppTextStyles.headingText.copyWith(
                color: textTheme,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              copy,
              style: AppTextStyles.regularText.copyWith(
                color: AppColors.mutedText(context),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _first,
              autofocus: true,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              maxLength: 50,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'First name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _last,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.words,
              maxLength: 50,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _save(),
              decoration: const InputDecoration(labelText: 'Last name'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 4),
              Text(
                _error!,
                style: AppTextStyles.regularText.copyWith(
                  color: AppColors.dangerText(context),
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving || !_dirty ? null : _save,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child:
                    _saving
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Text('Save name'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
