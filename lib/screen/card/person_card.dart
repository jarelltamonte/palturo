import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:palturo/theme/app_spacing.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_motion.dart';
import 'package:palturo/screen/action_dialogs.dart';
import 'package:palturo/screen/card/skills_card.dart' show toTitleCase;
import 'package:palturo/models/card_guide.dart';
import 'package:palturo/screen/utils/schedule_format.dart';
import 'package:palturo/widgets/showcase_media.dart';
import 'package:palturo/widgets/user_avatar.dart';

enum PersonRole { learner, mentor }

class Person {
  final String id;
  final String name;
  final String schedule;
  final String language;
  final String learningStyle;

  /// How this person teaches. Empty for learner-only profiles.
  final String teachingStyle;
  final String skillName;
  final String skillPath;
  final PersonRole role;
  final String bio;

  /// Approved, role-specific note for the skill shown on the card.
  final String skillNote;
  final List<String?> photoUrls;

  /// FR-5 short-form showcase media (image/video thumbnails) — shown first on
  /// the card per spec §6.3 recommendation card.
  final List<String?> showcaseUrls;

  /// Reciprocal compatibility (0..1) from the pipeline — spec §6.3 indicator.
  final double? compatibility;

  /// 'full' or 'basic_bi'. Basic mode is one-way similarity.
  final String pipeline;

  const Person({
    required this.id,
    required this.name,
    required this.schedule,
    required this.language,
    required this.learningStyle,
    this.teachingStyle = '',
    required this.skillName,
    this.skillPath = '',
    required this.role,
    this.bio = '',
    this.skillNote = '',
    this.photoUrls = const [null],
    this.showcaseUrls = const [],
    this.compatibility,
    this.pipeline = 'full',
  });

  /// Card page media: showcase content first, profile photos after.
  List<String?> get cardMedia => [...showcaseUrls, ...photoUrls];

  Person copyWith({
    String? id,
    String? name,
    String? schedule,
    String? language,
    String? learningStyle,
    String? teachingStyle,
    String? skillName,
    String? skillPath,
    PersonRole? role,
    String? bio,
    String? skillNote,
    List<String?>? photoUrls,
    List<String?>? showcaseUrls,
    double? compatibility,
    String? pipeline,
  }) {
    return Person(
      id: id ?? this.id,
      name: name ?? this.name,
      schedule: schedule ?? this.schedule,
      language: language ?? this.language,
      learningStyle: learningStyle ?? this.learningStyle,
      teachingStyle: teachingStyle ?? this.teachingStyle,
      skillName: skillName ?? this.skillName,
      skillPath: skillPath ?? this.skillPath,
      role: role ?? this.role,
      bio: bio ?? this.bio,
      skillNote: skillNote ?? this.skillNote,
      photoUrls: photoUrls ?? this.photoUrls,
      showcaseUrls: showcaseUrls ?? this.showcaseUrls,
      compatibility: compatibility ?? this.compatibility,
      pipeline: pipeline ?? this.pipeline,
    );
  }
}

class PersonCardOverlay extends StatefulWidget {
  final Person person;
  final VoidCallback? onAdd;
  final VoidCallback? onSkip;
  final VoidCallback? onBlock;
  final VoidCallback? onReport;
  final VoidCallback? onUnmatch;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onWhyMatch;
  final String skipLabel;
  final String addLabel;
  final bool showActions;
  final bool showMenu;
  final bool showProfilePill;
  final bool showShadow;
  final bool showSkillNote;

  /// Optional keys used by the first-card guide. Null in normal use.
  final CardGuideKeys? guideKeys;

  const PersonCardOverlay({
    super.key,
    required this.person,
    this.onAdd,
    this.onSkip,
    this.onBlock,
    this.onReport,
    this.onUnmatch,
    this.onOpenProfile,
    this.onWhyMatch,
    this.skipLabel = 'Skip',
    this.addLabel = 'Send request',
    this.showActions = true,
    this.showMenu = true,
    this.showProfilePill = true,
    this.showShadow = true,
    this.showSkillNote = false,
    this.guideKeys,
  });

