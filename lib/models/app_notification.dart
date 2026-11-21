/// A parsed PalTuro notification event.
///
/// Backend rows are untrusted input: every field is read defensively and
/// unknown kinds/fields fall back to safe values. UI code should use this
/// model instead of reading raw `payload` maps.
enum AppNotificationKind {
  connectionRequest('connection_request'),
  requestAccepted('request_accepted'),
  requestDeclined('request_declined'),
  feedbackReady('feedback_ready'),
  skillModeration('skill_moderation'),
  noteRejected('note_rejected'),
  possibleMatch('possible_match'),
  accountWarning('account_warning'),
  unknown('unknown');

  const AppNotificationKind(this.wireValue);

  final String wireValue;

  static AppNotificationKind fromWire(dynamic value) {
    final normalized = value?.toString().trim();
    if (normalized == null || normalized.isEmpty) {
      return AppNotificationKind.unknown;
    }
    for (final kind in values) {
      if (kind.wireValue == normalized) return kind;
    }
    return AppNotificationKind.unknown;
  }

  bool get isRequest => this == AppNotificationKind.connectionRequest;

  bool get isMatch => this == AppNotificationKind.requestAccepted;

  bool get isDecline => this == AppNotificationKind.requestDeclined;

  bool get isFeedback => this == AppNotificationKind.feedbackReady;

  /// A suggestion computed from a new profile, not a confirmed connection.
  bool get isPossibleMatch => this == AppNotificationKind.possibleMatch;

  /// A published note that inference later rejected.
  bool get isNoteRejected => this == AppNotificationKind.noteRejected;

  /// An account notice that must stay visible regardless of category toggles.
  bool get isAccountNotice => this == AppNotificationKind.accountWarning;
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.createdAt,
    this.payload = const {},
    this.readAt,
    this.actorId,
    this.actorName,
    this.actorAvatar,
    this.skillName,
    this.role,
    this.connectionStatus,
  });

  final String id;
  final AppNotificationKind kind;
  final DateTime createdAt;
  final DateTime? readAt;
  final Map<String, dynamic> payload;
  final String? actorId;
  final String? actorName;
  final String? actorAvatar;
  final String? skillName;
  final String? role;
  final String? connectionStatus;

  bool get isUnread => readAt == null;

  String? get connectionId => _text(payload['connection_id']);

  String? get actorLabel => actorName ?? _text(payload['name']);

  String? get skillLabel =>
      skillName ?? _text(payload['skill_name']) ?? _text(payload['skill']);

  /// Direction of a possible match: the role the candidate was suggested as.
  String? get possibleMatchRole => _text(payload['as_role']);

  /// Safe parser for a Supabase row from `list_notifications` or a realtime
  /// insert. Missing fields never throw.
  factory AppNotification.fromRow(Map<String, dynamic> row) {
    final payload = _map(row['payload']);
    final id = _text(row['id']) ?? '';
    final createdAt = _date(row['created_at']) ?? DateTime.now().toUtc();
    final kind = AppNotificationKind.fromWire(row['kind']);
    final actorId =
        _text(row['actor_id']) ??
        _text(payload['requester_id']) ??
        _text(payload['responder_id']) ??
        _text(payload['candidate_id']) ??
        _text(payload['actor_id']);
    final actorName =
        _text(row['actor_name']) ??
        _text(payload['actor_name']) ??
        _text(payload['requester_name']) ??
        _text(payload['responder_name']) ??
        _text(payload['name']);
    final actorAvatar =
        _text(row['actor_avatar']) ??
        _text(row['avatar_url']) ??
        _text(payload['actor_avatar']) ??
        _text(payload['avatar_url']);
    final skillName =
        _text(row['skill_name']) ??
        _text(payload['skill_name']) ??
        _text(payload['skill']);
    final role = _text(row['role']) ?? _text(payload['role']);
    final status = _text(row['connection_status']) ?? _text(row['status']);

    return AppNotification(
      id: id,
      kind: kind,
      createdAt: createdAt,
      readAt: _date(row['read_at']),
      payload: payload,
      actorId: actorId,
      actorName: actorName,
      actorAvatar: actorAvatar,
      skillName: skillName,
      role: role,
      connectionStatus: status,
    );
  }

  AppNotification copyWith({
    String? id,
    AppNotificationKind? kind,
    DateTime? createdAt,
    DateTime? readAt,
    Map<String, dynamic>? payload,
    String? actorId,
    String? actorName,
    String? actorAvatar,
    String? skillName,
    String? role,
    String? connectionStatus,
    bool clearReadAt = false,
  }) {
    return AppNotification(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      createdAt: createdAt ?? this.createdAt,
      readAt: clearReadAt ? null : (readAt ?? this.readAt),
      payload: payload ?? this.payload,
      actorId: actorId ?? this.actorId,
      actorName: actorName ?? this.actorName,
      actorAvatar: actorAvatar ?? this.actorAvatar,
      skillName: skillName ?? this.skillName,
      role: role ?? this.role,
      connectionStatus: connectionStatus ?? this.connectionStatus,
    );
  }

  /// Reconstructs the presentation-friendly map used by existing Activity
  /// helpers. Keeps one adapter for both raw RPC rows and typed events.
  Map<String, dynamic> toRow() {
    return {
      'id': id,
      'kind': kind.wireValue,
      'payload': payload,
      'read_at': readAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      if (actorId != null) 'actor_id': actorId,
      if (actorName != null) 'actor_name': actorName,
      if (actorAvatar != null) 'actor_avatar': actorAvatar,
      if (skillName != null) 'skill_name': skillName,
      if (role != null) 'role': role,
      if (connectionStatus != null) 'connection_status': connectionStatus,
    };
  }

  static String? _text(dynamic value) {
    if (value is! String) return null;
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  static DateTime? _date(dynamic value) {
    if (value is DateTime) return value.toUtc();
    final text = _text(value);
    if (text == null) return null;
    return DateTime.tryParse(text)?.toUtc();
  }
}
