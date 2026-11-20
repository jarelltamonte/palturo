import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/screen/profile_data.dart';

ProfileData _profile({
  List<String> teaching = const ['vocal_music', 'sewing'],
  Map<String, String> images = const {},
}) {
  return ProfileData(
    schedule: '',
    teachingSkillIds: teaching,
    teachingSkillImages: images,
  );
}

void main() {
  test('showcase getters distinguish no media, partial, and complete', () {
    final missing = _profile();
    expect(missing.hasAnyShowcase, isFalse);
    expect(missing.needsShowcase, isTrue);
    expect(missing.missingShowcaseSkillIds, ['vocal_music', 'sewing']);

    final partial = _profile(images: const {'vocal_music': 'https://x/v.mp4'});
    expect(partial.hasAnyShowcase, isTrue);
    expect(partial.needsShowcase, isFalse);
    expect(partial.hasIncompleteShowcases, isTrue);
    expect(partial.missingShowcaseSkillIds, ['sewing']);

    final complete = _profile(
      images: const {
        'vocal_music': 'https://x/v.mp4',
        'sewing': 'https://x/s.jpg',
      },
    );
    expect(complete.hasAnyShowcase, isTrue);
    expect(complete.needsShowcase, isFalse);
    expect(complete.hasIncompleteShowcases, isFalse);
    expect(complete.missingShowcaseSkillIds, isEmpty);
  });

  test('learner-only profiles do not need a showcase', () {
    final learner = _profile(teaching: const []);
    expect(learner.needsShowcase, isFalse);
    expect(learner.hasIncompleteShowcases, isFalse);
  });
}
