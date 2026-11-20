import 'package:flutter/material.dart';
import 'package:palturo/screen/card/person_card.dart';
import 'package:palturo/screen/chats_page.dart' show SkillTag;
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_motion.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/widgets/user_avatar.dart';

/// Openers for a brand-new match, built from the matched skill and role.
///
/// The list is deterministic so the same match always starts with the same
/// suggestions; [NewMatchEmpty] rotates it when the user asks for a shuffle.
List<String> buildIceBreakers({
  required String name,
  String? skillName,
  PersonRole? role,
}) {
  final first = name.trim().split(RegExp(r'\s+')).first;
  final peer = first.isEmpty ? 'them' : first;
  final skill = (skillName ?? '').trim();
  if (skill.isEmpty) {
    return [
      'What made you want to try something new?',
      'Ask $peer what they are hoping to find here.',
      'Share one thing you are curious about right now.',
    ];
  }
  return [
    'What’s the first thing you want to learn about $skill?',
    role == PersonRole.mentor
        ? 'Ask $peer what they love most about teaching $skill.'
        : 'Ask $peer what made them want to learn $skill.',
    'Share one tip about $skill you swear by.',
  ];
}

/// The first screen of a new chat: who you matched with, their preferences and
/// bio, and a sheet of starter messages above the composer.
class NewMatchEmpty extends StatefulWidget {
  const NewMatchEmpty({
    super.key,
    required this.name,
    required this.avatarImage,
    required this.onOpenProfile,
    required this.onUseStarter,
    required this.sheetVisible,
    required this.onDismissSheet,
    this.canRestoreSheet = false,
    this.onShowSheet,
    this.skillName,
    this.role,
    this.person,
  });

  final String name;
  final ImageProvider? avatarImage;
  final String? skillName;
  final PersonRole? role;
  final Person? person;
  final VoidCallback onOpenProfile;
  final ValueChanged<String> onUseStarter;
  final bool sheetVisible;
  final VoidCallback onDismissSheet;
  final bool canRestoreSheet;
  final VoidCallback? onShowSheet;

  @override
  State<NewMatchEmpty> createState() => _NewMatchEmptyState();
}

class _NewMatchEmptyState extends State<NewMatchEmpty> {
  final ScrollController _startersController = ScrollController();
  int _rotation = 0;
  int _page = 0;
  int _startersCount = 3;

  List<String> get _starters => buildIceBreakers(
    name: widget.name,
    skillName: widget.skillName,
    role: widget.role,
  );

  List<String> get _orderedStarters {
    final starters = _starters;
    return [
      for (var i = 0; i < starters.length; i++)
        starters[(i + _rotation) % starters.length],
    ];
  }

  List<({IconData icon, String label})> get _preferences {
    final person = widget.person;
    if (person == null) return const [];
    final out = <({IconData icon, String label})>[];
    void add(IconData icon, String value) {
      final text = value.trim();
      if (text.isNotEmpty) out.add((icon: icon, label: text));
    }

    add(Icons.calendar_today_outlined, person.schedule);
    add(Icons.translate, person.language);
    add(Icons.psychology, person.learningStyle);
    return out;
  }

  @override
  void initState() {
    super.initState();
    _startersController.addListener(_onStartersScroll);
  }

  @override
  void dispose() {
    _startersController
      ..removeListener(_onStartersScroll)
      ..dispose();
    super.dispose();
  }

  void _onStartersScroll() {
    if (!_startersController.hasClients || _startersCount <= 1) return;
    final position = _startersController.position;
    final max = position.maxScrollExtent;
    final page =
        max <= 0
            ? 0
            : ((position.pixels / max) * (_startersCount - 1)).round().clamp(
              0,
              _startersCount - 1,
            );
    if (page != _page) setState(() => _page = page);
  }

  void _shuffle() {
    if (_starters.length < 2) return;
    setState(() {
      _rotation = (_rotation + 1) % _starters.length;
      _page = 0;
    });
    if (_startersController.hasClients) _startersController.jumpTo(0);
  }

