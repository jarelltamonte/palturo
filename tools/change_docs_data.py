# -*- coding: utf-8 -*-
"""Shared, verified data for the PalTuro dynamic UX change record."""
import html
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TEMP = Path.home() / "AppData" / "Local" / "Temp" / "opencode"

def sh(*args):
    return subprocess.check_output(args, cwd=ROOT, text=True, encoding="utf-8").strip()


def esc(value):
    return html.escape(str(value))


commits = []
for line in sh("git", "log", "3ab6700..08de0e8", "--reverse", "--pretty=format:%h|%ad|%s", "--date=short").splitlines():
    h, d, subject = line.split("|", 2)
    commits.append((h, d, subject))

changed = []
for line in sh("git", "diff", "--name-status", "3ab6700..08de0e8").splitlines():
    status, path = line.split("\t", 1)
    changed.append((status, path))

shortstat = sh("git", "diff", "--shortstat", "3ab6700..08de0e8")

# Phase definitions: (id, title, status, commits, goal, changes[list], files[list], evidence)
phases = [
    (
        "A0", "Notification Foundation", "VERIFIED",
        "8e0f5f3, 5aed01e",
        "Introduce a typed, realtime notification backbone so every later notification surface uses one source of truth.",
        [
            "Added AppNotification with known kinds (request, accepted, declined, feedback, moderation, unknown), defensive parsing, payload fallbacks, read state, and copyWith/toRow adapters.",
            "Added NotificationService: notifications realtime channel, dedupe by id, unread count, mark-one/mark-all, lifecycle refresh, sign-out reset, and reconnect handling.",
            "Added AppRouter and a global navigator key so banners, Activity, local notifications, and cold starts can open Activity, Requests, Chat, or Profile before or after the first frame.",
            "Replaced ActivityService with NotificationService and migrated every caller.",
            "Server: notifications added to the supabase_realtime publication with a SELECT grant scoped by the existing notif_read policy; list_notifications enriched with actor name/avatar, skill, role, and connection status.",
        ],
        [
            "lib/models/app_notification.dart",
            "lib/services/notification_service.dart",
            "lib/services/app_navigation.dart",
            "lib/services/app_navigator.dart",
            "supabase/migrations/20261105000100_notifications_realtime.sql",
            "supabase/migrations/20261105000200_notification_context.sql",
        ],
        "91 tests; analyzer clean; live RPC and grant probes; three subagent audits PASS at 5aed01e.",
    ),
    (
        "A1", "In-app Dynamic UX", "VERIFIED",
        "45cf7e7, be90c0d, de4046e, c480fa7, 06f10d8",
        "Make live events visible without leaving the current screen, with a subtle top banner and a celebratory match moment.",
        [
            "Added a global AppBanner queue: one banner at a time, 4s default, close/swipe dismiss, tap routing, live-region semantics, reduced-motion support, and grouping per conversation.",
            "Added the match banner: 'You're now Pals with X', skill line, Say hello, about 7s, once per connection, persisted across restarts; it pre-empts a standard banner and restores the queued one.",
            "Replaced the old bottom match sheet with the top banner.",
            "Emitted IncomingMessageEvent from ChatStateService only for messages outside the active room and not authored by the current user; same-conversation messages coalesce.",
            "Added the Activity bell on For You with unread count, and route-aware suppression for Activity, pushed Requests, and the active chat.",
            "Hardened realtime auth: refresh expired sessions before joining, resubscribe with backoff on JWT/channel errors, track joined state, and recover on token refresh or resume.",
        ],
        [
            "lib/widgets/app_banner.dart",
            "lib/widgets/match_banner.dart",
            "lib/services/notification_presenter.dart",
            "lib/services/app_shell_state.dart",
            "lib/models/incoming_message_event.dart",
            "lib/services/chat_state_service.dart",
            "lib/screen/home_page.dart",
            "lib/screen/request_page.dart",
        ],
        "99 tests; live light/dark banner, match, and message probes; three subagent audits PASS at 06f10d8.",
    ),
    (
        "A2", "Haptics and Sound", "VERIFIED",
        "b96c571, 4de648a",
        "Give interactions meaningful physical and audio feedback without double-cueing or ignoring user preferences.",
        [
            "Rewrote Haptics as named intents: selection, tap, toggle, impact, success, warning, error, match; 50ms per-intent throttle; web/desktop no-op; Vibration preference gate.",
            "Added SoundService reusing existing assets: messages.wav, newmatch.wav, splash.wav; sound preference gate, lifecycle gate, 150ms debounce, serialized init, stop on route change.",
            "Wired feedback for matches, messages, requests, declines, sends, undo, profile save, settings toggles, filters, and destructive confirmations.",
            "Removed raw HapticFeedback calls from request cards so the preference cannot be bypassed; removed the duplicate decline cue.",
            "Settings enabling Sound or Vibration previews the choice.",
        ],
        [
            "lib/services/haptics.dart",
            "lib/services/sound_service.dart",
            "lib/services/notification_presenter.dart",
            "lib/main.dart",
            "lib/onboarding/onboarding_complete.dart",
        ],
        "106 tests; 4 haptic + 3 sound tests; single-cue audits; three subagent audits PASS at 4de648a.",
    ),
    (
        "A3", "Notification Preferences", "VERIFIED",
        "75b1ff8, 72fe744, f89f540",
        "Give users honest, per-category control over alerts, previews, quiet hours, sound, and vibration.",
        [
            "Expanded PreferencesService into an observable model: master switch, messages, requests/matches, activity, message previews, quiet hours window, sound, vibration.",
            "Presenter gates each event kind, suppresses sound/haptics during quiet hours while still showing banners, and replaces message text with 'New message' when previews are off.",
            "Added a dedicated Notifications settings page: delivery, permission status, categories, preview example, sound/vibration with previews, adaptive quiet-hours time pickers, and Pals-only context.",
            "Master off disables categories without erasing their values; Settings root shows an accurate summary.",
            "Removed fictional OS-permission copy and scoped quiet hours to notification feedback only.",
        ],
        [
            "lib/services/preferences_service.dart",
            "lib/screen/settings/notification_preferences_page.dart",
            "lib/screen/settings.dart",
            "lib/services/notification_presenter.dart",
        ],
        "114 tests; live light/dark settings screenshots; 360/200% coverage; three subagent audits PASS at f89f540.",
    ),
    (
        "A4", "Local Notifications", "VERIFIED",
        "dc5c03c, a2c3fc6, ed9c0ed",
        "Deliver system notifications while the process is alive, with permissions, channels, and tap routing.",
        [
            "Added flutter_local_notifications 22.3.3, Android core-library desugaring, POST_NOTIFICATIONS and VIBRATE, and ic_stat_palturo status icon.",
            "Added LocalNotificationService: initialization, four Android channel combinations per category (sound/vibration independently), web/iOS setup, foreground suppression, category/quiet/preview gating, logout cancel.",
            "Permission status model distinguishes not-asked from denied; request from Settings; denied opens system settings; state refreshes on resume.",
            "Tap and cold-start payloads route to Chat, Requests, Activity, or Profile with peer context.",
            "iOS: UNUserNotificationCenter delegate set in AppDelegate; deployment target raised to 13.0.",
        ],
        [
            "lib/services/local_notification_service.dart",
            "android/app/build.gradle.kts",
            "android/app/src/main/AndroidManifest.xml",
            "android/app/src/main/res/drawable/ic_stat_palturo.xml",
            "ios/Runner/AppDelegate.swift",
            "ios/Runner.xcodeproj/project.pbxproj",
        ],
        "120 tests; web release + Android debug APK; live permission screenshot; three subagent audits PASS at ed9c0ed.",
    ),
    (
        "A5", "Push Delivery", "BLOCKED",
        "none",
        "Deliver alerts to killed or suspended apps through FCM and APNs.",
        [
            "Not implemented. No Firebase project, google-services.json, GoogleService-Info.plist, APNs .p8/Key ID/Team ID, web VAPID key, or FCM service account is available.",
            "The app must not claim killed-app delivery or guaranteed iOS background delivery.",
            "Everything except killed-app push is covered by A4 local notifications plus server reconciliation on resume.",
        ],
        [
            "Would require: Firebase project (Android/iOS/web)",
            "android/app/google-services.json",
            "ios/Runner/GoogleService-Info.plist",
            "APNs auth key + Key ID + Team ID",
            "Web VAPID public key",
            "Firebase service account for the edge function",
        ],
        "BLOCKED on external credentials. See Accepted delivery gap in section 9.",
    ),
    (
        "A6", "Feedback System Audit", "VERIFIED",
        "8d8f9e6, 445c4c9, 5b97786, da7ff16",
        "Unify user feedback and remove technical error leakage.",
        [
            "Added AppFeedback: one snackbar contract with info/success/error tone, icon, durations (4s/3s/6s), one action, clearSnackBars, and a ScaffoldMessenger variant for dialogs.",
            "Adopted the helper across home, chat, matches, requests, block list, explore, account, and settings feedback paths.",
            "Friendly error mapping now rejects SQL/driver text (Postgrest, SQLSTATE, varying(), auth) before the allowlist, and preserves validation copy including password digit rules and account-deletion messages.",
            "Undo snackbars use an explicit 5s duration; account password/delete fallbacks are distinct and accurate.",
        ],
        [
            "lib/widgets/app_feedback.dart",
            "lib/utils/friendly_error.dart",
            "lib/screen/home_page.dart",
            "lib/screen/chats_room.dart",
            "lib/screen/request_page.dart",
        ],
        "122 tests; negative technical-leak tests; three subagent audits PASS at 5b97786/da7ff16.",
    ),
    (
        "A7", "Release 1 Verification", "VERIFIED",
        "verification only",
        "Prove the A track is release-ready.",
        [
            "Analyzer clean, 122/122 tests, release web build, Android debug APK.",
            "Visual matrix at 360/390/1440 and dark mode (home, settings, Activity, banner states).",
            "Live web probes for request, match, message, and permission states.",
            "Accepted delivery gap documented in the plan before B/C work continued.",
        ],
        [
            "Verification artifacts in the persistent plan",
            "No source changes in this phase",
        ],
        "All gates green; A5 remains blocked.",
    ),
    (
        "B0", "QOL Primitives", "VERIFIED",
        "cb7b96a, 27c3355, 9df1965",
        "Make the app feel current under poor connectivity and daily use.",
        [
            "Added pull-to-refresh to Chats, Activity, Requests (incoming/sent), and Browse; refresh keeps data and scroll position when content exists and shows a snackbar on failure instead of replacing the list.",
            "Added ConnectivityService and a persistent offline strip laid out above app content (not over the app bar), with reconnect refresh for notifications and conversations.",
            "Added AppBadgeService: launcher badge = activity unread + chat unread, gated by the master preference, skipped on web/unsupported, serialized writes, reset on sign-out.",
            "Added DraftService: per-conversation local drafts, 350ms debounce, restore on open, clear on send/sign-out, 'Draft:' preview in the chat list.",
        ],
        [
            "lib/services/connectivity_service.dart",
            "lib/services/app_badge_service.dart",
            "lib/services/draft_service.dart",
            "lib/widgets/offline_banner.dart",
            "lib/screen/chats_page.dart",
            "lib/screen/chats_room.dart",
        ],
        "131 tests; web + APK; live offline strip and draft screenshots; three subagent audits PASS at 9df1965.",
    ),
    (
        "B1", "Chat QOL", "VERIFIED",
        "a24048f, 4b18f8a, fdd641b",
        "Make everyday chat management fast and private.",
        [
            "Per-chat mute with 1h/8h/1d/1w/always and unmute; muted chats suppress banners and local notifications but still count unread; mute icon in the list; server-persisted.",
            "Mark unread: server flag, red dot in the list, clears when the chat opens, does not affect push.",
            "Draft integration in the composer and list preview.",
            "Scroll-to-bottom FAB with new-message count; auto-scroll only when already at the bottom.",
            "Long-press copy with clipboard + one snackbar; in-chat search with results, highlight, and jump; unread divider at the first unread message.",
            "Retry-all failed pending messages sequentially, stop on renewed failure; reconnect triggers retry.",
        ],
        [
            "lib/services/chat_state_service.dart",
            "lib/screen/chats_room.dart",
            "lib/screen/chats_page.dart",
            "lib/widgets/chat_search_sheet.dart",
            "lib/widgets/chat_menu_row.dart",
            "supabase/migrations/20261105000300_connection_preferences.sql",
        ],
        "138 tests; live mute/mark-unread/draft/divider/FAB/copy/search probes; three subagent audits PASS at fdd641b.",
    ),
    (
        "B2", "List and Activity QOL", "VERIFIED",
        "a25dacd, b8419ca, af0f3c4",
        "Bring chat management and Activity triage to the list level.",
        [
            "Chat long-press sheet: View profile, Mute/Unmute, Mark unread, Report, Block; profile dialog keeps block/report paths.",
            "Activity filters All/Unread/Requests/Updates with counts, day groups (Today, Yesterday, date), filtered empty state, and clear-search recovery.",
            "Swipe an unread row to mark it read; Clear read confirms and calls a server RPC that deletes only the caller's read rows (unread rows stay).",
            "Failure signalling for clear/mute/unread now reports errors instead of false success.",
            "Saved filters per screen: chat role/status and request incoming/sent filters persist, restore on open, and clear actions reset them.",
        ],
        [
            "lib/screen/notifications_page.dart",
            "lib/screen/chats_page.dart",
            "lib/widgets/chat_mute_sheet.dart",
            "lib/services/preferences_service.dart",
            "supabase/migrations/20261105000400_clear_read_notifications.sql",
        ],
        "141 tests; live Activity filters/groups/clear confirm and chat long-press; three subagent audits PASS at af0f3c4.",
    ),
    (
        "B3", "Contextual Polish", "VERIFIED",
        "2491fc3, 8110b51, 3e11df1, 12afa6e, 26d38a0, 708316e, bb54994",
        "Surface the right next step without nagging or dead ends.",
        [
            "Continue-setup card appears only when setup is incomplete and onboarding was skipped or a draft exists; Resume restores the review step; dismiss persists per user; it reappears after skipping again.",
            "Profile completion nudge after a successful request uses the app banner (non-blocking, SafeArea, queued, closable, 10s) and shows at most once per session; the request is already committed.",
            "Empty states now each have one clear action: start swiping, view sent requests/refresh, view requests/show all, update skills/refresh categories.",
            "Profile shows only one completion prompt at a time; chats filtered empty has a clear action; Requests never traps the tab in sent view.",
        ],
        [
            "lib/widgets/resume_setup_card.dart",
            "lib/screen/profile_page.dart",
            "lib/screen/home_page.dart",
            "lib/screen/chats_page.dart",
            "lib/screen/request_page.dart",
            "lib/screen/explore_page.dart",
        ],
        "145 tests; 360/200% card coverage; live nudge banner and dismissal; three subagent audits PASS at bb54994.",
    ),
    (
        "C0", "Privacy Contracts", "VERIFIED",
        "a79ed63, 5c1a4fd, 4aaaa02, 4021a43, 3fa4a45",
        "Define what status data exists and who may see it before adding presence/typing/receipts.",
        [
            "Profiles gained last_seen_at, presence_enabled, typing_enabled, read_receipts_enabled; no direct client column grants.",
            "Added touch_last_seen (self-only, only when presence enabled), set/get_chat_privacy, and get_pals_presence (accepted Pals only, last_seen masked when off).",
            "get_conversations exposes peer presence/typing/receipts/read fields, masked to accepted connections; read timestamps are hidden when receipts are off.",
            "Revoked table SELECT on connections and granted only non-receipt columns, closing the direct-read bypass for read timestamps.",
            "Chat privacy page with three switches and 'Pals only'; switches are disabled until server state loads, load failures show Retry, loads coalesce, and reset is generation-safe.",
        ],
        [
            "supabase/migrations/20261105000500_chat_privacy.sql",
            "supabase/migrations/20261105000600_privacy_status_masking.sql",
            "supabase/migrations/20261105000700_lock_connection_reads.sql",
            "lib/services/chat_privacy_service.dart",
            "lib/screen/settings/chat_privacy_page.dart",
        ],
        "149 tests; live ACL and masking probes; 360/200% page test; three subagent audits PASS at 3fa4a45.",
    ),
    (
        "C1", "Presence", "VERIFIED",
        "69bec41, c8bb845, 38949d7, b876970, 487b85a, 5829b91, 27f4784",
        "Show whether a Pal is online without leaking status or keeping stale state.",
        [
            "60s foreground heartbeat + conversation refresh while resumed; heartbeat is disabled when privacy is unloaded or presence is off; stops on pause/sign-out.",
            "Chat list shows a green Online or muted Active Nm/h/d only when the peer allows presence; message time remains visible.",
            "Chat room subscribes to chat:<connectionId> presence, tracks only with presence enabled, filters the peer by exact user id, and removes channels on leave/privacy-off/error without re-entrant teardown.",
            "Privacy toggle off stops broadcast and hides status; re-enabling retracks; typing-only mode still joins the channel.",
        ],
        [
            "lib/services/chat_state_service.dart",
            "lib/screen/chats_room.dart",
            "lib/screen/chats_page.dart",
            "lib/utils/presence_label.dart",
        ],
        "150 tests; live Online in list and room; three subagent audits PASS at 5829b91.",
    ),
    (
        "C2", "Typing Indicators", "VERIFIED",
        "354ff68, 8da9b57, 5bb26dc",
        "Show that a peer is composing without database writes or leaking to non-members.",
        [
            "Typing broadcasts on the existing chat channel; about 2s throttle, 3s peer expiry, stop on empty/send/leave; no DB writes.",
            "Typing indicator under the peer name: three animated dots, static fallback when animations are disabled, live-region label.",
            "Gated by the local typing setting and the peer's typing flag; works with presence off (channel joins, no presence track).",
            "Typing-only channels recover after errors; typing appears before the first message; the pre-first-message match card stays while typing.",
        ],
        [
            "lib/widgets/typing_indicator.dart",
            "lib/screen/chats_room.dart",
        ],
        "152 tests; typing payload and 200%/reduced-motion tests; three subagent audits PASS at 5bb26dc.",
    ),
    (
        "C3", "Read Receipts", "VERIFIED",
        "879e593, 3f468e5, 98e3b59",
        "Show Seen only when the peer has actually read and allows receipts.",
        [
            "Conversation contract carries other_read_at and other_read_receipts_enabled; unread counts unchanged; dead is_read handling removed.",
            "Seen renders only under the last own message, only when the peer's read timestamp covers it and the peer allows receipts.",
            "Live receipts use a throttled read broadcast on the chat channel (trailing flush), then reload the server timestamp; displayed time is server-authoritative, avoiding device-clock skew.",
            "Read broadcasts are paused while backgrounded, peer-scoped on receive, and do not echo; 60s refresh reconciles offline peers.",
        ],
        [
            "lib/screen/chats_room.dart",
            "lib/services/chat_state_service.dart",
        ],
        "154 tests; live Seen screenshot; three subagent audits PASS at 98e3b59.",
    ),
    (
        "D-01", "What's New", "VERIFIED",
        "08de0e8",
        "Tell returning users what changed once per version.",
        [
            "Version-gated bottom sheet with three bullets, 'Got it', scrollable at 360/200%, dismiss persists per version.",
        ],
        ["lib/widgets/whats_new_sheet.dart", "lib/screen/navigation_bar.dart"],
        "155 tests; live once-per-version probe (shown, dismissed, absent after reload).",
    ),
    (
        "D-02", "Review Prompt", "DEFERRED",
        "none",
        "Ask for a store review after a positive exchange with a frequency cap.",
        [
            "Deferred: no published store listing exists, so a prompt would either be fake or lead to a dead link.",
            "When a listing exists, gate on a positive feedback/exchange, once per version, and never over a dialog.",
        ],
        ["No code shipped"],
        "Deferred pending store listing/product decision.",
    ),
]

