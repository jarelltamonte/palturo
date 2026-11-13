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

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  List<Map<String, dynamic>> _roots = const [];
  Map<String, int> _rootCounts = const {};
  bool _hasMentorSkills = false;
  bool _loading = true;
  String? _error;

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
  /// Mentor: return only roots related to the user's mentor skills.
  Future<List<Map<String, dynamic>>> _filterByRole(
    List<Map<String, dynamic>> roots,
  ) async {
    if (_role == ExploreRole.learner) {
      _hasMentorSkills = false;
      return roots;
    }

    final skills = await MatchApi.mySkills();
    final mentorPaths =
        skills
            .where((skill) => skill['kind'] == 'teach')
            .map((skill) => (skill['path'] ?? '') as String)
            .where((path) => path.isNotEmpty)
            .toList();
    _hasMentorSkills = mentorPaths.isNotEmpty;

    return roots.where((root) {
      final rootPath = (root['path'] ?? '') as String;
      if (rootPath.isEmpty) return false;
      return mentorPaths.any(
        (path) => path == rootPath || path.startsWith('$rootPath.'),
      );
    }).toList();
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
          final people = await MatchApi.browseSkillUsers(path, kind: kind);
          return MapEntry(path, people.length);
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
      final nodes = await MatchApi.taxonomyVisible();
      final roots =
          nodes.where((n) => (n['depth'] as num?)?.toInt() == 1).toList();
      final filtered = await _filterByRole(roots);
      final counts = await _rootCountsFor(filtered);
      if (!mounted || requestId != _requestId) return;
      final visible =
          filtered
              .where(
                (root) => (counts[(root['path'] ?? '').toString()] ?? 1) > 0,
              )
              .toList();
      setState(() {
        _roots = visible;
        _rootCounts = counts;
        _loading = false;
      });
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

  Future<void> _refreshTaxonomy() => _loadTaxonomy(notifyFailure: true);

  void _onRoleChanged(ExploreRole role) {
    if (role == _role) return;
    setState(() => _role = role);
    PreferencesService.instance.setBool(_roleKey, role == ExploreRole.mentor);
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
              onRoleChanged: (mentor) {
                if (!mounted) return;
                setState(() {
                  _role = mentor ? ExploreRole.mentor : ExploreRole.learner;
                });
                _loadTaxonomy();
              },
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

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppChrome.appBar(
        titleSpacing: AppSpacing.titleSpacing,
        title: Padding(
          padding: EdgeInsets.zero,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Browse',
                style: AppTextStyles.headingText.copyWith(color: textTheme),
              ),
              SizedBox(
                width: AppSpacing.iconTarget,
                height: AppSpacing.iconTarget,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerRight,
                  tooltip: 'How Browse works',
                  icon: Icon(
                    CupertinoIcons.question_circle,
                    color: textTheme,
                    size: 24,
                  ),
                  onPressed: () {
                    showAdaptiveDialog(
                      context: context,
                      builder: (context) => const _ExploreInfoDialog(),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _RoleToggle(value: _role, onChanged: _onRoleChanged),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildCaption(textTheme),
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildContent(textTheme)),
          ],
        ),
      ),
    );
  }

  Widget _buildCaption(Color textTheme) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 18),
      child: AnimatedSwitcher(
        duration: AppMotion.base,
        child: Text(
          _role == ExploreRole.mentor
              ? 'Showing categories with learners available right now.'
              : 'Showing categories with mentors available right now.',
          key: ValueKey(_role),
          style: TextStyle(
            fontSize: 12,
            color: textTheme.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(Color textTheme) {
    if (_loading) {
      return const ExploreGridSkeleton();
    }
    if (_error != null) return _buildErrorState(textTheme);
    if (_roots.isEmpty) return _buildEmptyState(textTheme);
    return _roots.length == 4
        ? _buildGrid2x2(textTheme)
        : _buildGridAuto(textTheme);
  }

  Widget _buildGrid2x2(Color textTheme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 16.0;
        const topInset = 8.0;
        final bottomInset = AppSpacing.bottomNavClearanceFor(context);
        final rawItemHeight =
            (constraints.maxHeight - topInset - bottomInset - spacing) / 2;
        if (rawItemHeight < 172) return _buildGridAuto(textTheme);

        // Wide desktop surfaces lay the four roots out in one row so the cards
        // keep a comfortable aspect instead of stretching to half the viewport.
        final columns = constraints.maxWidth >= 900 ? 4 : 2;
        final itemHeight =
            columns == 4
                ? 210.0
                : constraints.maxWidth >= 700
                ? rawItemHeight.clamp(172.0, 300.0)
                : rawItemHeight;
        return RefreshIndicator(
          onRefresh: _refreshTaxonomy,
          child: GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16, topInset, 16, bottomInset),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
              mainAxisExtent: itemHeight,
            ),
            itemCount: _roots.length,
            itemBuilder: (context, index) => _buildCard(index),
          ),
        );
      },
    );
  }

  Widget _buildGridAuto(Color textTheme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 3 : 2;
        return RefreshIndicator(
          onRefresh: _refreshTaxonomy,
          child: GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              AppSpacing.bottomNavClearanceFor(context),
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              mainAxisExtent: 190,
            ),
            itemCount: _roots.length,
            itemBuilder: (context, index) => _buildCard(index),
          ),
        );
      },
    );
  }

  Widget _buildCard(int index) {
    final node = _roots[index];
    final path = (node['path'] ?? '') as String;
    return _CategoryCard(
      label: (node['name'] ?? '') as String,
      description: _descriptionFor(node),
      icon: exploreRootIcon(path),
      count: _rootCounts[path] ?? 0,
      countLabel: _role == ExploreRole.mentor ? 'learner' : 'mentor',
      onTap: () => _openCategory(node),
    );
  }

  Widget _buildEmptyState(Color textTheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
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
              style: AppTextStyles.regularText.copyWith(color: textTheme),
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

  Widget _buildErrorState(Color textTheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _error ?? "Couldn't load categories. Please try again.",
            style: AppTextStyles.regularText.copyWith(color: textTheme),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadTaxonomy,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text(
              'Retry',
              style: TextStyle(color: Colors.black, fontSize: 16),
            ),
          ),
        ],
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
                  AnimatedDefaultTextStyle(
                    duration: AppMotion.base,
                    style: AppTextStyles.regularText.copyWith(
                      fontSize: 14,
                      color: contentColor,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                    child: Text(label),
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

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
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
    final textColor = Theme.of(context).colorScheme.secondary;
    final cardColor = AppColors.elevatedSurface(context);

    return Container(
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border(context)),
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            spreadRadius: 0,
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            spreadRadius: 0,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 22, color: AppColors.background),
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.headingText.copyWith(
                    color: textColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: Text(
                    description,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    count >= 50
                        ? '50+ ${countLabel}s'
                        : '$count $countLabel${count == 1 ? '' : 's'}',
                    style: TextStyle(
                      color: AppColors.accentText(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
