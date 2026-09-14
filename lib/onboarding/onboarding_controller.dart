import 'package:flutter/foundation.dart';
import 'onboarding_models.dart';

class OnboardingController extends ChangeNotifier {
  OnboardingRole? role;

  final Set<String> learningInterests = {};
  final Set<String> teachingInterests = {};

  final Set<String> learningStyles = {};

  final Map<String, String> availability = {};

  final Set<String> languages = {};

  bool get wantsLearning =>
      role == OnboardingRole.learn || role == OnboardingRole.both;

  bool get wantsTeaching =>
      role == OnboardingRole.teach || role == OnboardingRole.both;

  void setRole(OnboardingRole newRole) {
    role = newRole;
    notifyListeners();
  }

  void toggleLearningInterest(String id, {required int max}) {
    _toggle(learningInterests, id, max);
  }

  void toggleTeachingInterest(String id, {required int max}) {
    _toggle(teachingInterests, id, max);
  }

  void toggleLearningStyle(String style) {
    if (learningStyles.contains(style)) {
      learningStyles.remove(style);
    } else {
      learningStyles.add(style);
    }
    notifyListeners();
  }

  void setLearningStyles(Iterable<String> values) {
    learningStyles
      ..clear()
      ..addAll(values);
    notifyListeners();
  }

  void setLanguages(Iterable<String> values) {
    languages
      ..clear()
      ..addAll(values);
    notifyListeners();
  }

  void setAvailability(String day, String timeRange) {
    availability[day] = timeRange;
    notifyListeners();
  }

  void removeAvailability(String day) {
    availability.remove(day);
    notifyListeners();
  }

  void _toggle(Set<String> set, String id, int max) {
    if (set.contains(id)) {
      set.remove(id);
    } else if (set.length < max) {
      set.add(id);
    }
    notifyListeners();
  }
}