migrations = [
    ("001", "20261105000100_notifications_realtime.sql", "Notifications realtime",
     "Adds public.notifications to supabase_realtime (guarded) and grants SELECT to authenticated; row visibility stays scoped by notif_read (user_id = auth.uid())."),
    ("002", "20261105000200_notification_context.sql", "Activity context",
     "Recreates list_notifications with actor name/avatar, skill, role, and connection status joins while keeping payload as the source of ids."),
    ("003", "20261105000300_connection_preferences.sql", "Chat mute + manual unread",
     "Adds connection_preferences (user_id, connection_id, muted_until, marked_unread), SELECT-only RLS, set_connection_mute, set_connection_unread, get_connection_preferences, and appends muted/marked fields to get_conversations."),
    ("004", "20261105000400_clear_read_notifications.sql", "Clear read Activity",
     "Adds clear_read_notifications(), a SECURITY DEFINER delete limited to user_id = auth.uid() and read_at is not null."),
    ("005", "20261105000500_chat_privacy.sql", "Privacy contracts",
     "Adds last_seen_at and three privacy flags to profiles; adds touch_last_seen, set/get_chat_privacy, get_pals_presence; appends peer presence/typing/receipts/read fields to get_conversations. Realtime topic ACL cannot be installed from the management role (see limitations)."),
    ("006", "20261105000600_privacy_status_masking.sql", "Status masking",
     "Recreates get_conversations so presence/typing/receipt flags and last_seen/read timestamps are returned only for accepted connections, and read_at is null when receipts are off."),
    ("007", "20261105000700_lock_connection_reads.sql", "RPC-only read timestamps",
     "Revokes table SELECT on connections from anon/authenticated and grants only id, requester_id, recipient_id, status, created_at, responded_at, skill_name, skill_path; read timestamps are reachable only through RPCs."),
]