  @override
  State<PersonCardOverlay> createState() => _PersonCardOverlayState();
}

class _PersonCardOverlayState extends State<PersonCardOverlay> {
  int _photoIndex = 0;
  bool _bioExpanded = false;
  final GlobalKey _infoKey = GlobalKey();
  double _infoHeight = 140;

  void _measureInfo() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _infoKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      final height = box.size.height;
      if ((height - _infoHeight).abs() > 0.5) {
        setState(() => _infoHeight = height);
      }
    });
  }

  @override
  void didUpdateWidget(covariant PersonCardOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.person.id != widget.person.id) {
      _photoIndex = 0;
      _bioExpanded = false;
    }

    // Showcase pages can change for the same person (e.g. after an edit).
    // Keep the index inside the current page list. The last page is the
    // details page, which sits one past the final media item.
    final lastPage = widget.person.cardMedia.length;
    if (_photoIndex > lastPage) {
      _photoIndex = lastPage;
    }
  }

  void _nextPhoto() {
    final lastPage = widget.person.cardMedia.length;
    if (_photoIndex < lastPage) {
      setState(() => _photoIndex++);
    }
  }

  void _previousPhoto() {
    if (_photoIndex > 0) {
      setState(() => _photoIndex--);
    }
  }

  Widget _buildBio(BuildContext context, String bio) {
    final style = AppTextStyles.regularText.copyWith(
      color: Colors.white,
      fontSize: 13,
      height: 1.35,
      shadows: [
        Shadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 6),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: bio, style: style),
          maxLines: 2,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth - 24);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();

        // Expanded bios used to grow without a bound and could overflow the
        // card on short screens or large text scales. Cap the expanded area
        // and let long text scroll instead.
        final maxExpandedHeight = (MediaQuery.sizeOf(context).height * 0.16)
            .clamp(72.0, 140.0);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap:
              overflows
                  ? () => setState(() => _bioExpanded = !_bioExpanded)
                  : null,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.format_quote_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: AnimatedSize(
                  duration: AppMotion.base,
                  curve: Curves.easeOut,
                  alignment: Alignment.topLeft,
                  child:
                      _bioExpanded
                          ? ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: maxExpandedHeight,
                            ),
                            child: SingleChildScrollView(
                              physics: const ClampingScrollPhysics(),
                              child: Text(bio, style: style),
                            ),
                          )
                          : Text(
                            bio,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: style,
                          ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final photoUrls = widget.person.cardMedia;
    final mediaCount = photoUrls.length;
    final totalPages = mediaCount + 1;
    final isDetailsPage = _photoIndex >= mediaCount;
    final currentPhoto = isDetailsPage ? null : photoUrls[_photoIndex];
    final hasVideo = isVideoUrl(currentPhoto);
    final backdropPhoto = photoUrls.firstWhere(
      (url) => url != null && !isVideoUrl(url),
      orElse: () => null,
    );
    final shownMedia = isDetailsPage ? backdropPhoto : currentPhoto;
    final showProfilePill = widget.showProfilePill && !isDetailsPage;

    if (!isDetailsPage) _measureInfo();
    final playBottom = (widget.showActions ? 130.0 : 64.0) + _infoHeight + 10;

    final shade = IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.85),
                ],
                stops: const [0.35, 1.0],
              ),
            ),
          ),
          AnimatedOpacity(
            opacity: isDetailsPage ? 1 : 0,
            duration: AppMotion.base,
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.82)),
          ),
        ],
      ),
    );

    final roleIconAsset =
        widget.person.role == PersonRole.learner
            ? 'assets/icons/rlearner.svg'
            : 'assets/icons/rmentor.svg';
    final roleLabel =
        widget.person.role == PersonRole.learner
            ? 'Wants to learn'
            : 'Wants to teach';
    final bodyText =
        (widget.showSkillNote ? widget.person.skillNote : widget.person.bio)
            .trim();
    final language = widget.person.language.trim();
    final learningStyle = widget.person.learningStyle.trim();
    final scheduleText = formatSchedule(widget.person.schedule);

    final card = Container(
      key: widget.guideKeys?.card,
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow:
            widget.showShadow
                ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ]
                : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.onOpenProfile != null && hasVideo)
            Positioned.fill(
              child: Semantics(
                container: true,
                button: true,
                label: 'Open ${widget.person.name} profile',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onOpenProfile,
                ),
              ),
            ),
          shownMedia != null
              ? ShowcaseMedia(
                url: shownMedia,
                fallback: _CardFallback(name: widget.person.name),
                alignment: Alignment.topCenter,
                foreground: shade,
                controlsBottom: playBottom,
              )
              : Stack(
                fit: StackFit.expand,
                children: [_CardFallback(name: widget.person.name), shade],
              ),
          if (widget.onOpenProfile != null && !hasVideo)
            Positioned.fill(
              child: Semantics(
                container: true,
                button: true,
                label: 'Open ${widget.person.name} profile',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onOpenProfile,
                ),
              ),
            ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 64,
            child: Semantics(
              container: true,
              button: true,
              label: 'Previous photo',
              child: GestureDetector(
                key: const ValueKey('card-previous'),
                behavior: HitTestBehavior.translucent,
                onTap: _previousPhoto,
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 64,
            child: Semantics(
              container: true,
              button: true,
              label: 'Next photo',
              child: GestureDetector(
                key: const ValueKey('card-next'),
                behavior: HitTestBehavior.translucent,
                onTap: _nextPhoto,
              ),
            ),
          ),
          if (totalPages > 1) ...[
            Positioned(
              left: 6,
              top: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Center(
                  child: _PhotoChevron(
                    icon: Icons.chevron_left,
                    visible: _photoIndex > 0,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 6,
              top: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Center(
                  child: _PhotoChevron(
                    icon: Icons.chevron_right,
                    visible: _photoIndex < totalPages - 1,
                  ),
                ),
              ),
            ),
          ],
          if (!isDetailsPage &&
              (widget.person.compatibility != null ||
                  widget.onOpenProfile != null))
            Positioned(
              top: 16,
              left: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.person.compatibility != null &&
                      widget.onWhyMatch != null)
                    _GlassPill(
                      onTap: widget.onWhyMatch,
                      icon: Icons.auto_awesome,
                      label:
                          '${((widget.person.compatibility! * 100).clamp(0, 100)).round()}% match',
                      semanticsLabel:
                          '${((widget.person.compatibility! * 100).clamp(0, 100)).round()} percent match. Why this match?',
                    ),
                  if (widget.person.compatibility != null &&
                      widget.onWhyMatch != null &&
                      widget.onOpenProfile != null &&
                      showProfilePill)
                    const SizedBox(height: 6),
                  if (widget.onOpenProfile != null && showProfilePill)
                    _GlassPill(
                      onTap: widget.onOpenProfile,
                      icon: Icons.person_outline,
                      label: 'View profile',
                      semanticsLabel: 'View ${widget.person.name} profile',
                    ),
                ],
              ),
            ),
          if (widget.showMenu)
            Positioned(
              top: 16,
              right: 16,
              child: PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: AppColors.elevatedSurface(context),
                elevation: 6,
                offset: const Offset(0, 40),
                onSelected: (value) {
                  if (value == 'unmatch') {
                    widget.onUnmatch?.call();
                  } else if (value == 'report') {
                    widget.onReport?.call();
                  } else if (value == 'block') {
                    widget.onBlock?.call();
                  }
                },
                itemBuilder:
                    (context) => [
                      if (widget.onUnmatch != null)
                        PopupMenuItem<String>(
                          value: 'unmatch',
                          child: Row(
                            children: [
                              Icon(
                                Icons.remove_circle_outline,
                                color: AppColors.dangerText(context),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Remove pal',
                                style: AppTextStyles.regularText.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      PopupMenuItem<String>(
                        value: 'report',
                        child: Row(
                          children: [
                            Icon(
                              Icons.flag_outlined,
                              color: AppColors.dangerText(context),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Report',
                              style: AppTextStyles.regularText.copyWith(
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'block',
                        child: Row(
                          children: [
                            Icon(
                              Icons.block,
                              color: AppColors.dangerText(context),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Block',
                              style: AppTextStyles.regularText.copyWith(
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                child: SizedBox(
                  width: AppSpacing.iconTarget,
                  height: AppSpacing.iconTarget,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.28),
                        ),
                      ),
                      child: const Icon(
                        Icons.more_horiz,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (!isDetailsPage || widget.onOpenProfile == null)
            Positioned(
              top: 16,
              right: widget.showMenu ? 16 + AppSpacing.iconTarget : 16,
              child: Semantics(
                container: true,
                button: true,
                label: isDetailsPage ? 'Back to photos' : 'Show full details',
                child: GestureDetector(
                  onTap:
                      () => setState(
                        () => _photoIndex = isDetailsPage ? 0 : mediaCount,
                      ),
                  child: SizedBox(
                    width: AppSpacing.iconTarget,
                    height: AppSpacing.iconTarget,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Icon(
                          isDetailsPage
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (isDetailsPage && widget.onOpenProfile != null)
            Positioned(
              top: 16,
              left: 16,
              child: Semantics(
                container: true,
                button: true,
                label: 'Back to photos',
                child: GestureDetector(
                  onTap: () => setState(() => _photoIndex = 0),
                  child: SizedBox(
                    width: AppSpacing.iconTarget,
                    height: AppSpacing.iconTarget,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.28),
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (!isDetailsPage)
            Positioned(
              left: 20,
              right: 20,
              bottom: widget.showActions ? 130 : 64,
              child: NotificationListener<SizeChangedLayoutNotification>(
                onNotification: (_) {
                  _measureInfo();
                  return false;
                },
                child: SizeChangedLayoutNotifier(
                  child: Column(
                    key: _infoKey,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        key: widget.guideKeys?.skill,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              '$roleLabel ',
                              style: AppTextStyles.regularText.copyWith(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Flexible(
                            child: Text(
                              toTitleCase(widget.person.skillName),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.boldText.copyWith(
                                color: AppColors.primary,
                                fontSize: 14,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          SvgPicture.asset(
                            roleIconAsset,
                            width: 16,
                            height: 16,
                            colorFilter: const ColorFilter.mode(
                              AppColors.primary,
                              BlendMode.srcIn,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              key: widget.guideKeys?.name,
                              widget.person.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.boldText.copyWith(
                                color: Colors.white,
                                fontSize: 22,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    blurRadius: 8,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (scheduleText.isNotEmpty) ...[
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            ConstrainedBox(
                              key: widget.guideKeys?.schedule,
                              constraints: const BoxConstraints(maxWidth: 150),
                              child: Text(
                                scheduleText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.regularText.copyWith(
                                  color: Colors.white,
                                  fontSize: 14,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.6,
                                      ),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (language.isNotEmpty || learningStyle.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 16,
                          children: [
                            if (language.isNotEmpty)
                              Row(
                                key: widget.guideKeys?.language,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.translate,
                                    size: 15,
                                    color: Colors.white70,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      language,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.regularText.copyWith(
                                        color: Colors.white70,
                                        fontSize: 13,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.6,
                                            ),
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            if (learningStyle.isNotEmpty)
                              Row(
                                key: widget.guideKeys?.learningStyle,
                                children: [
                                  const Icon(
                                    Icons.psychology,
                                    size: 15,
                                    color: Colors.white70,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      learningStyle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.regularText.copyWith(
                                        color: Colors.white70,
                                        fontSize: 13,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.6,
                                            ),
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                      if (bodyText.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        KeyedSubtree(
                          key: widget.guideKeys?.note,
                          child: _buildBio(context, bodyText),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          if (isDetailsPage)
            Positioned(
              left: 20,
              right: 20,
              top: 72,
              bottom: widget.showActions ? 130 : 64,
              child: _DetailsPage(
                roleLabel: roleLabel,
                roleIconAsset: roleIconAsset,
                skillName: toTitleCase(widget.person.skillName),
                name: widget.person.name,
                schedule: scheduleText,
                language: language,
                learningStyle: learningStyle,
                teachingStyle: widget.person.teachingStyle.trim(),
                bodyLabel: widget.showSkillNote ? 'About this skill' : 'About',
                body: bodyText,
              ),
            ),
          Positioned(
            left: 20,
            right: 20,
            bottom: widget.showActions ? 90 : 28,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (totalPages > 10)
                  Semantics(
                    label: 'Page ${_photoIndex + 1} of $totalPages',
                    excludeSemantics: true,
                    child: Text(
                      '${_photoIndex + 1} / $totalPages',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                      ),
                    ),
                  )
                else
                  for (int i = 0; i < totalPages; i++) ...[
                    Semantics(
                      button: true,
                      selected: i == _photoIndex,
                      label:
                          i == mediaCount
                              ? 'Show full details'
                              : 'Show photo ${i + 1}',
                      child: GestureDetector(
                        key: ValueKey('card-dot-$i'),
                        onTap: () => setState(() => _photoIndex = i),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: Center(
                            child: AnimatedContainer(
                              duration: AppMotion.base,
                              curve: Curves.easeOut,
                              width: i == _photoIndex ? 20 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color:
                                    i == _photoIndex
                                        ? AppColors.primary
                                        : isDetailsPage
                                        ? Colors.white.withValues(alpha: 0.35)
                                        : Colors.black.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (i != totalPages - 1) const SizedBox(width: 4),
                  ],
              ],
            ),
          ),
          if (widget.showActions)
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Row(
                key: widget.guideKeys?.actions,
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        onPressed: widget.onSkip,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.textPrimary),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          minimumSize: const Size(0, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(32),
                          ),
                        ),
                        child: Text(
                          widget.skipLabel,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: widget.onAdd,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          minimumSize: const Size(0, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(32),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          widget.addLabel,
                          style: TextStyle(
                            color: AppColors.black,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    final openProfile = widget.onOpenProfile;
    if (openProfile == null) return card;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: openProfile,
      child: card,
    );
  }
}

class _DetailsPage extends StatelessWidget {
  final String roleLabel;
  final String roleIconAsset;
  final String skillName;
  final String name;
  final String schedule;
  final String language;
  final String learningStyle;
  final String teachingStyle;
  final String bodyLabel;
  final String body;

  const _DetailsPage({
    required this.roleLabel,
    required this.roleIconAsset,
    required this.skillName,
    required this.name,
    required this.schedule,
    required this.language,
    required this.learningStyle,
    required this.teachingStyle,
    required this.bodyLabel,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                roleLabel,
                style: AppTextStyles.regularText.copyWith(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              Text(
                skillName,
                style: AppTextStyles.boldText.copyWith(
                  color: AppColors.primary,
                  fontSize: 14,
                ),
              ),
              SvgPicture.asset(
                roleIconAsset,
                width: 16,
                height: 16,
                colorFilter: const ColorFilter.mode(
                  AppColors.primary,
                  BlendMode.srcIn,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: AppTextStyles.boldText.copyWith(
              color: Colors.white,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.2)),
          if (language.isNotEmpty)
            _DetailRow(
              icon: Icons.translate,
              label: 'Languages',
              value: language,
            ),
          if (learningStyle.isNotEmpty)
            _DetailRow(
              icon: Icons.psychology,
              label: 'Learning style',
              value: learningStyle,
            ),
          if (teachingStyle.isNotEmpty)
            _DetailRow(
              icon: Icons.school_outlined,
              label: 'Teaching style',
              value: teachingStyle,
            ),
          if (schedule.isNotEmpty)
            _DetailRow(
              icon: Icons.calendar_today_outlined,
              label: 'Availability',
              value: schedule,
            ),
          if (body.isNotEmpty)
            _DetailRow(
              icon: Icons.format_quote_rounded,
              iconColor: AppColors.primary,
              label: bodyLabel,
              value: body,
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor = Colors.white70,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.regularText.copyWith(
                    color: Colors.white60,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTextStyles.regularText.copyWith(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoChevron extends StatelessWidget {
  final IconData icon;
  final bool visible;

  const _PhotoChevron({required this.icon, required this.visible});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 160),
      child: Container(
        width: 28,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  final VoidCallback? onTap;
  final IconData icon;
  final String label;
  final String semanticsLabel;

  const _GlassPill({
    required this.onTap,
    required this.icon,
    required this.label,
    required this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return pill;

    return Semantics(
      container: true,
      button: true,
      excludeSemantics: true,
      label: semanticsLabel,
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: SizedBox(height: 44, child: Center(child: pill)),
        ),
      ),
    );
  }
}

class _CardFallback extends StatelessWidget {
  final String name;

  const _CardFallback({required this.name});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3A3A3A), Color(0xFF1F1F1F)],
        ),
      ),
      child: Center(
        child: CircleAvatar(
          radius: 56,
          backgroundColor: Colors.white.withValues(alpha: 0.1),
          child: Text(
            UserAvatar.initialsFor(name),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 38,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

void showPersonProfileDialog(
  BuildContext context,
  Person person, {
  VoidCallback? onUnmatch,
  VoidCallback? onBlock,
  ValueChanged<String>? onReport,
}) {
  FocusManager.instance.primaryFocus?.unfocus();

  final hasMenu = onUnmatch != null || onBlock != null || onReport != null;

  showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.7),
    builder: (dialogContext) {
      final screenSize = MediaQuery.of(dialogContext).size;

      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: SizedBox(
          width: screenSize.width - 40,
          height: screenSize.height * 0.75,
          child: Stack(
            children: [
              PersonCardOverlay(
                person: person,
                showActions: false,
                showMenu: hasMenu,
                onUnmatch:
                    onUnmatch == null
                        ? null
                        : () async {
                          final confirmed = await showConfirmDialog(
                            dialogContext,
                            title: 'Remove pal',
                            message:
                                'Remove ${person.name} from your Pals? You’ll lose this pal and your chat history.',
                            confirmLabel: 'Remove pal',
                          );
                          if (!confirmed || !dialogContext.mounted) return;
                          Navigator.pop(dialogContext);
                          onUnmatch();
                        },
                onReport:
                    onReport == null
                        ? null
                        : () async {
                          final reason = await showReportReasonDialog(
                            dialogContext,
                            name: person.name,
                          );
                          if (reason == null || !dialogContext.mounted) return;
                          onReport(reason);
                        },
                onBlock:
                    onBlock == null
                        ? null
                        : () async {
                          final confirmed = await showConfirmDialog(
                            dialogContext,
                            title: 'Block',
                            message:
                                '${person.name} won’t be able to find or message you, and will be removed from your Pals. You can unblock them anytime in Settings.',
                            confirmLabel: 'Block',
                          );
                          if (!confirmed || !dialogContext.mounted) return;
                          Navigator.pop(dialogContext);
                          onBlock();
                        },
              ),
              Positioned(
                top: 16,
                left: 16,
                child: Semantics(
                  container: true,
                  button: true,
                  label: 'Close profile',
                  child: GestureDetector(
                    onTap: () => Navigator.pop(dialogContext),
                    child: SizedBox(
                      width: AppSpacing.iconTarget,
                      height: AppSpacing.iconTarget,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.28),
                            ),
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
