import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/screen/explore_expand.dart';
import 'package:palturo/services/match_api.dart';

enum ExploreRole { learner, mentor }

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  List<Map<String, dynamic>> _roots = const [];
  bool _loading = true;
  String? _error;

  // TODO: default to the user's primary role / last saved choice
  // (e.g. read from shared_preferences in initState before loading).
  ExploreRole _role = ExploreRole.learner;

  // Guards against out-of-order responses when the user toggles quickly.
  int _requestId = 0;

  static const Map<String, IconData> _rootIcons = {
    'cooking_culinary': Icons.restaurant_outlined,
    'traditional_crafts': Icons.palette_outlined,
    'performing_arts': Icons.music_note_outlined,
    'martial_arts': Icons.sports_martial_arts,
    'language_writing': Icons.translate,
    'household_skills': Icons.home_repair_service_outlined,
    'agriculture_livelihood': Icons.agriculture_outlined,
    'modern_practical_skills': Icons.handyman_outlined,
    'visual_arts_design': Icons.brush_outlined,
  };

  static const String _fallbackDescription =
      'Skills shared by the PalTuro community';

  @override
  void initState() {
    super.initState();
    _loadTaxonomy();
  }

  /// TODO(Jev): role-aware filtering.
  /// Learner: return all roots.
  /// Mentor: return only roots related to the user's mentor skills.
  /// This can either be done server-side (pass the role to the API) or here.
  List<Map<String, dynamic>> _filterByRole(List<Map<String, dynamic>> roots) {
    switch (_role) {
      case ExploreRole.learner:
        return roots;
      case ExploreRole.mentor:
        return roots; // placeholder until Jev's logic is ready
    }
  }

  /// Live data: 9 taxonomy roots from `skill_nodes` (DEV-20).
  Future<void> _loadTaxonomy() async {
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final nodes = await MatchApi.taxonomyVisible();
      final roots =
          nodes.where((n) => (n['depth'] as num?)?.toInt() == 1).toList();
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _roots = _filterByRole(roots);
        _loading = false;
      });
    } catch (e) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _onRoleChanged(ExploreRole role) {
    if (role == _role) return;
    setState(() => _role = role);
    _loadTaxonomy();
  }

  void _openCategory(Map<String, dynamic> root) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExploreExpand(
          nodePath: (root['path'] ?? '') as String,
          nodeLabel: (root['name'] ?? '') as String,
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
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Explore',
              style: AppTextStyles.headingText.copyWith(color: textTheme),
            ),
            IconButton(
              icon: Icon(
                CupertinoIcons.question_circle,
                color: textTheme,
                size: 24,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                showAdaptiveDialog(
                  context: context,
                  builder: (context) => const _ExploreInfoDialog(),
                );
              },
            ),
          ],
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
    // Fixed height so the grid doesn't jump when the caption changes.
    return SizedBox(
      height: 18,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Text(
          _role == ExploreRole.mentor
              ? 'Showing only categories that match your mentor skills.'
              : 'Showing all categories.',
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
    // Keep the previous grid visible while switching, so there's no spinner flash.
    if (_loading && _roots.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) return _buildErrorState(textTheme);
    if (_roots.isEmpty) return _buildEmptyState(textTheme);
    // Only stretch to fill the screen when there are exactly 4 cards;
    // 1-3 cards (common in Mentor mode) would look oversized.
    return _roots.length == 4
        ? _buildGrid2x2(textTheme)
        : _buildGridAuto(textTheme);
  }

  Widget _buildGrid2x2(Color textTheme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 16.0;
        const topInset = 8.0;
        const bottomInset = 90.0;
        final itemHeight =
            (constraints.maxHeight - topInset - bottomInset - spacing) / 2;
        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, topInset, 16, bottomInset),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            mainAxisExtent: itemHeight,
          ),
          itemCount: _roots.length,
          itemBuilder: (context, index) => _buildCard(index),
        );
      },
    );
  }

  Widget _buildGridAuto(Color textTheme) {
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: 150,
      ),
      itemCount: _roots.length,
      itemBuilder: (context, index) => _buildCard(index),
    );
  }

  Widget _buildCard(int index) {
    final node = _roots[index];
    final path = (node['path'] ?? '') as String;
    return _CategoryCard(
      label: (node['name'] ?? '') as String,
      description: _fallbackDescription,
      icon: _rootIcons[path] ?? Icons.category_outlined,
      onTap: () => _openCategory(node),
    );
  }

  Widget _buildEmptyState(Color textTheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          _role == ExploreRole.mentor
              ? 'You haven\'t added any mentor skills yet. Add some to your profile and matching categories will show up here.'
              : 'No categories available right now.',
          textAlign: TextAlign.center,
          style: AppTextStyles.regularText.copyWith(color: textTheme),
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
            'Couldn\'t load categories.\nPlease check your connection.',
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

    Widget segment(String label, ExploreRole role) {
      final selected = value == role;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(role),
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: AppTextStyles.regularText.copyWith(
                fontSize: 14,
                color:
                    selected ? Colors.black : textColor.withValues(alpha: 0.7),
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
              child: Text(label),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 220),
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
              segment('Learner', ExploreRole.learner),
              segment('Mentor', ExploreRole.mentor),
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
  static const _titles = ['Explore', 'Heads up'];

  static const _messages = [
    'Browse categories to discover skills and knowledge shared by other users. Use the toggle to switch between learning and mentoring, then pick a category and swipe through people who are teaching or learning in it.',
    'Most people you swipe on here won\'t match the skills you declared. That\'s intentional: Explore is for discovering something new, so keep an open mind.',
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
          duration: const Duration(milliseconds: 200),
          child: Icon(
            _icons[_page],
            key: ValueKey('icon_$_page'),
            size: 42,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
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
            duration: const Duration(milliseconds: 250),
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
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
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
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      );
    }

    return AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
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
            style: AppTextStyles.regularText.copyWith(color: AppColors.primary),
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
    required this.onTap,
  });

  final String label;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.secondary;
    final cardColor = Theme.of(context).colorScheme.surface;

    return Container(
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}