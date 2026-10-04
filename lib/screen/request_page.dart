import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/screen/card/request_card.dart';
import 'package:palturo/screen/card/person_card.dart';
import 'package:palturo/screen/card/request_detail.dart';
import 'package:palturo/screen/users_dump.dart';

class ConnectionRequest {
  final String id;
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
      id: id,
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

  Color get _filterDotColor => AppColors.primary;

  bool get _hasActiveFilter =>
      _dateFilter != DateFilter.all ||
      _roleFilter != RoleFilter.all ||
      _sortFilter != SortFilter.newest;

  late final List<ConnectionRequest> _requests = [
    ConnectionRequest(
      id: '1',
      skillName: 'Parol Making',
      requesterName: 'RJ',
      schedule: 'Mon/Wed/Sat',
      language: 'English',
      learningStyle: 'Discussion',
      bio: 'Gusto kong matutong gumawa ng parol para sa pamilya ko.',
      requestedAt: DateTime.now().subtract(const Duration(minutes: 2)),
      role: PersonRole.learner,
      photoUrls: const [null, null],
    ),
    ConnectionRequest(
      id: '2',
      skillName: 'Weaving Inabel',
      requesterName: 'Maria',
      schedule: 'Tue/Thu',
      language: 'Tagalog',
      learningStyle: 'Hands-on Practice',
      bio: 'Lumaki ako sa tabi ng habihan ni Lola. Tuturuan kita nang dahan-dahan.',
      requestedAt: DateTime.now().subtract(const Duration(days: 1)),
      role: PersonRole.mentor,
      photoUrls: const [null],
    ),
    ..._dumpRequests(),
  ];

  static List<ConnectionRequest> _dumpRequests() {
    final candidates =
        dumpUsers.where((u) => u.lastMessage == null).take(8).toList();
    final now = DateTime.now();
    return [
      for (var i = 0; i < candidates.length; i++)
        ConnectionRequest.fromMatchedUser(
          candidates[i],
          requestedAt: now.subtract(Duration(hours: 3 + i * 9)),
        ),
    ];
  }

  bool _matchesDateFilter(DateTime date) {
    final now = DateTime.now();
    switch (_dateFilter) {
      case DateFilter.all:
        return true;
      case DateFilter.today:
        return date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;
      case DateFilter.thisWeek:
        return now.difference(date).inDays <= 7;
      case DateFilter.thisMonth:
        return date.year == now.year && date.month == now.month;
      case DateFilter.thisYear:
        return date.year == now.year;
    }
  }

