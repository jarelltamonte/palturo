import 'package:flutter/material.dart';
import 'package:palturo/onboarding/onboarding_complete.dart';
import 'package:palturo/onboarding/onboarding_entry.dart';
import 'onboarding_controller.dart';
import 'onboarding_models.dart';
import 'screens/onboarding_final_screen.dart';
import 'screens/onboarding_interests_screen.dart';
import 'screens/onboarding_role_screen.dart';
import '../services/profile_service.dart';

enum OnboardingStep {
  intro,
  role,
  learningInterests,
  teachingInterests,
  finalDetails,
  complete,
}

const kBaseOptions = [
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

const kLearningOptions = kBaseOptions;
const kTeachingOptions = kBaseOptions;

const Map<String, String> kSkillToCategorySlug = {
  'barong_embroidery': 'arts_design',
  'weaving_inabel': 'arts_design',
  'parol_making': 'arts_design',
  'pagbabalat': 'arts_design',

  'baybayin_script': 'language_culture',
  'tinikling_dance': 'language_culture',
  'kulintang_drumming': 'language_culture',
  'kundiman_singing': 'language_culture',

  'cooking_pinakbet': 'everyday_skills',
  'cooking_puto': 'everyday_skills',
  'arnis_martial_arts': 'everyday_skills',
};

List<String> resolveCategoriesForSkills(Iterable<String> skills) {
  final categories = <String>{};
  for (final skill in skills) {
    final normalized = skill.trim().toLowerCase().replaceAll(
      RegExp(r'\s+'),
      '_',
    );

    final cat = kSkillToCategorySlug[normalized];
    if (cat != null) {
      categories.add(cat);
    }
  }
  return categories.toList();
}

class OnboardingFlow extends StatefulWidget {
  final VoidCallback onFinished;
  final VoidCallback onSkip;
  const OnboardingFlow({
    super.key,
    required this.onFinished,
    required this.onSkip,
  });

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final _controller = OnboardingController();
  final _profileService = ProfileService();
  final List<OnboardingStep> _history = [OnboardingStep.intro];

  List<OnboardingOption> _dynamicOptions = List.from(kBaseOptions);
  bool _isSaving = false;

  static const int _targetSkillsCount = 11;

  OnboardingStep get _current => _history.last;

  @override
  void initState() {
    super.initState();
    _fetchRandomCommunitySkills();
  }

  Future<void> _fetchRandomCommunitySkills() async {
    final baseSkillsWithoutOthers =
        kBaseOptions.where((o) => o.id != 'others').toList();

    final baseLabels = baseSkillsWithoutOthers.map((e) => e.label).toList();

    final dbSkills = await _profileService.getRandomDistinctSkills(
      excludeSkills: baseLabels,
      limit: 6,
    );

    final dbOptions =
        dbSkills.map((skill) {
          final slug = skill.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
          return OnboardingOption(slug, skill);
        }).toList();

    final Map<String, OnboardingOption> uniqueMap = {};
    for (final opt in [...baseSkillsWithoutOthers, ...dbOptions]) {
      uniqueMap.putIfAbsent(opt.label.toLowerCase(), () => opt);
    }

    final pool = uniqueMap.values.toList()..shuffle();

    final selectedSkills = pool.take(_targetSkillsCount).toList();

    if (mounted) {
      setState(() {
        _dynamicOptions = [
          ...selectedSkills,
          const OnboardingOption('others', 'Others'),
        ];
      });
    }
  }

  void _goTo(OnboardingStep step) => setState(() => _history.add(step));

  void _back() {
    if (_history.length > 1 && !_isSaving) {
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

  Future<void> _saveAndProceed() async {
    setState(() => _isSaving = true);
    try {
      await _profileService.saveOnboardingPreferences(_controller);
      if (!mounted) return;
      _goTo(OnboardingStep.complete);
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Save Failed'),
              content: Text(e.toString().replaceFirst('Exception: ', '')),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _back();
      },
      child: Container(
        color: Theme.of(context).colorScheme.surface,
        child: Stack(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: KeyedSubtree(
                key: ValueKey(_current),
                child: _buildStep(_current),
              ),
            ),
            if (_isSaving)
              Container(
                color: Colors.black45,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
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
          onBack: _back,
          onSkip: widget.onSkip,
        );

      case OnboardingStep.learningInterests:
        return AnimatedBuilder(
          animation: _controller,
          builder:
              (context, _) => OnboardingInterestsScreen(
                highlightWord: 'Learning',
                options: _dynamicOptions,
                selected: _controller.learningInterests,
                maxSelections: 3,
                onToggle:
                    (id) => _controller.toggleLearningInterest(id, max: 3),
                progress: 0.5,
                onContinue: () => _goTo(_next(step)),
                onBack: _back,
                onSkip: widget.onSkip,
              ),
        );

      case OnboardingStep.teachingInterests:
        return AnimatedBuilder(
          animation: _controller,
          builder:
              (context, _) => OnboardingInterestsScreen(
                highlightWord: 'Teaching',
                options: _dynamicOptions,
                selected: _controller.teachingInterests,
                maxSelections: 2,
                onToggle:
                    (id) => _controller.toggleTeachingInterest(id, max: 2),
                progress: 0.75,
                onContinue: () => _goTo(_next(step)),
                onBack: _back,
                onSkip: widget.onSkip,
              ),
        );

      case OnboardingStep.finalDetails:
        return AnimatedBuilder(
          animation: _controller,
          builder:
              (context, _) => OnboardingFinalScreen(
                controller: _controller,
                onDone: _saveAndProceed,
                onBack: _back,
                onSkip: widget.onSkip,
              ),
        );

      case OnboardingStep.complete:
        return OnboardingComplete(onDone: widget.onFinished);
    }
  }
}
