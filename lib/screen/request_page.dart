import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/screen/card/request_card.dart';
import 'package:palturo/screen/card/person_card.dart';
import 'package:palturo/screen/card/request_detail.dart';
import 'package:palturo/screen/users_dump.dart';
import 'package:palturo/screen/utils/filter_bottom_sheet.dart';
import 'package:palturo/services/match_api.dart';

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

class RequestPage extends StatefulWidget {
  const RequestPage({super.key});

  @override
  State<RequestPage> createState() => _RequestPageState();
}

class _RequestPageState extends State<RequestPage> {
  DateFilter _dateFilter = DateFilter.all;
  RoleFilter _roleFilter = RoleFilter.all;
  SortFilter _sortFilter = SortFilter.newest;

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
    FilterSection(key: 'skills', title: 'Skills'),
    FilterSection(
      key: 'sort',
      title: 'Filter',
      defaultValue: 'newest',
      options: [
        FilterOption('Newest', 'newest'),
        FilterOption('Oldest', 'oldest'),
        FilterOption('Ascending (A-Z)', 'ascending'),
        FilterOption('Descending (Z-A)', 'descending'),
      ],
    ),
  ];

  Color get _filterDotColor => AppColors.primary;

  bool get _hasActiveFilter =>
      _dateFilter != DateFilter.all ||
      _roleFilter != RoleFilter.all ||
      _sortFilter != SortFilter.newest;

  late List<ConnectionRequest> _requests = const [];
  bool _loading = true;
  String? _loadError;
  bool _responding = false;

  @override
  void initState() {
    super.initState();
    _loadRequests();
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

  void _removeRequest(String id) {
    setState(() {
      _requests.removeWhere((r) => r.id == id);
    });
  }

  void _blockRequester(ConnectionRequest request) async {
    if (!mounted) return;
    try {
      await MatchApi.blockUser(request.requesterId);
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

  Future<void> _respond(ConnectionRequest request, bool accept) async {
    if (_responding) return;
    _responding = true;

    try {
      await MatchApi.respondToRequest(request.id, accept);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? 'Connected with ${request.requesterName}!'
                : 'Request from ${request.requesterName} declined.',
          ),
        ),
      );
      _removeRequest(request.id);
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
              _respond(request, false);
            },
            onBlock: () => _blockRequester(request),
            onReport: (reason) => _reportRequester(request, reason),
          ),
    );
  }

  void _openFilterSheet() {
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
              filteredOut ? 'No requests found' : 'No requests yet',
              textAlign: TextAlign.center,
              style: AppTextStyles.regularText.copyWith(
                color: textTheme.withValues(alpha: 0.7),
              ),
            ),
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

    final requests = _filteredAndSortedRequests;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        toolbarHeight: adaptiveHeight,
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        automaticallyImplyLeading: false,
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
              GestureDetector(
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
                      if (_hasActiveFilter)
                        Positioned(
                          right: -2,
                          top: 9,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _filterDotColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _loadError != null
              ? _buildLoadError(textTheme)
              : requests.isEmpty
              ? _buildEmptyState(textTheme)
              : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                itemCount: requests.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        'They want to connect with you. Like back to start exchanging skills right away!',
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
                        onDecline: () => _respond(request, false),
                      ),
                    ),
                  );
                },
              ),
    );
  }
}
