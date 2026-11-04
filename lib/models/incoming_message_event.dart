/// A live incoming chat message, independent of the chat room widget.
class IncomingMessageEvent {
  const IncomingMessageEvent({
    required this.connectionId,
    required this.senderName,
    required this.body,
    required this.createdAt,
    this.avatarUrl,
    this.skillName,
    this.role,
  });

  final String connectionId;
  final String senderName;
  final String body;
  final DateTime createdAt;
  final String? avatarUrl;
  final String? skillName;
  final String? role;

  /// One-line preview for banners. Collapses whitespace and caps the length
  /// so a long message cannot take over the screen.
  String get preview {
    final collapsed = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (collapsed.length <= 120) return collapsed;
    return '${collapsed.substring(0, 117)}...';
  }
}
