import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/screen/card/person_card.dart';
import 'package:palturo/services/match_api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Opt-in integration test: calls the REAL Flutter client code against a local
/// Supabase stack seeded by supabase/tests/seed_local_accounts.sql and
/// seed_local_embeddings.sql.
///
///   $env:PALTURO_LOCAL_TEST = "1"
///   flutter test --no-pub test/local_matching_integration_test.dart
///
/// It is skipped in normal runs because CI has no local stack.
void main() {
  final enabled = Platform.environment['PALTURO_LOCAL_TEST'] == '1';

  setUpAll(() async {
    if (!enabled) return;
    TestWidgetsFlutterBinding.ensureInitialized();
    // The test binding installs an HttpOverrides that returns 400 for every
    // request. Clear it so this opt-in test can reach the local stack.
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://127.0.0.1:54321',
      publishableKey: 'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH',
    );
    await Supabase.instance.client.auth.signInWithPassword(
      email: 'marisol.rivera@example.test',
      password: 'TestPass123!',
    );
  });

  test(
    'client parses card-level matches and renders the matched skill',
    () async {
      final matches = await MatchApi.getMatches(
        asRole: 'learner',
        useCache: false,
      );

      expect(matches.length, 3, reason: 'Web Dev learners only');
      final names = matches.map((m) => m.displayName).toSet();
      expect(
        names,
        containsAll(['Lourdes Bautista', 'Rafael Mendoza', 'Gabriel Navarro']),
      );
      expect(names, isNot(contains('Diego Santos')));

      for (final match in matches) {
        expect(match.cardId, isNotNull);
        expect(
          match.skillPath,
          'modern_practical_skills.programming.web_development',
        );
        expect(match.skillKind, 'learn');
      }

      // Enrichment goes through get_public_profile and must keep the same card.
      final deck = await MatchApi.getMatchDeck(
        asRoleDb: 'learner',
        force: true,
        enrichLimit: 10,
      );
      expect(deck.length, 3);
      for (final person in deck) {
        expect(person.cardId, isNotNull);
        expect(person.skillKind, 'learn');
        expect(
          person.skillPath,
          'modern_practical_skills.programming.web_development',
          reason: 'card must show the skill that actually matched',
        );
      }

      final keys = deck.map((p) => p.cardId).toSet();
      expect(keys.length, deck.length, reason: 'one deck entry per card');

      // Lourdes teaches the cooking Marisol wants and learns the web Marisol
      // teaches, so she must appear as two distinct cards with different ids.
      final mentorDeck = await MatchApi.getMatchDeck(
        asRoleDb: 'mentor',
        force: true,
        enrichLimit: 10,
      );
      final lourdesLearner = deck.firstWhere(
        (p) => p.name == 'Lourdes Bautista',
      );
      final lourdesMentor = mentorDeck.firstWhere(
        (p) => p.name == 'Lourdes Bautista',
      );
      expect(lourdesLearner.skillKind, 'learn');
      expect(lourdesLearner.skillPath, endsWith('web_development'));
      expect(lourdesMentor.skillKind, 'teach');
      expect(lourdesMentor.skillPath, endsWith('filipino_cooking'));
      expect(lourdesLearner.cardId, isNot(lourdesMentor.cardId));
    },
    skip:
        enabled ? false : 'requires local Supabase (set PALTURO_LOCAL_TEST=1)',
  );

  test(
    'every seeded account renders the matched card accurately',
    () async {
      const emails = [
        'marisol.rivera@example.test',
        'diego.santos@example.test',
        'althea.cruz@example.test',
        'rafael.mendoza@example.test',
        'lourdes.bautista@example.test',
        'emilio.garcia@example.test',
        'bianca.reyes@example.test',
        'marco.villanueva@example.test',
        'carmela.delacruz@example.test',
        'nathaniel.ramos@example.test',
        'sofia.aquino@example.test',
        'gabriel.navarro@example.test',
        'isabella.torres@example.test',
        'joaquin.castillo@example.test',
        'camille.domingo@example.test',
        'elias.mercado@example.test',
        'teresa.salazar@example.test',
        'miguel.ferrer@example.test',
        'patricia.lim@example.test',
        'andres.velasco@example.test',
      ];

      var cards = 0;
      for (final email in emails) {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: 'TestPass123!',
        );
        final me = Supabase.instance.client.auth.currentUser!.id;

        for (final role in const ['learner', 'mentor']) {
          final matches = await MatchApi.getMatches(
            asRole: role,
            useCache: false,
          );
          final deck = await MatchApi.getMatchDeck(
            asRoleDb: role,
            force: true,
            enrichLimit: 10,
          );

          expect(deck.length, matches.length, reason: '$email/$role');
          expect(
            deck.map((p) => p.cardId).toSet().length,
            deck.length,
            reason: 'duplicate card id in $email/$role',
          );

          for (final person in deck) {
            expect(person.id, isNot(me));
            final match = matches.firstWhere((m) => m.cardId == person.cardId);
            expect(person.skillPath, match.skillPath, reason: '$email/$role');
            expect(person.skillKind, match.skillKind, reason: '$email/$role');

            final profile = await MatchApi.getPublicProfile(person.id);
            expect(profile, isNotNull);
            final entries =
                ((person.skillKind == 'learn'
                            ? profile!['p_learning']
                            : profile!['p_teaching'])
                        as List)
                    .cast<Map>();
            final entry = entries.firstWhere(
              (e) => e['path'] == person.skillPath,
              orElse:
                  () =>
                      throw StateError(
                        '${person.name} has no ${person.skillKind} entry '
                        'for ${person.skillPath}',
                      ),
            );

            expect(person.skillName, entry['skill']);
            expect(
              person.skillNote,
              (entry['note'] ?? '').toString().trim(),
              reason: '${person.name} note for ${person.skillPath}',
            );
            expect(person.skillNote, isNotEmpty);
            expect(
              person.role,
              person.skillKind == 'learn'
                  ? PersonRole.learner
                  : PersonRole.mentor,
            );
            if (person.skillKind == 'teach') {
              expect(person.showcaseUrls, isNotEmpty);
            }
            cards++;
          }
        }
      }

      expect(cards, 42, reason: '40 decks, 42 compatible card rows');
    },
    skip:
        enabled ? false : 'requires local Supabase (set PALTURO_LOCAL_TEST=1)',
  );
}
