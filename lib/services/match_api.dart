// PalTuro — MatchApi: typed bridge between the UI screens and the live backend
// (RPCs + Edge Functions). One place to adapt backend shapes into the legacy
// UI models (Person / ConnectionRequest / MatchedUser) so screens stay intact.
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:palturo/screen/card/person_card.dart';
import 'package:palturo/screen/request_page.dart' show ConnectionRequest;

class _Client {
  static SupabaseClient get c => Supabase.instance.client;
}

/// Result row of get-matches (Edge Function) adapted for the UI.
class MatchLite {
  final String userId;
  final int rank;
  final String displayName;
  final String role; // 'learner' | 'mentor' | 'both'
  final double compatibility; // calibrated 0..1
  final String pipeline; // 'full' | 'basic_bi'
  const MatchLite({
    required this.userId,
    required this.rank,
    required this.displayName,
    required this.role,
    required this.compatibility,
    required this.pipeline,
  });

  PersonRole get personRole =>
      role == 'learner' ? PersonRole.learner : PersonRole.mentor;

  Person toPerson(String? avatarUrl, {String bio = ''}) => Person(
        id: userId,
        name: displayName,
        schedule: '',
        language: '',
        learningStyle: '',
        skillName: '',
        role: personRole,
        bio: bio,
        photoUrls: [avatarUrl],
      );
}

/// Conversation row from get_conversations RPC (Chats/Matches).
class ConversationLite {
  final String connectionId;
  final String status; // pending | accepted | declined
  final String otherUserId;
  final String otherName;
  final String otherRole;
  final String? lastMessage;
  final DateTime? lastAt;
  final int unread;
  final String? otherAvatar;
  const ConversationLite({
    required this.connectionId,
    required this.status,
    required this.otherUserId,
    required this.otherName,
    required this.otherRole,
    this.lastMessage,
    this.lastAt,
    required this.unread,
    this.otherAvatar,
  });

  Person toPerson() => Person(
        id: otherUserId,
        name: otherName,
        schedule: '',
        language: '',
        learningStyle: '',
        skillName: '',
        role: otherRole == 'learner' ? PersonRole.learner : PersonRole.mentor,
        photoUrls: [otherAvatar],
      );
}

/// Incoming connection request from get_incoming_requests RPC (Requests page).
class RequestLite {
  final String connectionId;
  final String requesterId;
  final String requesterName;
  final String? avatarUrl;
  final List<String> skills; // title-cased skill names
  final DateTime createdAt;
  const RequestLite({
    required this.connectionId,
    required this.requesterId,
    required this.requesterName,
    this.avatarUrl,
    required this.skills,
    required this.createdAt,
  });

  ConnectionRequest toConnectionRequest() {
    final skill = skills.isNotEmpty ? skills.first : 'Skill sharing';
    return ConnectionRequest(
      id: connectionId,
      skillName: skill,
      requesterName: requesterName,
      schedule: '',
      language: '',
      learningStyle: '',
      bio: '',
      requestedAt: createdAt,
      iconAsset: 'assets/icons/rlearner.svg',
      seekingLabel: 'Wants to connect in',
      role: PersonRole.mentor,
      photoUrls: [avatarUrl],
    );
  }
}

class MatchApi {
  /// Edge Function: full recommendation pipeline.
  /// [asRole] = the role we want to find ('mentor' from a learner, etc).
  /// Returns ranked MatchLite list. Throws on hard failure (caller shows UI error).
  static Future<List<MatchLite>> getMatches({
    required String asRole,
    bool refresh = true,
  }) async {
    final res = await _Client.c.functions.invoke(
      'get-matches',
      body: {'as_role': asRole, 'refresh': refresh},
    );
    final data = (res.data as Map? ?? {});
    final results = (data['results'] as List? ?? []);
    return results
        .whereType<Map>()
        .map((r) => MatchLite(
              userId: r['user_id'] as String,
              rank: (r['rank'] as num).toInt(),
              displayName: (r['display_name'] ?? '') as String,
              role: (r['role'] ?? 'both') as String,
              compatibility: (r['compatibility'] as num?)?.toDouble() ?? 0.0,
              pipeline: (r['pipeline'] ?? 'full') as String,
            ))
        .toList();
  }

  /// Public profile detail to enrich a deck card / dialog.
  static Future<Map<String, dynamic>?> getPublicProfile(String userId) async {
    final res = await _Client.c
        .rpc('get_public_profile', params: {'p_user': userId}) as Map?;
    if (res == null) return null;
    return Map<String, dynamic>.from(res);
  }

  /// Build a rich Person (for PersonCard) from the public-profile RPC.
  static Future<Person?> getPersonFromPublicProfile(String userId) async {
    final p = await getPublicProfile(userId);
    if (p == null) return null;
    String name = (p['p_name'] ?? '') as String;
    String skill = '';
    final teaching = (p['p_teaching'] as List?) ?? [];
    final learning = (p['p_learning'] as List?) ?? [];
    dynamic first;
    if (teaching.isNotEmpty) {
      first = teaching.first;
      skill = ((first as Map)['skill'] ?? '').toString();
    } else if (learning.isNotEmpty) {
      first = learning.first;
      skill = ((first as Map)['skill'] ?? '').toString();
    }
    return Person(
      id: userId,
      name: name,
      schedule: '', // availability lives in p_availability jsonb (legacy shape)
      language: (p['p_languages'] ?? '') as String,
      learningStyle: (p['p_styles'] ?? '') as String,
      skillName: skill.replaceAll(' > ', '  •  '),
      role: (p['p_role'] == 'learner')
          ? PersonRole.learner
          : PersonRole.mentor,
      bio: (p['p_bio'] ?? '') as String,
      photoUrls: [(p['p_avatar'] as String?)],
    );
  }

