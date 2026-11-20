import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/screen/profile_data.dart';

void main() {
  test('copyWith can set and clear private demographics', () {
    final base = ProfileData(schedule: '');
    final withData = base.copyWith(age: 31, gender: 'nonbinary');
    expect(withData.age, 31);
    expect(withData.gender, 'nonbinary');
    expect(withData.genderLabel, 'Non-binary');

    final cleared = withData.copyWith(clearAge: true, clearGender: true);
    expect(cleared.age, isNull);
    expect(cleared.gender, isNull);
    expect(cleared.genderLabel, isNull);
  });

  test('fromMap parses age and gender defensively', () {
    final parsed = ProfileData.fromMap({'age': 27, 'gender': 'woman'});
    expect(parsed.age, 27);
    expect(parsed.gender, 'woman');

    final blank = ProfileData.fromMap({'age': 'not-a-number', 'gender': '   '});
    expect(blank.age, isNull);
    expect(blank.gender, isNull);
  });
}
