import 'package:flutter_test/flutter_test.dart';
import 'package:palturo/screen/activity_presentation.dart';
import 'package:palturo/screen/card/person_card.dart';
import 'package:palturo/services/match_api.dart';

void main() {
  test('connection request names the actor and requested skill', () {
    final view = presentActivity(
      {
        'kind': 'connection_request',
        'payload': {'connection_id': 'c1'},
      },
      incoming: RequestLite(
        connectionId: 'c1',
        requesterId: 'u1',
        requesterName: 'RJ Castillano',
        role: PersonRole.mentor,
        skills: const ['Barong Embroidery'],
        createdAt: DateTime(2026),
      ),
    );
    expect(view.title, 'New request');
    expect(view.body, contains('RJ Castillano'));
    expect(view.body, contains('Barong Embroidery'));
    expect(view.actionLabel, 'View request');
    expect(view.destination, ActivityDestination.incomingRequests);
  });

  test('accepted request opens chat with conversation context', () {
    final view = presentActivity(
      {
        'kind': 'request_accepted',
        'payload': {'connection_id': 'c2'},
      },
      conversation: ConversationLite(
        connectionId: 'c2',
        status: 'accepted',
        otherUserId: 'u2',
        otherName: 'Grace Lim',
        otherRole: 'both',
        otherSkill: 'Binangkal',
        unread: 0,
      ),
    );
    expect(view.title, 'Request accepted');
    expect(view.body, contains('Grace Lim'));
    expect(view.body, contains('Binangkal'));
    expect(view.destination, ActivityDestination.chat);
    expect(view.actionLabel, 'Open chat');
  });

  test('feedback notification opens the chat when connection is known', () {
    final view = presentActivity(
      {
        'kind': 'feedback_ready',
        'payload': {'connection_id': 'c3'},
      },
      conversation: ConversationLite(
        connectionId: 'c3',
        status: 'accepted',
        otherUserId: 'u3',
        otherName: 'Nanay Cita',
        otherRole: 'mentor',
        unread: 0,
      ),
    );
    expect(view.title, 'Feedback is ready');
    expect(view.body, contains('Nanay Cita'));
    expect(view.actionLabel, 'Open chat');
    expect(view.destination, ActivityDestination.chat);
    expect(view.connectionId, 'c3');
  });

  test('enriched top-level fields name the actor and skill', () {
    final view = presentActivity({
      'kind': 'request_accepted',
      'payload': {'connection_id': 'c4'},
      'actor_name': 'Grace Lim',
      'skill_name': 'Binangkal',
    });

    expect(view.body, contains('Grace Lim'));
    expect(view.body, contains('Binangkal'));
    expect(view.connectionId, 'c4');
  });

  test('possible match names the candidate and opens the profile', () {
    final view = presentActivity({
      'kind': 'possible_match',
      'payload': {
        'candidate_id': 'cand-1',
        'as_role': 'mentor',
        'skill_name': 'Filipino Cooking',
      },
      'actor_id': 'cand-1',
      'actor_name': 'Grace Lim',
      'skill_name': 'Filipino Cooking',
    });

    expect(view.title, 'New possible match');
    expect(view.body, contains('Grace Lim'));
    expect(view.body, contains('Filipino Cooking'));
    expect(view.body, contains('matches your interests'));
    expect(view.body, isNot(contains('you matched')));
    expect(view.actionLabel, 'View profile');
    expect(view.destination, ActivityDestination.profile);
    expect(view.profileUserId, 'cand-1');
  });

  test('possible match learner direction explains what the viewer teaches', () {
    final view = presentActivity({
      'kind': 'possible_match',
      'payload': {
        'candidate_id': 'cand-2',
        'as_role': 'learner',
        'skill_name': 'Philippine Handweaving',
      },
      'actor_name': 'Lolo Ben',
    });

    expect(view.title, 'New possible match');
    expect(view.body, contains('wants to learn Philippine Handweaving'));
    expect(view.body, contains('what you teach'));
    expect(view.destination, ActivityDestination.profile);
    expect(view.profileUserId, 'cand-2');
  });

  test('possible match without a skill still uses honest generic copy', () {
    final view = presentActivity({
      'kind': 'possible_match',
      'payload': {'candidate_id': 'cand-3', 'as_role': 'mentor'},
      'actor_name': 'RJ',
    });

    expect(view.body, 'RJ matches your interests.');
    expect(view.actionLabel, 'View profile');
    expect(view.destination, ActivityDestination.profile);
  });

  test('unknown kinds stay on Activity with generic copy', () {
    final view = presentActivity({'kind': 'mystery', 'payload': {}});
    expect(view.title, 'Activity');
    expect(view.body, isNot(contains('{')));
    expect(view.destination, ActivityDestination.none);
  });
}