services = [
    ("NotificationService", "Typed notification state, realtime channel, dedupe, unread list/count, mark read, lifecycle, sign-out reset."),
    ("NotificationPresenter", "Chooses banner kind, applies category/quiet/preview/privacy gates, plays match/message feedback, suppresses the active screen."),
    ("LocalNotificationService", "System notifications, Android channels (four sound/vibration combinations per category), permission state/request, tap and cold-start routing."),
    ("AppBadgeService", "Launcher badge from activity + chat unread, preference gate, serialized writes, web no-op, sign-out reset."),
    ("ConnectivityService", "Online state, offline strip source, reconnect refresh for notifications and conversations."),
    ("DraftService", "Per-conversation drafts, debounce, restore, clear on send/sign-out."),
    ("ChatPrivacyService", "Server-backed presence/typing/receipt switches, coalesced load, optimistic save with revert, reset on sign-out."),
    ("Haptics", "Named intents, throttle, platform and preference gates, match pattern."),
    ("SoundService", "Shared player over messages/newmatch/splash assets, preference/lifecycle gates, debounce, serialized init."),
    ("AppShellState", "Selected tab, Activity/Requests open flags for route-aware suppression."),
    ("AppRouter / navigatorKey", "Queue-safe routing from services and cold starts."),
]

