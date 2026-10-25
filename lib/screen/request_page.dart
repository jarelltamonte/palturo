import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_motion.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/screen/action_dialogs.dart';
import 'package:palturo/screen/card/request_card.dart';
import 'package:palturo/screen/card/person_card.dart';
import 'package:palturo/screen/card/request_detail.dart';
import 'package:palturo/screen/notifications_page.dart';
import 'package:palturo/screen/chats_room.dart';
import 'package:palturo/screen/matches.dart';
import 'package:palturo/screen/request_match_sheet.dart';
import 'package:palturo/screen/users_dump.dart';
import 'package:palturo/screen/utils/filter_bottom_sheet.dart';
import 'package:palturo/services/activity_service.dart';
import 'package:palturo/services/match_api.dart';
import 'package:palturo/services/chat_state_service.dart';
import 'package:palturo/services/preferences_service.dart';
import 'package:palturo/widgets/app_skeleton.dart';
import 'package:palturo/widgets/user_avatar.dart';

class ConnectionRequest {
  final String id;
  final String requesterId;
  final String skillName;
  final String requesterName;
  final String schedule;
  final String language;
  final String learningStyle;
  final String bio;
  final DateTime requestedAt;
  final String iconAsset;
  final String seekingLabel;
  final PersonRole role;
  final List<String?> photoUrls;

  const ConnectionRequest({
    required this.id,
    this.requesterId = '',
    required this.skillName,
    required this.requesterName,
    required this.schedule,
    required this.language,
    required this.learningStyle,
    required this.requestedAt,
    this.bio = '',
    this.iconAsset = 'assets/icons/rlearner.svg',
    this.seekingLabel = 'Seeking a learner in',
    this.role = PersonRole.learner,
    this.photoUrls = const [null],
  });

  factory ConnectionRequest.fromMatchedUser(
    MatchedUser user, {
    required DateTime requestedAt,
  }) {
    final isLearner = user.role == PersonRole.learner;
    return ConnectionRequest(
      id: 'dump_${user.id}',
      skillName: user.skillName,
      requesterName: user.name,
      schedule: user.schedule,
      language: user.language,
      learningStyle: user.learningStyle,
      bio: user.bio,
      requestedAt: requestedAt,
      iconAsset:
          isLearner ? 'assets/icons/rlearner.svg' : 'assets/icons/rmentor.svg',
      seekingLabel: isLearner ? 'Seeking a mentor in' : 'Seeking a learner in',
      role: user.role,
      photoUrls: [user.avatarUrl],
    );
  }

  Person toPerson() {
    return Person(
      id: requesterId.isNotEmpty ? requesterId : id,
      name: requesterName,
      schedule: schedule,
      language: language,
      learningStyle: learningStyle,
      skillName: skillName,
      role: role,
      bio: bio,
      photoUrls: photoUrls,
    );
  }
}

String timeAgo(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 30) return '${diff.inDays}d ago';
  return '${(diff.inDays / 30).floor()}mo ago';
}

enum DateFilter { all, today, thisWeek, thisMonth, thisYear }

bool matchesRequestDate(DateTime date, DateFilter filter, {DateTime? now}) {
  final current = now ?? DateTime.now();
  switch (filter) {
    case DateFilter.all:
      return true;
    case DateFilter.today:
      return date.year == current.year &&
          date.month == current.month &&
          date.day == current.day;
    case DateFilter.thisWeek:
      final startOfWeek = DateTime(
        current.year,
        current.month,
        current.day - (current.weekday - 1),
      );
      return !date.isBefore(startOfWeek) && !date.isAfter(current);
    case DateFilter.thisMonth:
      return date.year == current.year &&
          date.month == current.month &&
          !date.isAfter(current);
    case DateFilter.thisYear:
      return date.year == current.year && !date.isAfter(current);
  }
}

enum RoleFilter { all, learner, mentor }

enum SortFilter { newest, oldest, ascending, descending }

enum RequestView { incoming, sent }

class RequestPage extends StatefulWidget {
  final ValueListenable<int>? refreshSignal;
  final RequestView initialView;

  const RequestPage({
    super.key,
    this.refreshSignal,
    this.initialView = RequestView.incoming,
  });

  @override
  State<RequestPage> createState() => _RequestPageState();
}

class _RequestPageState extends State<RequestPage> {
  DateFilter _dateFilter = DateFilter.all;
  RoleFilter _roleFilter = RoleFilter.all;
  SortFilter _sortFilter = SortFilter.newest;
  RequestView _view = RequestView.incoming;

