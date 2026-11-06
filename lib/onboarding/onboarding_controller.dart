import 'package:flutter/foundation.dart';
import 'onboarding_models.dart';

class OnboardingController extends ChangeNotifier {
  OnboardingRole? role;

  final Set<String> learningInterests = {};
  final Set<String> teachingInterests = {};

  final Set<String> learningStyles = {};
  final Set<String> availabilityDays = {};
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

  void toggleAvailabilityDay(String day) {
    if (availabilityDays.contains(day)) {
      availabilityDays.remove(day);
      availability.remove(day);
    } else {
      availabilityDays.add(day);
      availability[day] = 'Available';
    }
    notifyListeners();
  }

  void setAvailabilityDays(Iterable<String> values) {
    availabilityDays
      ..clear()
      ..addAll(values);
    availability
      ..clear()
      ..addEntries(values.map((d) => MapEntry(d, 'Available')));
    notifyListeners();
  }

  void setAvailability(String day, String timeRange) {
    availability[day] = timeRange.isEmpty ? 'Available' : timeRange;
    availabilityDays.add(day);
    notifyListeners();
  }

  void removeAvailability(String day) {
    availability.remove(day);
    availabilityDays.remove(day);
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

  Map<String, dynamic> toJson() => {
    'role': role?.name,
    'learningInterests': learningInterests.toList(),
    'teachingInterests': teachingInterests.toList(),
    'learningStyles': learningStyles.toList(),
    'availabilityDays': availabilityDays.toList(),
    'availability': availability,
    'languages': languages.toList(),
  };

  void applyJson(Map<String, dynamic> json) {
    final roleName = json['role']?.toString();
    role =
        OnboardingRole.values
            .where((value) => value.name == roleName)
            .firstOrNull;
    learningInterests
      ..clear()
      ..addAll(_strings(json['learningInterests']));
    teachingInterests
      ..clear()
      ..addAll(_strings(json['teachingInterests']));
    learningStyles
      ..clear()
      ..addAll(_strings(json['learningStyles']));
    availabilityDays
      ..clear()
      ..addAll(_strings(json['availabilityDays']));
    languages
      ..clear()
      ..addAll(_strings(json['languages']));
    availability
      ..clear()
      ..addAll(
        (json['availability'] as Map?)?.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            ) ??
            const {},
      );
    notifyListeners();
  }

  List<String> _strings(dynamic value) {
    if (value is! List) return const [];
    return value.map((item) => item.toString()).toList();
  }
}
