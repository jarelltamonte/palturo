import 'package:flutter/material.dart';
import 'package:palturo/theme/app_text_styles.dart';
import 'package:palturo/theme/app_colors.dart';
import 'package:palturo/onboarding/onboarding_models.dart';
import 'package:palturo/onboarding/widgets/role_card_group.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const Color _accent = AppColors.primary;

  static const double _headerHeight = 150;
  static const double _avatarSize = 120;

  OnboardingRole? _role = OnboardingRole.both;

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
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).colorScheme.secondary;
    final textTheme2 = Theme.of(context).colorScheme.surface;
    final darkColor = Theme.of(context).colorScheme.primary;
    final lightColor = Theme.of(context).colorScheme.surface;

    return Scaffold(
      backgroundColor: lightColor,
      appBar: AppBar(
        backgroundColor: darkColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Padding(
          padding: const EdgeInsets.only(top: 32.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Profile',
              style: AppTextStyles.headingText.copyWith(color: textTheme2),
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(top: 32.0, right: 16.0),
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: textTheme2,
                foregroundColor: textTheme2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
              ),
              onPressed: () {
              },
              child: Text(
                'Edit',
                style: AppTextStyles.regularText.copyWith(color: textTheme),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: double.infinity,
                height: _headerHeight,
                decoration: BoxDecoration(
                  color: darkColor,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
              ),
              Positioned(
                top: _headerHeight - (_avatarSize / 2),
                left: 0,
                right: 0,
                child: Center(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: _avatarSize,
                        height: _avatarSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: lightColor, width: 4),
                          image: const DecorationImage(
                            image: NetworkImage(
                              'https://placehold.co/240x240/png',
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: _accent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.edit,
                            size: 16,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: _avatarSize / 2 + 16),
          Text(
            'Juan De La Cruz',
            style: AppTextStyles.headingText.copyWith(
              color: textTheme,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_today, size: 14, color: darkColor),
              const SizedBox(width: 6),
              Text(
                'Mon/Sat/Sun',
                style: TextStyle(color: textTheme, fontSize: 14),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: FractionallySizedBox(
                    widthFactor: 0.8,
                    child: Divider(color: darkColor, thickness: 1),
                  ),
                ),
                const SizedBox(height: 24),
                RoleCardGroup(
                  options: _roleOptions,
                  selected: _role,
                  onSelect: (role) => setState(() => _role = role),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