  List<ConnectionRequest> get _filteredAndSortedRequests {
    var filtered = _requests.where((r) {
      final matchesDate = _matchesDateFilter(r.requestedAt);
      final matchesRole = _roleFilter == RoleFilter.all ||
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

  void _openDetail(ConnectionRequest request) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => RequestDetailDialog(
        person: request.toPerson(),
        onAccept: () => _removeRequest(request.id),
        onDecline: () => _removeRequest(request.id),
      ),
    );
  }

  void _openFilterSheet() {
    DateFilter draftDate = _dateFilter;
    RoleFilter draftRole = _roleFilter;
    SortFilter draftSort = _sortFilter;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final textColor = Theme.of(context).colorScheme.secondary;
        final primaryColor = Theme.of(context).colorScheme.primary;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Filters',
                            style: AppTextStyles.boldText.copyWith(
                              color: textColor,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setModalState(() {
                            draftDate = DateFilter.all;
                            draftRole = RoleFilter.all;
                            draftSort = SortFilter.newest;
                          }),
                          child: Text(
                            'Reset',
                            style: AppTextStyles.regularText.copyWith(
                              color: textColor.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sheetSectionLabel('Date', textColor),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _filterChip(
                                  'All',
                                  draftDate == DateFilter.all,
                                  () => setModalState(
                                      () => draftDate = DateFilter.all),
                                  primaryColor,
                                  textColor,
                                ),
                                _filterChip(
                                  'Today',
                                  draftDate == DateFilter.today,
                                  () => setModalState(
                                      () => draftDate = DateFilter.today),
                                  primaryColor,
                                  textColor,
                                ),
                                _filterChip(
                                  'This Week',
                                  draftDate == DateFilter.thisWeek,
                                  () => setModalState(
                                      () => draftDate = DateFilter.thisWeek),
                                  primaryColor,
                                  textColor,
                                ),
                                _filterChip(
                                  'This Month',
                                  draftDate == DateFilter.thisMonth,
                                  () => setModalState(
                                      () => draftDate = DateFilter.thisMonth),
                                  primaryColor,
                                  textColor,
                                ),
                                _filterChip(
                                  'This Year',
                                  draftDate == DateFilter.thisYear,
                                  () => setModalState(
                                      () => draftDate = DateFilter.thisYear),
                                  primaryColor,
                                  textColor,
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _sheetSectionLabel('Role', textColor),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _filterChip(
                                  'All',
                                  draftRole == RoleFilter.all,
                                  () => setModalState(
                                      () => draftRole = RoleFilter.all),
                                  primaryColor,
                                  textColor,
                                ),
                                _filterChip(
                                  'Learner',
                                  draftRole == RoleFilter.learner,
                                  () => setModalState(
                                      () => draftRole = RoleFilter.learner),
                                  primaryColor,
                                  textColor,
                                ),
                                _filterChip(
                                  'Mentor',
                                  draftRole == RoleFilter.mentor,
                                  () => setModalState(
                                      () => draftRole = RoleFilter.mentor),
                                  primaryColor,
                                  textColor,
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _sheetSectionLabel('Skills', textColor),
                            const SizedBox(height: 8),
                            Text(
                              'Coming soon',
                              style: AppTextStyles.regularText.copyWith(
                                color: textColor.withValues(alpha: 0.4),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 20),
                            _sheetSectionLabel('Filter', textColor),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _filterChip(
                                  'Newest',
                                  draftSort == SortFilter.newest,
                                  () => setModalState(
                                      () => draftSort = SortFilter.newest),
                                  primaryColor,
                                  textColor,
                                ),
                                _filterChip(
                                  'Oldest',
                                  draftSort == SortFilter.oldest,
                                  () => setModalState(
                                      () => draftSort = SortFilter.oldest),
                                  primaryColor,
                                  textColor,
                                ),
                                _filterChip(
                                  'Ascending (A-Z)',
                                  draftSort == SortFilter.ascending,
                                  () => setModalState(
                                      () => draftSort = SortFilter.ascending),
                                  primaryColor,
                                  textColor,
                                ),
                                _filterChip(
                                  'Descending (Z-A)',
                                  draftSort == SortFilter.descending,
                                  () => setModalState(
                                      () => draftSort = SortFilter.descending),
                                  primaryColor,
                                  textColor,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          setState(() {
                            _dateFilter = draftDate;
                            _roleFilter = draftRole;
                            _sortFilter = draftSort;
                          });
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Apply',
                          style: TextStyle(color: Colors.black, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _sheetSectionLabel(String label, Color textColor) {
    return Text(
      label,
      style: AppTextStyles.regularText.copyWith(
        color: textColor,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _filterChip(
    String label,
    bool isSelected,
    VoidCallback onTap,
    Color primaryColor,
    Color textColor,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.secondary
                : textColor.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.regularText.copyWith(
            color: isSelected ? AppColors.black : textColor,
            fontSize: 13,
          ),
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
        titleSpacing: 16,
        title: Row(
          children: [
            Text(
              'Requests',
              style: AppTextStyles.headingText.copyWith(color: textTheme),
            ),
            const Spacer(),
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  onPressed: _openFilterSheet,
                  icon: Icon(Icons.tune, color: textTheme, size: 22),
                ),
                if (_hasActiveFilter)
                  Positioned(
                    right: 10,
                    top: 10,
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
          ],
        ),
      ),
      body: ListView.builder(
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
                  fontSize: 16,
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
                onAccept: () => _removeRequest(request.id),
                onDecline: () => _removeRequest(request.id),
              ),
            ),
          );
        },
      ),
    );
  }
}