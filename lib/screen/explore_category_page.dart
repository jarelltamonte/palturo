import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:palturo/screen/card/person_card.dart';
import 'package:palturo/screen/explore_expand.dart';
import 'package:palturo/services/match_api.dart';
import 'package:palturo/services/preferences_service.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/widgets/app_skeleton.dart';
import 'package:palturo/widgets/user_avatar.dart';

/// Category detail sits between the Browse root and the people deck.
///
/// It uses the visible taxonomy to expose child skills, shows a real count of
/// people for the selected role, and lets the user search the loaded preview
/// before committing to a swipe deck.
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
  static const _roleKey = 'browse_mentor_mode';

  late bool _mentor = widget.mentor;
  List<Map<String, dynamic>> _children = const [];
  List<Person> _people = const [];
  int _otherCount = 0;
  bool _loading = true;
  String? _error;
  String _query = '';
  int _requestId = 0;
  final TextEditingController _search = TextEditingController();

  String get _kind => _mentor ? 'learn' : 'teach';
  String get _roleLabel => _mentor ? 'Mentor' : 'Learner';
  String get _otherRoleLabel => _mentor ? 'mentors' : 'learners';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
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

      setState(() {
        _children =
            nodes
                .where((n) => (n['depth'] as num?)?.toInt() == rootDepth + 1)
                .toList();
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
        _error = 'Couldn’t load this category.\nPlease try again.';
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

  Future<void> _switchRole() async {
    final next = !_mentor;
    await PreferencesService.instance.setBool(_roleKey, next);
    if (!mounted) return;
    setState(() => _mentor = next);
    widget.onRoleChanged?.call(next);
    _load();
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
              onRoleChanged: (mentor) {
                if (!mounted) return;
                setState(() => _mentor = mentor);
                _load();
                widget.onRoleChanged?.call(mentor);
              },
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

  List<Person> get _visiblePeople {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _people;
    return _people
        .where(
          (p) =>
              p.name.toLowerCase().contains(q) ||
              p.bio.toLowerCase().contains(q) ||
              p.skillName.toLowerCase().contains(q),
        )
        .toList();
  }

  String _countLabel(int n) => n >= 50 ? '50+' : '$n';

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
          children: [
            Semantics(
              button: true,
              label: 'Back',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.pop(context),
                child: SizedBox(
                  width: 44,
                  height: 44,
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
                  fontSize: 18,
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
                ? const ListRowsSkeleton(count: 6, rowHeight: 86)
                : _error != null
                ? _buildError(textTheme)
                : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                  children: [
                    _buildHeader(textTheme),
                    if (_children.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        'Skills in this category',
                        style: AppTextStyles.boldText.copyWith(
                          color: textTheme,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
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
                    const SizedBox(height: 14),
                    TextField(
                      controller: _search,
                      onChanged: (value) => setState(() => _query = value),
                      style: AppTextStyles.regularText.copyWith(
                        color: textTheme,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search people in ${widget.nodeLabel}',
                        prefixIcon: Icon(
                          Icons.search,
                          color: textTheme.withValues(alpha: 0.6),
                        ),
                        suffixIcon:
                            _query.isEmpty
                                ? null
                                : IconButton(
                                  tooltip: 'Clear search',
                                  onPressed: () {
                                    _search.clear();
                                    setState(() => _query = '');
                                  },
                                  icon: Icon(
                                    Icons.cancel,
                                    color: textTheme.withValues(alpha: 0.6),
                                  ),
                                ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _startBrowsing,
                        icon: const Icon(Icons.style_outlined),
                        label: Text(
                          'Start browsing ${_mentor ? 'learners' : 'mentors'}',
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'People ${_mentor ? 'learning' : 'teaching'} this',
                            style: AppTextStyles.boldText.copyWith(
                              color: textTheme,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Text(
                          _query.trim().isEmpty
                              ? '${_countLabel(_people.length)} found'
                              : '${_visiblePeople.length} of ${_countLabel(_people.length)} found',
                          style: AppTextStyles.regularText.copyWith(
                            color: AppColors.mutedText(context),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_visiblePeople.isEmpty)
                      _buildEmpty(textTheme)
                    else
                      for (final person in _visiblePeople.take(4))
                        _PersonPreview(
                          person: person,
                          onTap: () => showPersonProfileDialog(context, person),
                        ),
                    if (_visiblePeople.length > 4) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Showing ${_visiblePeople.length > 4 ? 4 : _visiblePeople.length} of ${_countLabel(_people.length)} people. Start browsing to see everyone.',
                        style: AppTextStyles.regularText.copyWith(
                          color: AppColors.mutedText(context),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
      ),
    );
  }

  Widget _buildHeader(Color textTheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 14),
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.description,
                  style: AppTextStyles.regularText.copyWith(
                    color: textTheme.withValues(alpha: 0.76),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 44,
                child: TextButton(
                  onPressed: _switchRole,
                  style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
                  child: Text(
                    'Switch to ${_mentor ? 'Learner' : 'Mentor'}',
                    style: AppTextStyles.regularText.copyWith(
                      color: AppColors.accentText(context),
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _MetaPill(
                icon:
                    _mentor
                        ? Icons.workspace_premium_outlined
                        : Icons.menu_book_outlined,
                label: '$_roleLabel view',
              ),
              _MetaPill(
                icon: Icons.people_outline,
                label:
                    '${_countLabel(_people.length)} ${_mentor ? 'learners' : 'mentors'}',
              ),
              _MetaPill(
                icon: Icons.swap_horiz,
                label: '${_countLabel(_otherCount)} $_otherRoleLabel',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(Color textTheme) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.mutedSurface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 30,
            color: textTheme.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 8),
          Text(
            _query.isEmpty
                ? 'No people in this category yet.'
                : 'No people match your search.',
            textAlign: TextAlign.center,
            style: AppTextStyles.regularText.copyWith(
              color: textTheme.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
          if (_query.isNotEmpty) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                _search.clear();
                setState(() => _query = '');
              },
              child: const Text('Clear search'),
            ),
          ] else if (_otherCount > 0) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _switchRole,
              child: Text('Switch to ${_mentor ? 'Learner' : 'Mentor'} view'),
            ),
          ],
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

class _SkillChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SkillChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.45),
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.regularText.copyWith(
              color: AppColors.accentText(context),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.mutedSurface(context),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.mutedText(context)),
          const SizedBox(width: 4),
          Text(
            label,
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

class _PersonPreview extends StatelessWidget {
  final Person person;
  final VoidCallback onTap;

  const _PersonPreview({required this.person, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              UserAvatar(
                name: person.name,
                image:
                    person.photoUrls.isNotEmpty &&
                            person.photoUrls.first != null
                        ? NetworkImage(person.photoUrls.first!)
                        : null,
                size: 44,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.boldText.copyWith(
                        color: textTheme,
                        fontSize: 14,
                      ),
                    ),
                    if (person.bio.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        person.bio,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.regularText.copyWith(
                          color: textTheme.withValues(alpha: 0.62),
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
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