screens = [
    ("Activity", "Typed list, filters All/Unread/Requests/Updates with counts, day groups, swipe-to-read, clear-read, realtime updates."),
    ("Chats", "Pull-to-refresh, presence, mute icon, manual unread dot, draft preview, long-press actions, clear search/filters."),
    ("Chat room", "Banners/suppression, draft composer, scroll FAB with count, copy, search, unread divider, mute/mark unread, presence, typing, Seen."),
    ("Notifications settings", "Delivery, permission, categories, previews, sound/vibration previews, quiet hours, master gating."),
    ("Chat privacy", "Online status, typing, read receipts, Pals-only, load/error gating."),
    ("Profile", "One completion prompt at a time, resume setup, scoped dismissal."),
    ("Requests", "Pull-to-refresh, saved filters, clear actions, no tab dead ends, backable sent view."),
    ("Browse", "Pull-to-refresh, mentor/learner role, empty refresh action."),
]

test_areas = [
    ("Notification model/realtime", "app_notification_test.dart", "Parsing, unknown kinds, payload fallbacks, read state, presenter adapter."),
    ("Banners", "app_banner_test.dart", "Queue, action, dismiss, match preempt, message coalesce, 360/200%, dark surface."),
    ("Haptics/sound", "haptics_test.dart, sound_service_test.dart", "Intent mapping, preference gate, throttle, real asset presence, volumes."),
    ("Preferences", "notification_preferences_test.dart", "Defaults, persistence, quiet-hours windows, category gating, preview privacy, 360/200%."),
    ("Local notifications", "local_notification_payload_test.dart", "Deterministic ids, channel matrix, permission state, routing payloads."),
    ("Feedback/errors", "app_feedback_test.dart, friendly_error_test.dart", "One-at-a-time snackbars, undo, technical leakage, validation preservation."),
    ("QOL services", "qol_services_test.dart, draft_service_test.dart, offline_banner_test.dart", "Badge math, connectivity transitions, draft reload/clear, offline strip semantics/app-bar taps."),
    ("Chat QOL", "chat_qol_test.dart, chat_widgets_test.dart", "Mute window, manual unread, divider index, search sheet lifecycle, menu 200%, presence/time row, typing payloads/indicator, Seen gating."),
    ("Privacy", "chat_privacy_test.dart", "Presence labels/window, page render 200%, load-failure gate, keys."),
    ("Polish", "b3_polish_test.dart, whats_new_test.dart", "Resume gate/keys, scoped dismissal, card 360/200%, what's new bullets 360/200%."),
]

