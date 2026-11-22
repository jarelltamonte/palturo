import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:palturo/theme/app_motion.dart';
import 'package:palturo/onboarding/onboarding_complete.dart';
import 'package:palturo/onboarding/onboarding_entry.dart';
import 'onboarding_controller.dart';
import 'onboarding_models.dart';
import 'skill_options.dart';

export 'skill_options.dart'
    show kSelectableSkills, kSkillToCategorySlug, selectableSkillLabelForId;
import 'screens/onboarding_final_screen.dart';
import 'screens/onboarding_review_screen.dart';
import 'screens/onboarding_interests_screen.dart';
import 'screens/onboarding_note_screen.dart';
import 'screens/onboarding_role_screen.dart';
import 'widgets/onboarding_save_overlay.dart';
import '../services/profile_service.dart';
import '../services/preferences_service.dart';
import '../utils/friendly_error.dart';

enum OnboardingStep {
  intro,
  role,
  learningInterests,
  learningNotes,
  teachingInterests,
  finalDetails,
  review,
  complete,
}

const kBaseOptions = kSelectableSkills;
const kLearningOptions = kBaseOptions;
const kTeachingOptions = kBaseOptions;

String onboardingDraftKey(String? userId) =>
    userId == null ? 'onboarding_draft' : 'onboarding_draft_$userId';

String onboardingResumeDismissedKey(String? userId) =>
    userId == null
        ? 'onboarding_resume_dismissed'
        : 'onboarding_resume_dismissed_$userId';

class OnboardingFlow extends StatefulWidget {
  final VoidCallback onFinished;
  const OnboardingFlow({super.key, required this.onFinished});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final _controller = OnboardingController();
  late final ProfileService _profileService = ProfileService();
  final List<OnboardingStep> _history = [OnboardingStep.intro];

  List<OnboardingOption> _dynamicOptions = List.from(kBaseOptions);
  bool _isSaving = false;
  bool _saveSlow = false;
  Timer? _saveSlowTimer;
  Timer? _draftTimer;

  /// First-time saves warm matching, so the overlay explains the wait after
  /// this long instead of leaving a bare spinner.
  static const Duration saveSlowThreshold = Duration(seconds: 6);

  bool _returnToReview = false;
  List<OnboardingStep>? _reviewReturnHistory;
  int _noteIndex = 0;

  OnboardingStep get _current => _history.last;

  List<String> get _learningNoteIds =>
      _controller.learningInterests.toList(growable: false);

  @override
  void initState() {
    super.initState();
    _controller.addListener(_persistDraft);
    _restoreDraft();
    _fetchRandomCommunitySkills();
  }

  @override
  void dispose() {
    _saveSlowTimer?.cancel();
    _draftTimer?.cancel();
    _controller.removeListener(_persistDraft);
    super.dispose();
  }

  String get _draftKey {
    try {
      return onboardingDraftKey(Supabase.instance.client.auth.currentUser?.id);
    } catch (_) {
      // The flow is also mounted in widget tests and previews where Supabase
      // is not initialized. Fall back to the anonymous draft key.
      return onboardingDraftKey(null);
    }
  }

  OnboardingOption _optionForId(String id) {
    // A restored draft can hold `other:onboarding:...` ids. Use the same
    // display-label resolver as the review step so the chip never shows the
    // raw encoding.
    return OnboardingOption(id, onboardingInterestLabel(id));
  }

