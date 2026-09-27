import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/theme/app_colors.dart';

enum PersonRole { learner, mentor }

class Person {
  final String id;
  final String name;
  final String schedule;
  final String language;
  final String learningStyle;
  final String skillName;
  final PersonRole role;
  final List<String?> photoUrls;

  const Person({
    required this.id,
    required this.name,
    required this.schedule,
    required this.language,
    required this.learningStyle,
    required this.skillName,
    required this.role,
    this.photoUrls = const [null],
  });
}

class PersonCardOverlay extends StatefulWidget {
  final Person person;
  final VoidCallback onAdd;
  final VoidCallback onSkip;
  final VoidCallback? onBlock;
  final VoidCallback? onReport;

  const PersonCardOverlay({
    super.key,
    required this.person,
    required this.onAdd,
    required this.onSkip,
    this.onBlock,
    this.onReport,
  });

  @override
  State<PersonCardOverlay> createState() => _PersonCardOverlayState();
}

class _PersonCardOverlayState extends State<PersonCardOverlay> {
  int _photoIndex = 0;

  @override
  void didUpdateWidget(covariant PersonCardOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.person.id != widget.person.id) {
      _photoIndex = 0;
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

  @override
  Widget build(BuildContext context) {
    final photoUrls = widget.person.photoUrls;
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
              ? Image.network(currentPhoto, fit: BoxFit.cover)
              : Container(color: Colors.grey[400]),
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
                if (value == 'report') {
                  widget.onReport?.call();
                } else if (value == 'block') {
                  widget.onBlock?.call();
                }
              },
              itemBuilder:
                  (context) => [
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
                          const Icon(Icons.block, color: Colors.red, size: 20),
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
            bottom: 130,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
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
                    Text(
                      widget.person.skillName,
                      style: AppTextStyles.regularText.copyWith(
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
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.psychology,
                          size: 15,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.person.learningStyle,
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
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 100,
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
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text(
                      'Skip',
                      style: TextStyle(
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
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Add',
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