probes = [
    "Notification insert → top banner (light/dark), request accepted → match banner, message insert → message banner.",
    "Mute sheet → muted list icon; mark unread → list dot → open clears it; draft typed → 'Draft:' preview after back.",
    "Unread divider visible before unread rows; scroll-up + peer insert → FAB count; long-press copy → clipboard + snackbar; search → highlight/jump.",
    "Activity filters/counts/day groups; clear-read confirmation; chat long-press action sheet.",
    "Offline strip above the app bar; reconnect restores content; profile nudge banner; one-time what's new.",
    "Presence: peer last_seen set → Online in list and room; own last_seen advanced after app load.",
    "Read receipts: Seen under the last own message.",
]

limitations = [
    ("A5 push", "Blocked on Firebase project/config, APNs key, web VAPID, and a service account. Killed-app alerts and guaranteed iOS background delivery are unavailable. In-app, Activity, badges, foreground banners, local notifications while alive, and server reconciliation remain."),
    ("Realtime topic ACL", "The management role cannot alter realtime.messages (owned by supabase_realtime_admin). chat:<connectionId> topics rely on unguessable UUIDs and client-side privacy gating. Add a dashboard-authored policy if server-side ACLs are required."),
    ("Read-receipt transport", "C3 uses a read broadcast + 60s conversation refresh instead of publishing connections, because C0 made connection read timestamps RPC-only to honor the receipt toggle."),
    ("iOS build", "Source/config verified but not compiled on this Windows host. A macOS build and device pass are still required."),
    ("D-02 review prompt", "Deferred until a store listing exists."),
    ("Background receipts", "A read event can arrive before mark_messages_read commits; server refresh reconciles within the next poll."),
]

