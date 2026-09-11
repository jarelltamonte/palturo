import 'package:flutter/material.dart';
import 'onboarding_controller.dart';
import 'onboarding_models.dart';
import 'screens/onboarding_interests_screen.dart';
import 'screens/onboarding_role_screen.dart';

import 'onboarding_entry.dart';
import 'onboarding_complete.dart';

enum OnboardingStep {
  intro,
  role,
  learningInterests,
  teachingInterests,
  finalDetails,
  complete,
}

const kLearningOptions = [
  OnboardingOption('cooking_pinakbet', 'Cooking Pinakbet'),
  OnboardingOption('baybayin_script', 'Baybayin Script'),
  OnboardingOption('barong_embroidery', 'Barong Embroidery'),
  OnboardingOption('weaving_inabel', 'Weaving Inabel'),
  OnboardingOption('cooking_puto', 'Cooking Puto'),
  OnboardingOption('arnis_martial_arts', 'Arnis Martial Arts'),
  OnboardingOption('tinikling_dance', 'Tinikling Dance'),
  OnboardingOption('parol_making', 'Parol Making'),
  OnboardingOption('kulintang_drumming', 'Kulintang Drumming'),
  OnboardingOption('kundiman_singing', 'Kundiman Singing'),
  OnboardingOption('pagbabalat', 'Pagbabalat'),
  OnboardingOption('others', 'Others'),
];

const kTeachingOptions = kLearningOptions;

class OnboardingFlow extends StatefulWidget {
  final VoidCallback onFinished;
  const OnboardingFlow({super.key, required this.onFinished});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final _controller = OnboardingController();
  final List<OnboardingStep> _history = [OnboardingStep.intro];

  OnboardingStep get _current => _history.last;

  void _goTo(OnboardingStep step) {
    setState(() => _history.add(step));
  }

  void _back() {
    if (_history.length > 1) {
      setState(() => _history.removeLast());
    }
  }

  OnboardingStep _next(OnboardingStep from) {
    switch (from) {
      case OnboardingStep.intro:
        return OnboardingStep.role;
      case OnboardingStep.role:
        if (_controller.wantsLearning) return OnboardingStep.learningInterests;
        if (_controller.wantsTeaching) return OnboardingStep.teachingInterests;
        return OnboardingStep.finalDetails;
      case OnboardingStep.learningInterests:
        return _controller.wantsTeaching
            ? OnboardingStep.teachingInterests
            : OnboardingStep.finalDetails;
      case OnboardingStep.teachingInterests:
        return OnboardingStep.finalDetails;
      case OnboardingStep.finalDetails:
        return OnboardingStep.complete;
      case OnboardingStep.complete:
        return OnboardingStep.complete;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: KeyedSubtree(
        key: ValueKey(_current),
        child: _buildStep(_current),
      ),
    );
  }

  Widget _buildStep(OnboardingStep step) {
    switch (step) {
      case OnboardingStep.intro:
        return OnboardingEntry(onContinue: () => _goTo(_next(step)));

      case OnboardingStep.role:
        return OnboardingRoleScreen(
          controller: _controller,
          onContinue: () => _goTo(_next(step)),
          onSkip: widget.onFinished,
        );

      case OnboardingStep.learningInterests:
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => OnboardingInterestsScreen(
            highlightWord: 'Learning',
            options: kLearningOptions,
            selected: _controller.learningInterests,
            maxSelections: 3,
            onToggle: (id) => _controller.toggleLearningInterest(id, max: 3),
            progress: 0.5,
            onContinue: () => _goTo(_next(step)),
            onBack: _back,
            onSkip: widget.onFinished,
          ),
        );

      case OnboardingStep.teachingInterests:
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => OnboardingInterestsScreen(
            highlightWord: 'Teaching',
            options: kTeachingOptions,
            selected: _controller.teachingInterests,
            maxSelections: 2,
            onToggle: (id) => _controller.toggleTeachingInterest(id, max: 2),
            progress: 0.75,
            onContinue: () => _goTo(_next(step)),
            onBack: _back,
            onSkip: widget.onFinished,
          ),
        );

      case OnboardingStep.finalDetails:
        return const SizedBox.shrink();

      case OnboardingStep.complete:
        return OnboardingComplete(onDone: widget.onFinished);
    }
  }
}
