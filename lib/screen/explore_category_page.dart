import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:palturo/screen/card/person_card.dart';
import 'package:palturo/screen/explore_expand.dart';
import 'package:palturo/services/match_api.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_spacing.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/utils/media_url.dart';
import 'package:palturo/widgets/app_skeleton.dart';
import 'package:palturo/widgets/user_avatar.dart';
import 'package:palturo/utils/friendly_error.dart';

/// Category detail sits between the Browse root and the people deck.
///
/// It uses the visible taxonomy to expose child skills, shows a real count of
/// people for the selected role, and sends the user straight to a swipe deck.
class ExploreCategoryPage extends StatefulWidget {
  const ExploreCategoryPage({
    super.key,
    required this.nodePath,
    required this.nodeLabel,
    required this.description,
    required this.mentor,
    this.onRoleChanged,
  });

  final String nodePath;
  final String nodeLabel;
  final String description;
  final bool mentor;
  final ValueChanged<bool>? onRoleChanged;

  @override
  State<ExploreCategoryPage> createState() => _ExploreCategoryPageState();
}

class _ExploreCategoryPageState extends State<ExploreCategoryPage> {
  static const double _navClearance = 88;

  late final bool _mentor = widget.mentor;
  List<Map<String, dynamic>> _children = const [];
  List<Person> _people = const [];
  int _otherCount = 0;
  bool _loading = true;
  String? _error;
  int _requestId = 0;

  String get _kind => _mentor ? 'learn' : 'teach';

  bool get _showCta => !_loading && _error == null && _people.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rootDepth = widget.nodePath.split('.').length;
      var nodes = <Map<String, dynamic>>[];
      try {
        nodes = await MatchApi.taxonomyVisible(rootPath: widget.nodePath);
      } catch (e) {
        debugPrint('[Browse] taxonomy unavailable: $e');
      }
      final people = await MatchApi.browseSkillUsers(
        widget.nodePath,
        kind: _kind,
      );
      if (!mounted || requestId != _requestId) return;