credentials = [
    ("Firebase project", "Android, iOS, web apps registered to the release application id."),
    ("android/app/google-services.json", "Android Firebase identity."),
    ("ios/Runner/GoogleService-Info.plist", "iOS Firebase identity."),
    ("APNs .p8 + Key ID + Team ID", "Apple push authorization."),
    ("Web VAPID public key", "Browser push subscription identity."),
    ("Firebase service account JSON", "Edge function authentication to FCM HTTP v1."),
]

commit_phase = {}
phase_commit_map = {
    "A0": ["8e0f5f3", "5aed01e"],
    "A1": ["45cf7e7", "be90c0d", "de4046e", "c480fa7", "06f10d8"],
    "A2": ["b96c571", "4de648a"],
    "A3": ["75b1ff8", "72fe744", "f89f540"],
    "A4": ["dc5c03c", "a2c3fc6", "ed9c0ed"],
    "A6": ["8d8f9e6", "445c4c9", "5b97786", "da7ff16"],
    "B0": ["cb7b96a", "27c3355", "9df1965"],
    "B1": ["a24048f", "4b18f8a", "fdd641b"],
    "B2": ["a25dacd", "b8419ca", "af0f3c4"],
    "B3": ["2491fc3", "8110b51", "3e11df1", "12afa6e", "26d38a0", "708316e", "bb54994"],
    "C0": ["a79ed63", "5c1a4fd", "4aaaa02", "4021a43", "3fa4a45"],
    "C1": ["69bec41", "c8bb845", "38949d7", "b876970", "487b85a", "5829b91", "27f4784"],
    "C2": ["354ff68", "8da9b57", "5bb26dc"],
    "C3": ["879e593", "3f468e5", "98e3b59"],
    "D": ["08de0e8"],
}
for phase, hashes in phase_commit_map.items():
    for h in hashes:
        commit_phase[h] = phase

