import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/onboarding/onboarding_models.dart';
import 'package:palturo/onboarding/onboarding_flow.dart'
    show OnboardingFlow, kLearningOptions, kTeachingOptions;
import 'package:palturo/services/preferences_service.dart';
import 'package:palturo/screen/card/person_card.dart';
import 'package:palturo/screen/card/skills_card.dart';
import 'package:palturo/services/profile_service.dart';
import 'package:palturo/services/chat_state_service.dart';
import 'package:palturo/screen/utils/pals_count.dart';
import 'package:palturo/screen/utils/schedule_format.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'matches.dart';
import 'profile_data.dart';
import 'profile_edit.dart';
import 'settings.dart';
import 'package:palturo/widgets/app_skeleton.dart';
import 'package:palturo/widgets/user_avatar.dart';

String _skillLabel(String id, List<OnboardingOption> options) {
  final custom = CustomSkill.tryParse(id);
  if (custom != null) return custom.text;
  for (final option in options) {
    if (option.id == id) return option.label;
  }
  return id;
}

class ProfilePage extends StatefulWidget {
  final VoidCallback? onStartSwiping;

  const ProfilePage({super.key, this.onStartSwiping});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ProfileService _profileService = ProfileService();
  ProfileData? _profile;
  bool _isLoading = true;
  static const String _loadError =
      "Couldn't load your profile. Please try again.";
  int? _friendCount;
  bool _openingEditor = false;
  bool _hasSkipped = false;

  @override
  void initState() {
    super.initState();
    ChatStateService.instance.addListener(_onPalsChanged);
    _onPalsChanged();
    ChatStateService.instance.loadConversations(showSpinner: false);
    _loadSkipped();
    _loadProfile();
  }

  Future<void> _loadSkipped() async {
    final skipped =
        await PreferencesService.instance.getBool('skipped_onboarding') ??
        false;
    if (mounted) setState(() => _hasSkipped = skipped);
  }

