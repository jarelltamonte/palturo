import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/widgets/app_chrome.dart';
import 'package:palturo/theme/app_spacing.dart';
import 'package:palturo/theme/app_motion.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/widgets/app_feedback.dart';
import 'package:palturo/widgets/app_skeleton.dart';
import 'package:palturo/utils/friendly_error.dart';
import 'package:palturo/screen/explore_category_page.dart';
import 'package:palturo/screen/explore_taxonomy.dart';
import 'package:palturo/screen/profile_edit.dart';
import 'package:palturo/services/match_api.dart';
import 'package:palturo/services/preferences_service.dart';
import 'package:palturo/services/profile_service.dart';

enum ExploreRole { learner, mentor }

/// The domain the field guide features on a given day.
///
/// Domains rotate daily through a stable path-sorted list, so the featured
/// pick changes each day but stays put across reloads on the same day.
Map<String, dynamic>? featuredDomainForDay(
  List<Map<String, dynamic>> roots,
  DateTime day,
) {
  if (roots.isEmpty) return null;
  final ordered = [...roots]..sort(
    (a, b) =>
        (a['path'] ?? '').toString().compareTo((b['path'] ?? '').toString()),
  );
  final start = DateTime.utc(2024, 1, 1);
  final days =
      DateTime.utc(day.year, day.month, day.day).difference(start).inDays;
  final index = days % ordered.length;
  return ordered[index < 0 ? index + ordered.length : index];
}

class ExplorePage extends StatefulWidget {
  /// Test hooks. Production leaves these null.
  final Future<List<Map<String, dynamic>>> Function()? taxonomyLoader;
  final Future<int> Function(String path, {required String kind})? countLoader;
  final Future<List<Map<String, dynamic>>> Function()? skillsLoader;
  final DateTime Function()? now;

  const ExplorePage({
    super.key,
    this.taxonomyLoader,
    this.countLoader,
    this.skillsLoader,
    this.now,
  });

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _roots = const [];
  Map<String, int> _rootCounts = const {};
  bool _hasMentorSkills = false;
  bool _loading = true;
  String? _error;
  String _query = '';

  static const _roleKey = 'browse_mentor_mode';

  ExploreRole _role = ExploreRole.learner;

  int _requestId = 0;

  static const Map<String, String> _descriptionRules = {
    'cook': 'Recipes, flavors, and kitchen traditions',
    'craft': 'Weaving, carving, and handmade heritage',
    'perform': 'Music, dance, and stage traditions',
    'martial': 'Combat arts and discipline',
    'language': 'Languages, scripts, and storytelling',
    'household': 'Everyday skills for the home',
    'agricult': 'Farming, fishing, and local trades',
    'modern': "Useful skills for today's world",
    'visual': 'Drawing, painting, and design',
  };

  static const String _fallbackDescription =
      'Skills shared by the PalTuro community';

  String _descriptionFor(Map<String, dynamic> node) {
    final key = '${node['path'] ?? ''} ${node['name'] ?? ''}'.toLowerCase();
    for (final rule in _descriptionRules.entries) {
      if (key.contains(rule.key)) return rule.value;
    }
    return _fallbackDescription;
  }

