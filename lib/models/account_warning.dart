/// A warning issued to the signed-in account.
///
/// Backend rows are untrusted: every field is read defensively. Warnings are
/// only returned while inside their visibility window; the record itself is
/// retained for moderation after that.
class AccountWarning {
  const AccountWarning({
    required this.id,
    required this.category,
    required this.message,
    required this.createdAt,
    required this.visibleUntil,
    this.acknowledgedAt,
  });

  final String id;
  final String category;
  final String message;
  final DateTime createdAt;
  final DateTime visibleUntil;
  final DateTime? acknowledgedAt;

  bool get isAcknowledged => acknowledgedAt != null;

  bool get isVisible => visibleUntil.isAfter(DateTime.now().toUtc());

  String get categoryLabel {
    switch (category) {
      case 'spam':
        return 'Spam or fake profile';
      case 'harassment':
        return 'Harassment';
      case 'irrelevant':
        return 'Irrelevant';
      default:
        return 'Community guidelines';
    }
  }

  factory AccountWarning.fromRow(Map<String, dynamic> row) {
    return AccountWarning(
      id: _text(row['id']) ?? '',
      category: _text(row['category']) ?? 'other',
      message: _text(row['message']) ?? '',
      createdAt: _date(row['created_at']) ?? DateTime.now().toUtc(),
      visibleUntil: _date(row['visible_until']) ?? DateTime.now().toUtc(),
      acknowledgedAt: _date(row['acknowledged_at']),
    );
  }

  static String? _text(dynamic value) {
    if (value is! String) return null;
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  static DateTime? _date(dynamic value) {
    if (value is DateTime) return value.toUtc();
    final text = _text(value);
    if (text == null) return null;
    return DateTime.tryParse(text)?.toUtc();
  }
}