  Future<void> _openSetup() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => OnboardingFlow(
              onFinished: () async {
                await PreferencesService.instance.setBool(
                  'skipped_onboarding',
                  false,
                );
                if (!mounted) return;
                Navigator.of(context).pop();
                setState(() => _hasSkipped = false);
                _loadProfile();
              },
              onSkip: () async {
                await PreferencesService.instance.setBool(
                  'skipped_onboarding',
                  true,
                );
                if (mounted) Navigator.of(context).pop();
              },
            ),
      ),
    );
  }

  void _onPalsChanged() {
    if (!mounted) return;
    final service = ChatStateService.instance;
    final count = service.hasLoaded ? service.conversations.length : null;
    if (_friendCount != count) {
      setState(() => _friendCount = count);
    }
  }

  @override
  void dispose() {
    ChatStateService.instance.removeListener(_onPalsChanged);
    super.dispose();
  }

  Future<void> _refreshProfileAndPals() async {
    await Future.wait([
      _loadProfile(showSpinner: false),
      ChatStateService.instance.loadConversations(showSpinner: false),
    ]);
  }

  Future<void> _loadProfile({bool showSpinner = true}) async {
    if (!mounted) return;

    if (showSpinner) {
      setState(() => _isLoading = true);
    }

    final data = await _profileService.getCurrentUserProfile();

    if (!mounted) return;

    if (data != null) {
      setState(() {
        _profile = data;
        _isLoading = false;
      });
      return;
    }

    // A failed refresh must not discard a profile that is already on screen.
    setState(() => _isLoading = false);
    if (_profile != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Couldn’t refresh your profile. Please try again.'),
        ),
      );
    }
  }

  Future<void> _openEdit() async {
    final profile = _profile;
    if (profile == null || _openingEditor) return;

    _openingEditor = true;
    try {
      final updated = await Navigator.push<ProfileData>(
        context,
        MaterialPageRoute(builder: (_) => ProfileEditPage(profile: profile)),
      );

      if (!mounted) return;
      if (updated != null) {
        setState(() => _profile = updated);
      }
    } finally {
      _openingEditor = false;
    }
  }

  Person _profileToPerson() {
    final profile = _profile!;
    final learnId =
        profile.learningSkillIds.isNotEmpty
            ? profile.learningSkillIds.first
            : null;
    final teachId =
        profile.teachingSkillIds.isNotEmpty
            ? profile.teachingSkillIds.first
            : null;

    PersonRole role;
    String skillName;

    if (profile.role == OnboardingRole.teach) {
      role = PersonRole.mentor;
      skillName = teachId == null ? '' : _skillLabel(teachId, kTeachingOptions);
    } else if (profile.role == OnboardingRole.learn) {
      role = PersonRole.learner;
      skillName = learnId == null ? '' : _skillLabel(learnId, kLearningOptions);
    } else if (learnId != null) {
      role = PersonRole.learner;
      skillName = _skillLabel(learnId, kLearningOptions);
    } else if (teachId != null) {
      role = PersonRole.mentor;
      skillName = _skillLabel(teachId, kTeachingOptions);
    } else {
      role = PersonRole.learner;
      skillName = '';
    }

    final formattedSched = formatSchedule(profile.schedule);
    return Person(
      id: profile.id.isNotEmpty ? profile.id : 'me',
      name: profile.name,
      schedule: formattedSched.isNotEmpty ? formattedSched : 'No schedule set',
      language: profile.languages.join(', '),
      learningStyle: profile.interests.join(', '),
      skillName: skillName,
      role: role,
      bio: profile.bio,
      photoUrls: [profile.avatarUrl],
    );
  }

  void _showMyProfile() {
    if (_profile == null) return;
    showPersonProfileDialog(context, _profileToPerson());
  }

  bool _needsProfileTip(ProfileData profile) {
    final wantsTeaching =
        profile.role == OnboardingRole.teach ||
        profile.role == OnboardingRole.both;
    return profile.bio.trim().isEmpty ||
        profile.languages.isEmpty ||
        profile.availableDays.isEmpty ||
        (wantsTeaching && profile.teachingSkillImages.isEmpty);
  }

  Widget _buildErrorState(Color textTheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_off_outlined,
              size: 48,
              color: textTheme.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              _loadError,
              textAlign: TextAlign.center,
              style: AppTextStyles.regularText.copyWith(color: textTheme),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadProfile(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text(
                'Retry',
                style: TextStyle(color: Colors.black, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgTheme = Theme.of(context).colorScheme.surface;
    final textTheme = Theme.of(context).colorScheme.secondary;
    final adaptiveHeight =
        defaultTargetPlatform == TargetPlatform.iOS ? 44.0 : 56.0;

    return Scaffold(
      backgroundColor: bgTheme,
      appBar: AppBar(
        toolbarHeight: adaptiveHeight,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Profile',
            style: AppTextStyles.headingText.copyWith(color: textTheme),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Semantics(
              button: true,
              label: 'Settings',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const Settings()),
                  );
                },
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Icon(Icons.settings, color: textTheme),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body:
          _isLoading
              ? const ProfileSkeleton()
              : _profile == null
              ? _buildErrorState(textTheme)
              : RefreshIndicator(
                onRefresh: _refreshProfileAndPals,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: _ProfileSummaryCard(
                          profile: _profile!,
                          onTap: _openEdit,
                          onAvatarTap: _showMyProfile,
                        ),
                      ),
                      if (_needsProfileTip(_profile!))
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: _ProfileTip(onEdit: _openEdit),
                        ),
                      if (_hasSkipped)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: _ContinueSetupCard(onTap: _openSetup),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(24),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => Matches(
                                            onStartSwiping:
                                                widget.onStartSwiping,
                                          ),
                                    ),
                                  );
                                },
                                child: Container(
                                  constraints: const BoxConstraints(
                                    minHeight: 56,
                                  ),
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.elevatedSurface(context),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: AppColors.border(context),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.1,
                                        ),
                                        spreadRadius: 0,
                                        blurRadius: 16,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Semantics(
                                          label:
                                              _friendCount == null
                                                  ? 'Pals'
                                                  : palCountLabel(
                                                    _friendCount!,
                                                  ),
                                          excludeSemantics: true,
                                          child: Row(
                                            children: [
                                              Text(
                                                (_friendCount ?? 0) > 1
                                                    ? 'Pals'
                                                    : 'Pal',
                                                style: AppTextStyles.boldText
                                                    .copyWith(color: textTheme),
                                              ),
                                              if (_friendCount != null) ...[
                                                const SizedBox(width: 8),
                                                Text(
                                                  '$_friendCount',
                                                  style: AppTextStyles
                                                      .regularText
                                                      .copyWith(
                                                        color:
                                                            AppColors.mutedText(
                                                              context,
                                                            ),
                                                        fontSize: 14,
                                                      ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right,
                                        color: textTheme,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Divider(
                              color: textTheme.withValues(alpha: 0.2),
                              thickness: 1,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Role',
                              style: AppTextStyles.regularText.copyWith(
                                color: AppColors.mutedText(context),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            _RoleSummary(role: _profile!.role),
                            const SizedBox(height: 24),
                            if (_profile!.role == OnboardingRole.learn ||
                                _profile!.role == OnboardingRole.both) ...[
                              SkillsCard.toLearn(
                                isEditing: false,
                                initialSkillIds: _profile!.learningSkillIds,
                                notes: _profile!.learningNotes,
                              ),
                              const SizedBox(height: 24),
                            ],
                            if (_profile!.role == OnboardingRole.teach ||
                                _profile!.role == OnboardingRole.both)
                              SkillsCard.toTeach(
                                isEditing: false,
                                initialSkillIds: _profile!.teachingSkillIds,
                                notes: _profile!.teachingNotes,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
    );
  }
}

class _ProfileSummaryCard extends StatelessWidget {
  final ProfileData profile;
  final VoidCallback onTap;
  final VoidCallback onAvatarTap;

  const _ProfileSummaryCard({
    required this.profile,
    required this.onTap,
    required this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.secondary;
    final cardColor = AppColors.elevatedSurface(context);
    final displayAvatar =
        (profile.photos.isNotEmpty && profile.photos[0] != null)
            ? profile.photos[0]
            : profile.avatarUrl;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              spreadRadius: 0,
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  container: true,
                  button: true,
                  label: 'View profile photo',
                  child: GestureDetector(
                    onTap: onAvatarTap,
                    child: UserAvatar(
                      name: profile.name,
                      image:
                          displayAvatar != null
                              ? NetworkImage(displayAvatar)
                              : null,
                      size: 80,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        profile.name,
                        style: AppTextStyles.headingText.copyWith(
                          color: textColor,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 14,
                            color: textColor,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              formatSchedule(profile.schedule).isNotEmpty
                                  ? formatSchedule(profile.schedule)
                                  : 'No schedule set',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: textColor, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: onTap,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accentText(context),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 36),
                  ),
                  child: const Text('Edit'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: textColor.withValues(alpha: 0.2)),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.translate, size: 18, color: textColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    profile.languages.join(', '),
                    style: TextStyle(color: textColor, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.psychology, size: 18, color: textColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    profile.interests.join(', '),
                    style: TextStyle(color: textColor, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ContinueSetupCard extends StatelessWidget {
  final VoidCallback onTap;

  const _ContinueSetupCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.secondary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: BoxDecoration(
            color: AppColors.elevatedSurface(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.play_circle_outline,
                color: AppColors.accentText(context),
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Continue setup',
                      style: AppTextStyles.boldText.copyWith(
                        color: textColor,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Add the details that power better matches.',
                      style: AppTextStyles.regularText.copyWith(
                        color: AppColors.mutedText(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.mutedText(context)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileTip extends StatelessWidget {
  final VoidCallback onEdit;

  const _ProfileTip({required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome_outlined,
            color: AppColors.accentText(context),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Finish your profile details to improve your recommendations.',
              style: AppTextStyles.regularText.copyWith(
                color: textColor,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
          TextButton(onPressed: onEdit, child: const Text('Improve')),
        ],
      ),
    );
  }
}

class _RoleSummary extends StatelessWidget {
  final OnboardingRole? role;

  const _RoleSummary({required this.role});

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    if (role == OnboardingRole.learn || role == OnboardingRole.both) {
      chips.add(
        _RoleChip(
          svgAsset: 'assets/icons/rlearner.svg',
          label: role == OnboardingRole.both ? 'Learner' : 'I want to learn',
        ),
      );
    }
    if (role == OnboardingRole.teach || role == OnboardingRole.both) {
      chips.add(
        _RoleChip(
          svgAsset: 'assets/icons/rmentor.svg',
          label: role == OnboardingRole.both ? 'Mentor' : 'I want to teach',
        ),
      );
    }
    if (chips.isEmpty) {
      chips.add(_RoleChip(icon: Icons.help_outline, label: 'Role not set'));
    }
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }
}

class _RoleChip extends StatelessWidget {
  final IconData? icon;
  final String? svgAsset;
  final String label;

  const _RoleChip({this.icon, this.svgAsset, required this.label})
    : assert(icon != null || svgAsset != null);

  @override
  Widget build(BuildContext context) {
    final iconColor = AppColors.accentText(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (svgAsset != null)
            SvgPicture.asset(
              svgAsset!,
              width: 16,
              height: 16,
              colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
            )
          else
            Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.boldText.copyWith(
              color: Theme.of(context).colorScheme.secondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