  @override
  void initState() {
    super.initState();
    _loadSavedRole();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredRoots {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _roots;
    return _roots.where((node) {
      final label = (node['name'] ?? '').toString().toLowerCase();
      final description = _descriptionFor(node).toLowerCase();
      return label.contains(query) || description.contains(query);
    }).toList();
  }

  Map<String, dynamic>? get _featuredRoot =>
      featuredDomainForDay(_roots, (widget.now ?? DateTime.now)());

  String get _roleNoun => _role == ExploreRole.mentor ? 'learner' : 'mentor';

  int _countFor(Map<String, dynamic> node) =>
      _rootCounts[(node['path'] ?? '').toString()] ?? 0;

  Future<void> _loadSavedRole() async {
    var mentor = false;
    try {
      mentor = await PreferencesService.instance.getBool(_roleKey) ?? false;
    } catch (_) {
      // Preference failure falls back to the learner view.
    }
    if (!mounted) return;
    setState(() {
      _role = mentor ? ExploreRole.mentor : ExploreRole.learner;
    });
    _loadTaxonomy();
  }

  /// Learner: return all roots.
  /// Mentor: return only roots related to the user's mentor skills. The
  /// `hasMentorSkills` flag travels with the result so a superseded request
  /// cannot leave the empty state describing the wrong situation.
  Future<({List<Map<String, dynamic>> roots, bool hasMentorSkills})>
  _filterByRole(List<Map<String, dynamic>> roots) async {
    if (_role == ExploreRole.learner) {
      return (roots: roots, hasMentorSkills: false);
    }

    final skills =
        widget.skillsLoader != null
            ? await widget.skillsLoader!()
            : await MatchApi.mySkills();
    final mentorPaths =
        skills
            .where((skill) => skill['kind'] == 'teach')
            .map((skill) => (skill['path'] ?? '') as String)
            .where((path) => path.isNotEmpty)
            .toList();

    final filtered =
        roots.where((root) {
          final rootPath = (root['path'] ?? '') as String;
          if (rootPath.isEmpty) return false;
          return mentorPaths.any(
            (path) => path == rootPath || path.startsWith('$rootPath.'),
          );
        }).toList();

    return (roots: filtered, hasMentorSkills: mentorPaths.isNotEmpty);
  }

  /// Counts the people available under each root for the active role. Empty
  /// branches are hidden and the counts make the remaining cards informative.
  Future<Map<String, int>> _rootCountsFor(
    List<Map<String, dynamic>> roots,
  ) async {
    if (roots.isEmpty) return const <String, int>{};
    final kind = _role == ExploreRole.mentor ? 'learn' : 'teach';
    final entries = await Future.wait(
      roots.map((root) async {
        final path = (root['path'] ?? '').toString();
        if (path.isEmpty) return const MapEntry('', 0);
        try {
          final count =
              widget.countLoader != null
                  ? await widget.countLoader!(path, kind: kind)
                  : (await MatchApi.browseSkillUsers(path, kind: kind)).length;
          return MapEntry(path, count);
        } catch (e) {
          // A failed count must not hide a valid category.
          debugPrint('[Browse] count failed for $path: $e');
          return MapEntry(path, 1);
        }
      }),
    );
    return Map<String, int>.fromEntries(entries);
  }

  Future<void> _loadTaxonomy({bool notifyFailure = false}) async {
    final requestId = ++_requestId;
    final hadData = _roots.isNotEmpty;
    if (!hadData) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final nodes =
          widget.taxonomyLoader != null
              ? await widget.taxonomyLoader!()
              : await MatchApi.taxonomyVisible();
      final roots =
          nodes.where((n) => (n['depth'] as num?)?.toInt() == 1).toList();
      final roleResult = await _filterByRole(roots);
      final counts = await _rootCountsFor(roleResult.roots);
      if (!mounted || requestId != _requestId) return;
      final visible =
          roleResult.roots
              .where(
                (root) => (counts[(root['path'] ?? '').toString()] ?? 1) > 0,
              )
              .toList();
      setState(() {
        _roots = visible;
        _rootCounts = counts;
        _hasMentorSkills = roleResult.hasMentorSkills;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || requestId != _requestId) return;
      final message = friendlyError(
        e,
        fallback: "Couldn't load domains. Please try again.",
      );
      setState(() {
        _loading = false;
        if (!hadData) _error = message;
      });
      if (notifyFailure && hadData) showAppError(context, message);
    }
  }

  Future<void> _refreshTaxonomy() => _loadTaxonomy(notifyFailure: true);

  void _onRoleChanged(ExploreRole role) {
    if (role == _role) return;
    setState(() => _role = role);
    PreferencesService.instance
        .setBool(_roleKey, role == ExploreRole.mentor)
        .catchError((Object _) {});
    _loadTaxonomy();
  }

  void _openCategory(Map<String, dynamic> root) {
    final path = (root['path'] ?? '').toString();
    final label = (root['name'] ?? '').toString();
    if (path.isEmpty || label.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ExploreCategoryPage(
              nodePath: path,
              nodeLabel: label,
              description: _descriptionFor(root),
              mentor: _role == ExploreRole.mentor,
            ),
      ),
    );
  }