audits = [
    ("A0", "2026-11-04", "ses_e592a7f30ffeq8fUwgk2ANDfUM", "ses_e592a7f2effeLn8rVWs2rrQPbq", "ses_e592a7f2cffe8GfwwpD640Klre", "5aed01e"),
    ("A1", "2026-11-04", "ses_e5901577affeq2wa4Giny1Zc2G", "ses_e59015779ffeOb8RHyB6BUeNZe", "ses_e59015777ffeEdT9T7s7tkrkxz", "06f10d8"),
    ("A2", "2026-11-04", "ses_e58dab2d7ffeux946Z2eIEhyzD", "ses_e58dab2d5ffezFyNm7D75VvxET", "ses_e58dab2d3ffeV5XsamgW1U0F5L", "4de648a"),
    ("A3", "2026-11-05", "ses_e58c5095fffegIgQeovEXrHzdE", "ses_e58c5095effeUezhvpt8d7r2sM", "ses_e58c5095cffegDv70umgaruv8T", "f89f540"),
    ("A4", "2026-11-05", "ses_e58adc0d1ffeVWtFpai92ukhG8", "ses_e58adc0ceffedzJvP1urIo5eUn", "ses_e58adc0caffe3Ux8H0s31HmBs0", "ed9c0ed"),
    ("A6", "2026-11-05", "ses_e588dbc5affeGDZTXb8Pmwvtnw", "ses_e588dbc48ffeXisBr5i8JIysPv", "ses_e588dbc45ffesfpI7VGMo097lk", "5b97786"),
    ("B0", "2026-11-05", "ses_e5843f5e2ffefz7EXGxqIi7bLv", "ses_e5836b58bffeKweLZoQIitxgHT", "ses_e58300b0bffeTYwA6tCsWyiY2M", "9df1965"),
    ("B1", "2026-11-05", "ses_e58162853ffeY6eXrwW9epCzOH", "ses_e58102699ffe7qOQlEUSgH3ZZD", "ses_e58000898ffe0vOEXUSh9pzpQy", "fdd641b"),
    ("B2", "2026-11-05", "ses_e57ef735fffeE9Nt6jlx4U5ATu", "ses_e57e2ef40ffeWacaCAK9NOF8US", "ses_e57d3680bffeb5fsW9dx9hHZ45", "af0f3c4"),
    ("B3", "2026-11-05", "ses_e57c785d2ffe2ZSlK7cqlhTQff", "ses_e57bc1a33ffefghRV09XmL0825", "ses_e57920c5bffeSS8Rni62EB084P", "bb54994"),
    ("C0", "2026-11-05", "ses_e577e7e0bffeGsh00O8TG4Aap5", "ses_e5771c409ffeX81Tj3KRgUxjeZ", "ses_e575d14d5ffeer0oF029QXVh3t", "3fa4a45"),
    ("C1", "2026-11-05", "ses_e56cb7616ffekYx0WUloT2M0zV", "ses_e56bd7611ffeNnX2Oe0ucXYyKl", "ses_e56a791a8ffesn8nk0lS0zWOFT", "5829b91"),
    ("C2", "2026-11-05", "ses_e5699eeebffef3BcJw4yGqjhig", "ses_e56930aa7ffe3BEpK6pz3eqfd4", "ses_e568a4196ffeROc75CIa5nBffl", "5bb26dc"),
    ("C3", "2026-11-05", "ses_e567e3b64ffe16SQgNbF6cUg0W", "ses_e56783fa9ffeX0OJ37fR5RdQMt", "ses_e56698147ffezN0ys13sCwpNYN", "98e3b59"),
]

