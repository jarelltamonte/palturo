import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:lottie/lottie.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_text_styles.dart';

class HistoryListPage extends StatefulWidget {
  const HistoryListPage({super.key});

  @override
  State<HistoryListPage> createState() => _HistoryListPageState();
}

class _HistoryListPageState extends State<HistoryListPage> {
  final List<Map<String, dynamic>> _history = [];

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
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leadingWidth: 60,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.pop(context),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Icon(Icons.arrow_back_ios_new, color: textTheme, size: 16),
            ),
          ),
        ),
        title: Text(
          'History',
          style: AppTextStyles.regularText.copyWith(
            color: textTheme,
            fontSize: 16,
          ),
        ),
      ),
      body: _history.isEmpty
          ? _buildEmptyState(textTheme)
          : _buildList(textTheme),
    );
  }

  Widget _buildList(Color textTheme) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _history.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        color: textTheme.withValues(alpha: 0.1),
      ),
      itemBuilder: (context, index) {
        final entry = _history[index];
        return _HistoryTile(
          name: entry['name'] as String? ?? '',
          avatarUrl: entry['avatar_url'] as String?,
          action: entry['action'] as String? ?? '',
          onUndo: () {},
        );
      },
    );
  }

  Widget _buildEmptyState(Color textColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset(
              'assets/lottie/empty.json',
              width: 220,
              height: 220,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 8),
            Text(
              'No history yet',
              textAlign: TextAlign.center,
              style: AppTextStyles.regularText.copyWith(
                color: textColor.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final String action;
  final VoidCallback onUndo;

  const _HistoryTile({
    required this.name,
    required this.avatarUrl,
    required this.action,
    required this.onUndo,
  });

  String get _label {
    switch (action) {
      case 'accepted':
        return 'Accepted';
      case 'skipped':
        return 'Skipped';
      case 'added':
        return 'Added';
      default:
        return action;
    }
  }

  Color _labelColor(Color textTheme) {
    switch (action) {
      case 'accepted':
        return Colors.green;
      case 'added':
        return AppColors.primary;
      default:
        return textTheme.withValues(alpha: 0.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.grey.withValues(alpha: 0.3),
            backgroundImage:
                avatarUrl == null ? null : NetworkImage(avatarUrl!),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTextStyles.regularText.copyWith(color: textTheme),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _label,
                  style: AppTextStyles.regularText.copyWith(
                    color: _labelColor(textTheme),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: onUndo,
            style: OutlinedButton.styleFrom(
              foregroundColor: textTheme,
              side: BorderSide(color: textTheme.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              'Undo',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}