import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:palturo/screen/card/person_card.dart';
import 'package:palturo/screen/action_dialogs.dart';
import 'package:palturo/screen/profile_data.dart';
import 'package:palturo/screen/profile_edit.dart';
import 'package:palturo/services/match_api.dart';
import 'package:palturo/services/profile_service.dart';
import 'package:palturo/onboarding/onboarding_models.dart';

enum RoleFilter { all, learner, mentor }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Person> _people = const [];
  bool _loading = true;
  String? _error;
  ProfileData? _myProfile;

  final ProfileData _fallbackSelfProfile = ProfileData(
    name: 'You',
    schedule: 'Select your availability',
  );

  late final TapGestureRecognizer _settingsTap =
      TapGestureRecognizer()..onTap = _openSettings;

  RoleFilter _roleFilter = RoleFilter.all;
  int _currentIndex = 0;
  final List<int> _history = [];

  @override
  void initState() {
    super.initState();
    _loadDeck();
  }

  /// Loads the live recommendation deck (get-matches + public profiles).
  Future<void> _loadDeck() async {
    setState(() {
      _loading = true;
      _error = null;
      _currentIndex = 0;
      _history.clear();
    });
    try {
      final me = await ProfileService().getCurrentUserProfile();
      if (!mounted) return;
      setState(() => _myProfile = me);

      // Candidate side for retrieval: chips pick directly, "All" = opposite role.
      final String asRole = switch (_roleFilter) {
        RoleFilter.learner => 'learner',
        RoleFilter.mentor => 'mentor',
        RoleFilter.all =>
          (me?.role == OnboardingRole.teach) ? 'learner' : 'mentor',
      };

      final deck = await MatchApi.getMatchDeck(asRoleDb: asRole);
      if (!mounted) return;
      setState(() => _people = deck);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// Live "Add": sends a connection request from the feed (FR-9).
  Future<void> _confirmAdd(Person person) async {
    try {
      await MatchApi.sendConnectionRequest(person.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection request sent to ${person.name}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request failed: $e')),
      );
    }
    _next();
  }

  @override
  void dispose() {
    _settingsTap.dispose();
    super.dispose();
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ProfileEditPage(profile: _myProfile ?? _fallbackSelfProfile),
      ),
    );
  }

  bool get _hasActiveFilter => _roleFilter != RoleFilter.all;

  /// Role selection happens at retrieval time (as_role) — deck is prefiltered.
  List<Person> get _filteredPeople => _people;

  void _next() {
    setState(() {
      _history.add(_currentIndex);
      _currentIndex++;
    });
  }

  void _undo() {
    if (_history.isEmpty) return;
    setState(() {
      _currentIndex = _history.removeLast();
    });
  }

  Future<void> _confirmBlock(Person person) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Block',
      message:
          '${person.name} won’t be able to find or message you. You can unblock them anytime in Settings.',
      confirmLabel: 'Block',
    );
    if (!confirmed || !mounted) return;

    try {
      await MatchApi.blockUser(person.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You blocked ${person.name}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Block failed: $e')),
      );
    }
    _next();
  }

  Future<void> _confirmReport(Person person) async {
    final reason = await showReportReasonDialog(context, name: person.name);
    if (reason == null || !mounted) return;

    try {
      await MatchApi.reportUser(person.id, reason);
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
    _next();
  }

  void _openFilterSheet() {
    RoleFilter draftRole = _roleFilter;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final textColor = Theme.of(context).colorScheme.secondary;
        final primaryColor = AppColors.primary;

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
                          onPressed:
                              () => setModalState(
                                () => draftRole = RoleFilter.all,
                              ),
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
                    _sheetSectionLabel('Role', textColor),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _filterChip(
                          'All',
                          draftRole == RoleFilter.all,
                          () => setModalState(() => draftRole = RoleFilter.all),
                          primaryColor,
                          textColor,
                        ),
                        _filterChip(
                          'Learner',
                          draftRole == RoleFilter.learner,
                          () => setModalState(
                            () => draftRole = RoleFilter.learner,
                          ),
                          primaryColor,
                          textColor,
                        ),
                        _filterChip(
                          'Mentor',
                          draftRole == RoleFilter.mentor,
                          () => setModalState(
                            () => draftRole = RoleFilter.mentor,
                          ),
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
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          if (draftRole != _roleFilter) {
                            _roleFilter = draftRole;
                            _loadDeck();
                          }
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
          color: isSelected ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryColor : textColor.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.regularText.copyWith(
            color: isSelected ? Colors.black : textColor,
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

    final people = _filteredPeople;
    final hasMore = _currentIndex < people.length;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        toolbarHeight: adaptiveHeight,
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'PalTuro',
              style: AppTextStyles.headingText.copyWith(color: textTheme),
            ),
            Row(
              children: [
                IconButton(
                  onPressed: _history.isEmpty ? null : _undo,
                  icon: Icon(
                    CupertinoIcons.arrow_uturn_left,
                    color:
                        _history.isEmpty
                            ? textTheme.withValues(alpha: 0.3)
                            : textTheme,
                    size: 24,
                  ),
                ),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      onPressed: _openFilterSheet,
                      icon: Icon(Icons.tune, color: textTheme, size: 24),
                    ),
                    if (_hasActiveFilter)
                      Positioned(
                        right: 8,
                        top: 8,
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
              ],
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildErrorState(textTheme)
                : hasMore
                    ? Dismissible(
                        key: ValueKey(people[_currentIndex].id),
                        direction: DismissDirection.horizontal,
                        background: _swipeBackground(
                          alignment: Alignment.centerLeft,
                          color: AppColors.primary,
                          icon: Icons.check,
                        ),
                        secondaryBackground: _swipeBackground(
                          alignment: Alignment.centerRight,
                          color: Colors.red,
                          icon: Icons.close,
                        ),
                        onDismissed: (_) => _next(),
                        child: PersonCardOverlay(
                          person: people[_currentIndex],
                          onAdd: () => _confirmAdd(people[_currentIndex]),
                          onSkip: _next,
                          onBlock: () => _confirmBlock(people[_currentIndex]),
                          onReport: () => _confirmReport(people[_currentIndex]),
                        ),
                      )
                    : _buildEmptyState(textTheme),
      ),
    );
  }

  Widget _buildErrorState(Color textColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Couldn’t load recommendations.\nPlease check your connection.',
              style: AppTextStyles.regularText.copyWith(color: textColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadDeck,
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
            Text.rich(
              TextSpan(
                style: AppTextStyles.regularText.copyWith(
                  color: textColor.withValues(alpha: 0.7),
                ),
                children: [
                  const TextSpan(text: 'Nothing more to show\n'),
                  const TextSpan(text: 'Consider changing your '),
                  TextSpan(
                    text: 'Settings',
                    recognizer: _settingsTap,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _swipeBackground({
    required Alignment alignment,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(28),
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Icon(icon, color: color, size: 36),
    );
  }
}
