import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/onboarding/onboarding_controller.dart';
import 'package:palturo/onboarding/onboarding_models.dart';

void main() {
  test('onboarding controller round-trips the persisted draft', () {
    final source =
        OnboardingController()
          ..role = OnboardingRole.both
          ..learningInterests.addAll(['cooking_pinakbet', 'baybayin_script'])
          ..teachingInterests.add('barong_embroidery')
          ..learningStyles.add('Hands-on Practice')
          ..languages.addAll(['English', 'Filipino'])
          ..setAvailabilityDays({'Friday', 'Saturday'});

    final restored =
        OnboardingController()
          ..applyJson(Map<String, dynamic>.from(source.toJson()));

    expect(restored.role, OnboardingRole.both);
    expect(restored.learningInterests, source.learningInterests);
    expect(restored.teachingInterests, source.teachingInterests);
    expect(restored.learningStyles, source.learningStyles);
    expect(restored.languages, source.languages);
    expect(restored.availabilityDays, source.availabilityDays);
    expect(restored.availability['Friday'], 'Available');
  });
}
