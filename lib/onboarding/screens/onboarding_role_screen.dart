import 'package:flutter/material.dart';
import '../onboarding_controller.dart';
import '../onboarding_models.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/role_card_group.dart';

class OnboardingRoleScreen extends StatelessWidget {
  final OnboardingController controller;
  final VoidCallback onContinue;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;
  final String stepLabel;
  final double progress;

  const OnboardingRoleScreen({
    super.key,
    required this.controller,
    required this.onContinue,
    this.onBack,
    this.onSkip,
    this.stepLabel = 'Step 1 of 4 - Role',
    this.progress = 0.2,
  });

  static const _options = [
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
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return OnboardingScaffold(
          title: 'What describes\nyou best?',
          subtitle: 'Select one that applies',
          stepLabel:
              controller.role == OnboardingRole.both
                  ? 'Step 1 of 5 - Role'
                  : 'Step 1 of 4 - Role',
          progress: controller.role == OnboardingRole.both ? 1 / 5 : 1 / 4,
          showBackButton: true,
          onBack: onBack,
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