      final children =
          nodes
              .where((n) => (n['depth'] as num?)?.toInt() == rootDepth + 1)
              .toList();
      setState(() {
        _children = _visibleChildren(children, nodes);
        _people = people;
        _otherCount = 0;
        _loading = false;
      });
      unawaited(_loadOtherCount(requestId));
    } catch (e) {
      debugPrint('[Browse] category load failed: $e');
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _loading = false;
        _error = friendlyError(
          e,
          fallback: "Couldn't load this category. Please try again.",
        );
      });
    }
  }

  Future<void> _loadOtherCount(int requestId) async {
    try {
      final other = await MatchApi.browseSkillUsers(
        widget.nodePath,
        kind: _mentor ? 'teach' : 'learn',
      );
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
              onRoleChanged: widget.onRoleChanged,
            ),
      ),
    );
  }

  void _startBrowsing() {
    Navigator.push(
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
  }

  String _countLabel(int n) => n >= 50 ? '50+' : '$n';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;
    final surface = Theme.of(context).colorScheme.surface;
    final adaptiveHeight = AppSpacing.topBarHeight();

    return Scaffold(
      backgroundColor: surface,
      appBar: AppBar(
        toolbarHeight: adaptiveHeight,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: AppSpacing.titleSpacing,
        title: Row(
          children: [
            Semantics(
              button: true,
              label: 'Back',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.pop(context),
                child: SizedBox(
                  width: AppSpacing.iconTarget,
                  height: AppSpacing.iconTarget,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Icon(
                      Icons.arrow_back_ios_new,
                      color: textTheme,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.nodeLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.headingText.copyWith(
                  color: textTheme,
                  fontSize: 20,
                ),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        bottom: false,
        child:
            _loading
                ? const _CategorySkeleton()
                : _error != null
                ? _buildError(textTheme)
                : Stack(
                  children: [
                    ListView(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        8,
                        16,
                        _showCta ? _navClearance + 88 : 120,
                      ),
                      children: [
                        _buildHeader(textTheme),
                        if (_people.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Text(
                            _mentor ? 'Learners here' : 'Mentors here',
                            style: AppTextStyles.boldText.copyWith(
                              color: textTheme,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildPeoplePreview(textTheme),
                        ],
                        if (_children.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Text(
                            'Skills in this category',
                            style: AppTextStyles.boldText.copyWith(
                              color: textTheme,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final child in _children)
                                _SkillChip(
                                  label: (child['name'] ?? '').toString(),
                                  onTap: () => _openChild(child),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    if (_showCta)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: _buildBottomCta(surface),
                      ),
                  ],
                ),
      ),
    );
  }

  Widget _buildPeoplePreview(Color textTheme) {
    final visible = _people.length > 6 ? 6 : _people.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 82,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: visible,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final person = _people[index];
              final photo =
                  person.photoUrls.isNotEmpty ? person.photoUrls.first : null;
              return SizedBox(
                width: 64,
                child: Column(
                  children: [
                    UserAvatar(
                      name: person.name,
                      image: MediaUrl.image(photo),
                      size: 48,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      person.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.regularText.copyWith(
                        color: textTheme.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (_people.length > visible) ...[
          const SizedBox(height: 4),
          Text(
            'and ${_people.length - visible} more',
            style: AppTextStyles.regularText.copyWith(
              color: AppColors.mutedText(context),
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBottomCta(Color surface) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, _navClearance),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [surface.withValues(alpha: 0), surface],
          stops: const [0, 0.45],
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: _startBrowsing,
          icon: const Icon(Icons.style_outlined),
          label: Text('Start browsing ${_mentor ? 'learners' : 'mentors'}'),
        ),
      ),
    );
  }

  Widget _buildRolePill() {
    final roleName = _mentor ? 'Mentor' : 'Learner';
    final svgAsset =
        _mentor ? 'assets/icons/rmentor.svg' : 'assets/icons/rlearner.svg';

    return Semantics(
      label: 'Browsing as $roleName',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.mutedSurface(context),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              svgAsset,
              width: 16,
              height: 16,
              colorFilter: ColorFilter.mode(
                AppColors.accentText(context),
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Browsing as $roleName',
              style: AppTextStyles.boldText.copyWith(
                color: Theme.of(context).colorScheme.secondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color textTheme) {
    final noun = _mentor ? 'learner' : 'mentor';
    final otherNoun = _mentor ? 'mentor' : 'learner';
    final count = _people.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface(context),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRolePill(),
          const SizedBox(height: 18),
          Text(
            widget.description,
            style: AppTextStyles.regularText.copyWith(
              color: textTheme.withValues(alpha: 0.76),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          if (_people.isEmpty)
            _buildEmpty(textTheme)
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _countLabel(count),
                  style: AppTextStyles.headingText.copyWith(
                    color: AppColors.accentText(context),
                    fontSize: 44,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$noun${count == 1 ? '' : 's'} available',
                    style: AppTextStyles.regularText.copyWith(
                      color: textTheme,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          if (_otherCount > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.swap_horiz,
                  size: 15,
                  color: AppColors.mutedText(context),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${_countLabel(_otherCount)} fellow $otherNoun${_otherCount == 1 ? '' : 's'} here',
                    style: AppTextStyles.regularText.copyWith(
                      color: AppColors.mutedText(context),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmpty(Color textTheme) {
    return Row(
      children: [
        Icon(
          Icons.groups_outlined,
          size: 26,
          color: textTheme.withValues(alpha: 0.35),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'No one is available in this category right now.',
            style: AppTextStyles.regularText.copyWith(
              color: textTheme.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
        ),
      ],
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

class _SkillChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SkillChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;

    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.fromLTRB(16, 0, 10, 0),
          backgroundColor: Colors.transparent,
          side: BorderSide(color: AppColors.border(context)),
          shape: const StadiumBorder(),
          elevation: 0,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppTextStyles.regularText.copyWith(
                color: textTheme,
                fontSize: 13,
                fontWeight: FontWeight.w600,
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
            height: 200,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.elevatedSurface(context),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 140, height: 28, radius: 14),
                SizedBox(height: 18),
                SkeletonBox(width: 220, height: 14),
                Spacer(),
                SkeletonBox(width: 170, height: 40),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SkeletonBox(width: 150, height: 14),
          const SizedBox(height: 10),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SkeletonBox(width: 100, height: 44, radius: 22),
              SkeletonBox(width: 128, height: 44, radius: 22),
              SkeletonBox(width: 90, height: 44, radius: 22),
            ],
          ),
        ],
      ),
    );
  }
}
