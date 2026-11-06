import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/screen/card/person_card.dart';
import 'package:palturo/screen/home_page.dart';

void main() {
  test('a stalled request send is capped by the timeout', () async {
    final never = Completer<String?>();
    const person = Person(
      id: 'p1',
      name: 'Test Pal',
      schedule: 'Weekends',
      language: 'English',
      learningStyle: 'Hands-on Practice',
      skillName: 'Cooking',
      role: PersonRole.mentor,
    );

    await expectLater(
      sendRequestWithTimeout(
        (id, {String? skillName, String? skillPath}) => never.future,
        person,
        timeout: const Duration(milliseconds: 10),
      ),
      throwsA(isA<TimeoutException>()),
    );
  });
}
