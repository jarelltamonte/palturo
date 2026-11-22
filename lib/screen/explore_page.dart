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
import 'package:palturo/screen/action_dialogs.dart';
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
  final Future<Map<String, ({int total, int fresh, int newcomers})>> Function(
    String kind,
  )?
  domainCountsLoader;
  final Future<List<Map<String, dynamic>>> Function()? skillsLoader;
  final DateTime Function()? now;

  const ExplorePage({
    super.key,
    this.taxonomyLoader,
    this.countLoader,
    this.domainCountsLoader,
    this.skillsLoader,
    this.now,
  });

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _roots = const [];
  Set<String> _teachingPaths = const {};
  Set<String> _teachingSkillPaths = const {};
  Map<String, List<String>> _mentorSkills = const {};
  Map<String, ({int total, int fresh, int newcomers})> _rootCounts = const {};
  bool _hasMentorSkills = false;
  bool _loading = true;
  bool _roleLoading = false;
  ExploreRole? _roleLoadingFor;
  final Map<ExploreRole, _RoleSnapshot> _roleCache = {};
  List<Map<String, dynamic>>? _mySkillsCache;
  String? _error;
  String _query = '';

  static const _roleKey = 'browse_mentor_mode';

  ExploreRole _role = ExploreRole.learner;

  int _requestId = 0;
  bool _openingEditor = false;
  bool _openingCategory = false;

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

  /// The daily featured domain prefers one with new people so the field guide
  /// still opens on a card worth tapping; it falls back to domains with any
  /// people, then to the full list when every domain is empty.
  Map<String, dynamic>? get _featuredRoot {
    final fresh = _roots.where((node) => _countFor(node).fresh > 0).toList();
    final populated =
        _roots.where((node) => _countFor(node).total > 0).toList();
    return featuredDomainForDay(
      fresh.isNotEmpty
          ? fresh
          : populated.isNotEmpty
          ? populated
          : _roots,
      (widget.now ?? DateTime.now)(),
    );
  }

  String get _roleNoun => _role == ExploreRole.mentor ? 'learner' : 'mentor';

  ({int total, int fresh, int newcomers}) _countFor(
    Map<String, dynamic> node,
  ) =>
      _rootCounts[(node['path'] ?? '').toString()] ??
      (total: 0, fresh: 0, newcomers: 0);

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
  /// Mentor: return the roots related to the user's teaching skills plus the
  /// skill names per root for the teaching cards. The `hasMentorSkills` flag
  /// travels with the result so a superseded request cannot leave the empty
  /// state describing the wrong situation.
  Future<
    ({
      List<Map<String, dynamic>> roots,
      bool hasMentorSkills,
      Map<String, List<String>> skillsByRoot,
      List<String> skillPaths,
    })
  >
  _filterByRole(
    List<Map<String, dynamic>> roots, {
    required ExploreRole role,
    bool force = false,
  }) async {
    if (role == ExploreRole.learner) {
      return (
        roots: roots,
        hasMentorSkills: false,
        skillsByRoot: const <String, List<String>>{},
        skillPaths: const <String>[],
      );
    }

    final cachedSkills = force ? null : _mySkillsCache;
    final skills =
        cachedSkills ??
        (widget.skillsLoader != null
            ? await widget.skillsLoader!()
            : await MatchApi.mySkills());
    _mySkillsCache = skills;
    final teaching = skills.where((skill) => skill['kind'] == 'teach');
    final mentorPaths =
        teaching
            .map((skill) => (skill['path'] ?? '') as String)
            .where((path) => path.isNotEmpty)
            .toList();

    final skillsByRoot = <String, List<String>>{};
    for (final skill in teaching) {
      final path = (skill['path'] ?? '') as String;
      if (path.isEmpty) continue;
      final root = path.split('.').first;
      final name = (skill['name'] ?? '').toString().trim();
      final label =
          name.isNotEmpty
              ? name
              : path.split('.').last.replaceAll('_', ' ').trim();
      if (label.isEmpty) continue;
      final list = skillsByRoot.putIfAbsent(root, () => <String>[]);
      if (!list.contains(label)) list.add(label);
    }
    for (final list in skillsByRoot.values) {
      list.sort();
    }

    final filtered =
        roots.where((root) {
          final rootPath = (root['path'] ?? '') as String;
          if (rootPath.isEmpty) return false;
          return mentorPaths.any(
            (path) => path == rootPath || path.startsWith('$rootPath.'),
          );
        }).toList();

    return (
      roots: filtered,
      hasMentorSkills: mentorPaths.isNotEmpty,
      skillsByRoot: skillsByRoot,
      skillPaths: mentorPaths,
    );
  }

  /// Population, fresh, and newcomer counts for every root.
  ///
  /// `total` is everyone in the domain, `fresh` excludes existing connections
  /// (used to pick the featured domain), and `newcomers` counts registrations
  /// in the last seven days. The cards show the total and only add a "new"
  /// suffix when people actually joined recently.
  Future<Map<String, ({int total, int fresh, int newcomers})>> _rootCountsFor(
    List<Map<String, dynamic>> roots, {
    required ExploreRole role,
  }) async {
    if (roots.isEmpty) {
      return const <String, ({int total, int fresh, int newcomers})>{};
    }
    final kind = role == ExploreRole.mentor ? 'learn' : 'teach';

    if (widget.domainCountsLoader != null) {
      try {
        return await widget.domainCountsLoader!(kind);
      } catch (e) {
        debugPrint('[Browse] domain counts failed: $e');
        return const <String, ({int total, int fresh, int newcomers})>{};
      }
    }

    // A single RPC covers every root. The per-root loader stays for tests that
    // only care about the total.
    if (widget.countLoader == null) {
      try {
        return await MatchApi.browseDomainCounts(kind: kind);
      } catch (e) {
        debugPrint('[Browse] domain counts failed: $e');
        return const <String, ({int total, int fresh, int newcomers})>{};
      }
    }

    final entries = await Future.wait(
      roots.map((root) async {
        final path = (root['path'] ?? '').toString();
        if (path.isEmpty) {
          return const MapEntry('', (total: 0, fresh: 0, newcomers: 0));
        }
        try {
          final count = await widget.countLoader!(path, kind: kind);
          return MapEntry(path, (total: count, fresh: count, newcomers: 0));
        } catch (e) {
          // A failed count must not hide a valid category.
          debugPrint('[Browse] count failed for $path: $e');
          return MapEntry(path, (total: 1, fresh: 1, newcomers: 0));
        }
      }),
    );
    return Map<String, ({int total, int fresh, int newcomers})>.fromEntries(
      entries,
    );
  }

  Future<void> _loadTaxonomy({
    bool notifyFailure = false,
    bool force = false,
  }) async {
    final requestId = ++_requestId;
    final hadData = _roots.isNotEmpty;
    if (!hadData) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      if (!hadData || force) {
        final nodes =
            widget.taxonomyLoader != null
                ? await widget.taxonomyLoader!()
                : await MatchApi.taxonomyVisible();
        final roots =
            nodes.where((n) => (n['depth'] as num?)?.toInt() == 1).toList();
        if (!mounted || requestId != _requestId) return;
        setState(() => _roots = roots);
      }
      await _loadRole(_role, force: force, notifyFailure: notifyFailure);
    } catch (e) {
      if (!mounted || requestId != _requestId) return;
      final message = friendlyError(
        e,
        fallback: "Couldn't load categories. Please try again.",
      );
      setState(() {
        _loading = false;
        if (!hadData) _error = message;
      });
      if (notifyFailure && hadData) showAppError(context, message);
    }
  }

  /// Loads the data for one role and caches it.
  ///
  /// Switching roles applies the cached snapshot immediately; a missing cache
  /// shows the skeleton instead of flashing the "no mentor skills" empty state
  /// while the skills and counts are still loading.
  Future<void> _loadRole(
    ExploreRole role, {
    bool force = false,
    bool notifyFailure = false,
  }) async {
    if (_roots.isEmpty) return;
    // A role switch and the initial taxonomy load can race; keep one fetch per
    // role in flight so the skills loader is not called twice.
    if (!force && _roleLoadingFor == role) return;
    _roleLoadingFor = role;
    final requestId = ++_requestId;
    final cached = _roleCache[role];
    if (cached == null) {
      setState(() => _roleLoading = true);
    }
    try {
      final roleResult = await _filterByRole(_roots, role: role, force: force);
      // Count every root: Mentor mode shows the teaching domains as cards and
      // the rest in an "Explore other categories" grid.
      final counts = await _rootCountsFor(_roots, role: role);
      if (!mounted || requestId != _requestId || role != _role) return;
      final snapshot = _RoleSnapshot(
        teachingPaths:
            role == ExploreRole.mentor
                ? roleResult.roots
                    .map((root) => (root['path'] ?? '').toString())
                    .where((path) => path.isNotEmpty)
                    .toSet()
                : const <String>{},
        skillsByRoot: roleResult.skillsByRoot,
        hasMentorSkills: roleResult.hasMentorSkills,
        teachingSkillPaths:
            role == ExploreRole.mentor
                ? roleResult.skillPaths.toSet()
                : const <String>{},
        counts: counts,
      );
      _roleCache[role] = snapshot;
      setState(() {
        _applyRoleSnapshot(snapshot);
        _roleLoading = false;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || requestId != _requestId || role != _role) return;
      final message = friendlyError(
        e,
        fallback: "Couldn't load categories. Please try again.",
      );
      setState(() {
        _roleLoading = false;
        if (cached == null) {
          _loading = false;
          _error = message;
        }
      });
      if (cached != null && notifyFailure) showAppError(context, message);
    } finally {
      if (_roleLoadingFor == role) _roleLoadingFor = null;
    }
  }

  void _applyRoleSnapshot(_RoleSnapshot snapshot) {
    _teachingPaths = snapshot.teachingPaths;
    _teachingSkillPaths = snapshot.teachingSkillPaths;
    _mentorSkills = snapshot.skillsByRoot;
    _hasMentorSkills = snapshot.hasMentorSkills;
    _rootCounts = snapshot.counts;
  }

  Future<void> _refreshTaxonomy() =>
      _loadTaxonomy(notifyFailure: true, force: true);

  void _onRoleChanged(ExploreRole role) {
    if (role == _role) return;
    final cached = _roleCache[role];
    setState(() {
      _role = role;
      if (cached != null) {
        _applyRoleSnapshot(cached);
        _roleLoading = false;
      } else {
        _roleLoading = true;
      }
    });
    PreferencesService.instance
        .setBool(_roleKey, role == ExploreRole.mentor)
        .catchError((Object _) {});
    if (_roots.isEmpty) {
      _loadTaxonomy();
    } else {
      _loadRole(role);
    }
  }

  Future<void> _openCategory(Map<String, dynamic> root) async {
    if (_openingCategory) return;
    final path = (root['path'] ?? '').toString();
    final label = (root['name'] ?? '').toString();
    if (path.isEmpty || label.isEmpty) return;
    _openingCategory = true;
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => ExploreCategoryPage(
                nodePath: path,
                nodeLabel: label,
                description: _descriptionFor(root),
                mentor: _role == ExploreRole.mentor,
                teachingPaths:
                    _role == ExploreRole.mentor
                        ? _teachingSkillPaths
                        : const <String>{},
                ancestors: const <BrowseCrumb>[],
                nodeKind: 'category',
                nodeDepth: 1,
              ),
        ),
      );
    } finally {
      _openingCategory = false;
    }
    // Requests sent from the deck change who is available; refresh silently
    // from the cached snapshot so returning here never flashes a skeleton.
    if (mounted) _loadRole(_role, force: true);
  }

  /// Mentors can inspect every domain, but only browse learners in a domain
  /// they teach. Anything else points at the teaching skills editor.
  Future<void> _handleDomainTap(Map<String, dynamic> root) async {
    if (_role == ExploreRole.mentor) {
      final path = (root['path'] ?? '').toString();
      if (!_teachingPaths.contains(path)) {
        await _promptTeachSkill(root);
        return;
      }
    }
    await _openCategory(root);
  }

  Future<void> _promptTeachSkill(Map<String, dynamic> root) async {
    final label = (root['name'] ?? '').toString();
    final confirmed = await showConfirmDialog(
      context,
      title: 'Teach $label?',
      message:
          'You can explore $label, but browsing learners is limited to the '
          'skills you teach. Add $label to your teaching skills to mentor '
          'learners here.',
      confirmLabel: 'Update teaching skills',
      cancelLabel: 'Not now',
      destructive: false,
    );
    if (!confirmed || !mounted) return;
    await _openProfileEditor();
  }

  Future<void> _openProfileEditor() async {
    if (_openingEditor) return;
    _openingEditor = true;
    try {
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
      if (mounted) _loadTaxonomy(force: true);
    } finally {
      _openingEditor = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;
    final muted = _fgMuted(context);
    final queryActive = _query.trim().isNotEmpty;
    final mentorMode = _role == ExploreRole.mentor;
    final featured = !queryActive && !mentorMode ? _featuredRoot : null;
    final roots = _filteredRoots;
    final featuredPath = (featured?['path'] ?? '').toString();
    final teachingRoots =
        mentorMode
            ? roots
                .where(
                  (node) =>
                      _teachingPaths.contains((node['path'] ?? '').toString()),
                )
                .toList()
            : const <Map<String, dynamic>>[];
    final otherRoots =
        mentorMode
            ? roots
                .where(
                  (node) =>
                      !_teachingPaths.contains((node['path'] ?? '').toString()),
                )
                .toList()
            : roots;
    final gridRoots =
        queryActive
            ? roots
            : featured == null
            ? otherRoots
            : otherRoots
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
        // The 48px action target centers a 24px glyph, so 4px outer padding
        // puts the icon's right edge on the 16px content inset.
        actionsPadding: const EdgeInsets.only(right: 4),
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
            _RoleToggle(value: _role, onChanged: _onRoleChanged),
            const SizedBox(height: 10),
            _FieldGuideSearch(
              controller: _searchController,
              query: _query,
              onChanged: (value) => setState(() => _query = value),
              onClear: () {
                _searchController.clear();
                setState(() => _query = '');
              },
            ),
            const SizedBox(height: 14),
            if (_loading || _roleLoading)
              const _FieldGuideSkeleton()
            else if (_error != null)
              _buildErrorState(context)
            else if (_roots.isEmpty)
              _buildEmptyState(context)
            else if (roots.isEmpty)
              _buildSearchEmpty(context)
            else if (mentorMode && !queryActive && teachingRoots.isEmpty)
              _buildEmptyState(context)
            else if (mentorMode && !queryActive) ...[
              if (teachingRoots.isNotEmpty) ...[
                _buildMentorSectionLabel(
                  context,
                  'YOUR TEACHING CATEGORIES',
                  hint:
                      '${teachingRoots.length} '
                      'categor${teachingRoots.length == 1 ? 'y' : 'ies'}',
                ),
                const SizedBox(height: 8),
                for (final root in teachingRoots) ...[
                  _TeachingDomainCard(
                    label: (root['name'] ?? '').toString(),
                    description: _descriptionFor(root),
                    icon: exploreRootIcon((root['path'] ?? '').toString()),
                    total: _countFor(root).total,
                    newcomers: _countFor(root).newcomers,
                    skills:
                        _mentorSkills[(root['path'] ?? '').toString()] ??
                        const <String>[],
                    countLabel: _roleNoun,
                    onTap: () => _openCategory(root),
                  ),
                  const SizedBox(height: 10),
                ],
                if (gridRoots.isNotEmpty) const SizedBox(height: 6),
              ],
              if (gridRoots.isNotEmpty) ...[
                _buildMentorSectionLabel(context, 'EXPLORE OTHER CATEGORIES'),
                const SizedBox(height: 8),
                _buildDomainGrid(context, gridRoots),
              ],
            ] else ...[
              if (featured != null) ...[
                _FeaturedDomainCard(
                  label: (featured['name'] ?? '').toString(),
                  description: _descriptionFor(featured),
                  icon: exploreRootIcon(featuredPath),
                  total: _countFor(featured).total,
                  newcomers: _countFor(featured).newcomers,
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
            ? 'MORE CATEGORIES'
            : 'ALL CATEGORIES';
    return Text(
      label,
      style: AppTextStyles.boldText.copyWith(
        fontSize: 10,
        letterSpacing: 1.2,
        color: muted,
      ),
    );
  }

  Widget _buildMentorSectionLabel(
    BuildContext context,
    String label, {
    String? hint,
  }) {
    final muted = _fgMuted(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.boldText.copyWith(
              fontSize: 10,
              letterSpacing: 1.2,
              color: muted,
            ),
          ),
        ),
        if (hint != null)
          Text(
            hint,
            style: AppTextStyles.regularText.copyWith(
              fontSize: 11,
              color: muted,
            ),
          ),
      ],
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
              total:
                  (_rootCounts[path] ?? (total: 0, fresh: 0, newcomers: 0))
                      .total,
              newcomers:
                  (_rootCounts[path] ?? (total: 0, fresh: 0, newcomers: 0))
                      .newcomers,
              countLabel: _roleNoun,
              onTap: () => _handleDomainTap(node),
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
              'No categories match "${_query.trim()}".',
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
                      : 'You haven\'t added any mentor skills yet. Add some to your profile and matching categories will show up here.'
                  : 'No categories available right now.',
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
                child: const Text('Refresh categories'),
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
              _error ?? "Couldn't load categories. Please try again.",
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
    'Browse categories to discover skills and knowledge shared by other users. Use the toggle to switch between learning and mentoring, then pick a category and swipe through people who are teaching or learning in it.',
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
            color: AppColors.primary,
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
                backgroundColor: AppColors.progressTrack(context),
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
      scrollable: true,
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

/// The domain card's count line.
///
/// Shows the whole domain. The "new" suffix is reserved for people who
/// registered in the last seven days, so it always means new to PalTuro.
String _domainCountText(int total, int newcomers, String countLabel) {
  if (total <= 0) return 'No ${countLabel}s yet';
  final base = _countLabelText(total, countLabel);
  if (newcomers <= 0) return base;
  final freshText = newcomers >= 50 ? '50+ new' : '$newcomers new';
  return '$base · $freshText';
}

class _RoleSnapshot {
  const _RoleSnapshot({
    required this.teachingPaths,
    required this.teachingSkillPaths,
    required this.skillsByRoot,
    required this.hasMentorSkills,
    required this.counts,
  });

  final Set<String> teachingPaths;
  final Set<String> teachingSkillPaths;
  final Map<String, List<String>> skillsByRoot;
  final bool hasMentorSkills;
  final Map<String, ({int total, int fresh, int newcomers})> counts;
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
              cursorColor: AppColors.primary,
              style: AppTextStyles.regularText.copyWith(color: textTheme),
              decoration: InputDecoration(
                hintText: 'Search categories',
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
    required this.total,
    required this.newcomers,
    required this.countLabel,
    required this.onTap,
  });

  final String label;
  final String description;
  final IconData icon;
  final int total;
  final int newcomers;
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
                      _domainCountText(total, newcomers, countLabel),
                      style: AppTextStyles.boldText.copyWith(
                        fontSize: 11,
                        color: total > 0 ? accent : muted,
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
                child: Icon(icon, size: 28, color: AppColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeachingDomainCard extends StatelessWidget {
  const _TeachingDomainCard({
    required this.label,
    required this.description,
    required this.icon,
    required this.total,
    required this.newcomers,
    required this.skills,
    required this.countLabel,
    required this.onTap,
  });

  final String label;
  final String description;
  final IconData icon;
  final int total;
  final int newcomers;
  final List<String> skills;
  final String countLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final card = _fgCard(context);
    final border = _fgBorder(context);
    final ink = _fgInk(context);
    final muted = _fgMuted(context);
    final accent = AppColors.accentText(context);
    final visibleSkills = skills.take(3).toList();
    final extra = skills.length - visibleSkills.length;

    return Semantics(
      container: true,
      button: true,
      label:
          '$label. $description. '
          '${_domainCountText(total, newcomers, countLabel)}. '
          '${skills.isEmpty ? '' : '${skills.join(', ')}. '}',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: card,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: exploreTileTint(context),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(icon, size: 22, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: AppTextStyles.boldText.copyWith(
                              fontSize: 16,
                              color: ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            description,
                            style: AppTextStyles.regularText.copyWith(
                              fontSize: 11.5,
                              height: 1.35,
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          total <= 0
                              ? 'No ${countLabel}s yet'
                              : _countLabelText(total, countLabel),
                          style: AppTextStyles.boldText.copyWith(
                            fontSize: 10.5,
                            color: total > 0 ? accent : muted,
                          ),
                        ),
                        if (newcomers > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            newcomers >= 50 ? '50+ new' : '$newcomers new',
                            style: AppTextStyles.boldText.copyWith(
                              fontSize: 10,
                              color: accent,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                if (skills.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final skill in visibleSkills)
                        _MentorSkillChip(label: skill),
                      if (extra > 0) _MentorSkillChip(label: '+$extra'),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Divider(height: 1, thickness: 1, color: border),
                const SizedBox(height: 9),
                Text(
                  'YOU TEACH HERE',
                  style: AppTextStyles.boldText.copyWith(
                    fontSize: 9,
                    letterSpacing: 1.2,
                    color: accent,
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

class _MentorSkillChip extends StatelessWidget {
  const _MentorSkillChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: ink.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: AppTextStyles.regularText.copyWith(
          color: ink.withValues(alpha: 0.8),
          fontSize: 12,
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
    required this.total,
    required this.newcomers,
    required this.countLabel,
    required this.onTap,
  });

  final String label;
  final String description;
  final IconData icon;
  final Color tint;
  final int total;
  final int newcomers;
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
      label:
          '$label. $description. ${_domainCountText(total, newcomers, countLabel)}.',
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
                  _domainCountText(total, newcomers, countLabel),
                  style: AppTextStyles.boldText.copyWith(
                    fontSize: 10,
                    color: total > 0 ? AppColors.accentText(context) : muted,
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
      label: 'Loading categories',
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
