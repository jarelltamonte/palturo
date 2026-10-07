import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/screen/action_dialogs.dart';

enum PersonRole { learner, mentor }

class Person {
  final String id;
  final String name;
  final String schedule;
  final String language;
  final String learningStyle;
  final String skillName;
  final PersonRole role;
  final String bio;
  final List<String?> photoUrls;
  /// FR-5 short-form showcase media (image/video thumbnails) — shown first on
  /// the card per spec §6.3 recommendation card.
  final List<String?> showcaseUrls;
  /// Reciprocal compatibility (0..1) from the pipeline — spec §6.3 indicator.
  final double? compatibility;

  const Person({
    required this.id,
    required this.name,
    required this.schedule,
    required this.language,
    required this.learningStyle,
    required this.skillName,
    required this.role,
    this.bio = '',
    this.photoUrls = const [null],
    this.showcaseUrls = const [null],
    this.compatibility,
  });

  /// Card page media: showcase content first, profile photos after.
  List<String?> get cardMedia => [
        ...showcaseUrls,
        ...photoUrls,
      ];
}

class PersonCardOverlay extends StatefulWidget {
  final Person person;
  final VoidCallback? onAdd;
  final VoidCallback? onSkip;
  final VoidCallback? onBlock;
  final VoidCallback? onReport;
  final VoidCallback? onUnmatch;
  final String skipLabel;
  final String addLabel;
  final bool showActions;
  final bool showMenu;

  const PersonCardOverlay({
    super.key,
    required this.person,
    this.onAdd,
    this.onSkip,
    this.onBlock,
    this.onReport,
    this.onUnmatch,
    this.skipLabel = 'Skip',
    this.addLabel = 'Add',
    this.showActions = true,
    this.showMenu = true,
  });

  @override
  State<PersonCardOverlay> createState() => _PersonCardOverlayState();
}

class _PersonCardOverlayState extends State<PersonCardOverlay> {
  int _photoIndex = 0;
  bool _bioExpanded = false;

  @override
  void didUpdateWidget(covariant PersonCardOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.person.id != widget.person.id) {
      _photoIndex = 0;
      _bioExpanded = false;
    }
  }

  void _nextPhoto() {
    final total = widget.person.photoUrls.length;
    if (_photoIndex < total - 1) {
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
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  alignment: Alignment.topLeft,
                  child: Text(
                    bio,
                    maxLines: _bioExpanded ? null : 2,
                    overflow:
                        _bioExpanded
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
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
    final currentPhoto =
        photoUrls.isNotEmpty && _photoIndex < photoUrls.length
            ? photoUrls[_photoIndex]
            : null;

    final roleIconAsset =
        widget.person.role == PersonRole.learner
            ? 'assets/icons/rlearner.svg'
            : 'assets/icons/rmentor.svg';
    final roleLabel =
        widget.person.role == PersonRole.learner
            ? 'Wants to learn'
            : 'Wants to teach';
    final bio = widget.person.bio.trim();
    final compat = widget.person.compatibility;
    final compatPct =
        compat == null ? null : ((compat * 100).clamp(0, 100)).round();

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          currentPhoto != null
              ? Image.network(currentPhoto,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(color: Colors.grey[400]))
              : Container(color: Colors.grey[400]),
          if (compatPct != null)
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$compatPct% match',
                  style: AppTextStyles.boldText.copyWith(
                    color: AppColors.primary,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _previousPhoto,
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _nextPhoto,
                ),
              ),
            ],
          ),
          Container(
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
          if (widget.showMenu)
            Positioned(
              top: 16,
              right: 16,
              child: PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                color: Theme.of(context).colorScheme.surface,
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
                              const Icon(
                                Icons.remove_circle_outline,
                                color: Colors.red,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Unmatch',
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
                            const Icon(
                              Icons.flag_outlined,
                              color: Colors.red,
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
                            const Icon(
                              Icons.block,
                              color: Colors.red,
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
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.more_horiz,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          Positioned(
            left: 20,
            right: 20,
            bottom: widget.showActions ? 130 : 64,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                        widget.person.skillName,
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
                        widget.person.name,
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
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.person.schedule,
                      style: AppTextStyles.regularText.copyWith(
                        color: Colors.white,
                        fontSize: 14,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.translate,
                          size: 15,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.person.language,
                          style: AppTextStyles.regularText.copyWith(
                            color: Colors.white70,
                            fontSize: 13,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.6),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.psychology,
                          size: 15,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.person.learningStyle.isNotEmpty
                                ? widget.person.learningStyle
                                : 'No learning styles set',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.regularText.copyWith(
                              color: Colors.white70,
                              fontSize: 13,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.6),
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
                if (bio.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildBio(context, bio),
                ],
              ],
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: widget.showActions ? 90 : 28,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < photoUrls.length; i++) ...[
                  GestureDetector(
                    onTap: () => setState(() => _photoIndex = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      width: i == _photoIndex ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color:
                            i == _photoIndex
                                ? AppColors.primary
                                : Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  if (i != photoUrls.length - 1) const SizedBox(width: 6),
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
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onSkip,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.textPrimary),
                        padding: const EdgeInsets.symmetric(vertical: 16),
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: widget.onAdd,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        widget.addLabel,
                        style: TextStyle(color: AppColors.black, fontSize: 16),
                      ),
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
                            title: 'Unmatch',
                            message:
                                'Unmatch ${person.name}? You’ll lose this match and your chat history.',
                            confirmLabel: 'Unmatch',
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
                                '${person.name} won’t be able to find or message you, and will be removed from your matches. You can unblock them anytime in Settings.',
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
                child: GestureDetector(
                  onTap: () => Navigator.pop(dialogContext),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 18,
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
