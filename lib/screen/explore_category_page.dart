import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:palturo/screen/card/person_card.dart';
import 'package:palturo/screen/explore_expand.dart';
import 'package:palturo/screen/explore_taxonomy.dart';
import 'package:palturo/screen/profile_edit.dart';
import 'package:palturo/services/match_api.dart';
import 'package:palturo/services/profile_service.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_spacing.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/utils/friendly_error.dart';
import 'package:palturo/widgets/app_chrome.dart';
import 'package:palturo/widgets/app_feedback.dart';
import 'package:palturo/widgets/app_skeleton.dart';

/// Category detail sits between the Browse root and the people deck.
///
/// It reads like the field guide chapter opener: the domain and who is here,
/// then the skills inside it, then one way into the deck.
class ExploreCategoryPage extends StatefulWidget {
  const ExploreCategoryPage({
    super.key,
    required this.nodePath,
    required this.nodeLabel,
    required this.description,
    required this.mentor,
    this.teachingPaths = const <String>{},
    this.ancestors = const <BrowseCrumb>[],
    this.nodeKind = 'category',
    this.nodeDepth = 1,
    this.taxonomyLoader,
    this.usersLoader,
    this.countsLoader,
  });

  final String nodePath;
  final String nodeLabel;
  final String description;
  final bool mentor;

  /// The exact skill paths the mentor teaches. Learner browsing is limited to
  /// these nodes; the rest of the domain stays readable.
  final Set<String> teachingPaths;

  /// Parent trail above this node. Empty for a root domain.
  final List<BrowseCrumb> ancestors;

  /// `category` or `skill`; used for the level badge and row labels.
  final String nodeKind;

  /// Taxonomy depth (1 = domain).
  final int nodeDepth;

  /// Test hooks. Production leaves these null.
  final Future<List<Map<String, dynamic>>> Function(String path)?
  taxonomyLoader;
  final Future<List<Person>> Function(String path, {required String kind})?
  usersLoader;
  final Future<({int total, int fresh, int newcomers})> Function(
    String path, {
    required String kind,
  })?
  countsLoader;

  @override
  State<ExploreCategoryPage> createState() => _ExploreCategoryPageState();
}

class _ExploreCategoryPageState extends State<ExploreCategoryPage> {
  static const double _barReserve = 120;
  static const double _pageReserve = 120;

  bool get _mentor => widget.mentor;
  late Set<String> _teachingPaths;
  List<Map<String, dynamic>> _children = const [];
  Map<String, int> _childCounts = const {};
  List<Person> _people = const [];
  int _total = 0;
  int _otherCount = 0;
  bool _loading = true;
  String? _error;
  int _requestId = 0;

  String get _kind => _mentor ? 'learn' : 'teach';

  String get _noun => _mentor ? 'learner' : 'mentor';

  String get _otherNoun => _mentor ? 'mentor' : 'learner';

  String get _nounHere => '$_noun${_total == 1 ? '' : 's'} here';

  String get _levelLabel =>
      browseLevelLabel(kind: widget.nodeKind, depth: widget.nodeDepth);

  String? get _parentLabel =>
      widget.ancestors.isEmpty ? null : widget.ancestors.last.label;

  String get _childrenSectionLabel {
    final hasCategory = _children.any(
      (child) => (child['kind'] ?? '') == 'category',
    );
    final hasSkill = _children.any(
      (child) => (child['kind'] ?? '') != 'category',
    );
    if (hasCategory && hasSkill) return 'Inside ${widget.nodeLabel}';
    if (hasCategory) return 'Subcategories';
    if (hasSkill) return 'Skills';
    return 'People here';
  }

  /// Mentors can read every domain and skill, but the learner deck is limited
  /// to the exact skills they teach.
  bool get _canBrowse => !_mentor || _teachingPaths.contains(widget.nodePath);

