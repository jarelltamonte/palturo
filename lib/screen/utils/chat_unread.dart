import 'package:palturo/services/match_api.dart';

/// Unread is conversation data, never a notification-preference side effect.
bool conversationHasUnread(ConversationLite conversation) =>
    conversation.unread > 0;

/// The dot/badge is the only part that respects the preference.
bool showConversationUnreadIndicator(
  ConversationLite conversation,
  bool notificationsEnabled,
) => notificationsEnabled && conversationHasUnread(conversation);
