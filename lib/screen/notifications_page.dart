import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:palturo/models/app_notification.dart';
import 'package:palturo/screen/action_dialogs.dart';
import 'package:palturo/screen/activity_presentation.dart';
import 'package:palturo/screen/card/person_card.dart';
import 'package:palturo/screen/request_page.dart';
import 'package:palturo/screen/utils/chat_time_formatter.dart';
import 'package:palturo/services/app_navigation.dart';
import 'package:palturo/services/app_navigator.dart';
import 'package:palturo/services/app_shell_state.dart';
import 'package:palturo/services/match_api.dart';
import 'package:palturo/services/notification_service.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/utils/friendly_error.dart';
import 'package:palturo/widgets/app_feedback.dart';
import 'package:palturo/widgets/app_skeleton.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> with RouteAware {
  Map<String, ConversationLite> _conversations = const {};
  Map<String, RequestLite> _incoming = const {};
  bool _loading = true;
  bool _markingAll = false;
  bool _conversationsLoaded = false;
  bool _incomingLoaded = false;
  String? _error;
  Future<void>? _enrichmentFuture;

  List<AppNotification> get _items => NotificationService.instance.items;

  @override
  void initState() {
    super.initState();
    AppShellState.instance.setActivityOpen(true);
    NotificationService.instance.addListener(_onServiceChanged);
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPushNext() => AppShellState.instance.setActivityOpen(false);

  @override
  void didPopNext() => AppShellState.instance.setActivityOpen(true);

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    AppShellState.instance.setActivityOpen(false);
    NotificationService.instance.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    if (!mounted) return;
    final scheduler = SchedulerBinding.instance;
    if (scheduler.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      scheduler.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
          _refreshIfNewConnection();
        }
      });
    } else {
      setState(() {});
      _refreshIfNewConnection();
    }
  }

  /// A realtime row can arrive after the initial enrichment snapshot. Reload
  /// conversations/requests so the new row cannot be mistaken for deleted.
  void _refreshIfNewConnection() {
    final needsRefresh = _items.any((item) {
      final id = item.connectionId;
      if (id == null) return false;
      return (_incomingLoaded && !_incoming.containsKey(id)) ||
          (_conversationsLoaded && !_conversations.containsKey(id));
    });
    if (needsRefresh) unawaited(_refreshEnrichment());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    await NotificationService.instance.refresh();
    await _refreshEnrichment();

    if (!mounted) return;
    setState(() {
      _loading = false;
      if (_items.isEmpty && NotificationService.instance.error != null) {
        _error = friendlyError(
          NotificationService.instance.error ?? '',
          fallback: "Couldn't load activity. Please try again.",
        );
      } else {
        _error = null;
      }
    });
  }

  Future<void> _refreshEnrichment() {
    final existing = _enrichmentFuture;
    if (existing != null) return existing;
    final future = _doRefreshEnrichment();
    _enrichmentFuture = future;
    return future.whenComplete(() => _enrichmentFuture = null);
  }

  Future<void> _doRefreshEnrichment() async {
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
      _conversations = conversations;
      _incoming = incoming;
      _conversationsLoaded = conversationsLoaded;
      _incomingLoaded = incomingLoaded;
    });
  }

  bool get _hasUnread => _items.any((item) => item.isUnread);

  Future<void> _markItemRead(AppNotification item) =>
      NotificationService.instance.markItemRead(item.id);

  Future<void> _markAllRead() async {
    if (_markingAll) return;
    setState(() => _markingAll = true);
    await NotificationService.instance.markAllRead();
    if (mounted) setState(() => _markingAll = false);
  }

  Future<void> _openItem(AppNotification item) async {
    final connectionId = item.connectionId;
    var conversation =
        connectionId == null ? null : _conversations[connectionId];
    var incoming = connectionId == null ? null : _incoming[connectionId];

    // A row may have arrived after the initial snapshot. Re-read once before
    // concluding that its conversation/request no longer exists.
    if (connectionId != null &&
        ((_incomingLoaded && incoming == null) ||
            (_conversationsLoaded && conversation == null))) {
      await _refreshEnrichment();
      conversation = _conversations[connectionId];
      incoming = _incoming[connectionId];
    }

    final view = presentActivity(
      item.toRow(),
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
        await AppRouter.openRequests(view: RequestView.incoming);
      case ActivityDestination.sentRequests:
        unawaited(_markItemRead(item));
        await AppRouter.openRequests(view: RequestView.sent);
      case ActivityDestination.chat:
        if (view.connectionId == null ||
            (_conversationsLoaded && conversation == null)) {
          _showFallback('This chat is no longer available.');
          return;
        }
        unawaited(_markItemRead(item));
        await AppRouter.openChat(
          connectionId: view.connectionId!,
          name: view.actorName ?? 'Pal',
          skillName: view.skillName,
          role: _roleFrom(conversation?.otherRole),
          avatarUrl: conversation?.otherAvatar,
        );
      case ActivityDestination.none:
        _showFallback(
          item.kind == AppNotificationKind.skillModeration
              ? 'Open Profile to review this skill update.'
              : 'This update is no longer available.',
        );
    }
  }

  PersonRole? _roleFrom(String? role) {
    switch (role?.trim().toLowerCase()) {
      case 'learner':
        return PersonRole.learner;
      case 'mentor':
        return PersonRole.mentor;
      default:
        return null;
    }
  }

  void _showFallback(String message) {
    showAppSnackBar(context, message);
  }

  ActivityFilter _filter = ActivityFilter.all;

  bool _matchesFilter(AppNotification item, ActivityFilter filter) {
    switch (filter) {
      case ActivityFilter.all:
        return true;
      case ActivityFilter.unread:
        return item.isUnread;
      case ActivityFilter.requests:
        return item.kind.isRequest || item.kind.isMatch || item.kind.isDecline;
      case ActivityFilter.updates:
        return item.kind.isFeedback ||
            item.kind == AppNotificationKind.skillModeration ||
            item.kind == AppNotificationKind.unknown;
    }
  }

  List<AppNotification> get _filteredItems => _items
      .where((item) => _matchesFilter(item, _filter))
      .toList(growable: false);

  int _countFor(ActivityFilter filter) {
    if (filter == ActivityFilter.all) return _items.length;
    return _items.where((item) => _matchesFilter(item, filter)).length;
  }

  Future<void> _clearRead() async {
    final readCount = _items.where((item) => !item.isUnread).length;
    if (readCount == 0) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Clear read activity',
      message:
          'Remove $readCount read update${readCount == 1 ? '' : 's'}? Unread updates stay.',
      confirmLabel: 'Clear',
    );
    if (!confirmed || !mounted) return;
    final cleared = await NotificationService.instance.clearRead();
    if (!mounted) return;
    if (cleared) {
      showAppSuccess(context, 'Read activity cleared');
    } else {
      showAppError(context, "Couldn't clear read activity. Please try again.");
    }
  }

  Widget _filterBar(Color textColor) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        itemCount: ActivityFilter.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = ActivityFilter.values[index];
          final selected = filter == _filter;
          return ChoiceChip(
            label: Text('${filter.label} ${_countFor(filter)}'),
            selected: selected,
            showCheckmark: false,
            selectedColor: AppColors.primary,
            backgroundColor: AppColors.elevatedSurface(context),
            side: BorderSide(color: AppColors.border(context)),
            labelStyle: AppTextStyles.regularText.copyWith(
              fontSize: 12,
              color: selected ? Colors.black : textColor,
            ),
            onSelected: (_) => setState(() => _filter = filter),
          );
        },
      ),
    );
  }

  Widget _dayHeader(DateTime day, Color textColor) {
    final label = activityDayLabel(day);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Text(
        label,
        style: AppTextStyles.regularText.copyWith(
          color: AppColors.mutedText(context),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  List<Widget> _buildRows(List<AppNotification> items, Color textColor) {
    final children = <Widget>[];
    DateTime? lastDay;
    for (final item in items) {
      final local = item.createdAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      if (lastDay != day) {
        children.add(_dayHeader(day, textColor));
        lastDay = day;
      }
      final connectionId = item.connectionId;
      final conversation =
          connectionId == null ? null : _conversations[connectionId];
      final incoming = connectionId == null ? null : _incoming[connectionId];
      final view = presentActivity(
        item.toRow(),
        incoming: incoming,
        conversation: conversation,
      );
      final timeLabel = ChatTimeFormatter.formatChatListTime(item.createdAt);
      children.add(
        Dismissible(
          key: ValueKey('activity:${item.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.mark_email_read_outlined,
              color: AppColors.accentText(context),
            ),
          ),
          confirmDismiss: (_) async {
            if (item.isUnread) await _markItemRead(item);
            return false;
          },
          child: _ActivityRow(
            view: view,
            unread: item.isUnread,
            timeLabel: timeLabel,
            onTap: () => _openItem(item),
          ),
        ),
      );
      children.add(const SizedBox(height: 8));
    }
    return children;
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.secondary;
    final all = _items;
    final items = _filteredItems;
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
              child: Text(_markingAll ? 'Marking...' : 'Mark all read'),
            ),
          if (!_loading && _error == null && all.any((item) => !item.isUnread))
            IconButton(
              tooltip: 'Clear read notifications',
              onPressed: _clearRead,
              icon: Icon(
                Icons.delete_sweep_outlined,
                size: 20,
                color: textColor,
              ),
            ),
        ],
      ),
      body:
          _loading && all.isEmpty
              ? const ActivitySkeleton()
              : _error != null && all.isEmpty
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
              : Column(
                children: [
                  if (all.isNotEmpty) _filterBar(textColor),
                  Expanded(
                    child:
                        all.isEmpty
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
                                        () => AppRouter.openRequests(
                                          view: RequestView.incoming,
                                        ),
                                    child: const Text('View requests'),
                                  ),
                                ],
                              ),
                            )
                            : items.isEmpty
                            ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'No ${_filter.label.toLowerCase()} activity.',
                                    style: AppTextStyles.regularText.copyWith(
                                      color: AppColors.mutedText(context),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed:
                                        () => setState(
                                          () => _filter = ActivityFilter.all,
                                        ),
                                    child: const Text('Show all'),
                                  ),
                                ],
                              ),
                            )
                            : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  4,
                                  16,
                                  100,
                                ),
                                children: _buildRows(items, textColor),
                              ),
                            ),
                  ),
                ],
              ),
    );
  }
}

@visibleForTesting
bool activityMatchesFilter(AppNotification item, ActivityFilter filter) {
  switch (filter) {
    case ActivityFilter.all:
      return true;
    case ActivityFilter.unread:
      return item.isUnread;
    case ActivityFilter.requests:
      return item.kind.isRequest || item.kind.isMatch || item.kind.isDecline;
    case ActivityFilter.updates:
      return item.kind.isFeedback ||
          item.kind == AppNotificationKind.skillModeration ||
          item.kind == AppNotificationKind.unknown;
  }
}

@visibleForTesting
String activityDayLabel(DateTime day, {DateTime? now}) {
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
  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return '${months[day.month - 1]} ${day.day}';
}

enum ActivityFilter {
  all('All'),
  unread('Unread'),
  requests('Requests'),
  updates('Updates');

  const ActivityFilter(this.label);

  final String label;
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