  /// Debounced so typing a note does not hit platform preferences on every
  /// keystroke.
  void _persistDraft() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 400), _writeDraft);
  }

  void _writeDraft() {
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

  void _editFromReview(OnboardingStep step) {
    setState(() {
      _returnToReview = true;
      _reviewReturnHistory = List.of(_history);
      // Jump to the real position of the edited step instead of stacking it on
      // top of Review. Back then follows the onboarding sequence (for example,
      // Back from Role goes to Intro), while Continue still returns to Review.
      _history
        ..clear()
        ..addAll(_pathTo(step));
    });
  }

  double _progress(OnboardingStep step) {
    final both = _controller.role == OnboardingRole.both;
    final noteCount =
        _controller.wantsLearning ? _controller.learningInterests.length : 0;
    final total = (both ? 5 : 4) + noteCount;
    switch (step) {
      case OnboardingStep.role:
        return 1 / total;
      case OnboardingStep.learningInterests:
        return 2 / total;
      case OnboardingStep.learningNotes:
        final index = noteCount == 0 ? 0 : _noteIndex.clamp(0, noteCount - 1);
        return (3 + index) / total;
      case OnboardingStep.teachingInterests:
        return (both ? 3 + noteCount : 2 + noteCount) / total;
      case OnboardingStep.finalDetails:
        return (both ? 4 + noteCount : 3 + noteCount) / total;
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

    final baseLabels = kBaseOptions.map((e) => e.label).toList();

    List<String> dbSkills;
    try {
      dbSkills = await _profileService.getRandomDistinctSkills(
        excludeSkills: baseLabels,
        limit: 6,
      );
    } catch (_) {
      // Community suggestions are optional; the base taxonomy still works.
      return;
    }

    final dbOptions =
        dbSkills
            .map((skill) {
              final slug = skill.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
              return OnboardingOption(slug, skill);
            })
            .where((option) => option.id != 'others')
            .toList();

    final Map<String, OnboardingOption> uniqueMap = {};
    for (final opt in [...baseSkillsWithoutOthers, ...dbOptions]) {
      uniqueMap.putIfAbsent(opt.label.toLowerCase(), () => opt);
    }

    final selected = {
      ..._controller.learningInterests,
      ..._controller.teachingInterests,
    };
    final preserved =
        selected
            .where(
              (id) =>
                  id != 'others' &&
                  !uniqueMap.values.any((option) => option.id == id),
            )
            .map(_optionForId)
            .toList();
    for (final option in preserved) {
      uniqueMap.putIfAbsent(option.label.toLowerCase(), () => option);
    }

    if (mounted) {
      setState(() {
        _dynamicOptions = [
          ...uniqueMap.values,
          const OnboardingOption('others', 'Others'),
        ];
      });
    }
  }

  Future<OnboardingCreateResult> _createInterest(
    String text, {
    required bool teaching,
  }) async {
    final label = text.trim();
    if (label.isEmpty) {
      return const OnboardingCreateResult.failed('Enter a skill name.');
    }

    final SkillModerationResult verdict;
    try {
      verdict = await _profileService.moderateSkillName(
        label,
        teaching ? 'teach' : 'learn',
      );
    } on SkillModerationException {
      return const OnboardingCreateResult.failed(
        'That name does not look like a skill we can add. Try a clearer name, '
        'like "Sourdough Baking".',
      );
    } catch (e) {
      return OnboardingCreateResult.failed(
        friendlyError(
          e,
          fallback:
              'We could not check that skill right now. Please try again.',
        ),
      );
    }

    // Any selectable id on the path becomes the canonical chip, regardless of
    // the node's depth. A focus leaf still resolves to its parent skill; a
    // genuinely new skill keeps the user's wording and stores as a custom
    // pending skill.
    final canonicalId = selectableSkillIdForPath(verdict.path);
    final id = canonicalId ?? 'other:onboarding:${verdict.name}';
    final displayName = selectableSkillLabelForId(id) ?? verdict.name;

    if (canonicalId == null) {
      setState(() {
        if (!_dynamicOptions.any((option) => option.id == id)) {
          _dynamicOptions = [
            ..._dynamicOptions.where((option) => option.id != 'others'),
            OnboardingOption(id, verdict.name),
            const OnboardingOption('others', 'Others'),
          ];
        }
      });
    }

    final alreadySelected =
        teaching
            ? _controller.teachingInterests.contains(id)
            : _controller.learningInterests.contains(id);
    if (!alreadySelected) {
      if (teaching) {
        _controller.toggleTeachingInterest(id, max: 2);
      } else {
        _controller.toggleLearningInterest(id, max: 3);
      }
    }

    return OnboardingCreateResult.added(displayName);
  }

  void _goTo(OnboardingStep step) {
    setState(() {
      if (_returnToReview && step == OnboardingStep.review) {
        // Returning from an edit started on Review: restore the stack the user
        // had before editing so Back from Review still goes to the step that
        // preceded it.
        _returnToReview = false;
        final returnHistory = _reviewReturnHistory;
        _reviewReturnHistory = null;
        if (returnHistory != null) {
          _history
            ..clear()
            ..addAll(returnHistory);
          if (_history.last != OnboardingStep.review) {
            _history.add(OnboardingStep.review);
          }
        } else {
          _history.add(step);
        }
      } else {
        _history.add(step);
      }
    });
  }

  /// True when this flow is presented as a pushed route (the setup entry
  /// points on Home and Profile) rather than the mandatory gate root.
  bool get _canDismissRoute => ModalRoute.of(context)?.canPop ?? false;

  void _back() {
    if (_isSaving) return;
    _reviewReturnHistory = null;
    if (_history.length > 1) {
      setState(() {
        _history.removeLast();
        _returnToReview = false;
      });
      return;
    }
    _returnToReview = false;
    // A pushed onboarding route must stay dismissible; otherwise the only
    // exit from the intro would be force-quitting the app.
    if (_canDismissRoute) Navigator.of(context).pop();
  }

  void _continueNote(List<String> ids) {
    if (_returnToReview) {
      _goTo(_next(OnboardingStep.learningNotes));
      return;
    }
    if (_noteIndex < ids.length - 1) {
      setState(() => _noteIndex++);
      return;
    }
    _goTo(_next(OnboardingStep.learningNotes));
  }

  void _backNote() {
    if (_noteIndex > 0) {
      setState(() {
        _noteIndex--;
        _returnToReview = false;
        _reviewReturnHistory = null;
      });
      return;
    }
    _back();
  }

  OnboardingStep _next(OnboardingStep from) {
    if (_returnToReview && from != OnboardingStep.intro) {
      return OnboardingStep.review;
    }
    final next = _nextInFlow(from);
    if (from == OnboardingStep.learningInterests &&
        next == OnboardingStep.learningNotes) {
      _noteIndex = 0;
    }
    return next;
  }

  /// Canonical steps leading to [target]. Used when jumping into an edit from
  /// Review so Back walks the real sequence rather than popping to Review.
  List<OnboardingStep> _pathTo(OnboardingStep target) {
    final path = <OnboardingStep>[OnboardingStep.intro];
    var current = OnboardingStep.intro;
    while (current != target) {
      final next = _nextInFlow(current);
      if (next == current || next == OnboardingStep.review) break;
      path.add(next);
      current = next;
    }
    if (path.last != target) path.add(target);
    return path;
  }

  OnboardingStep _nextInFlow(OnboardingStep from) {
    switch (from) {
      case OnboardingStep.intro:
        return OnboardingStep.role;
      case OnboardingStep.role:
        if (_controller.wantsLearning) return OnboardingStep.learningInterests;
        if (_controller.wantsTeaching) return OnboardingStep.teachingInterests;
        return OnboardingStep.finalDetails;
      case OnboardingStep.learningInterests:
        if (_controller.wantsLearning &&
            _controller.learningInterests.isNotEmpty) {
          return OnboardingStep.learningNotes;
        }
        return _controller.wantsTeaching
            ? OnboardingStep.teachingInterests
            : OnboardingStep.finalDetails;
      case OnboardingStep.learningNotes:
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
    setState(() {
      _isSaving = true;
      _saveSlow = false;
    });
    _saveSlowTimer?.cancel();
    _saveSlowTimer = Timer(saveSlowThreshold, () {
      if (mounted && _isSaving) setState(() => _saveSlow = true);
    });
    try {
      await _profileService.saveOnboardingPreferences(_controller);
      _draftTimer?.cancel();
      try {
        await PreferencesService.instance.setString(_draftKey, '');
        await PreferencesService.instance.setBool('skipped_onboarding', false);
      } catch (_) {
        // The profile is already saved; preference cleanup is best-effort.
      }
      if (!mounted) return;
      _returnToReview = false;
      _reviewReturnHistory = null;
      _goTo(OnboardingStep.complete);
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Save Failed'),
              content: Text(
                friendlyError(
                  e,
                  fallback: "We couldn't save your profile. Please try again.",
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
      );
    } finally {
      _saveSlowTimer?.cancel();
      _saveSlowTimer = null;
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveSlow = false;
        });
      }
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
              duration: AppMotion.screen,
              child: KeyedSubtree(
                key: ValueKey(_current),
                child: _buildStep(_current),
              ),
            ),
            if (_isSaving) OnboardingSaveOverlay(slow: _saveSlow),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(OnboardingStep step) {
    switch (step) {
      case OnboardingStep.intro:
        return OnboardingEntry(
          onContinue: () => _goTo(_next(step)),
          onClose: _canDismissRoute ? () => Navigator.of(context).pop() : null,
        );

      case OnboardingStep.role:
        return OnboardingRoleScreen(
          controller: _controller,
          onContinue: () => _goTo(_next(step)),
          onBack: _back,
          stepLabel: '',
          progress: _progress(step),
        );

      case OnboardingStep.learningInterests:
        return AnimatedBuilder(
          animation: _controller,
          builder:
              (context, _) => OnboardingInterestsScreen(
                key: const ValueKey('onboarding-learning-interests'),
                highlightWord: 'Learning?',
                options: _dynamicOptions,
                selected: _controller.learningInterests,
                maxSelections: 3,
                onToggle:
                    (id) => _controller.toggleLearningInterest(id, max: 3),
                onCreate: (text) => _createInterest(text, teaching: false),
                progress: _progress(step),
                stepLabel: '',
                onContinue: () => _goTo(_next(step)),
                onBack: _back,
              ),
        );

      case OnboardingStep.learningNotes:
        final ids = _learningNoteIds;
        if (ids.isEmpty) {
          // Unreachable: the interests step cannot continue without a
          // selection. Returning to the previous step is the safe recovery.
          return OnboardingInterestsScreen(
            highlightWord: 'Learning?',
            options: _dynamicOptions,
            selected: _controller.learningInterests,
            maxSelections: 3,
            onToggle: (id) => _controller.toggleLearningInterest(id, max: 3),
            onCreate: (text) => _createInterest(text, teaching: false),
            progress: _progress(OnboardingStep.learningInterests),
            stepLabel: '',
            onContinue: _back,
            onBack: _back,
          );
        }
        final index = _noteIndex.clamp(0, ids.length - 1);
        final id = ids[index];
        return OnboardingNoteScreen(
          key: ValueKey('onboarding-note-$id'),
          skillLabel:
              selectableSkillLabelForId(id) ?? onboardingInterestLabel(id),
          initialNote: _controller.learningNotes[id] ?? '',
          onChanged: (text) => _controller.setLearningNote(id, text),
          onContinue: () => _continueNote(ids),
          onBack: _backNote,
          progress: _progress(OnboardingStep.learningNotes),
          index: index,
          total: ids.length,
        );

      case OnboardingStep.teachingInterests:
        return AnimatedBuilder(
          animation: _controller,
          builder:
              (context, _) => OnboardingInterestsScreen(
                key: const ValueKey('onboarding-teaching-interests'),
                highlightWord: 'Teaching?',
                options: _dynamicOptions,
                selected: _controller.teachingInterests,
                maxSelections: 2,
                onToggle:
                    (id) => _controller.toggleTeachingInterest(id, max: 2),
                onCreate: (text) => _createInterest(text, teaching: true),
                progress: _progress(step),
                stepLabel: '',
                onContinue: () => _goTo(_next(step)),
                onBack: _back,
              ),
        );

      case OnboardingStep.finalDetails:
        return AnimatedBuilder(
          animation: _controller,
          builder:
              (context, _) => OnboardingFinalScreen(
                controller: _controller,
                onDone: () => _goTo(OnboardingStep.review),
                onBack: _back,
                progress: _progress(step),
              ),
        );

      case OnboardingStep.review:
        return OnboardingReviewScreen(
          controller: _controller,
          onSave: _saveAndProceed,
          onBack: _back,
          stepLabel: '',
          onEditRole: () => _editFromReview(OnboardingStep.role),
          onEditLearning:
              () => _editFromReview(OnboardingStep.learningInterests),
          onEditLearningNote: (index) {
            _noteIndex = index;
            _editFromReview(OnboardingStep.learningNotes);
          },
          onEditTeaching:
              () => _editFromReview(OnboardingStep.teachingInterests),
          onEditDetails: () => _editFromReview(OnboardingStep.finalDetails),
        );

      case OnboardingStep.complete:
        return OnboardingComplete(onDone: widget.onFinished);
    }
  }
}
