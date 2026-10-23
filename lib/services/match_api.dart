// PalTuro — MatchApi: typed bridge between the UI screens and the live backend
// (RPCs + Edge Functions). One place to adapt backend shapes into the legacy
// UI models (Person / ConnectionRequest / MatchedUser) so screens stay intact.
import 'dart:convert';
import 'package:flutter/foundation.dart';
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
  final String? otherSkill;
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
    this.otherSkill,
  });

  ConversationLite copyWith({
    String? connectionId,
    String? status,
    String? otherUserId,
    String? otherName,
    String? otherRole,
    String? lastMessage,
    DateTime? lastAt,
    int? unread,
    String? otherAvatar,
    String? otherSkill,
  }) {
    return ConversationLite(
      connectionId: connectionId ?? this.connectionId,
      status: status ?? this.status,
      otherUserId: otherUserId ?? this.otherUserId,
      otherName: otherName ?? this.otherName,
      otherRole: otherRole ?? this.otherRole,
      lastMessage: lastMessage ?? this.lastMessage,
      lastAt: lastAt ?? this.lastAt,
      unread: unread ?? this.unread,
      otherAvatar: otherAvatar ?? this.otherAvatar,
      otherSkill: otherSkill ?? this.otherSkill,
    );
  }

  Person toPerson() => Person(
    id: otherUserId,
    name: otherName,
    schedule: '',
    language: '',
    learningStyle: '',
    skillName: otherSkill ?? '',
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
      requesterId: requesterId,
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
  /// Backend rows may have a missing display name; never let an empty string
  /// reach list widgets that index `name[0]`.
  static String _displayName(dynamic value) {
    final name = (value ?? '').toString().trim();
    return name.isEmpty ? 'Community member' : name;
  }

  /// Edge Function: full recommendation pipeline.
  /// [asRole] = the role we want to find ('mentor' from a learner, etc).
  /// [useCache] lets the function return its cached ranking when it is still
  /// fresh; false forces a full pipeline recompute (the function interprets
  /// `refresh: false` as "do not use the cache").
  /// Returns ranked MatchLite list. Throws on hard failure (caller shows UI error).
  static Future<List<MatchLite>> getMatches({
    required String asRole,
    bool useCache = true,
  }) async {
    late final FunctionResponse res;
    try {
      res = await _Client.c.functions.invoke(
        'get-matches',
        body: {'as_role': asRole, 'refresh': useCache},
      );
    } on FunctionException catch (e) {
      if (e.status == 429) {
        throw Exception('Too many deck requests. Please try again later.');
      }
      rethrow;
    }
    // supabase_flutter may hand res.data back as a decoded Map or a raw JSON
    // string depending on platform — handle both before reading keys.
    final dynamic raw = res.data;
    late final Map<String, dynamic> data;
    if (raw is Map) {
      data = Map<String, dynamic>.from(raw);
    } else if (raw is String && raw.isNotEmpty) {
      debugPrint(
        '[MatchApi] res.data was String: ${raw.substring(0, raw.length.clamp(0, 200))}',
      );
      data = (jsonDecode(raw) as Map).cast<String, dynamic>();
    } else {
      debugPrint('[MatchApi] res.data unexpected type: ${raw.runtimeType}');
      data = {};
    }
    final results = (data['results'] as List? ?? []);
    debugPrint('[MatchApi] get-matches parsed: ${results.length} results');
    return results
        .whereType<Map>()
        .map(
          (r) => MatchLite(
            userId: r['user_id'] as String,
            rank: (r['rank'] as num?)?.toInt() ?? 0,
            displayName: _displayName(r['display_name']),
            role: (r['role'] ?? 'both') as String,
            compatibility: (r['compatibility'] as num?)?.toDouble() ?? 0.0,
            pipeline: (r['pipeline'] ?? 'full') as String,
          ),
        )
        .toList();
  }

  /// Public profile detail to enrich a deck card / dialog.
  static Future<Map<String, dynamic>?> getPublicProfile(String userId) async {
    final res =
        await _Client.c.rpc('get_public_profile', params: {'p_user': userId})
            as Map?;
    if (res == null) return null;
    return Map<String, dynamic>.from(res);
  }

  /// Build a rich Person (for PersonCard) from the public-profile RPC.
  static Future<Person?> getPersonFromPublicProfile(String userId) async {
    final p = await getPublicProfile(userId);
    if (p == null) return null;
    String name = ((p['p_name'] ?? '') as String).trim();
    if (name.isEmpty) name = 'Community member';
    String skill = '';
    final teaching = (p['p_teaching'] as List?) ?? [];
    final learning = (p['p_learning'] as List?) ?? [];
    if (teaching.isNotEmpty) {
      final t = teaching.first as Map;
      // leaf name only (short-form template) — full chain lives in the profile dialog
      final raw = ((t['path'] ?? '') as String);
      skill =
          raw.isEmpty
              ? ((t['skill'] ?? '') as String)
              : raw.split('.').last.replaceAll('_', ' ').trim();
    } else if (learning.isNotEmpty) {
      final l = learning.first as Map;
      final raw = ((l['path'] ?? '') as String);
      skill =
          raw.isEmpty
              ? ((l['skill'] ?? '') as String)
              : raw.split('.').last.replaceAll('_', ' ').trim();
    }
    final showcases =
        ((p['p_showcases'] as List?) ?? [])
            .whereType<Map>()
            .map((m) => m['media'] as String?)
            .whereType<String>()
            .toList();
    return Person(
      id: userId,
      name: name,
      schedule: '', // availability lives in p_availability jsonb (legacy shape)
      language: (p['p_languages'] ?? '') as String,
      learningStyle: (p['p_styles'] ?? '') as String,
      skillName: skill,
      role: (p['p_role'] == 'learner') ? PersonRole.learner : PersonRole.mentor,
      bio: (p['p_bio'] ?? '') as String,
      photoUrls: [(p['p_avatar'] as String?)],
      showcaseUrls: showcases.isNotEmpty ? showcases : const [null],
    );
  }

  // ---- Deck preloading (stale-while-revalidate) ----
  static final Map<String, List<Person>> _deckCache = {};
  static final Map<String, DateTime> _deckFetchedAt = {};
  static const Duration _deckTtl = Duration(minutes: 10);
  static String? _deckCacheUserId;

  /// Cache key is scoped to the signed-in user. If the session changes (sign
  /// out / account switch) the previous user's deck is discarded immediately.
  static String _deckKey(String asRoleDb) {
    final userId = _Client.c.auth.currentUser?.id ?? 'anonymous';
    if (_deckCacheUserId != userId) {
      _deckCache.clear();
      _deckFetchedAt.clear();
      _deckCacheUserId = userId;
    }
    return '$userId|$asRoleDb';
  }

  /// Drops all cached decks. Call on sign-out.
  static void clearCaches() {
    _deckCache.clear();
    _deckFetchedAt.clear();
    _deckCacheUserId = null;
  }

  static bool hasCachedDeck(String asRoleDb) =>
      _deckCache.containsKey(_deckKey(asRoleDb));

  /// Cached deck instantly (no spinner); triggers a background refresh when
  /// stale. force bypasses both.
  static Future<List<Person>> getMatchDeck({
    required String asRoleDb,
    String? learnerOrMentorFilter,
    bool force = false,
    int enrichLimit = 10,
  }) async {
    final key = _deckKey(asRoleDb);
    final cached = _deckCache[key];
    final fetchedAt = _deckFetchedAt[key];
    final fresh =
        cached != null &&
        fetchedAt != null &&
        DateTime.now().difference(fetchedAt) < _deckTtl;
    if (cached != null && fresh && !force) return cached;
    if (cached != null && !force) {
      // stale-while-revalidate: serve the cached copy, refresh silently
      getMatchDeck(
        asRoleDb: asRoleDb,
        force: true,
        enrichLimit: enrichLimit,
      ).then((_) {}, onError: (_) {});
      return cached;
    }
    return fetchAndCacheDeck(asRoleDb, enrichLimit, force: force);
  }

  static Future<List<Person>> fetchAndCacheDeck(
    String asRoleDb,
    int enrichLimit, {
    bool force = false,
  }) async {
    final key = _deckKey(asRoleDb);
    final matches = await getMatches(asRole: asRoleDb, useCache: !force);
    final targetMatches = matches.take(enrichLimit).toList();
    final out = <Person>[];
    for (final m in targetMatches) {
      final person = await getPersonFromPublicProfile(m.userId);
      if (person == null) continue;
      // carry the compatibility score onto the card (spec §6.3 indicator)
      final compat = m.compatibility;
      out.add(
        Person(
          id: person.id,
          name: person.name,
          schedule: person.schedule,
          language: person.language,
          learningStyle: person.learningStyle,
          skillName: person.skillName,
          role: person.role,
          bio: person.bio,
          photoUrls: person.photoUrls,
          showcaseUrls: person.showcaseUrls,
          compatibility: compat,
        ),
      );
    }
    // Guard against a user switch during the fetch.
    if (key == _deckKey(asRoleDb)) {
      _deckCache[key] = out;
      _deckFetchedAt[key] = DateTime.now();
    }
    return out;
  }

  /// Random users after the deck is exhausted (FR-13 discovery).
  ///
  /// [role] filters on the raw DB role before enrichment, so `both` users are
  /// eligible for either side. The RPC is sampled with extra headroom because
  /// it has no role parameter; only the first [limit] matches are enriched.
  static Future<List<Person>> getRandomDeck({
    int limit = 20,
    String? role,
  }) async {
    final sampleSize =
        role == null ? limit : (limit * 10).clamp(0, 200).toInt();
    final res =
        await _Client.c.rpc(
              'browse_random_users',
              params: {'p_limit': sampleSize},
            )
            as List;

    final seen = <String>{};
    final ids =
        res
            .whereType<Map>()
            .where((r) {
              if (role == null) return true;
              final rawRole = r['role'] as String?;
              return rawRole == null || rawRole == role || rawRole == 'both';
            })
            .map((r) => r['user_id'] as String)
            .where(seen.add)
            .take(limit)
            .toList();

    // Enrich concurrently; one missing/deleted profile must not discard the
    // rest of the batch.
    final people = await Future.wait(
      ids.map((id) async {
        try {
          return await getPersonFromPublicProfile(id);
        } catch (_) {
          return null;
        }
      }),
    );
    final out = people.whereType<Person>().toList();
    if (out.length < ids.length) {
      debugPrint(
        '[MatchApi] random discovery enriched ${out.length}/${ids.length}',
      );
    }
    return out;
  }

  /// Conversations for Chats/Matches/Requests surfaces.
  static Future<List<ConversationLite>> getConversations() async {
    final res = await _Client.c.rpc('get_conversations') as List;
    return res
        .whereType<Map>()
        .map(
          (r) => ConversationLite(
            connectionId: r['connection_id'] as String,
            status: (r['status'] ?? 'pending') as String,
            otherUserId: (r['other_user_id'] ?? '') as String,
            otherName: _displayName(r['other_name']),
            otherRole: (r['other_role'] ?? 'both') as String,
            lastMessage: r['last_message'] as String?,
            lastAt: DateTime.tryParse(r['last_at']?.toString() ?? ''),
            unread: (r['unread'] as num?)?.toInt() ?? 0,
            otherAvatar: r['other_avatar'] as String?,
            otherSkill:
                (r['other_skill'] ?? r['skill_name'] ?? r['skill']) as String?,
          ),
        )
        .toList();
  }

  /// Messages in one room (renders in ChatRoom). Keeps created_at so the
  /// client-side sort is deterministic (BUGFIX: dropping it made the thread
  /// render newest-first on open and flip when realtime kicked in).
  static Future<List<Map<String, dynamic>>> getMessages(
    String connectionId,
  ) async {
    final res =
        await _Client.c.rpc(
              'get_conversation',
              params: {'p_connection': connectionId},
            )
            as List;
    return res.whereType<Map>().map((m) {
      return {
        'id': m['id'],
        'sender_id': m['sender_id'],
        'body': m['body'],
        'created_at': m['created_at'],
      };
    }).toList();
  }

  static Future<void> sendMessage(String connectionId, String body) async {
    await _Client.c.rpc(
      'send_message',
      params: {'p_connection': connectionId, 'p_body': body},
    );
  }

  /// Whether the 15-message feedback gate is open and whether this user rated.
  static Future<({bool gateOpen, bool alreadyRated})> feedbackStatus(
    String connectionId,
  ) async {
    final res =
        await _Client.c.rpc(
              'my_feedback_status',
              params: {'p_connection': connectionId},
            )
            as List;
    final rows = res.whereType<Map>();
    final row = rows.isEmpty ? null : rows.first;
    return (
      gateOpen: row?['gate_open'] == true,
      alreadyRated: row?['already_rated'] == true,
    );
  }

  /// Creates the one-time feedback notifications once a thread reaches 15
  /// messages. Safe to call after each send; the RPC deduplicates.
  static Future<void> checkFeedbackGate(String connectionId) => _Client.c.rpc(
    'check_feedback_gate',
    params: {'p_connection': connectionId},
  );

  static Future<void> submitFeedback(
    String connectionId, {
    required int clarity,
    required int reliability,
  }) => _Client.c.rpc(
    'submit_feedback',
    params: {
      'p_connection': connectionId,
      'p_clarity': clarity,
      'p_reliability': reliability,
    },
  );

  /// Marks unread messages in this connection as read.
  static Future<void> markMessagesRead(String connectionId) async {
    try {
      await _Client.c.rpc(
        'mark_messages_read',
        params: {'p_connection': connectionId},
      );
    } catch (_) {
      // Best-effort; the next sync recomputes unread from the read timestamps.
    }
  }

  /// Requests page: incoming pending connections (+ requester details).
  static Future<List<RequestLite>> getIncomingRequests() async {
    final res = await _Client.c.rpc('get_incoming_requests') as List;
    return res.whereType<Map>().map((r) {
      final skills =
          ((r['skills'] as List?) ?? [])
              .whereType<dynamic>()
              .map((s) => s.toString())
              .toList();
      return RequestLite(
        connectionId: r['connection_id'] as String,
        requesterId: r['requester_id'] as String,
        requesterName: _displayName(r['requester_name']),
        avatarUrl: r['avatar_url'] as String?,
        skills: skills,
        createdAt:
            DateTime.tryParse(r['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );
    }).toList();
  }

  static Future<void> respondToRequest(String connectionId, bool accept) async {
    await _Client.c.rpc(
      'respond_connection_request',
      params: {'p_connection': connectionId, 'p_accept': accept},
    );
  }

  /// Deletes an accepted connection. The RPC verifies the caller is one of the
  /// two participants before removing it and its messages/feedback.
  static Future<void> unmatch(String connectionId) async {
    await _Client.c.rpc(
      'unmatch_connection',
      params: {'p_connection': connectionId},
    );
  }

  static Future<void> sendConnectionRequest(String userId) =>
      _Client.c.rpc('send_connection_request', params: {'p_recipient': userId});

  static Future<void> blockUser(String userId) =>
      _Client.c.rpc('block_user', params: {'p_target': userId});

  static Future<void> unblockUser(String userId) =>
      _Client.c.rpc('unblock_user', params: {'p_target': userId});

  static Future<void> reportUser(String userId, String reason) => _Client.c.rpc(
    'report_user',
    params: {'p_target': userId, 'p_reason': reason},
  );

  static Future<List<Map<String, dynamic>>> getBlockList() async {
    final res = await _Client.c.rpc('get_block_list') as List;
    return res
        .whereType<Map>()
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
  }

  // ---- Explore taxonomy ----

  /// Visible taxonomy nodes (id, name, path, depth, is_leaf, usage_count).
  static Future<List<Map<String, dynamic>>> taxonomyVisible({
    String? rootPath,
  }) async {
    final res =
        await _Client.c.rpc(
              'taxonomy_visible',
              params: {'p_root_path': rootPath},
            )
            as List;
    return res
        .whereType<Map>()
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
  }

  /// Skill users for Explore expand (teach side by default).
  static Future<List<Person>> browseSkillUsers(
    String nodePath, {
    String kind = 'teach',
  }) async {
    final res =
        await _Client.c.rpc(
              'browse_skill_users',
              params: {'p_node': nodePath, 'p_kind': kind},
            )
            as List;
    return (res.whereType<Map>()).map((r) {
      return Person(
        id: r['user_id'] as String,
        name: _displayName(r['name']),
        schedule: '',
        language: '',
        learningStyle: '',
        skillName: '',
        // The card is shown in a teaching or learning deck, so reflect the
        // placement being browsed rather than the profile's global role.
        role: kind == 'learn' ? PersonRole.learner : PersonRole.mentor,
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

  // ---- Skill selection (spec: taxonomy + notes + classify) ----

  /// The caller's placements: [{kind, note, id, name, path}].
  static Future<List<Map<String, dynamic>>> mySkills() async {
    final res =
        await _Client.c
                .from('user_skills')
                .select('kind, note, skill:skill_id(id, name, path)')
            as List;
    return res.whereType<Map>().map((m) {
      final skill = (m['skill'] as Map?) ?? {};
      return {
        'kind': m['kind'],
        'note': m['note'],
        'id': skill['id'],
        'name': skill['name'],
        'path': skill['path'],
      };
    }).toList();
  }
}