  static String _tagFor(String text) {
    final trimmed = text.trimLeft();
    if (trimmed.startsWith('Ask ')) return 'Ask';
    if (trimmed.startsWith('Share ')) return 'Share';
    return 'Question';
  }

  @override
  Widget build(BuildContext context) {
    final preferences = _preferences;
    final bio = (widget.person?.bio ?? '').trim();
    final canOpenProfile = widget.person != null;
    final starters = _orderedStarters;
    _startersCount = starters.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
        final profile = Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: _buildProfile(
              context,
              preferences: preferences,
              bio: bio,
              canOpenProfile: canOpenProfile,
            ),
          ),
        );
        // On short screens or with large text, let the whole empty state
        // scroll together instead of stacking two scroll areas.
        final stacked =
            widget.sheetVisible && (scale > 1.3 || constraints.maxHeight < 560);
        if (stacked) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                profile,
                const SizedBox(height: 16),
                _buildStarterSheet(
                  context,
                  constraints,
                  starters: starters,
                  stacked: true,
                ),
              ],
            ),
          );
        }
        return Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                  child: profile,
                ),
              ),
            ),
            if (widget.sheetVisible)
              _buildStarterSheet(
                context,
                constraints,
                starters: starters,
                stacked: false,
              ),
          ],
        );
      },
    );
  }

  Widget _buildProfile(
    BuildContext context, {
    required List<({IconData icon, String label})> preferences,
    required String bio,
    required bool canOpenProfile,
  }) {
    final textTheme = Theme.of(context).colorScheme.secondary;
    final muted = AppColors.mutedText(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ProfileAvatar(
          name: widget.name,
          image: widget.avatarImage,
          canOpenProfile: canOpenProfile,
          onTap: widget.onOpenProfile,
        ),
        const SizedBox(height: 12),
        Text(
          widget.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: AppTextStyles.boldText.copyWith(
            color: textTheme,
            fontSize: 21,
            letterSpacing: -0.4,
          ),
        ),
        if (widget.skillName != null &&
            widget.skillName!.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'You matched on',
            style: AppTextStyles.regularText.copyWith(
              color: muted,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 6),
          SkillTag(skillName: widget.skillName!, role: widget.role),
        ],
        if (preferences.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final pref in preferences)
                _PreferenceChip(icon: pref.icon, label: pref.label),
            ],
          ),
        ],
        if (bio.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            bio,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTextStyles.regularText.copyWith(
              color: muted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
        if (widget.canRestoreSheet && widget.onShowSheet != null) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: widget.onShowSheet,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accentText(context),
              minimumSize: const Size(0, 44),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.lightbulb_outline, size: 16),
            label: Text(
              'Show starters',
              style: AppTextStyles.boldText.copyWith(
                fontSize: 11.5,
                color: AppColors.accentText(context),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStarterSheet(
    BuildContext context,
    BoxConstraints constraints, {
    required List<String> starters,
    required bool stacked,
  }) {
    final textTheme = Theme.of(context).colorScheme.secondary;
    final muted = AppColors.mutedText(context);
    // The sheet's padding (32) and 1px border each side come out of the row.
    final contentWidth = (constraints.maxWidth - 34).clamp(240.0, 848.0);
    final fitsThree = contentWidth >= 3 * 200 + 16;
    final cardWidth = (contentWidth * 0.62).clamp(200.0, 280.0);
    final cards = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < starters.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            if (fitsThree)
              Expanded(
                child: _StarterCard(
                  text: starters[i],
                  tag: _tagFor(starters[i]),
                  onUse: () => widget.onUseStarter(starters[i]),
                ),
              )
            else
              _StarterCard(
                width: cardWidth,
                text: starters[i],
                tag: _tagFor(starters[i]),
                onUse: () => widget.onUseStarter(starters[i]),
              ),
          ],
        ],
      ),
    );
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Start the conversation',
                    style: AppTextStyles.boldText.copyWith(
                      color: textTheme,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Pick a starter or write your own',
                    style: AppTextStyles.regularText.copyWith(
                      color: muted,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Hide starter suggestions',
              onPressed: widget.onDismissSheet,
              style: IconButton.styleFrom(
                minimumSize: const Size(44, 44),
                maximumSize: const Size(44, 44),
                padding: EdgeInsets.zero,
              ),
              icon: Icon(Icons.close_rounded, size: 18, color: muted),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (fitsThree)
          cards
        else
          SingleChildScrollView(
            key: const ValueKey('starter-scroll'),
            controller: _startersController,
            scrollDirection: Axis.horizontal,
            child: cards,
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton.icon(
              onPressed: starters.length < 2 ? null : _shuffle,
              style: TextButton.styleFrom(
                foregroundColor: muted,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: const Size(0, 44),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.shuffle_rounded, size: 15),
              label: Text(
                'Shuffle',
                style: AppTextStyles.boldText.copyWith(
                  fontSize: 11,
                  color: muted,
                ),
              ),
            ),
            const Spacer(),
            if (!fitsThree) _Dots(count: starters.length, active: _page),
          ],
        ),
      ],
    );

    final surface = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface(context),
        // Round every corner: the sheet floats above the transparent composer,
        // so a square bottom edge reads as a hard cut.
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border(context)),
        boxShadow:
            stacked
                ? null
                : [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha:
                          Theme.of(context).brightness == Brightness.dark
                              ? 0.16
                              : 0.05,
                    ),
                    blurRadius: 14,
                    offset: const Offset(0, -3),
                  ),
                ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: contentWidth),
          child: content,
        ),
      ),
    );

    if (stacked) return surface;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: constraints.maxHeight * 0.55),
      child: SingleChildScrollView(child: surface),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.name,
    required this.image,
    required this.canOpenProfile,
    required this.onTap,
  });

  final String name;
  final ImageProvider? image;
  final bool canOpenProfile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final avatar = UserAvatar(name: name, image: image, size: 88);
    if (!canOpenProfile) return avatar;
    return Semantics(
      container: true,
      button: true,
      excludeSemantics: true,
      label: 'View $name’s profile',
      onTap: onTap,
      child: GestureDetector(onTap: onTap, child: avatar),
    );
  }
}

