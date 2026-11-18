import 'package:flutter/widgets.dart';
import 'package:palturo/screen/card/person_card.dart';

/// A person shown on the Chats, Pals, and Requests surfaces.
class MatchedUser {
  final String id;
  final String name;
  final PersonRole role;
  final String skillName;
  final String schedule;
  final String language;
  final String learningStyle;
  final String bio;
  final String? avatarUrl;
  final String? lastMessage;
  final String? lastMessageTime;
  final bool hasUnread;

  /// True for an accepted match with no messages yet. The Chats list shows a
  /// "Start talking" prompt instead of an empty preview.
  final bool needsFirstMessage;
  final String? presence;

  /// True when the peer's last heartbeat is recent. Quick Access sorts these
  /// first so the pals you can actually reach right now sit at the front.
  final bool isOnline;

  /// Live-data extras: the connection row + counterpart profile id.
  final String? connectionId;
  final String? otherUserId;

  const MatchedUser({
    required this.id,
    required this.name,
    required this.role,
    required this.skillName,
    required this.schedule,
    required this.language,
    required this.learningStyle,
    this.bio = '',
    this.avatarUrl,
    this.lastMessage,
    this.lastMessageTime,
    this.hasUnread = false,
    this.needsFirstMessage = false,
    this.presence,
    this.isOnline = false,
    this.connectionId,
    this.otherUserId,
  });

  ImageProvider? get avatarImage =>
      avatarUrl == null ? null : NetworkImage(avatarUrl!);

  Person toPerson() {
    return Person(
      id: (otherUserId != null && otherUserId!.isNotEmpty) ? otherUserId! : id,
      name: name,
      schedule: schedule,
      language: language,
      learningStyle: learningStyle,
      skillName: skillName,
      role: role,
      bio: bio,
      photoUrls: [avatarUrl],
    );
  }
}
