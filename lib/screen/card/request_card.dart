import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/screen/utils/schedule_format.dart';
import 'package:palturo/screen/card/person_card.dart';
import 'package:palturo/screen/chats_room.dart';
import 'package:palturo/screen/chats_page.dart' show SkillTag;
import 'package:palturo/widgets/user_avatar.dart';

enum _RequestOutcome { none, accepted, declined }

class RequestCard extends StatefulWidget {
  final String skillName;
  final String requesterName;
  final String schedule;
  final String language;
  final String learningStyle;
  final String timeAgo;
  final String iconAsset;
  final String seekingLabel;
  final String? connectionId;
  final ImageProvider? avatarImage;
  final Person? person;
  final PersonRole? role;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback? onUndo;
  final VoidCallback? onStartChatting;

  const RequestCard({
    super.key,
    required this.skillName,
    required this.requesterName,
    required this.schedule,
    required this.language,
    required this.learningStyle,
    required this.timeAgo,
    this.iconAsset = 'assets/icons/rlearner.svg',
    this.seekingLabel = 'Seeking a learner in',
    this.connectionId,
    this.avatarImage,
    this.person,
    this.role,
    required this.onAccept,
    required this.onDecline,
    this.onUndo,
    this.onStartChatting,
  });

  @override
  State<RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<RequestCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  _RequestOutcome _outcome = _RequestOutcome.none;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && mounted) {
        setState(() => _outcome = _RequestOutcome.none);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleAccept() {
    if (_controller.isAnimating || _outcome != _RequestOutcome.none) return;
    HapticFeedback.lightImpact();
    setState(() => _outcome = _RequestOutcome.accepted);
    _controller.forward();
    widget.onAccept();
  }

  void _handleDecline() {
    if (_controller.isAnimating || _outcome != _RequestOutcome.none) return;
    HapticFeedback.lightImpact();
    setState(() => _outcome = _RequestOutcome.declined);
    _controller.forward();
    widget.onDecline();
  }

  void _handleUndo() {
    if (_controller.isAnimating || _outcome == _RequestOutcome.none) return;
    HapticFeedback.selectionClick();
    _controller.reverse();
    widget.onUndo?.call();
  }

  void _handleStartChatting() {
    final custom = widget.onStartChatting;
    if (custom != null) {
      custom();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => ChatRoom(
              connectionId: widget.connectionId,
              name: widget.requesterName,
              avatarImage: widget.avatarImage,
              skillName: widget.skillName,
              role: widget.role,
              person: widget.person,
            ),
      ),
    );
  }

  BoxDecoration _cardDecoration(
    BuildContext context, {
    Color? color,
    Color? borderColor,
    bool shadow = true,
  }) {
    return BoxDecoration(
      color: color ?? AppColors.elevatedSurface(context),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: borderColor ?? AppColors.border(context)),
      boxShadow:
          shadow
              ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  spreadRadius: 0,
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ]
              : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final angle = _animation.value * pi;
        final showBack = angle > pi / 2;

        return Transform(
          alignment: Alignment.center,
          transform:
              Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateY(angle),
          child: Stack(
            children: [
              Visibility(
                visible: !showBack,
                maintainSize: true,
                maintainState: true,
                maintainAnimation: true,
                child: _buildFront(context),
              ),
              if (showBack)
                Positioned.fill(
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.rotationY(pi),
                    child: _buildBack(context),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBack(BuildContext context) {
    switch (_outcome) {
      case _RequestOutcome.accepted:
        return _buildAcceptedBack(context);
      case _RequestOutcome.declined:
        return _buildDeclinedBack(context);
      case _RequestOutcome.none:
        return const SizedBox.shrink();
    }
  }

  Widget _statusAvatar(
    BuildContext context, {
    required IconData badgeIcon,
    required Color badgeColor,
    required Color badgeBackground,
    required Color ringColor,
    double avatarOpacity = 1,
  }) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: avatarOpacity,
              child: UserAvatar(
                name: widget.requesterName,
                image: widget.avatarImage,
                size: 64,
              ),
            ),
          ),
          Positioned(
            right: -4,
            bottom: -4,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: badgeBackground,
                shape: BoxShape.circle,
                border: Border.all(color: ringColor, width: 2),
              ),
              child: Icon(badgeIcon, size: 14, color: badgeColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcceptedBack(BuildContext context) {
    final surface = AppColors.elevatedSurface(context);
    final accentColor = AppColors.accentText(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: _cardDecoration(
        context,
        color: surface,
        borderColor: AppColors.primary.withValues(alpha: 0.6),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _statusAvatar(
              context,
              badgeIcon: Icons.check,
              badgeColor: Colors.white,
              badgeBackground: const Color(0xFF2E9E5B),
              ringColor: surface,
            ),
            const SizedBox(height: 10),
            Text(
              widget.requesterName,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.boldText.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 6),
            SkillTag(skillName: widget.skillName, role: widget.role),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: _handleStartChatting,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(23),
                  ),
                ),
                child: Text(
                  'Start chatting',
                  style: AppTextStyles.boldText.copyWith(
                    color: Colors.black,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeclinedBack(BuildContext context) {
    final surface = AppColors.mutedSurface(context);
    final secondary = Theme.of(context).colorScheme.secondary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: _cardDecoration(context, color: surface, shadow: false),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _statusAvatar(
              context,
              badgeIcon: Icons.close,
              badgeColor: Colors.white,
              badgeBackground: AppColors.dangerText(context),
              ringColor: surface,
              avatarOpacity: 0.5,
            ),
            const SizedBox(height: 10),
            Text(
              widget.requesterName,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.boldText.copyWith(
                color: secondary,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Request declined',
              style: AppTextStyles.regularText.copyWith(
                color: AppColors.mutedText(context),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                onPressed: _handleUndo,
                icon: Icon(Icons.undo, size: 18, color: secondary),
                label: Text(
                  'Undo',
                  style: AppTextStyles.regularText.copyWith(
                    color: secondary,
                    fontSize: 15,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.border(context)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(23),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFront(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;
    final accentColor = AppColors.accentText(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SvgPicture.asset(widget.iconAsset, width: 22, height: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.seekingLabel,
                  style: AppTextStyles.regularText.copyWith(
                    color: textTheme,
                    fontSize: 13,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: textTheme),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  widget.skillName,
                  style: AppTextStyles.boldText.copyWith(
                    color: accentColor,
                    fontSize: 20,
                  ),
                ),
              ),
              Text(
                widget.timeAgo,
                style: AppTextStyles.regularText.copyWith(
                  color: AppColors.mutedText(context),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(
            height: 1,
            thickness: 0.5,
            color: textTheme.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              UserAvatar(
                name: widget.requesterName,
                image: widget.avatarImage,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.requesterName,
                      style: AppTextStyles.boldText.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (widget.schedule.trim().isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 13,
                                color: textTheme,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                formatSchedule(widget.schedule),
                                style: AppTextStyles.regularText.copyWith(
                                  color: textTheme,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        if (widget.language.trim().isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.translate, size: 13, color: textTheme),
                              const SizedBox(width: 4),
                              Text(
                                widget.language,
                                style: AppTextStyles.regularText.copyWith(
                                  color: textTheme,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        if (widget.learningStyle.trim().isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.psychology,
                                size: 13,
                                color: textTheme,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.learningStyle,
                                style: AppTextStyles.regularText.copyWith(
                                  color: textTheme,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: TextButton(
                    onPressed: _handleDecline,
                    child: Text(
                      'Decline',
                      style: AppTextStyles.regularText.copyWith(
                        color: AppColors.dangerText(context),
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
              Container(width: 1, height: 30, color: AppColors.border(context)),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: TextButton(
                    onPressed: _handleAccept,
                    child: Text(
                      'Accept',
                      style: AppTextStyles.regularText.copyWith(
                        color: accentColor,
                        fontSize: 16,
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