class _PreferenceChip extends StatelessWidget {
  const _PreferenceChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.mutedText(context);
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.mutedSurface(context),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: muted),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.regularText.copyWith(
                color: Theme.of(context).colorScheme.secondary,
                fontSize: 11.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StarterCard extends StatelessWidget {
  const _StarterCard({
    this.width,
    required this.text,
    required this.tag,
    required this.onUse,
  });

  final double? width;
  final String text;
  final String tag;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.mutedText(context);
    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      decoration: BoxDecoration(
        color: AppColors.mutedSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: AppTextStyles.regularText.copyWith(
              color: Theme.of(context).colorScheme.secondary,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Flexible(
                child: Text(
                  tag.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.boldText.copyWith(
                    color: muted,
                    fontSize: 9,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                container: true,
                button: true,
                excludeSemantics: true,
                label: 'Use this starter',
                hint: text,
                onTap: onUse,
                child: Tooltip(
                  message: 'Use this starter',
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onUse,
                      customBorder: const CircleBorder(),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary.withValues(alpha: 0.16),
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              size: 14,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final on = AppColors.primary;
    final off = AppColors.border(context);
    return Semantics(
      liveRegion: true,
      label: 'Starter ${active + 1} of $count',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < count; i++)
              AnimatedContainer(
                duration: AppMotion.base,
                curve: Curves.easeOut,
                width: i == active % count ? 20 : 8,
                height: 8,
                margin: const EdgeInsets.only(left: 4),
                decoration: BoxDecoration(
                  color: i == active % count ? on : off,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