  Future<void> _openProfileEditor() async {
    final profile = await ProfileService().getCurrentUserProfile();
    if (!mounted) return;
    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Couldn’t load your profile. Please try again.'),
        ),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileEditPage(profile: profile)),
    );
    if (mounted) _loadTaxonomy();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;
    final muted = _fgMuted(context);
    final featured = _query.trim().isEmpty ? _featuredRoot : null;
    final roots = _filteredRoots;
    final featuredPath = (featured?['path'] ?? '').toString();
    final gridRoots =
        featured == null
            ? roots
            : roots
                .where(
                  (node) => (node['path'] ?? '').toString() != featuredPath,
                )
                .toList();
    final appBarHeight = math.max(
      AppSpacing.topBarHeight(),
      MediaQuery.textScalerOf(context).scale(24) + 24,
    );

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppChrome.appBar(
        toolbarHeight: appBarHeight,
        title: Text(
          'Browse',
          style: AppTextStyles.headingText.copyWith(color: textTheme),
        ),
        actions: [
          AppChrome.iconAction(
            icon: CupertinoIcons.question_circle,
            tooltip: 'How Browse works',
            color: textTheme,
            onPressed: () {
              showAdaptiveDialog(
                context: context,
                builder: (context) => const _ExploreInfoDialog(),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshTaxonomy,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            AppSpacing.bottomNavClearanceFor(context),
          ),
          children: [
            Text(
              'Follow a craft, meet the person behind it.',
              style: AppTextStyles.regularText.copyWith(
                fontSize: 13,
                height: 1.45,
                color: muted,
              ),
            ),
            const SizedBox(height: 12),
            _FieldGuideSearch(
              controller: _searchController,
              query: _query,
              onChanged: (value) => setState(() => _query = value),
              onClear: () {
                _searchController.clear();
                setState(() => _query = '');
              },
            ),
            const SizedBox(height: 10),
            _RoleToggle(value: _role, onChanged: _onRoleChanged),
            const SizedBox(height: 14),
            if (_loading)
              const _FieldGuideSkeleton()
            else if (_error != null)
              _buildErrorState(context)
            else if (_roots.isEmpty)
              _buildEmptyState(context)
            else if (roots.isEmpty)
              _buildSearchEmpty(context)
            else ...[
              if (featured != null) ...[
                _FeaturedDomainCard(
                  label: (featured['name'] ?? '').toString(),
                  description: _descriptionFor(featured),
                  icon: exploreRootIcon(featuredPath),
                  count: _countFor(featured),
                  countLabel: _roleNoun,
                  onTap: () => _openCategory(featured),
                ),
                const SizedBox(height: 14),
              ],
              if (gridRoots.isNotEmpty) ...[
                _buildSectionLabel(context, featuredShown: featured != null),
                const SizedBox(height: 8),
                _buildDomainGrid(context, gridRoots),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(
    BuildContext context, {
    bool featuredShown = false,
  }) {
    final muted = _fgMuted(context);
    final label =
        _query.trim().isNotEmpty
            ? 'RESULTS'
            : featuredShown
            ? 'MORE DOMAINS'
            : 'ALL DOMAINS';
    return Text(
      label,
      style: AppTextStyles.boldText.copyWith(
        fontSize: 10,
        letterSpacing: 1.2,
        color: muted,
      ),
    );
  }

  Widget _buildDomainGrid(
    BuildContext context,
    List<Map<String, dynamic>> roots,
  ) {
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    final cardHeight = (132 * scale).toDouble();
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            constraints.maxWidth >= 1000
                ? 4
                : constraints.maxWidth >= 900
                ? 3
                : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: roots.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: cardHeight,
          ),
          itemBuilder: (context, index) {
            final node = roots[index];
            final path = (node['path'] ?? '').toString();
            return _DomainCard(
              label: (node['name'] ?? '').toString(),
              description: _descriptionFor(node),
              icon: exploreRootIcon(path),
              tint: exploreTileTint(context),
              count: _rootCounts[path] ?? 0,
              countLabel: _roleNoun,
              onTap: () => _openCategory(node),
            );
          },
        );
      },
    );
  }

  Widget _buildSearchEmpty(BuildContext context) {
    final muted = _fgMuted(context);
    return SizedBox(
      height: 320,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No domains match "${_query.trim()}".',
              textAlign: TextAlign.center,
              style: AppTextStyles.regularText.copyWith(
                fontSize: 14,
                color: muted,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                _searchController.clear();
                setState(() => _query = '');
              },
              child: const Text('Clear search'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final muted = _fgMuted(context);
    return SizedBox(
      height: 320,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _role == ExploreRole.mentor
                  ? _hasMentorSkills
                      ? 'No learners are looking for your skills right now. Check back soon.'
                      : 'You haven\'t added any mentor skills yet. Add some to your profile and matching domains will show up here.'
                  : 'No domains available right now.',
              textAlign: TextAlign.center,
              style: AppTextStyles.regularText.copyWith(
                fontSize: 14,
                color: muted,
              ),
            ),
            if (_role == ExploreRole.mentor) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed:
                    _hasMentorSkills ? _loadTaxonomy : _openProfileEditor,
                child: Text(
                  _hasMentorSkills
                      ? 'Check again'
                      : 'Update your teaching skills',
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _loadTaxonomy,
                child: const Text('Refresh domains'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final muted = _fgMuted(context);
    return SizedBox(
      height: 320,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error ?? "Couldn't load domains. Please try again.",
              textAlign: TextAlign.center,
              style: AppTextStyles.regularText.copyWith(
                fontSize: 14,
                color: muted,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadTaxonomy,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleToggle extends StatelessWidget {
  const _RoleToggle({required this.value, required this.onChanged});

  final ExploreRole value;
  final ValueChanged<ExploreRole> onChanged;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.secondary;
    final isMentor = value == ExploreRole.mentor;

    Widget segment(String label, String svgAsset, ExploreRole role) {
      final selected = value == role;
      final contentColor =
          selected ? Colors.black : textColor.withValues(alpha: 0.7);

      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          label: '$label role',
          excludeSemantics: true,
          onTap: () => onChanged(role),
          child: InkWell(
            onTap: () => onChanged(role),
            borderRadius: BorderRadius.circular(999),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<Color?>(
                    tween: ColorTween(end: contentColor),
                    duration: AppMotion.base,
                    builder: (context, color, _) {
                      return SvgPicture.asset(
                        svgAsset,
                        width: 18,
                        height: 18,
                        colorFilter: ColorFilter.mode(
                          color ?? contentColor,
                          BlendMode.srcIn,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: AnimatedDefaultTextStyle(
                      duration: AppMotion.base,
                      style: AppTextStyles.regularText.copyWith(
                        fontSize: 14,
                        color: contentColor,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: AppSpacing.iconTarget,
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: AppMotion.base,
            curve: Curves.easeOut,
            alignment: isMentor ? Alignment.centerRight : Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: Container(
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
          Row(
            children: [
              segment(
                'Learner',
                'assets/icons/rlearner.svg',
                ExploreRole.learner,
              ),
              segment('Mentor', 'assets/icons/rmentor.svg', ExploreRole.mentor),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExploreInfoDialog extends StatefulWidget {
  const _ExploreInfoDialog();

  @override
  State<_ExploreInfoDialog> createState() => _ExploreInfoDialogState();
}

class _ExploreInfoDialogState extends State<_ExploreInfoDialog> {
  static const _titles = ['Browse', 'Heads up'];

  static const _messages = [
    'Browse domains to discover skills and knowledge shared by other users. Use the toggle to switch between learning and mentoring, then pick a domain and swipe through people who are teaching or learning in it.',
    'Most people you swipe on here won\'t match the skills you declared. That\'s intentional: Browse is for discovering something new, so keep an open mind.',
  ];

  static const _icons = [CupertinoIcons.compass, CupertinoIcons.lightbulb];

  int _page = 0;

  bool get _isLastPage => _page == _titles.length - 1;

  void _next() {
    if (_isLastPage) {
      Navigator.pop(context);
    } else {
      setState(() => _page++);
    }
  }

  void _back() {
    setState(() => _page--);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    final title = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: AppMotion.base,
          child: Icon(
            _icons[_page],
            key: ValueKey('icon_$_page'),
            size: 42,
            color: AppColors.accentText(context),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: AppMotion.base,
          child: Text(
            _titles[_page],
            key: ValueKey('title_$_page'),
            style: AppTextStyles.regularText.copyWith(
              color: textTheme,
              fontSize: 18,
            ),
          ),
        ),
      ],
    );

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Step ${_page + 1} of ${_titles.length}',
          style: AppTextStyles.regularText.copyWith(
            color: textTheme.withValues(alpha: 0.5),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: (_page + 1) / _titles.length),
            duration: AppMotion.screen,
            curve: Curves.easeOut,
            builder: (context, value, _) {
              return LinearProgressIndicator(
                value: value,
                minHeight: 4,
                backgroundColor: textTheme.withValues(alpha: 0.1),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primary,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        AnimatedSize(
          duration: AppMotion.base,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: AppMotion.base,
            child: Text(
              _messages[_page],
              key: ValueKey('message_$_page'),
              textAlign: TextAlign.center,
              style: AppTextStyles.regularText.copyWith(
                color: textTheme,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );

    if (isIOS) {
      return CupertinoAlertDialog(
        title: title,
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Material(color: Colors.transparent, child: content),
        ),
        actions: [
          if (_page > 0)
            CupertinoDialogAction(
              onPressed: _back,
              child: Text(
                'Back',
                style: AppTextStyles.regularText.copyWith(color: textTheme),
              ),
            ),
          CupertinoDialogAction(
            onPressed: _next,
            child: Text(
              _isLastPage ? 'Okay' : 'Next',
              style: AppTextStyles.regularText.copyWith(
                color: AppColors.accentText(context),
              ),
            ),
          ),
        ],
      );
    }

    return AlertDialog(
      backgroundColor: AppColors.elevatedSurface(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: title,
      content: SizedBox(width: double.maxFinite, child: content),
      actions: [
        if (_page > 0)
          TextButton(
            onPressed: _back,
            child: Text(
              'Back',
              style: AppTextStyles.regularText.copyWith(color: textTheme),
            ),
          ),
        TextButton(
          onPressed: _next,
          child: Text(
            _isLastPage ? 'Okay' : 'Next',
            style: AppTextStyles.regularText.copyWith(
              color: AppColors.accentText(context),
            ),
          ),
        ),
      ],
    );
  }
}

Color _fgCard(BuildContext context) => AppColors.elevatedSurface(context);

Color _fgInk(BuildContext context) => Theme.of(context).colorScheme.secondary;

Color _fgMuted(BuildContext context) => AppColors.mutedText(context);

Color _fgBorder(BuildContext context) => AppColors.border(context);

String _countLabelText(int count, String countLabel) {
  if (count >= 50) return '50+ ${countLabel}s';
  return '$count $countLabel${count == 1 ? '' : 's'}';
}

class _FieldGuideSearch extends StatelessWidget {
  const _FieldGuideSearch({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;
    final muted = _fgMuted(context);

    return Container(
      height: AppSpacing.iconTarget,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: textTheme.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 18, color: muted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              cursorColor: AppColors.accentText(context),
              style: AppTextStyles.regularText.copyWith(color: textTheme),
              decoration: InputDecoration(
                hintText: 'Search domains',
                hintStyle: AppTextStyles.regularText.copyWith(color: muted),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (query.trim().isNotEmpty)
            Semantics(
              container: true,
              button: true,
              label: 'Clear search',
              child: GestureDetector(
                onTap: onClear,
                child: SizedBox(
                  width: AppSpacing.iconTarget,
                  height: AppSpacing.iconTarget,
                  child: Center(
                    child: Icon(Icons.cancel, size: 18, color: muted),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FeaturedDomainCard extends StatelessWidget {
  const _FeaturedDomainCard({
    required this.label,
    required this.description,
    required this.icon,
    required this.count,
    required this.countLabel,
    required this.onTap,
  });

  final String label;
  final String description;
  final IconData icon;
  final int count;
  final String countLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final card = AppColors.mutedSurface(context);
    final border = _fgBorder(context);
    final ink = _fgInk(context);
    final muted = _fgMuted(context);
    final accent = AppColors.accentText(context);

    return Material(
      color: card,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: border),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'FEATURED',
                      style: AppTextStyles.boldText.copyWith(
                        fontSize: 9,
                        letterSpacing: 1.2,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.headingText.copyWith(
                        fontSize: 20,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.regularText.copyWith(
                        fontSize: 12,
                        height: 1.4,
                        color: muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_countLabelText(count, countLabel)} available',
                      style: AppTextStyles.boldText.copyWith(
                        fontSize: 11,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: exploreTileTint(context),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.45),
                  ),
                ),
                child: Icon(icon, size: 28, color: accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DomainCard extends StatelessWidget {
  const _DomainCard({
    required this.label,
    required this.description,
    required this.icon,
    required this.tint,
    required this.count,
    required this.countLabel,
    required this.onTap,
  });

  final String label;
  final String description;
  final IconData icon;
  final Color tint;
  final int count;
  final String countLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final card = _fgCard(context);
    final border = _fgBorder(context);
    final ink = _fgInk(context);
    final muted = _fgMuted(context);

    return Semantics(
      container: true,
      button: true,
      label: '$label. $description. ${_countLabelText(count, countLabel)}.',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: card,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: border),
            ),
            padding: const EdgeInsets.fromLTRB(11, 11, 11, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: tint,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    icon,
                    size: 17,
                    color: AppColors.accentText(context),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.boldText.copyWith(
                    fontSize: 13,
                    height: 1.2,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 3),
                Flexible(
                  child: Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.regularText.copyWith(
                      fontSize: 11,
                      height: 1.35,
                      color: muted,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _countLabelText(count, countLabel),
                  style: AppTextStyles.boldText.copyWith(
                    fontSize: 10,
                    color: AppColors.accentText(context),
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

class _FieldGuideSkeleton extends StatelessWidget {
  const _FieldGuideSkeleton();

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    final cardHeight = (132 * scale).toDouble();
    return Semantics(
      label: 'Loading domains',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns =
              constraints.maxWidth >= 1000
                  ? 4
                  : constraints.maxWidth >= 900
                  ? 3
                  : 2;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(height: 96, radius: 24),
              const SizedBox(height: 14),
              const SkeletonBox(width: 90, height: 10),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: 4,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  mainAxisExtent: cardHeight,
                ),
                itemBuilder:
                    (_, __) => Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: _fgCard(context),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _fgBorder(context)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: 32, height: 32, radius: 11),
                          SizedBox(height: 10),
                          SkeletonBox(width: 110, height: 10),
                          SizedBox(height: 6),
                          SkeletonBox(width: 80, height: 8),
                        ],
                      ),
                    ),
              ),
            ],
          );
        },
      ),
    );
  }
}
