import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:palturo/screen/card/person_card.dart';
import 'package:palturo/screen/explore_expand.dart';
import 'package:palturo/screen/explore_taxonomy.dart';
import 'package:palturo/services/match_api.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_spacing.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/utils/friendly_error.dart';
import 'package:palturo/utils/media_url.dart';
import 'package:palturo/widgets/app_chrome.dart';
import 'package:palturo/widgets/app_feedback.dart';
import 'package:palturo/widgets/app_skeleton.dart';
import 'package:palturo/widgets/user_avatar.dart';

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
    this.taxonomyLoader,
    this.usersLoader,
  });

  final String nodePath;
  final String nodeLabel;
  final String description;
  final bool mentor;

  /// Test hooks. Production leaves these null.
  final Future<List<Map<String, dynamic>>> Function(String path)?
  taxonomyLoader;
  final Future<List<Person>> Function(String path, {required String kind})?
  usersLoader;

  @override
  State<ExploreCategoryPage> createState() => _ExploreCategoryPageState();
}

class _ExploreCategoryPageState extends State<ExploreCategoryPage> {
  static const double _barReserve = 120;
  static const double _pageReserve = 120;

  bool get _mentor => widget.mentor;
  List<Map<String, dynamic>> _children = const [];
  Map<String, int> _childCounts = const {};
  List<Person> _people = const [];
  int _otherCount = 0;
  bool _loading = true;
  String? _error;
  int _requestId = 0;

  String get _kind => _mentor ? 'learn' : 'teach';

  String get _noun => _mentor ? 'learner' : 'mentor';

  String get _otherNoun => _mentor ? 'mentor' : 'learner';

  String get _peopleLabel => _mentor ? 'Learners here' : 'Mentors here';

  String get _nounAvailable =>
      '$_noun${_people.length == 1 ? '' : 's'} available';

  bool get _showDeckCta => !_loading && _error == null && _people.isNotEmpty;

  @override
  void initState() {
    super.initState();
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
    try {
      final other = await _users(widget.nodePath, _mentor ? 'teach' : 'learn');
      if (!mounted || requestId != _requestId) return;
      setState(() => _otherCount = other.length);
    } catch (_) {
      // The opposite-role count is decorative; never block the category.
    }
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
              taxonomyLoader: widget.taxonomyLoader,
              usersLoader: widget.usersLoader,
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
      _buildHero(),
      if (_people.isNotEmpty) ...[
        const SizedBox(height: 24),
        _buildSectionLabel(_peopleLabel, _people.length),
        const SizedBox(height: 10),
        _buildPeople(),
      ],
      if (_children.isNotEmpty) ...[
        const SizedBox(height: 24),
        _buildSectionLabel('Skills in this domain', _children.length),
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
              if (_people.isNotEmpty) ...[
                _buildSectionLabel(_peopleLabel, _people.length),
                const SizedBox(height: 10),
                _buildPeople(),
              ],
              if (_children.isNotEmpty) ...[
                if (_people.isNotEmpty) const SizedBox(height: 24),
                _buildSectionLabel('Skills in this domain', _children.length),
                const SizedBox(height: 10),
                _buildSkills(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHero() {
    final muted = AppColors.mutedText(context);
    final accent = AppColors.accentText(context);
    final count = _people.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: exploreTileTint(context),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                exploreRootIcon(widget.nodePath),
                size: 26,
                color: AppColors.accentText(context),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            widget.description,
            style: AppTextStyles.regularText.copyWith(
              color: muted,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          if (count == 0) ...[
            _buildEmptyPanel(muted),
            if (_otherCount > 0) ...[
              const SizedBox(height: 10),
              _buildOtherCount(muted),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _load,
                child: const Text('Check again'),
              ),
            ),
          ] else
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
                  _nounAvailable,
                  style: AppTextStyles.regularText.copyWith(
                    color: muted,
                    fontSize: 12,
                  ),
                ),
                if (_otherCount > 0) _buildOtherCount(muted),
              ],
            ),
        ],
      ),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.mutedSurface(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.groups_outlined, size: 20, color: muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'No ${_noun}s are free in this domain right now.$tail',
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

  Widget _buildSectionLabel(String label, int count) {
    final ink = Theme.of(context).colorScheme.secondary;
    final muted = AppColors.mutedText(context);
    return Semantics(
      container: true,
      header: true,
      label: '$label, ${_countLabel(count)}',
      excludeSemantics: true,
      child: Row(
        children: [
          Flexible(
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
          ),
          const SizedBox(width: 8),
          Text(
            _countLabel(count).padLeft(2, '0'),
            style: AppTextStyles.boldText.copyWith(fontSize: 10, color: muted),
          ),
        ],
      ),
    );
  }

  Widget _buildPeople() {
    final visible = _people.length > 4 ? 4 : _people.length;
    final remaining = _people.length - visible;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final person in _people.take(visible)) ...[
            _PersonTile(person: person),
            const SizedBox(width: 10),
          ],
          if (remaining > 0)
            Semantics(
              container: true,
              button: true,
              label: '$remaining more ${_noun}s. Start browsing.',
              onTap: _startBrowsing,
              excludeSemantics: true,
              child: InkWell(
                onTap: _startBrowsing,
                borderRadius: BorderRadius.circular(26),
                child: SizedBox(
                  width: 52,
                  child: Column(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.mutedSurface(context),
                          border: Border.all(color: AppColors.border(context)),
                        ),
                        child: Center(
                          child: Text(
                            '+$remaining',
                            style: AppTextStyles.boldText.copyWith(
                              fontSize: 11,
                              color: AppColors.mutedText(context),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'more',
                        style: AppTextStyles.regularText.copyWith(
                          fontSize: 10,
                          color: AppColors.mutedText(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
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

class _PersonTile extends StatelessWidget {
  const _PersonTile({required this.person});

  final Person person;

  @override
  Widget build(BuildContext context) {
    final photo = person.photoUrls.isNotEmpty ? person.photoUrls.first : null;

    return SizedBox(
      width: 52,
      child: Column(
        children: [
          ExcludeSemantics(
            child: UserAvatar(
              name: person.name,
              image: MediaUrl.image(photo),
              size: 46,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            person.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTextStyles.regularText.copyWith(
              color: AppColors.mutedText(context),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _SkillRow extends StatelessWidget {
  const _SkillRow({
    required this.label,
    required this.count,
    required this.countLabel,
    required this.onTap,
  });

  final String label;
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
    return Semantics(
      container: true,
      button: true,
      label: countText == null ? '$label.' : '$label. $countText.',
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          child: Row(
            children: [
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
              if (countText != null)
                Text(
                  countText,
                  style: AppTextStyles.boldText.copyWith(
                    fontSize: 11,
                    color: AppColors.accentText(context),
                  ),
                ),
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
          const SkeletonBox(width: 110, height: 10),
          const SizedBox(height: 10),
          const Row(
            children: [
              SkeletonBox(width: 46, height: 46, radius: 23),
              SizedBox(width: 10),
              SkeletonBox(width: 46, height: 46, radius: 23),
              SizedBox(width: 10),
              SkeletonBox(width: 46, height: 46, radius: 23),
            ],
          ),
          const SizedBox(height: 24),
          const SkeletonBox(width: 140, height: 10),
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