  /// Recommended deck: get-matches + public-profile enrichment, capped.
  static Future<List<Person>> getMatchDeck({
    required String asRoleDb,
    String? learnerOrMentorFilter,
    int enrichLimit = 10,
  }) async {
    final matches = await getMatches(asRole: asRoleDb);
    // non-self, ranked, filtered by UI role filter (both passes all)
    final targetMatches = matches
        .where((m) =>
            learnerOrMentorFilter == null ||
            m.role == learnerOrMentorFilter ||
            m.role == 'both')
        .take(enrichLimit)
        .toList();
    final out = <Person>[];
    for (final m in targetMatches) {
      final person = await getPersonFromPublicProfile(m.userId);
      if (person != null) out.add(person);
    }
    return out;
  }

  /// Conversations for Chats/Matches/Requests surfaces.
  static Future<List<ConversationLite>> getConversations() async {
    final res = await _Client.c.rpc('get_conversations') as List;
    return res
        .whereType<Map>()
        .map((r) => ConversationLite(
              connectionId: r['connection_id'] as String,
              status: (r['status'] ?? 'pending') as String,
              otherUserId: (r['other_user_id'] ?? '') as String,
              otherName: (r['other_name'] ?? '') as String,
              otherRole: (r['other_role'] ?? 'both') as String,
              lastMessage: r['last_message'] as String?,
              lastAt: DateTime.tryParse(r['last_at']?.toString() ?? ''),
              unread: (r['unread'] as num?)?.toInt() ?? 0,
              otherAvatar: r['other_avatar'] as String?,
            ))
        .toList();
  }

  /// Messages in one room (renders in ChatRoom).
  static Future<List<Map<String, dynamic>>> getMessages(
    String connectionId,
  ) async {
    final res = await _Client.c
        .rpc('get_conversation', params: {'p_connection': connectionId}) as List;
    return res.whereType<Map>().map((m) {
      return {'sender_id': m['sender_id'], 'body': m['body']};
    }).toList();
  }

  static Future<void> sendMessage(String connectionId, String body) async {
    await _Client.c.rpc('send_message', params: {
      'p_connection': connectionId,
      'p_body': body,
    });
  }

  /// Requests page: incoming pending connections (+ requester details).
  static Future<List<RequestLite>> getIncomingRequests() async {
    final res = await _Client.c.rpc('get_incoming_requests') as List;
    return res.whereType<Map>().map((r) {
      final skills = ((r['skills'] as List?) ?? [])
          .whereType<dynamic>()
          .map((s) => s.toString())
          .toList();
      return RequestLite(
        connectionId: r['connection_id'] as String,
        requesterId: r['requester_id'] as String,
        requesterName: (r['requester_name'] ?? '') as String,
        avatarUrl: r['avatar_url'] as String?,
        skills: skills,
        createdAt: DateTime.tryParse(r['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );
    }).toList();
  }

  static Future<void> respondToRequest(
      String connectionId, bool accept) async {
    await _Client.c.rpc('respond_connection_request', params: {
      'p_connection': connectionId,
      'p_accept': accept,
    });
  }

  static Future<void> sendConnectionRequest(String userId) =>
      _Client.c.rpc('send_connection_request', params: {'p_recipient': userId});

  static Future<void> blockUser(String userId) =>
      _Client.c.rpc('block_user', params: {'p_target': userId});

  static Future<void> unblockUser(String userId) =>
      _Client.c.rpc('unblock_user', params: {'p_target': userId});

  static Future<void> reportUser(String userId, String reason) =>
      _Client.c.rpc('report_user', params: {
        'p_target': userId,
        'p_reason': reason,
      });

  static Future<List<Map<String, dynamic>>> getBlockList() async {
    final res = await _Client.c.rpc('get_block_list') as List;
    return res
        .whereType<Map>()
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
  }

  // ---- Explore taxonomy ----

  /// Visible taxonomy nodes (id, name, path, depth, is_leaf, usage_count).
  static Future<List<Map<String, dynamic>>> taxonomyVisible(
      {String? rootPath}) async {
    final res = await _Client.c.rpc('taxonomy_visible',
        params: {'p_root_path': rootPath}) as List;
    return res
        .whereType<Map>()
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
  }

  /// Skill users for Explore expand (teach side by default).
  static Future<List<Person>> browseSkillUsers(String nodePath,
      {String kind = 'teach'}) async {
    final res = await _Client.c.rpc('browse_skill_users', params: {
      'p_node': nodePath,
      'p_kind': kind,
    }) as List;
    return (res.whereType<Map>()).map((r) {
      final role = (r['role'] ?? 'both') as String;
      return Person(
        id: r['user_id'] as String,
        name: (r['name'] ?? '') as String,
        schedule: '',
        language: '',
        learningStyle: '',
        skillName: '',
        role: role == 'learner' ? PersonRole.learner : PersonRole.mentor,
        bio: (r['note'] ?? '') as String,
        photoUrls: [r['avatar_url'] as String?],
      );
    }).toList();
  }

  /// Notifications badge helpers.
  static Future<int> unreadNotifications() async {
    final res = await _Client.c.rpc('count_unread_notifications');
    return (res as num?)?.toInt() ?? 0;
  }

  static Future<void> markNotificationsRead() =>
      _Client.c.rpc('mark_notifications_read');
}
