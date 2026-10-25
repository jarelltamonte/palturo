import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:palturo/theme/app_motion.dart';
import 'package:palturo/onboarding/onboarding_complete.dart';
import 'package:palturo/onboarding/onboarding_entry.dart';
import 'onboarding_controller.dart';
import 'onboarding_models.dart';
import 'screens/onboarding_final_screen.dart';
import 'screens/onboarding_review_screen.dart';
import 'screens/onboarding_interests_screen.dart';
import 'screens/onboarding_role_screen.dart';
import '../services/profile_service.dart';
import '../services/preferences_service.dart';
import '../screen/action_dialogs.dart';

enum OnboardingStep {
  intro,
  role,
  learningInterests,
  teachingInterests,
  finalDetails,
  review,
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
  bool _returnToReview = false;

  OnboardingStep get _current => _history.last;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_persistDraft);
    _restoreDraft();
    _fetchRandomCommunitySkills();
  }

  @override
  void dispose() {
    _controller.removeListener(_persistDraft);
    super.dispose();
  }

  String get _draftKey {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    return uid == null ? 'onboarding_draft' : 'onboarding_draft_$uid';
  }

  OnboardingOption _optionForId(String id) {
    return OnboardingOption(
      id,
      id
          .split('_')
          .where((part) => part.isNotEmpty)
          .map((part) => part[0].toUpperCase() + part.substring(1))
          .join(' '),
    );
  }

  void _persistDraft() {
    final raw = jsonEncode(_controller.toJson());
    PreferencesService.instance.setString(_draftKey, raw).catchError((_) {});
  }

  Future<void> _restoreDraft() async {
    final raw = await PreferencesService.instance.getString(_draftKey);
    if (raw == null || raw.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final map = Map<String, dynamic>.from(decoded);
      if (map['role'] == null) return;
      _controller.applyJson(map);
      if (!mounted) return;
      final selected = {
        ..._controller.learningInterests,
        ..._controller.teachingInterests,
      };
      final extras =
          selected
              .where((id) => !_dynamicOptions.any((option) => option.id == id))
              .map(_optionForId)
              .toList();
      setState(() {
        if (extras.isNotEmpty) {
          _dynamicOptions = [...extras, ..._dynamicOptions];
        }
        _history
          ..clear()
          ..add(OnboardingStep.review);
      });
    } catch (_) {
      // A malformed draft must never block onboarding.
    }
  }

  Future<void> _confirmSkip() async {
    final leave = await showConfirmDialog(
      context,
      title: 'Finish later?',
      message:
          'Your matches will be less relevant until you add your role, skills, and availability.',
      confirmLabel: 'Finish later',
      cancelLabel: 'Keep editing',
      destructive: false,
    );
    if (!leave || !mounted) return;
    widget.onSkip();
  }

  void _editFromReview(OnboardingStep step) {
    setState(() {
      _returnToReview = true;
      _history.add(step);
    });
  }

  void _backOrSkip() {
    if (_history.length > 1) {
      _back();
    } else {
      _confirmSkip();
    }
  }

  String _stepLabel(OnboardingStep step) {
    final both = _controller.role == OnboardingRole.both;
    final total = both ? 5 : 4;
    switch (step) {
      case OnboardingStep.role:
        return 'Step 1 of 4 - Role';
      case OnboardingStep.learningInterests:
        return 'Step 2 of $total - Learning skills';
      case OnboardingStep.teachingInterests:
        return 'Step ${both ? 3 : 2} of $total - Teaching skills';
      case OnboardingStep.finalDetails:
        return 'Step ${both ? 4 : 3} of $total - Availability';
      case OnboardingStep.review:
        return 'Step $total of $total - Review';
      case OnboardingStep.intro:
      case OnboardingStep.complete:
        return '';
    }
  }

  double _progress(OnboardingStep step) {
    final both = _controller.role == OnboardingRole.both;
    final total = both ? 5 : 4;
    switch (step) {
      case OnboardingStep.role:
        return 1 / total;
      case OnboardingStep.learningInterests:
        return 2 / total;
      case OnboardingStep.teachingInterests:
        return (both ? 3 : 2) / total;
      case OnboardingStep.finalDetails:
        return (both ? 4 : 3) / total;
      case OnboardingStep.review:
      case OnboardingStep.complete:
        return 1;
      case OnboardingStep.intro:
        return 0;
    }
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
      final selected = {
        ..._controller.learningInterests,
        ..._controller.teachingInterests,
      };
      final preserved =
          selected
              .where(
                (id) =>
                    id != 'others' &&
                    !selectedSkills.any((option) => option.id == id),
              )
              .map(_optionForId)
              .toList();
      setState(() {
        _dynamicOptions = [
          ...preserved,
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
    if (_returnToReview && from != OnboardingStep.intro) {
      return OnboardingStep.review;
    }
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
        return OnboardingStep.review;
      case OnboardingStep.review:
        return OnboardingStep.complete;
      case OnboardingStep.complete:
        return OnboardingStep.complete;
    }
  }

  Future<void> _saveAndProceed() async {
    setState(() => _isSaving = true);
    try {
      await _profileService.saveOnboardingPreferences(_controller);
      try {
        await PreferencesService.instance.setString(_draftKey, '');
        await PreferencesService.instance.setBool('skipped_onboarding', false);
      } catch (_) {
        // The profile is already saved; preference cleanup is best-effort.
      }
      if (!mounted) return;
      _returnToReview = false;
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
        _backOrSkip();
      },
      child: Container(
        color: Theme.of(context).colorScheme.surface,
        child: Stack(
          children: [
            AnimatedSwitcher(
              duration: AppMotion.screen,
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
          onBack: _backOrSkip,
          onSkip: _confirmSkip,
          stepLabel: _stepLabel(step),
          progress: _progress(step),
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
                progress: _progress(step),
                stepLabel: _stepLabel(step),
                onContinue: () => _goTo(_next(step)),
                onBack: _backOrSkip,
                onSkip: _confirmSkip,
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
                progress: _progress(step),
                stepLabel: _stepLabel(step),
                onContinue: () => _goTo(_next(step)),
                onBack: _backOrSkip,
                onSkip: _confirmSkip,
              ),
        );

      case OnboardingStep.finalDetails:
        return AnimatedBuilder(
          animation: _controller,
          builder:
              (context, _) => OnboardingFinalScreen(
                controller: _controller,
                onDone: () => _goTo(OnboardingStep.review),
                onBack: _backOrSkip,
                onSkip: _confirmSkip,
                stepLabel: _stepLabel(step),
                progress: _progress(step),
              ),
        );

      case OnboardingStep.review:
        return OnboardingReviewScreen(
          controller: _controller,
          onSave: _saveAndProceed,
          onBack: _backOrSkip,
          onSkip: _confirmSkip,
          stepLabel: _stepLabel(step),
          onEditRole: () => _editFromReview(OnboardingStep.role),
          onEditLearning:
              () => _editFromReview(OnboardingStep.learningInterests),
          onEditTeaching:
              () => _editFromReview(OnboardingStep.teachingInterests),
          onEditDetails: () => _editFromReview(OnboardingStep.finalDetails),
        );

      case OnboardingStep.complete:
        return OnboardingComplete(onDone: widget.onFinished);
    }
  }
}
