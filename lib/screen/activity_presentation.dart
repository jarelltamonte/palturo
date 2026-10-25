import 'package:flutter/material.dart';
import 'package:palturo/services/match_api.dart';

enum ActivityDestination { incomingRequests, sentRequests, chat, none }

/// Pure presentation model for one notification row.
///
/// Payloads are hints, never instructions: only known string fields are read,
/// and the UI falls back to generic copy when they are missing.
class ActivityItemView {
  final String title;
  final String body;
  final String actionLabel;
  final IconData icon;
  final ActivityDestination destination;
  final String? connectionId;
  final String? actorName;
  final String? skillName;

  const ActivityItemView({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.icon,
    required this.destination,
    this.connectionId,
    this.actorName,
    this.skillName,
  });
}

String? _text(dynamic value) {
  if (value is! String) return null;
  final text = value.trim();
  return text.isEmpty ? null : text;
}

Map<String, dynamic> _payloadOf(Map<String, dynamic> item) {
  final payload = item['payload'];
  return payload is Map ? Map<String, dynamic>.from(payload) : const {};
}

ActivityItemView presentActivity(
  Map<String, dynamic> item, {
  RequestLite? incoming,
  ConversationLite? conversation,
}) {
  final kind = _text(item['kind']) ?? 'unknown';
  final payload = _payloadOf(item);
  final connectionId =
      _text(payload['connection_id']) ??
      incoming?.connectionId ??
      conversation?.connectionId;
  final name =
      _text(payload['name']) ??
      _text(payload['actor_name']) ??
      _text(payload['requester_name']) ??
      _text(payload['responder_name']) ??
      incoming?.requesterName ??
      conversation?.otherName;
  final skill =
      _text(payload['skill']) ??
      _text(payload['skill_name']) ??
      (incoming != null && incoming.skills.isNotEmpty
          ? incoming.skills.first
          : null) ??
      conversation?.otherSkill;

  switch (kind) {
    case 'connection_request':
      return ActivityItemView(
        title: 'New request',
        body:
            name == null
                ? 'Someone wants to exchange skills with you.'
                : skill == null
                ? '$name wants to exchange skills with you.'
                : '$name wants to exchange $skill with you.',
        actionLabel: 'View request',
        icon: Icons.person_add_alt_1_outlined,
        destination: ActivityDestination.incomingRequests,
        connectionId: connectionId,
        actorName: name,
        skillName: skill,
      );
    case 'request_accepted':
      return ActivityItemView(
        title: 'Request accepted',
        body:
            name == null
                ? 'Your request was accepted. You can start chatting.'
                : skill == null
                ? '$name accepted your request. You can start chatting.'
                : '$name accepted your request for $skill.',
        actionLabel: connectionId == null ? '' : 'Open chat',
        icon: Icons.check_circle_outline,
        destination:
            connectionId == null
                ? ActivityDestination.none
                : ActivityDestination.chat,
        connectionId: connectionId,
        actorName: name,
        skillName: skill,
      );
    case 'request_declined':
      return ActivityItemView(
        title: 'Request declined',
        body:
            name == null
                ? 'This request did not move forward.'
                : '$name declined your request.',
        actionLabel: 'View sent',
        icon: Icons.info_outline,
        destination: ActivityDestination.sentRequests,
        connectionId: connectionId,
        actorName: name,
        skillName: skill,
      );
    case 'feedback_ready':
      return ActivityItemView(
        title: 'Feedback is ready',
        body:
            name == null
                ? 'Your 15-message exchange can now be rated.'
                : 'You and $name can now rate your exchange.',
        actionLabel: connectionId == null ? '' : 'Open chat',
        icon: Icons.rate_review_outlined,
        destination:
            connectionId == null
                ? ActivityDestination.none
                : ActivityDestination.chat,
        connectionId: connectionId,
        actorName: name,
        skillName: skill,
      );
    case 'skill_moderation':
      return ActivityItemView(
        title: 'Skill update',
        body: 'Open Profile to review the latest update to a submitted skill.',
        actionLabel: '',
        icon: Icons.workspace_premium_outlined,
        destination: ActivityDestination.none,
      );
    default:
      return const ActivityItemView(
        title: 'Activity',
        body: 'There is a new update in PalTuro.',
        actionLabel: '',
        icon: Icons.notifications_none,
        destination: ActivityDestination.none,
      );
  }
}
