import 'package:flutter/material.dart';

import 'package:palturo/models/account_warning.dart';
import 'package:palturo/services/warning_service.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_spacing.dart';
import 'package:palturo/theme/app_text_styles.dart';

/// Shows warnings while they are inside their visibility window.
///
/// The warning record stays in the database after this list empties so
/// moderation can keep using it; the user simply stops seeing it.
class AccountStandingPage extends StatefulWidget {
  const AccountStandingPage({super.key});

  @override
  State<AccountStandingPage> createState() => _AccountStandingPageState();
}

class _AccountStandingPageState extends State<AccountStandingPage> {
  final _service = WarningService();

  bool _loading = true;
  String? _error;
  List<AccountWarning> _warnings = const [];
  final Set<String> _acknowledging = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final warnings = await _service.fetchMyWarnings();
      if (!mounted) return;
      setState(() {
        _warnings = warnings;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load your account standing. Pull to retry.';
        _loading = false;
      });
    }
  }

  Future<void> _acknowledge(AccountWarning warning) async {
    if (_acknowledging.contains(warning.id)) return;
    setState(() => _acknowledging.add(warning.id));
    try {
      final ok = await _service.acknowledge(warning.id);
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This warning is no longer available.')),
        );
        await _load();
        return;
      }
      setState(() {
        _warnings = _warnings
            .map(
              (item) => item.id == warning.id
                  ? AccountWarning(
                    id: item.id,
                    category: item.category,
                    message: item.message,
                    createdAt: item.createdAt,
                    visibleUntil: item.visibleUntil,
                    acknowledgedAt: DateTime.now().toUtc(),
                  )
                  : item,
            )
            .toList(growable: false);
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save that. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _acknowledging.remove(warning.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        toolbarHeight: AppSpacing.topBarHeight(),
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_new, size: 16, color: textTheme),
        ),
        title: Text(
          'Account standing',
          style: AppTextStyles.headingText.copyWith(
            color: textTheme,
            fontSize: 20,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Text(
              'Warnings are shown here for a limited time. They stay on record '
              'for moderation even after they disappear from this screen.',
              style: AppTextStyles.regularText.copyWith(
                color: AppColors.mutedText(context),
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _Notice(
                icon: Icons.cloud_off_outlined,
                title: 'Could not load',
                body: _error!,
              )
            else if (_warnings.isEmpty)
              _Notice(
                icon: Icons.verified_user_outlined,
                title: 'No active warnings',
                body: 'Your account is in good standing.',
              )
            else
              ..._warnings.map((warning) => _warningCard(context, warning)),
          ],
        ),
      ),
    );
  }

  Widget _warningCard(BuildContext context, AccountWarning warning) {
    final textTheme = Theme.of(context).colorScheme.secondary;
    final busy = _acknowledging.contains(warning.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.mutedSurface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.shield_outlined,
                size: 18,
                color: AppColors.accentText(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  warning.categoryLabel,
                  style: AppTextStyles.boldText.copyWith(
                    color: textTheme,
                    fontSize: 14,
                  ),
                ),
              ),
              if (warning.isAcknowledged)
                Icon(
                  Icons.check_circle_outline,
                  size: 18,
                  color: AppColors.mutedText(context),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            warning.message,
            style: AppTextStyles.regularText.copyWith(
              color: textTheme,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Issued ${_formatDate(warning.createdAt.toLocal())} · '
            'visible until ${_formatDate(warning.visibleUntil.toLocal())}',
            style: AppTextStyles.regularText.copyWith(
              color: AppColors.mutedText(context),
              fontSize: 11.5,
            ),
          ),
          if (!warning.isAcknowledged) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonal(
                onPressed: busy ? null : () => _acknowledge(warning),
                child: Text(busy ? 'Saving…' : 'Understood'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[value.month - 1]} ${value.day}, ${value.year}';
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.mutedSurface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: AppColors.mutedText(context)),
          const SizedBox(height: 10),
          Text(
            title,
            style: AppTextStyles.boldText.copyWith(
              color: textTheme,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: AppTextStyles.regularText.copyWith(
              color: AppColors.mutedText(context),
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
