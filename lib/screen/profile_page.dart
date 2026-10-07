import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/onboarding/onboarding_models.dart';
import 'package:palturo/onboarding/onboarding_flow.dart'
    show kLearningOptions, kTeachingOptions;
import 'package:palturo/onboarding/widgets/role_card_group.dart';
import 'package:palturo/screen/card/person_card.dart';
import 'package:palturo/screen/card/skills_card.dart';
import 'package:palturo/services/profile_service.dart';
import 'package:palturo/services/match_api.dart';
import 'matches.dart';
import 'profile_data.dart';
import 'profile_edit.dart';
import 'settings.dart';

const Map<String, int> _dayOrder = {
  'Monday': 0,
  'Tuesday': 1,
  'Wednesday': 2,
  'Thursday': 3,
  'Friday': 4,
  'Saturday': 5,
  'Sunday': 6,
  'Mon': 0,
  'Tue': 1,
  'Wed': 2,
  'Thu': 3,
  'Fri': 4,
  'Sat': 5,
  'Sun': 6,
};

String _formatSchedule(String schedule) {
  final days =
      schedule
          .split('/')
          .map((day) => day.trim())
          .where((day) => day.isNotEmpty)
          .toList();

  days.sort((a, b) => (_dayOrder[a] ?? 999).compareTo(_dayOrder[b] ?? 999));

  return days
      .map((day) => day.length > 3 ? day.substring(0, 3) : day)
      .join('/');
}

String _skillLabel(String id, List<OnboardingOption> options) {
  final custom = CustomSkill.tryParse(id);
  if (custom != null) return custom.text;
  for (final option in options) {
    if (option.id == id) return option.label;
  }
  return id;
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ProfileService _profileService = ProfileService();
  ProfileData? _profile;
  bool _isLoading = true;
  int? _friendCount;

  static const _roleOptions = [
    RoleOption(
      OnboardingRole.learn,
      'assets/icons/rlearner.svg',
      'I want to\nlearn',
    ),
    RoleOption(
      OnboardingRole.teach,
      'assets/icons/rmentor.svg',
      'I want to\nteach',
    ),
    RoleOption(OnboardingRole.both, 'assets/icons/rboth.svg', 'I can do\nboth'),
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadFriendCount();
  }

  Future<void> _loadFriendCount() async {
    try {
      final convos = await MatchApi.getConversations();
      final accepted = convos.where((c) => c.status == 'accepted').length;
      if (mounted) setState(() => _friendCount = accepted);
    } catch (_) {/* keep null → renders plain label */}
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final data = await _profileService.getCurrentUserProfile();
    if (mounted) {
      setState(() {
        _profile =
            data ??
            ProfileData(
              firstName: 'Juan',
              lastName: 'De La Cruz',
              schedule: 'Mon/Sat/Sun',
              bio:
                  'Mahilig akong magluto at matuto ng lumang gawang-kamay. Tara, magpalitan tayo ng kaalaman!',
              languages: const ['English', 'Tagalog'],
              interests: const ['Discussion', 'Visual Demons...'],
              role: OnboardingRole.both,
              learningSkillIds: const [
                'cooking_pinakbet',
                'weaving_inabel',
                'parol_making',
              ],
              teachingSkillIds: const [],
            );
        _isLoading = false;
      });
    }
  }

  Future<void> _openEdit() async {
    if (_profile == null) return;

    final updated = await Navigator.push<ProfileData>(
      context,
      MaterialPageRoute(builder: (_) => ProfileEditPage(profile: _profile!)),
    );

    if (updated != null && mounted) {
      setState(() => _profile = updated);
      await _loadProfile();
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

    return Person(
      id: profile.id.isNotEmpty ? profile.id : 'me',
      name: profile.name,
      schedule: _formatSchedule(profile.schedule),
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
            child: IconButton(
              icon: Icon(Icons.settings, color: textTheme),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const Settings()),
                );
              },
            ),
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _loadProfile,
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
                                      builder: (context) => const Matches(),
                                    ),
                                  );
                                },
                                child: Container(
                                  height: 56,
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: bgTheme,
                                    borderRadius: BorderRadius.circular(24),
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
                                        child: Row(
                                          children: [
                                            Text(
                                              _friendCount == null
                                                  ? 'Friends'
                                                  : 'Friends ($_friendCount)',
                                              style: AppTextStyles.boldText
                                                  .copyWith(color: textTheme),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '142',
                                              style: AppTextStyles.regularText
                                                  .copyWith(
                                                    color: textTheme.withValues(
                                                      alpha: 0.6,
                                                    ),
                                                    fontSize: 12,
                                                  ),
                                            ),
                                          ],
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
                            RoleCardGroup(
                              options: _roleOptions,
                              selected: _profile!.role,
                              isEditing: false,
                              onSelect: (_) {},
                            ),
                            const SizedBox(height: 24),
                            if (_profile!.role == OnboardingRole.learn ||
                                _profile!.role == OnboardingRole.both) ...[
                              SkillsCard.toLearn(
                                isEditing: false,
                                initialSkillIds: _profile!.learningSkillIds,
                              ),
                              const SizedBox(height: 24),
                            ],
                            if (_profile!.role == OnboardingRole.teach ||
                                _profile!.role == OnboardingRole.both)
                              SkillsCard.toTeach(
                                isEditing: false,
                                initialSkillIds: _profile!.teachingSkillIds,
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
    final cardColor = Theme.of(context).colorScheme.surface;
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
                GestureDetector(
                  onTap: onAvatarTap,
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.grey[300],
                    backgroundImage:
                        displayAvatar != null
                            ? NetworkImage(displayAvatar)
                            : null,
                    child:
                        displayAvatar == null
                            ? Icon(
                              Icons.person,
                              size: 40,
                              color: Colors.grey[600],
                            )
                            : null,
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
                          fontSize: 20,
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
                          Text(
                            _formatSchedule(profile.schedule),
                            style: TextStyle(color: textColor, fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: textColor),
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