  static const List<FilterSection> _filterSections = [
    FilterSection(
      key: 'date',
      title: 'Date',
      options: [
        FilterOption('All', 'all'),
        FilterOption('Today', 'today'),
        FilterOption('This Week', 'thisWeek'),
        FilterOption('This Month', 'thisMonth'),
        FilterOption('This Year', 'thisYear'),
      ],
    ),
    FilterSection(
      key: 'role',
      title: 'Role',
      options: [
        FilterOption('All', 'all'),
        FilterOption('Learner', 'learner'),
        FilterOption('Mentor', 'mentor'),
      ],
    ),
    FilterSection(
      key: 'sort',
      title: 'Sort by',
      defaultValue: 'newest',
      options: [
        FilterOption('Newest', 'newest'),
        FilterOption('Oldest', 'oldest'),
        FilterOption('Ascending (A-Z)', 'ascending'),
        FilterOption('Descending (Z-A)', 'descending'),
      ],
    ),
  ];

  static const List<FilterSection> _sentFilterSections = [
    FilterSection(
      key: 'status',
      title: 'Status',
      options: [
        FilterOption('All', 'all'),
        FilterOption('Waiting', 'pending'),
        FilterOption('Declined', 'declined'),
      ],
    ),
    FilterSection(
      key: 'date',
      title: 'Date',
      options: [
        FilterOption('All', 'all'),
        FilterOption('This Week', 'thisWeek'),
        FilterOption('This Month', 'thisMonth'),
      ],
    ),
    FilterSection(
      key: 'sort',
      title: 'Sort by',
      defaultValue: 'newest',
      options: [
        FilterOption('Newest', 'newest'),
        FilterOption('Oldest', 'oldest'),
      ],
    ),
  ];

  bool get _hasActiveFilter =>
      _dateFilter != DateFilter.all ||
      _roleFilter != RoleFilter.all ||
      _sortFilter != SortFilter.newest;

  String _sentStatusFilter = 'all';
  DateFilter _sentDateFilter = DateFilter.all;
  SortFilter _sentSortFilter = SortFilter.newest;

  bool get _hasSentFilter =>
      _sentStatusFilter != 'all' ||
      _sentDateFilter != DateFilter.all ||
      _sentSortFilter != SortFilter.newest;

