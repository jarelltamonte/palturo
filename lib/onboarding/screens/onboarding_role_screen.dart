import 'package:flutter/material.dart';
import '../onboarding_controller.dart';
import '../onboarding_models.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/role_card_group.dart';

class OnboardingRoleScreen extends StatelessWidget {
  final OnboardingController controller;
  final VoidCallback onContinue;
  final VoidCallback? onSkip;

  const OnboardingRoleScreen({
    super.key,
    required this.controller,
    required this.onContinue,
    this.onSkip,
  });

  static const _options = [
    RoleOption(OnboardingRole.learn, Icons.menu_book_rounded, 'I want to\nlearn'),
    RoleOption(OnboardingRole.teach, Icons.school_rounded, 'I want to\nteach'),
    RoleOption(OnboardingRole.both, Icons.diversity_3_rounded, 'I can do\nboth'),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return OnboardingScaffold(
          title: 'What describes\nyou best?',
          subtitle: 'Select one that applies',
          progress: 0.2,
          showBackButton: true,
          onPrimaryPressed: controller.role == null ? null : onContinue,
          onSkip: onSkip,
          child: RoleCardGroup(
            options: _options,
            selected: controller.role,
            onSelect: controller.setRole,
          ),
        );
      },
    );
  }
}