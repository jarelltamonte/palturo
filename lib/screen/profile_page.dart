import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/onboarding/onboarding_models.dart';
import 'package:palturo/onboarding/widgets/role_card_group.dart';
import 'package:palturo/onboarding/widgets/skills_card.dart';
import 'profile_data.dart';
import 'profile_edit.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  ProfileData _profile = const ProfileData(
    name: 'Juan De La Cruz',
    schedule: 'Mon/Sat/Sun',
    languages: ['English', 'Tagalog'],
    interests: ['Discussion', 'Visual Demons...'],
    role: OnboardingRole.both,
    learningSkillIds: ['cooking_pinakbet', 'weaving_inabel', 'parol_making'],
    teachingSkillIds: [],
  );

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

  Future<void> _openEdit() async {
    final updated = await Navigator.push<ProfileData>(
      context,
      MaterialPageRoute(builder: (_) => ProfileEditPage(profile: _profile)),
    );
    if (updated != null) {
      setState(() => _profile = updated);
    }
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
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _ProfileSummaryCard(profile: _profile, onTap: _openEdit),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RoleCardGroup(
                    options: _roleOptions,
                    selected: _profile.role,
                    isEditing: false,
                    onSelect: (_) {},
                  ),
                  const SizedBox(height: 24),
                  if (_profile.role == OnboardingRole.learn ||
                      _profile.role == OnboardingRole.both) ...[
                    SkillsCard.toLearn(
                      isEditing: false,
                      initialSkillIds: _profile.learningSkillIds,
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (_profile.role == OnboardingRole.teach ||
                      _profile.role == OnboardingRole.both)
                    SkillsCard.toTeach(
                      isEditing: false,
                      initialSkillIds: _profile.teachingSkillIds,
                    ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                // Logout logic here
              },
              icon: const Icon(Icons.logout_rounded),
              label: Text('Logout', style: AppTextStyles.regularText.copyWith(
                    color: Theme.of(context).colorScheme.primary, fontSize: 16,
                  ),),
            ),
            const SizedBox(height: 16),
            Center(
              child: GestureDetector(
                onTap: () {},
                child: Text(
                  'Report a Problem',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.regularText.copyWith(
                    color: Theme.of(context).colorScheme.primary, fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileSummaryCard extends StatelessWidget {
  final ProfileData profile;
  final VoidCallback onTap;

  const _ProfileSummaryCard({required this.profile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.secondary;
    final cardColor = Theme.of(context).colorScheme.surface;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
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
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.grey[300],
                  backgroundImage:
                      profile.avatarUrl != null
                          ? NetworkImage(profile.avatarUrl!)
                          : null,
                  child:
                      profile.avatarUrl == null
                          ? Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.grey[600],
                          )
                          : null,
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
                            profile.schedule,
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
