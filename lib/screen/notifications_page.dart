import 'dart:async';
import 'package:flutter/material.dart';
import 'package:palturo/screen/activity_presentation.dart';
import 'package:palturo/screen/chats_room.dart';
import 'package:palturo/screen/request_page.dart';
import 'package:palturo/services/activity_service.dart';
import 'package:palturo/services/match_api.dart';
import 'package:palturo/screen/utils/chat_time_formatter.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/widgets/app_skeleton.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<Map<String, dynamic>> _items = const [];
  Map<String, ConversationLite> _conversations = const {};
  Map<String, RequestLite> _incoming = const {};
  bool _loading = true;
  bool _markingAll = false;
  bool _conversationsLoaded = false;
  bool _incomingLoaded = false;
  String? _error;

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
      final items = await MatchApi.listNotifications(limit: 50);
      var conversations = <String, ConversationLite>{};
      var incoming = <String, RequestLite>{};
      var conversationsLoaded = false;
      var incomingLoaded = false;
      try {
        final rows = await MatchApi.getConversations();
        conversations = {for (final row in rows) row.connectionId: row};
        conversationsLoaded = true;
      } catch (_) {
        // Enrichment is optional; absence must not imply deletion.
      }
      try {
        final rows = await MatchApi.getIncomingRequests();
        incoming = {for (final row in rows) row.connectionId: row};
        incomingLoaded = true;
      } catch (_) {
        // Enrichment is optional; absence must not imply deletion.
      }
      if (!mounted) return;
      setState(() {
        _items = items;
        _conversations = conversations;
        _incoming = incoming;
        _conversationsLoaded = conversationsLoaded;
        _incomingLoaded = incomingLoaded;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Couldn’t load activity.\nPlease check your connection.';
      });
    }
  }

  bool get _hasUnread =>
      _items.any((item) => (item['read_at']?.toString().trim() ?? '').isEmpty);

  Future<void> _markItemRead(Map<String, dynamic> item) async {
    final id = item['id']?.toString();
    if (id == null || id.isEmpty) return;
    try {
      await MatchApi.markNotificationRead(id);
    } catch (_) {
      if (mounted) {
        _showFallback('Couldn’t mark this update as read.');
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _items =
          _items
              .map(
                (row) =>
                    row['id'] == item['id']
                        ? {
                          ...row,
                          'read_at': DateTime.now().toUtc().toIso8601String(),
                        }
                        : row,
              )
              .toList();
    });
    await ActivityService.instance.refresh();
  }

  Future<void> _markAllRead() async {
    if (_markingAll) return;
    setState(() => _markingAll = true);
    try {
      await MatchApi.markNotificationsRead();
    } catch (_) {
      if (mounted) {
        setState(() => _markingAll = false);
        _showFallback('Couldn’t mark all activity as read.');
      }
      return;
    }
    if (!mounted) return;
    final now = DateTime.now().toUtc().toIso8601String();
    setState(() {
      _items = _items.map((row) => {...row, 'read_at': now}).toList();
      _markingAll = false;
    });
    await ActivityService.instance.refresh();
  }

  Future<void> _openItem(Map<String, dynamic> item) async {
    final connectionId =
        item['payload'] is Map
            ? (item['payload'] as Map)['connection_id']?.toString()
            : null;
    final conversation =
        connectionId == null ? null : _conversations[connectionId];
    final incoming = connectionId == null ? null : _incoming[connectionId];
    final view = presentActivity(
      item,
      incoming: incoming,
      conversation: conversation,
    );

    switch (view.destination) {
      case ActivityDestination.incomingRequests:
        if (_incomingLoaded && incoming == null) {
          _showFallback('This request is no longer available.');
          return;
        }
        unawaited(_markItemRead(item));
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) => const RequestPage(initialView: RequestView.incoming),
          ),
        );
      case ActivityDestination.sentRequests:
        unawaited(_markItemRead(item));
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const RequestPage(initialView: RequestView.sent),
          ),
        );
      case ActivityDestination.chat:
        if (view.connectionId == null ||
            (_conversationsLoaded && conversation == null)) {
          _showFallback('This chat is no longer available.');
          return;
        }
        unawaited(_markItemRead(item));
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (_) => ChatRoom(
                  connectionId: view.connectionId,
                  name: view.actorName ?? 'Pal',
                  skillName: view.skillName,
                ),
          ),
        );
      case ActivityDestination.none:
        final kind = item['kind']?.toString();
        _showFallback(
          kind == 'skill_moderation'
              ? 'Open Profile to review this skill update.'
              : 'This update is no longer available.',
        );
    }
  }

  void _showFallback(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.secondary;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_new, size: 16, color: textColor),
        ),
        title: Text(
          'Activity',
          style: AppTextStyles.headingText.copyWith(
            color: textColor,
            fontSize: 20,
          ),
        ),
        actions: [
          if (!_loading && _error == null && _hasUnread)
            TextButton(
              onPressed: _markingAll ? null : _markAllRead,
              child: Text(_markingAll ? 'Marking…' : 'Mark all read'),
            ),
        ],
      ),
      body:
          _loading
              ? const ListRowsSkeleton(count: 6, rowHeight: 92)
              : _error != null
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.regularText.copyWith(
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
              : _items.isEmpty
              ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'No activity yet',
                      style: AppTextStyles.regularText.copyWith(
                        color: AppColors.mutedText(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => const RequestPage(
                                    initialView: RequestView.incoming,
                                  ),
                            ),
                          ),
                      child: const Text('View requests'),
                    ),
                  ],
                ),
              )
              : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final connectionId =
                      item['payload'] is Map
                          ? (item['payload'] as Map)['connection_id']
                              ?.toString()
                          : null;
                  final conversation =
                      connectionId == null
                          ? null
                          : _conversations[connectionId];
                  final incoming =
                      connectionId == null ? null : _incoming[connectionId];
                  final view = presentActivity(
                    item,
                    incoming: incoming,
                    conversation: conversation,
                  );
                  final created = DateTime.tryParse(
                    item['created_at']?.toString() ?? '',
                  );
                  final unread =
                      (item['read_at']?.toString().trim() ?? '').isEmpty;
                  return _ActivityRow(
                    view: view,
                    unread: unread,
                    timeLabel:
                        created == null
                            ? null
                            : ChatTimeFormatter.formatChatListTime(created),
                    onTap: () => _openItem(item),
                  );
                },
              ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final ActivityItemView view;
  final bool unread;
  final String? timeLabel;
  final VoidCallback onTap;

  const _ActivityRow({
    required this.view,
    required this.unread,
    required this.timeLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.secondary;
    return Semantics(
      button: true,
      label:
          '${view.title}. ${view.body}.${unread ? ' Unread.' : ''}'
          '${view.actionLabel.isEmpty ? '' : ' ${view.actionLabel}.'}',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color:
                  unread
                      ? AppColors.accentText(context).withValues(alpha: 0.08)
                      : AppColors.elevatedSurface(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color:
                    unread
                        ? AppColors.accentText(context).withValues(alpha: 0.45)
                        : AppColors.border(context),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    view.icon,
                    size: 19,
                    color: AppColors.accentText(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              view.title,
                              style: AppTextStyles.boldText.copyWith(
                                color: textColor,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (unread)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppColors.accentText(context),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        view.body,
                        style: AppTextStyles.regularText.copyWith(
                          color: textColor.withValues(alpha: 0.7),
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                      if (view.actionLabel.isNotEmpty || timeLabel != null) ...[
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            if (view.actionLabel.isNotEmpty)
                              Text(
                                view.actionLabel,
                                style: AppTextStyles.regularText.copyWith(
                                  color: AppColors.accentText(context),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            const Spacer(),
                            if (timeLabel != null)
                              Text(
                                timeLabel!,
                                style: AppTextStyles.regularText.copyWith(
                                  color: AppColors.mutedText(context),
                                  fontSize: 11,
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
          ),
        ),
      ),
    );
  }
}