  bool get _showDeckCta =>
      _canBrowse && !_loading && _error == null && _people.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _teachingPaths = widget.teachingPaths;
    _load();
  }

  Future<List<Map<String, dynamic>>> _taxonomy(String path) =>
      widget.taxonomyLoader != null
          ? widget.taxonomyLoader!(path)
          : MatchApi.taxonomyVisible(rootPath: path);

  Future<List<Person>> _users(String path, String kind) =>
      widget.usersLoader != null
          ? widget.usersLoader!(path, kind: kind)
          : MatchApi.browseSkillUsers(path, kind: kind);

  Future<({int total, int fresh, int newcomers})> _counts(
    String path,
    String kind,
  ) =>
      widget.countsLoader != null
          ? widget.countsLoader!(path, kind: kind)
          : MatchApi.browsePeopleCounts(path, kind: kind);

  Future<void> _load() async {
    final requestId = ++_requestId;
    final hadData = _people.isNotEmpty || _children.isNotEmpty;
    if (!hadData) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final kind = _kind;
    try {
      final rootDepth = widget.nodePath.split('.').length;
      var nodes = <Map<String, dynamic>>[];
      try {
        nodes = await _taxonomy(widget.nodePath);
      } catch (e) {
        debugPrint('[Browse] taxonomy unavailable: $e');
      }
      final people = await _users(widget.nodePath, kind);
      var total = people.length;
      if (widget.countsLoader != null || widget.usersLoader == null) {
        try {
          final counts = await _counts(widget.nodePath, kind);
          total = counts.total;
        } catch (e) {
          // The total is explanatory; the loaded people still drive the deck.
          debugPrint('[Browse] people count unavailable: $e');
        }
      }
      if (!mounted || requestId != _requestId) return;

      final children = _visibleChildren(
        nodes
            .where(
              (n) =>
                  (n['depth'] as num?)?.toInt() == rootDepth + 1 &&
                  (n['kind'] ?? '') != 'focus',
            )
            .toList(),
        nodes,
      );
      // Paint the page before the per-skill counts land; the rows fill in.
      setState(() {
        _people = people;
        _total = total;
        _children = children;
        _childCounts = const {};
        _loading = false;
        _error = null;
      });
      unawaited(_loadChildCounts(requestId, children, kind, people));
      unawaited(_loadOtherCount(requestId));
    } catch (e) {
      debugPrint('[Browse] category load failed: $e');
      if (!mounted || requestId != _requestId) return;
      final message = friendlyError(
        e,
        fallback: "Couldn't load this category. Please try again.",
      );
      if (hadData) {
        if (mounted && (ModalRoute.of(context)?.isCurrent ?? true)) {
          showAppError(context, message);
        }
        return;
      }
      setState(() {
        _loading = false;
        _error = message;
      });
    }
  }

  /// Role-specific counts for the child skills, so every visible row leads to
  /// people in the active role. `-1` marks a count that failed: the row stays,
  /// but no number is shown.
  Future<void> _loadChildCounts(
    int requestId,
    List<Map<String, dynamic>> children,
    String kind,
    List<Person> people,
  ) async {
    if (children.isEmpty) return;
    final entries = await Future.wait(
      children.map((child) async {
        final path = (child['path'] ?? '').toString();
        if (path.isEmpty) return const MapEntry('', -1);
        try {
          if (widget.countsLoader != null || widget.usersLoader == null) {
            final counts = await _counts(path, kind);
            return MapEntry(path, counts.total);
          }
          final users = await _users(path, kind);
          return MapEntry(path, users.length);
        } catch (e) {
          debugPrint('[Browse] skill count failed for $path: $e');
          return MapEntry(path, -1);
        }
      }),
    );
    if (!mounted || requestId != _requestId) return;
    final counts = Map<String, int>.fromEntries(entries);
    setState(() {
      _childCounts = counts;
      final withPeople =
          children.where((child) {
            final value = counts[(child['path'] ?? '').toString()];
            // Keep unknown counts (-1); drop skills that are known to be empty.
            return value != 0;
          }).toList();
      // If nobody here, or nobody is tagged on a child, keep the taxonomy so
      // the page still offers a way forward.
      _children = people.isEmpty || withPeople.isEmpty ? children : withPeople;
    });
  }

  Future<void> _loadOtherCount(int requestId) async {
    final otherKind = _mentor ? 'teach' : 'learn';
    var count = 0;
    if (widget.countsLoader != null || widget.usersLoader == null) {
      try {
        count = (await _counts(widget.nodePath, otherKind)).total;
      } catch (_) {
        // Fall through to the loaded people below.
      }
    }
    if (count == 0) {
      try {
        count = (await _users(widget.nodePath, otherKind)).length;
      } catch (_) {
        // The opposite-role count is decorative; never block the category.
      }
    }
    if (!mounted || requestId != _requestId) return;
    setState(() => _otherCount = count);
  }

  /// Drops child branches with no people anywhere below them. The taxonomy
  /// returns every child and leaf, so a child's subtree usage is the sum of
  /// its own count and its descendants' counts.
  List<Map<String, dynamic>> _visibleChildren(
    List<Map<String, dynamic>> children,
    List<Map<String, dynamic>> nodes,
  ) {
    if (children.isEmpty) return children;
    final childPaths =
        children
            .map((child) => (child['path'] ?? '').toString())
            .where((path) => path.isNotEmpty)
            .toSet();
    if (childPaths.isEmpty) return children;

    final usage = <String, int>{};
    for (final node in nodes) {
      final count = (node['usage_count'] as num?)?.toInt() ?? 0;
      if (count <= 0) continue;
      var path = (node['path'] ?? '').toString();
      while (path.isNotEmpty) {
        if (childPaths.contains(path)) {
          usage[path] = (usage[path] ?? 0) + count;
        }
        final dot = path.lastIndexOf('.');
        path = dot > 0 ? path.substring(0, dot) : '';
      }
    }

    return children
        .where((child) => (usage[(child['path'] ?? '').toString()] ?? 0) > 0)
        .toList();
  }

  void _openChild(Map<String, dynamic> node) {
    final path = (node['path'] ?? '').toString();
    final label = (node['name'] ?? '').toString();
    if (path.isEmpty || label.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => ExploreCategoryPage(
              nodePath: path,
              nodeLabel: label,
              description: 'Explore $label in the PalTuro community.',
              mentor: _mentor,
              teachingPaths: _teachingPaths,
              ancestors: [
                ...widget.ancestors,
                BrowseCrumb(label: widget.nodeLabel, path: widget.nodePath),
              ],
              nodeKind: (node['kind'] ?? 'skill').toString(),
              nodeDepth:
                  (node['depth'] as num?)?.toInt() ?? widget.nodeDepth + 1,
              taxonomyLoader: widget.taxonomyLoader,
              usersLoader: widget.usersLoader,
              countsLoader: widget.countsLoader,
            ),
      ),
    );
  }

  Future<void> _startBrowsing() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => ExploreExpand(
              nodePath: widget.nodePath,
              nodeLabel: widget.nodeLabel,
              kind: _kind,
            ),
      ),
    );
    // Requests sent in the deck change who is available.
    if (mounted) _load();
  }

  String _countLabel(int n) => n >= 50 ? '50+' : '$n';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;
    final appBarHeight = math.max(
      AppSpacing.topBarHeight(),
      MediaQuery.textScalerOf(context).scale(24) + 24,
    );

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppChrome.appBar(
        toolbarHeight: appBarHeight,
        leading: AppChrome.backButton(context, color: textTheme),
        title: Text(
          widget.nodeLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.headingText.copyWith(
            color: textTheme,
            fontSize: 20,
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (_loading) return const _CategorySkeleton();
            if (_error != null) return _buildError(textTheme);

            final wide = constraints.maxWidth >= 760;
            final scale = (MediaQuery.textScalerOf(context).scale(12) / 12)
                .clamp(1.0, 2.5);
            final barReserve =
                _showDeckCta
                    ? AppSpacing.bottomNavClearanceFor(context) +
                        _barReserve * scale
                    : _pageReserve;
            final bottomInset =
                wide
                    ? math.max(
                      AppSpacing.pageBottom,
                      AppSpacing.bottomNavClearanceFor(context) + 16,
                    )
                    : barReserve;

            return Stack(
              children: [
                ListView(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset),
                  children: [
                    if (wide)
                      _buildWideBody(constraints.maxWidth)
                    else
                      ..._buildNarrowBody(),
                  ],
                ),
                if (_showDeckCta && !wide)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _buildBottomBar(),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildNarrowBody() {
    return [
      _buildBreadcrumb(),
      const SizedBox(height: 12),
      _buildHero(),
      if (_children.isNotEmpty) ...[
        const SizedBox(height: 24),
        _buildSectionLabel(_childrenSectionLabel),
        const SizedBox(height: 10),
        _buildSkills(),
      ],
    ];
  }

  Widget _buildWideBody(double width) {
    final leftWidth = width >= 1000 ? 380.0 : 300.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: leftWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildBreadcrumb(),
              const SizedBox(height: 10),
              _buildHero(),
              if (_showDeckCta) ...[
                const SizedBox(height: 18),
                _buildDeckButton(),
              ],
            ],
          ),
        ),
        const SizedBox(width: 28),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_children.isNotEmpty) ...[
                _buildSectionLabel(_childrenSectionLabel),
                const SizedBox(height: 10),
                _buildSkills(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBreadcrumb() {
    final muted = AppColors.mutedText(context);
    final ink = Theme.of(context).colorScheme.secondary;
    final crumbs = widget.ancestors;
    final pathLabel = [
      'Browse',
      ...crumbs.map((c) => c.label),
      widget.nodeLabel,
    ].join(' / ');

    return Semantics(
      container: true,
      label: 'Browse path: $pathLabel',
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text(
                    'Browse',
                    style: AppTextStyles.regularText.copyWith(
                      color: muted,
                      fontSize: 11,
                    ),
                  ),
                  for (var i = 0; i < crumbs.length; i++) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        Icons.chevron_right,
                        size: 14,
                        color: muted.withValues(alpha: 0.7),
                      ),
                    ),
                    Text(
                      crumbs[i].label,
                      style: AppTextStyles.regularText.copyWith(
                        color: i == crumbs.length - 1 ? ink : muted,
                        fontSize: 11,
                        fontWeight:
                            i == crumbs.length - 1
                                ? FontWeight.w700
                                : FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    final muted = AppColors.mutedText(context);
    final accent = AppColors.accentText(context);
    final fill = AppColors.primary;
    final count = _total;
    final teachBlocked = _mentor && !_canBrowse;
    final isDomain = widget.nodeDepth <= 1;
    final isSkill = widget.nodeKind == 'skill';
    final iconSize = isDomain ? 52.0 : (isSkill ? 38.0 : 44.0);
    final iconRadius = isDomain ? 16.0 : (isSkill ? 12.0 : 14.0);
    final heroRadius = isDomain ? 24.0 : (isSkill ? 16.0 : 20.0);
    final heroPadding = isDomain ? 16.0 : 14.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(heroPadding),
      decoration: BoxDecoration(
        color:
            isDomain
                ? AppColors.elevatedSurface(context)
                : AppColors.mutedSurface(context),
        borderRadius: BorderRadius.circular(heroRadius),
        border: Border.all(
          color:
              isDomain
                  ? AppColors.border(context)
                  : fill.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  color: exploreTileTint(context),
                  borderRadius: BorderRadius.circular(iconRadius),
                ),
                child: Icon(
                  exploreRootIcon(widget.nodePath),
                  size: iconSize * 0.5,
                  color: fill,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.nodeLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.boldText.copyWith(
                        color: Theme.of(context).colorScheme.secondary,
                        fontSize: isSkill ? 13 : 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _levelLabel.toUpperCase(),
                      style: AppTextStyles.boldText.copyWith(
                        color: accent,
                        fontSize: 9,
                        letterSpacing: 1.1,
                      ),
                    ),
                    if (_parentLabel != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Part of $_parentLabel',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.regularText.copyWith(
                          color: muted,
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.description,
            style: AppTextStyles.regularText.copyWith(
              color: muted,
              fontSize: isSkill ? 13 : 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          if (count == 0) ...[
            if (teachBlocked)
              _buildTeachPanel(muted)
            else
              _buildEmptyPanel(muted),
            if (_otherCount > 0) ...[
              const SizedBox(height: 10),
              _buildOtherCount(muted),
            ],
            if (!teachBlocked)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _load,
                  child: const Text('Check again'),
                ),
              ),
          ] else ...[
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  _countLabel(count),
                  style: AppTextStyles.headingText.copyWith(
                    color: accent,
                    fontSize: 20,
                    letterSpacing: -0.4,
                  ),
                ),
                Text(
                  _nounHere,
                  style: AppTextStyles.regularText.copyWith(
                    color: muted,
                    fontSize: 12,
                  ),
                ),
                if (_people.isNotEmpty && _people.length < count) ...[
                  _buildDot(muted),
                  Text(
                    '${_countLabel(_people.length)} available',
                    style: AppTextStyles.regularText.copyWith(
                      color: muted,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (_otherCount > 0) _buildOtherCount(muted),
              ],
            ),
            if (teachBlocked) ...[
              const SizedBox(height: 12),
              _buildTeachPanel(muted),
            ] else if (_people.isEmpty) ...[
              const SizedBox(height: 12),
              _buildEmptyPanel(muted),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _load,
                  child: const Text('Check again'),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildDot(Color muted) {
    return Container(
      width: 3,
      height: 3,
      decoration: BoxDecoration(color: muted, shape: BoxShape.circle),
    );
  }

  Widget _buildOtherCount(Color muted) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 3,
          height: 3,
          decoration: BoxDecoration(color: muted, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            '${_countLabel(_otherCount)} $_otherNoun${_otherCount == 1 ? '' : 's'} here',
            style: AppTextStyles.regularText.copyWith(
              color: muted,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyPanel(Color muted) {
    final tail = _children.isNotEmpty ? ' Try a skill below.' : '';
    final matched = _total > 0;
    final matchedNoun = _total == 1 ? _noun : '${_noun}s';
    final text =
        matched
            ? 'Matched with $_total $matchedNoun in this category. '
                'No new ${_noun}s are free right now.$tail'
            : 'No ${_noun}s are free in this category right now.$tail';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.mutedSurface(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            matched ? Icons.check_circle_outline : Icons.groups_outlined,
            size: 20,
            color: muted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.regularText.copyWith(
                color: muted,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeachPanel(Color muted) {
    final teachesUnder = _teachingPaths.any(
      (path) => path.startsWith('${widget.nodePath}.'),
    );
    final text =
        teachesUnder
            ? 'Choose a skill you teach below to browse learners.'
            : 'Add ${widget.nodeLabel} to your teaching skills to browse '
                'learners here.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.mutedSurface(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SvgPicture.asset(
                'assets/icons/rmentor.svg',
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(
                  AppColors.primary,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: AppTextStyles.regularText.copyWith(
                    color: muted,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _openTeachingEditor,
              child: const Text('Update teaching skills'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openTeachingEditor() async {
    final profile = await ProfileService().getCurrentUserProfile();
    if (!mounted) return;
    if (profile == null) {
      showAppError(context, 'Couldn’t load your profile. Please try again.');
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileEditPage(profile: profile)),
    );
    if (!mounted) return;
    // Refresh the gate so a newly added skill unlocks the deck immediately.
    try {
      final skills = await MatchApi.mySkills();
      final paths =
          skills
              .where((skill) => skill['kind'] == 'teach')
              .map((skill) => (skill['path'] ?? '') as String)
              .where((path) => path.isNotEmpty)
              .toSet();
      if (!mounted) return;
      setState(() => _teachingPaths = paths);
    } catch (_) {
      // Keep the previous paths if the read fails.
    }
    _load();
  }

  Widget _buildSectionLabel(String label) {
    final ink = Theme.of(context).colorScheme.secondary;
    return Semantics(
      container: true,
      header: true,
      label: label,
      excludeSemantics: true,
      child: Text(
        label.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.boldText.copyWith(
          fontSize: 10,
          letterSpacing: 1.2,
          color: ink,
        ),
      ),
    );
  }

  Widget _buildSkills() {
    final border = AppColors.border(context);
    final rows = <Widget>[];
    for (final child in _children) {
      if (rows.isNotEmpty) {
        rows.add(Divider(height: 1, thickness: 1, color: border));
      }
      rows.add(
        _SkillRow(
          label: (child['name'] ?? '').toString(),
          kind: (child['kind'] ?? 'skill').toString(),
          count: _childCounts[(child['path'] ?? '').toString()],
          countLabel: _noun,
          onTap: () => _openChild(child),
        ),
      );
    }
    return Material(
      color: AppColors.elevatedSurface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: rows),
    );
  }

  Widget _buildDeckButton() {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.style_outlined, size: 20),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'Start browsing ${_mentor ? 'learners' : 'mentors'}',
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(onPressed: _startBrowsing, child: child),
    );
  }

  Widget _buildBottomBar() {
    final count = _people.length;
    final muted = AppColors.mutedText(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        AppSpacing.bottomNavClearanceFor(context),
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: AppColors.border(context))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDeckButton(),
          const SizedBox(height: 6),
          Text(
            'Swipe through $count $_noun${count == 1 ? '' : 's'}, no pressure to match',
            textAlign: TextAlign.center,
            style: AppTextStyles.regularText.copyWith(
              fontSize: 10,
              color: muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(Color textTheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: AppTextStyles.regularText.copyWith(color: textTheme),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _SkillRow extends StatelessWidget {
  const _SkillRow({
    required this.label,
    required this.kind,
    required this.count,
    required this.countLabel,
    required this.onTap,
  });

  final String label;
  final String kind;
  final int? count;
  final String countLabel;
  final VoidCallback onTap;

  String? get _countText {
    final value = count;
    if (value == null || value <= 0) return null;
    if (value >= 50) return '50+ ${countLabel}s';
    return '$value $countLabel${value == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context) {
    final countText = _countText;
    final isCategory = kind == 'category';
    return Semantics(
      container: true,
      button: true,
      label:
          countText == null
              ? '$label. ${isCategory ? 'Subcategory' : 'Skill'}.'
              : '$label. ${isCategory ? 'Subcategory' : 'Skill'}. $countText.',
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isCategory ? 'SUBCATEGORY' : 'SKILL',
                  style: AppTextStyles.boldText.copyWith(
                    fontSize: 8,
                    letterSpacing: 0.6,
                    color: AppColors.accentText(context),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.boldText.copyWith(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (countText != null) ...[
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 110),
                  child: Text(
                    countText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: AppTextStyles.boldText.copyWith(
                      fontSize: 11,
                      color: AppColors.accentText(context),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              const SizedBox(width: 2),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.mutedText(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategorySkeleton extends StatelessWidget {
  const _CategorySkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading category',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.elevatedSurface(context),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 52, height: 52, radius: 16),
                SizedBox(height: 16),
                SkeletonBox(width: 220, height: 12),
                SizedBox(height: 16),
                SkeletonBox(width: 150, height: 20),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SkeletonBox(width: 60, height: 10),
          const SizedBox(height: 10),
          const SkeletonBox(height: 56, radius: 14),
          const SizedBox(height: 8),
          const SkeletonBox(height: 56, radius: 14),
          const SizedBox(height: 8),
          const SkeletonBox(height: 56, radius: 14),
        ],
      ),
    );
  }
}