  late List<ConnectionRequest> _requests = const [];
  late List<OutgoingRequestLite> _outgoing = const [];
  bool _loading = true;
  bool _loadingOutgoing = true;
  String? _loadError;
  String? _outgoingError;
  bool _responding = false;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _view = widget.initialView;
    widget.refreshSignal?.addListener(_refreshFromShell);
    ActivityService.instance.addListener(_onActivityChanged);
    _loadRequests();
    _loadOutgoing();
  }

  @override
  void dispose() {
    widget.refreshSignal?.removeListener(_refreshFromShell);
    ActivityService.instance.removeListener(_onActivityChanged);
    super.dispose();
  }

  void _onActivityChanged() {
    if (mounted) setState(() {});
  }

  void _refreshFromShell() {
    if (!mounted) return;
    _loadRequests();
    _loadOutgoing();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final incoming = await MatchApi.getIncomingRequests();
      if (!mounted) return;
      setState(() {
        _requests = incoming.map((r) => r.toConnectionRequest()).toList();
        _loading = false;
        _loadError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Couldn’t load requests.\nPlease check your connection.';
      });
    }
  }

  Future<void> _loadOutgoing() async {
    setState(() {
      _loadingOutgoing = true;
      _outgoingError = null;
    });
    try {
      final sent = await MatchApi.getOutgoingRequests();
      if (!mounted) return;
      setState(() {
        _outgoing = sent;
        _loadingOutgoing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingOutgoing = false;
        _outgoingError =
            'Couldn’t load sent requests.\nPlease check your connection.';
      });
    }
  }

  Future<void> _cancelOutgoing(OutgoingRequestLite request) async {
    if (_cancelling) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Withdraw request',
      message:
          'Withdraw your connection request to ${request.recipientName}? They will no longer see it.',
      confirmLabel: 'Withdraw',
    );
    if (!confirmed || !mounted) return;

    setState(() => _cancelling = true);
    try {
      await MatchApi.cancelConnectionRequest(request.connectionId);
      if (!mounted) return;
      setState(() {
        _outgoing =
            _outgoing
                .where((item) => item.connectionId != request.connectionId)
                .toList();
      });
      ActivityService.instance.refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request to ${request.recipientName} withdrawn'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not withdraw request: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  bool _matchesDateFilter(DateTime date) {
    return matchesRequestDate(date, _dateFilter);
  }

  List<ConnectionRequest> get _filteredAndSortedRequests {
    var filtered =
        _requests.where((r) {
          final matchesDate = _matchesDateFilter(r.requestedAt);
          final matchesRole =
              _roleFilter == RoleFilter.all ||
              (_roleFilter == RoleFilter.learner &&
                  r.role == PersonRole.learner) ||
              (_roleFilter == RoleFilter.mentor && r.role == PersonRole.mentor);
          return matchesDate && matchesRole;
        }).toList();

    switch (_sortFilter) {
      case SortFilter.newest:
        filtered.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
        break;
      case SortFilter.oldest:
        filtered.sort((a, b) => a.requestedAt.compareTo(b.requestedAt));
        break;
      case SortFilter.ascending:
        filtered.sort((a, b) => a.requesterName.compareTo(b.requesterName));
        break;
      case SortFilter.descending:
        filtered.sort((a, b) => b.requesterName.compareTo(a.requesterName));
        break;
    }
    return filtered;
  }

  List<OutgoingRequestLite> get _filteredAndSortedOutgoing {
    final filtered =
        _outgoing.where((request) {
          final matchesStatus =
              _sentStatusFilter == 'all' || request.status == _sentStatusFilter;
          return matchesStatus &&
              matchesRequestDate(request.createdAt, _sentDateFilter);
        }).toList();
    switch (_sentSortFilter) {
      case SortFilter.newest:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortFilter.oldest:
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case SortFilter.ascending:
        filtered.sort((a, b) => a.recipientName.compareTo(b.recipientName));
        break;
      case SortFilter.descending:
        filtered.sort((a, b) => b.recipientName.compareTo(a.recipientName));
        break;
    }
    return filtered;
  }

  void _removeRequest(String id) {
    setState(() {
      _requests.removeWhere((r) => r.id == id);
    });
  }

  void _blockRequester(ConnectionRequest request) async {
    if (!mounted) return;
    try {
      await MatchApi.blockUser(request.requesterId);
      await ChatStateService.instance.loadConversations(showSpinner: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Block failed: $e')));
      return;
    }
    if (!mounted) return;
    _removeRequest(request.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('You blocked ${request.requesterName}')),
    );
  }

  void _reportRequester(ConnectionRequest request, String reason) async {
    if (!mounted) return;
    try {
      await MatchApi.reportUser(request.requesterId, reason);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Thanks for your report.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Report failed: $e')));
    }
  }

  Future<void> _confirmDecline(ConnectionRequest request) async {
    if (_responding) return;
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Decline request?',
      message:
          'Decline ${request.requesterName}? They will not become a Pal and cannot message you.',
      confirmLabel: 'Decline',
    );
    if (!confirmed || !mounted) return;
    await _respond(request, false);
  }

  ImageProvider? _requestAvatar(ConnectionRequest request) {
    if (request.photoUrls.isEmpty) return null;
    final url = request.photoUrls.first;
    if (url == null || url.trim().isEmpty) return null;
    return NetworkImage(url);
  }

  Future<void> _respond(ConnectionRequest request, bool accept) async {
    if (_responding) return;
    _responding = true;

    try {
      await MatchApi.respondToRequest(request.id, accept);
      await ChatStateService.instance.loadConversations(showSpinner: false);
      if (!mounted) return;

      ActivityService.instance.refresh();
      _removeRequest(request.id);

      if (!accept) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request from ${request.requesterName} declined.'),
          ),
        );
        return;
      }

      final action = await showRequestMatchSheet(
        context,
        name: request.requesterName,
        skillName: request.skillName,
        avatarImage: _requestAvatar(request),
      );
      if (!mounted || action != RequestMatchAction.sayHello) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => ChatRoom(
                connectionId: request.id,
                name: request.requesterName,
                skillName: request.skillName,
                role: request.role,
                person: request.toPerson(),
                avatarImage: _requestAvatar(request),
              ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to respond: $e')));
    } finally {
      _responding = false;
    }
  }

  void _openDetail(ConnectionRequest request) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder:
          (_) => RequestDetailDialog(
            person: request.toPerson(),
            onAccept: () {
              _respond(request, true);
            },
            onDecline: () {
              _confirmDecline(request);
            },
            onBlock: () => _blockRequester(request),
            onReport: (reason) => _reportRequester(request, reason),
          ),
    );
  }

  void _openFilterSheet() {
    if (_view == RequestView.sent) {
      FilterBottomSheet.show(
        context,
        sections: _sentFilterSections,
        selected: {
          'status': _sentStatusFilter,
          'date': _sentDateFilter.name,
          'sort': _sentSortFilter.name,
        },
        onApply: (result) {
          setState(() {
            _sentStatusFilter = result['status'] ?? 'all';
            _sentDateFilter = DateFilter.values.firstWhere(
              (d) => d.name == result['date'],
              orElse: () => DateFilter.all,
            );
            _sentSortFilter = SortFilter.values.firstWhere(
              (s) => s.name == result['sort'],
              orElse: () => SortFilter.newest,
            );
          });
        },
      );
      return;
    }
    FilterBottomSheet.show(
      context,
      sections: _filterSections,
      selected: {
        'date': _dateFilter.name,
        'role': _roleFilter.name,
        'sort': _sortFilter.name,
      },
      onApply: (result) {
        setState(() {
          _dateFilter = DateFilter.values.firstWhere(
            (d) => d.name == result['date'],
            orElse: () => DateFilter.all,
          );
          _roleFilter = RoleFilter.values.firstWhere(
            (r) => r.name == result['role'],
            orElse: () => RoleFilter.all,
          );
          _sortFilter = SortFilter.values.firstWhere(
            (s) => s.name == result['sort'],
            orElse: () => SortFilter.newest,
          );
        });
      },
    );
  }

  void _clearSentFilters() {
    setState(() {
      _sentStatusFilter = 'all';
      _sentDateFilter = DateFilter.all;
      _sentSortFilter = SortFilter.newest;
    });
  }

  Widget _buildViewToggle(Color textTheme) {
    Widget segment(String label, RequestView value) {
      final selected = _view == value;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          label: label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (_view == value) {
                if (value == RequestView.sent) _loadOutgoing();
                return;
              }
              setState(() => _view = value);
              if (value == RequestView.sent) _loadOutgoing();
            },
            child: AnimatedContainer(
              duration: AppMotion.base,
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: AppTextStyles.regularText.copyWith(
                  color:
                      selected
                          ? Colors.black
                          : textTheme.withValues(alpha: 0.65),
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 44,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: textTheme.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          segment('Incoming', RequestView.incoming),
          segment('Sent', RequestView.sent),
        ],
      ),
    );
  }

  Widget _buildIncoming(Color textTheme) {
    final requests = _filteredAndSortedRequests;
    if (_loading) return const RequestCardsSkeleton();
    if (_loadError != null) return _buildLoadError(textTheme);
    if (requests.isEmpty) return _buildEmptyState(textTheme);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: requests.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'They want to connect with you. Accept to become Pals.',
              style: AppTextStyles.regularText.copyWith(
                color: textTheme.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          );
        }
        final request = requests[index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: GestureDetector(
            onTap: () => _openDetail(request),
            child: RequestCard(
              skillName: request.skillName,
              requesterName: request.requesterName,
              schedule: request.schedule,
              language: request.language,
              learningStyle: request.learningStyle,
              timeAgo: timeAgo(request.requestedAt),
              iconAsset: request.iconAsset,
              seekingLabel: request.seekingLabel,
              onAccept: () => _respond(request, true),
              onDecline: () => _confirmDecline(request),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSent(Color textTheme) {
    if (_loadingOutgoing) {
      return const ListRowsSkeleton(count: 3, rowHeight: 96);
    }
    if (_outgoingError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _outgoingError!,
                textAlign: TextAlign.center,
                style: AppTextStyles.regularText.copyWith(color: textTheme),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadOutgoing,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_outgoing.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.outbox_outlined,
                size: 44,
                color: textTheme.withValues(alpha: 0.35),
              ),
              const SizedBox(height: 12),
              Text(
                'No sent requests yet',
                style: AppTextStyles.boldText.copyWith(color: textTheme),
              ),
              const SizedBox(height: 6),
              Text(
                'Requests you send from For You or Browse will appear here. Accepted requests move to Pals.',
                textAlign: TextAlign.center,
                style: AppTextStyles.regularText.copyWith(
                  color: textTheme.withValues(alpha: 0.65),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const Matches()),
                  );
                },
                child: const Text('View Pals'),
              ),
            ],
          ),
        ),
      );
    }

    final requests = _filteredAndSortedOutgoing;
    if (requests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.filter_alt_off_outlined,
                size: 44,
                color: textTheme.withValues(alpha: 0.35),
              ),
              const SizedBox(height: 12),
              Text(
                'No sent requests match your filters',
                textAlign: TextAlign.center,
                style: AppTextStyles.boldText.copyWith(color: textTheme),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _clearSentFilters,
                child: const Text('Clear filters'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: requests.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pending and declined requests. Accepted requests move to Pals.',
                  style: AppTextStyles.regularText.copyWith(
                    color: textTheme.withValues(alpha: 0.7),
                    fontSize: 14,
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const Matches()),
                      );
                    },
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text('View Pals'),
                  ),
                ),
              ],
            ),
          );
        }
        final request = requests[index - 1];
        return _SentRequestCard(
          request: request,
          onWithdraw: request.isPending ? () => _cancelOutgoing(request) : null,
        );
      },
    );
  }

  Widget _buildLoadError(Color textTheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _loadError!,
              textAlign: TextAlign.center,
              style: AppTextStyles.regularText.copyWith(color: textTheme),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadRequests,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text(
                'Retry',
                style: TextStyle(color: Colors.black, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color textTheme) {
    final filteredOut = _requests.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 110),
      child: Center(
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
              filteredOut
                  ? 'No requests match your filters'
                  : 'No requests yet',
              textAlign: TextAlign.center,
              style: AppTextStyles.regularText.copyWith(
                color: textTheme.withValues(alpha: 0.7),
              ),
            ),
            if (filteredOut) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    _dateFilter = DateFilter.all;
                    _roleFilter = RoleFilter.all;
                    _sortFilter = SortFilter.newest;
                  });
                },
                child: const Text('Clear filters'),
              ),
            ],
          ],
        ),
      ),
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
        leading:
            ModalRoute.of(context)?.isFirst == false
                ? IconButton(
                  tooltip: 'Back',
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.arrow_back_ios_new,
                    size: 16,
                    color: textTheme,
                  ),
                )
                : null,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                'Requests',
                style: AppTextStyles.headingText.copyWith(color: textTheme),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Activity',
                onPressed:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationsPage(),
                      ),
                    ),
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      color: textTheme,
                      size: 24,
                    ),
                    if (PreferencesService.instance.notificationsEnabled &&
                        ActivityService.instance.unread > 0)
                      Positioned(
                        right: -1,
                        top: -1,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Semantics(
                container: true,
                button: true,
                label:
                    _view == RequestView.incoming
                        ? 'Filter requests'
                        : 'Filter sent requests',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _openFilterSheet,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: Icon(Icons.tune, color: textTheme, size: 24),
                        ),
                        if (_view == RequestView.incoming
                            ? _hasActiveFilter
                            : _hasSentFilter)
                          Positioned(
                            right: -2,
                            top: 9,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppColors.accentText(context),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          _buildViewToggle(textTheme),
          Expanded(
            child:
                _view == RequestView.incoming
                    ? _buildIncoming(textTheme)
                    : _buildSent(textTheme),
          ),
        ],
      ),
    );
  }
}

class _SentRequestCard extends StatelessWidget {
  final OutgoingRequestLite request;
  final VoidCallback? onWithdraw;

  const _SentRequestCard({required this.request, this.onWithdraw});

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.secondary;
    final statusColor =
        request.isPending
            ? AppColors.accentText(context)
            : AppColors.dangerText(context);
    final statusLabel = request.isPending ? 'Waiting for reply' : 'Declined';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(
            name: request.recipientName,
            image:
                request.avatarUrl == null
                    ? null
                    : NetworkImage(request.avatarUrl!),
            size: 48,
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
                        request.recipientName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.boldText.copyWith(
                          color: textColor,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        statusLabel,
                        style: AppTextStyles.regularText.copyWith(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  request.skills.isEmpty
                      ? 'Skill exchange'
                      : request.skills.first,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.regularText.copyWith(
                    color: textColor.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timeAgo(request.createdAt),
                  style: AppTextStyles.regularText.copyWith(
                    color: AppColors.mutedText(context),
                    fontSize: 12,
                  ),
                ),
                if (onWithdraw != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: onWithdraw,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.dangerText(context),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: const Size(0, 36),
                      ),
                      child: const Text('Withdraw request'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
