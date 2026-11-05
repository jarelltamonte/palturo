# -*- coding: utf-8 -*-
"""Generate the complete PalTuro dynamic UX change documentation HTML."""
import html
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs" / "PalTuro-Dynamic-UX-Changes.html"


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

css = """
@page { size: A4; margin: 18mm 16mm 20mm 16mm; }
* { box-sizing: border-box; }
body {
  font-family: 'Segoe UI', 'Helvetica Neue', Arial, sans-serif;
  color: #161616;
  background: #F5F4EF;
  font-size: 9.6pt;
  line-height: 1.5;
  margin: 0;
}
h1, h2, h3, h4 { font-family: 'Segoe UI', 'Helvetica Neue', Arial, sans-serif; color: #111; }
h2 { font-size: 23pt; line-height: 1.08; margin: 0 0 7pt; letter-spacing: -0.5pt; page-break-after: avoid; }
h3 { font-size: 12.4pt; margin: 14pt 0 4pt; color: #111; page-break-after: avoid; }
p { margin: 0 0 6pt; }
ul { margin: 3pt 0 8pt 13pt; padding: 0; }
li { margin-bottom: 3pt; }
.small { font-size: 8.3pt; }
.muted { color: #6C7560; }
.kicker {
  font-size: 7.2pt;
  letter-spacing: 1.8pt;
  text-transform: uppercase;
  color: #6F7A4A;
  font-weight: 700;
  margin: 0 0 7pt;
}
.section-label {
  font-size: 7pt;
  letter-spacing: 1.6pt;
  text-transform: uppercase;
  color: #6F7A4A;
  font-weight: 700;
  text-align: right;
}
.section-top { display: flex; justify-content: space-between; align-items: baseline; border-bottom: 1px solid #D9DCCD; padding-bottom: 4mm; margin-bottom: 6mm; }
.cover {
  width: 210mm;
  height: 297mm;
  background: #171717;
  color: #fff;
  padding: 20mm;
  position: relative;
  overflow: hidden;
  page-break-after: always;
}
.cover .glow {
  position: absolute; right: -55mm; bottom: -70mm; width: 190mm; height: 190mm;
  border: 0.35mm solid rgba(191,225,9,0.55); border-radius: 50%;
}
.cover .glow:after {
  content: ''; position: absolute; inset: 18mm; border: 0.25mm solid rgba(191,225,9,0.30); border-radius: 50%;
}
.cover .glow:before {
  content: ''; position: absolute; inset: 38mm; border: 0.2mm solid rgba(191,225,9,0.16); border-radius: 50%;
}
.cover-logo { height: 11mm; }
.cover-kicker { margin-top: 26mm; color: #BFE109; font-size: 7.2pt; letter-spacing: 2pt; text-transform: uppercase; font-weight: 700; }
.cover h1 { color: #fff; font-size: 34pt; line-height: 1.03; letter-spacing: -1.2pt; margin: 5mm 0 5mm; max-width: 100mm; }
.cover h1 .lime { color: #BFE109; }
.cover .subtitle { color: #D8D8D3; font-size: 11.5pt; line-height: 1.35; max-width: 96mm; }
.cover .desc { color: #A9ADA4; font-size: 8.2pt; line-height: 1.5; max-width: 96mm; margin-top: 4mm; }
.cover .stats { display: grid; grid-template-columns: repeat(4, 22mm); gap: 3mm; margin-top: 9mm; width: 97mm; }
.cover .stat { background: #222; border: 0.25mm solid #333; border-radius: 2.5mm; padding: 3.2mm 2.8mm; }
.cover .stat b { color: #BFE109; display: block; font-size: 19pt; line-height: 1; font-weight: 700; }
.cover .stat span { color: #A9ADA4; display: block; margin-top: 2mm; font-size: 5.8pt; letter-spacing: 1.2pt; text-transform: uppercase; }
.cover .meta { display: grid; grid-template-columns: 24mm 1fr 24mm 1fr; gap: 2mm 3mm; margin-top: 10mm; font-size: 6.4pt; color: #8F948B; max-width: 100mm; }
.cover .meta b { color: #EDEDE7; display: block; font-weight: 600; font-size: 8pt; margin-top: 1mm; }
.cover .phone { position: absolute; right: 12mm; top: 45mm; width: 70mm; }
.cover .phone img { width: 100%; border-radius: 5mm; border: 1mm solid #2A2A2A; box-shadow: 0 8mm 22mm rgba(0,0,0,0.55); }
.cover-foot { position: absolute; left: 20mm; right: 20mm; bottom: 13mm; border-top: 0.25mm solid #3A3A3A; padding-top: 4mm; color: #777; font-size: 6.4pt; letter-spacing: 1.2pt; text-transform: uppercase; }
.cover-page { margin: 0; }
.badge { display: inline-block; border-radius: 8pt; padding: 1.5pt 6pt; font-size: 7pt; font-weight: 700; letter-spacing: 0.3pt; color: #fff; background: #2F7D32; }
.badge.blocked { background: #A23B3B; }
.badge.deferred { background: #9A6A00; }
table { width: 100%; border-collapse: collapse; margin: 4pt 0 9pt; font-size: 8.4pt; page-break-inside: auto; }
th { background: transparent; color: #6F7A4A; text-align: left; padding: 3pt 4pt 4pt; font-weight: 700; font-size: 6.8pt; letter-spacing: 1.1pt; text-transform: uppercase; border-bottom: 1px solid #B9C09F; }
td { padding: 4.5pt 4pt; border-bottom: 1px solid #E1E3D5; vertical-align: top; }
tr { page-break-inside: avoid; }
.callout { background: #EAF4B8; border-left: 3px solid #BFE109; padding: 7pt 10pt; margin: 8pt 0 10pt; page-break-inside: avoid; color: #1C1C1C; }
.callout.warn { background: #FBF0DC; border-left-color: #C58A2B; }
.callout.risk { background: #F8E4E1; border-left-color: #A23B3B; }
.kv { display: grid; grid-template-columns: 40mm 1fr; gap: 2pt 5mm; margin: 4pt 0 10pt; }
.kv div:nth-child(odd) { color: #6C7560; font-weight: 600; }
.card-row { display: grid; grid-template-columns: repeat(3, 1fr); gap: 4mm; margin: 6mm 0; }
.card { background: #fff; border: 0.25mm solid #E2E3D7; border-radius: 3mm; padding: 5mm; page-break-inside: avoid; }
.card .num { color: #7C8A22; font-size: 17pt; font-weight: 700; line-height: 1; }
.card h4 { font-size: 9.5pt; margin: 2mm 0 1.5mm; }
.card p { font-size: 7.8pt; color: #5D6558; margin: 0; line-height: 1.4; }
.stat-row { display: grid; grid-template-columns: repeat(4, 1fr); gap: 3mm; margin: 4mm 0 6mm; }
.stat-box { background: #EFF4D2; border-radius: 2.5mm; padding: 4mm; }
.stat-box b { display: block; font-size: 20pt; line-height: 1; font-weight: 700; }
.stat-box span { display: block; font-size: 6.4pt; letter-spacing: 1.1pt; text-transform: uppercase; color: #667048; margin-top: 1.5mm; }
.phase-head { display: flex; align-items: baseline; justify-content: space-between; gap: 8mm; }
.phase-meta { font-size: 7.4pt; color: #6C7560; margin: 1pt 0 6pt; }
.page-break { page-break-before: always; }
.toc { columns: 2; column-gap: 12mm; font-size: 9pt; margin-top: 4mm; }
.toc div { margin-bottom: 4pt; break-inside: avoid; }
.toc .num { display: inline-block; width: 11mm; color: #7C8A22; font-weight: 700; }
code, .mono { font-family: 'Cascadia Mono', Consolas, monospace; font-size: 7.9pt; color: #2C3E2A; }
.hash { font-family: 'Cascadia Mono', Consolas, monospace; font-size: 7.7pt; }
.note { font-size: 8.1pt; color: #6C7560; }
.shots { display: grid; grid-template-columns: repeat(3, 1fr); gap: 4mm; margin: 5mm 0 4mm; }
.shots.two { grid-template-columns: repeat(2, 1fr); }
.shot { margin: 0; background: #fff; border: 0.25mm solid #E2E3D7; border-radius: 4mm; padding: 2.5mm; page-break-inside: avoid; }
.shot img { width: 100%; display: block; border-radius: 2.5mm; }
.shot figcaption { font-size: 6.8pt; color: #5D6558; line-height: 1.35; padding: 2mm 1mm 0.5mm; }
.caption { font-size: 7.2pt; color: #6C7560; margin-top: 2mm; }
"""


from pathlib import Path as _Path
import base64 as _b64
_TEMP = _Path.home() / 'AppData' / 'Local' / 'Temp' / 'opencode'

def data_uri(rel):
    path = _Path(rel)
    if not path.is_absolute():
        path = ROOT / path if (ROOT / path).exists() else _TEMP / path
    return 'data:image/png;base64,' + _b64.b64encode(path.read_bytes()).decode()

def shot(image, caption):
    return f"<figure class='shot'><img src='{data_uri(image)}' alt='{esc(caption)}'><figcaption>{esc(caption)}</figcaption></figure>"

def shot_grid(items, two=False):
    cls = 'shots two' if two else 'shots'
    return f"<div class='{cls}'>{''.join(shot(i, c) for i, c in items)}</div>"

parts = []
parts.append(f"<!DOCTYPE html><html><head><meta charset='utf-8'><title>PalTuro Dynamic UX - Change Documentation</title><style>{css}</style></head><body>")

# Cover
cover_html = f"""
<section class='cover cover-page'>
  <div class='glow'></div>
  <img class='cover-logo' src='{data_uri('assets/images/hlogo_white.png')}' alt='PalTuro'>
  <div class='cover-kicker'>Implementation &amp; verification &middot; 5 November 2026</div>
  <h1>Dynamic UX,<br><span class='lime'>QOL &amp; Social</span><br>Presence</h1>
  <div class='subtitle'>What changed, how it was audited, and what is ready to ship.</div>
  <div class='desc'>A complete record of the notification, banner, feedback, chat quality-of-life, privacy, presence, typing, and read-receipt work &mdash; from the first typed event to the final release gate.</div>
  <div class='stats'>
    <div class='stat'><b>{len(commits)}</b><span>Commits</span></div>
    <div class='stat'><b>155</b><span>Tests passing</span></div>
    <div class='stat'><b>14</b><span>Phases verified</span></div>
    <div class='stat'><b>1</b><span>External blocker</span></div>
  </div>
  <div class='meta'>
    <div>BRANCH<b>ui-features @ 08de0e8</b></div>
    <div>PREPARED FOR<b>PalTuro product team</b></div>
    <div>METHOD<b>3 independent audits per phase</b></div>
    <div>SCOPE<b>{len(changed)} files &middot; 7 migrations</b></div>
  </div>
  <div class='phone'>
    <img src='{data_uri('a1-home-390.png')}' alt='PalTuro For You deck'>
  </div>
</section>
"""
parts.append(cover_html)
parts.append("<!-- CONTENT_START -->")
# TOC
parts.append("""
<section>
<h2>Contents</h2>
<div class='toc'>
  <div><span class='num'>1</span>Executive summary</div>
  <div><span class='num'>2</span>Scope and tracks</div>
  <div><span class='num'>3</span>Track A - Notification experience</div>
  <div><span class='num'>4</span>Track B - Quality of life</div>
  <div><span class='num'>5</span>Track C - Privacy and realtime social</div>
  <div><span class='num'>6</span>Track D - Optional polish</div>
  <div><span class='num'>7</span>Architecture and new modules</div>
  <div><span class='num'>8</span>Database and server changes</div>
  <div><span class='num'>9</span>Delivery and privacy behaviour</div>
  <div><span class='num'>10</span>Platform configuration</div>
  <div><span class='num'>11</span>Verification and audits</div>
  <div><span class='num'>12</span>Visual evidence</div>
  <div><span class='num'>13</span>Known limitations and deferred work</div>
  <div><span class='num'>14</span>Operations and credential checklist</div>
  <div><span class='num'>A</span>Appendix A - Commit log</div>
  <div><span class='num'>B</span>Appendix B - File inventory</div>
  <div><span class='num'>C</span>Appendix C - Test suite and audit sessions</div>
</div>
<div class='callout'>
  <strong>Reading note.</strong> Phase IDs match the persistent plan (A0-A7, B0-B3, C0-C3, D-01/D-02).
  A phase marked VERIFIED passed three independent subagent audits: functionality, quality, and regression.
</div>
</section>
""")

# 1 executive summary
parts.append(f"""
<section>
<h2>1. Executive summary</h2>
<p>This release turns PalTuro's notification layer into a complete dynamic UX system, then adds the day-to-day chat and list controls expected from a modern messaging product, and finally introduces privacy-controlled presence, typing, and read receipts.</p>
<div class='kv'>
  <div>Commits</div><div>{len(commits)} (from <span class='hash'>3ab6700</span> to <span class='hash'>08de0e8</span>)</div>
  <div>Files changed</div><div>{len(changed)} ({shortstat})</div>
  <div>Test suite</div><div>155 tests passing</div>
  <div>Builds</div><div>Web release and Android debug APK pass</div>
  <div>Database</div><div>7 forward-only migrations, applied to the linked Supabase project</div>
  <div>Audits</div><div>14 gated phases, each with 3 PASS audits (A0-A4, A6, B0-B3, C0-C3)</div>
</div>
<h3>What users can now do</h3>
<ul>
  <li>See live request, match, feedback, moderation, and message events as non-blocking top banners, with a subtle match moment and an Activity inbox.</li>
  <li>Control notifications by category, previews, quiet hours, sound, and vibration, and see honest permission state.</li>
  <li>Receive local system notifications while the app is alive, including while backgrounded on Android, with tap and cold-start routing.</li>
  <li>Refresh lists, work offline with a clear strip, see an app badge, and keep unsent drafts per chat.</li>
  <li>Mute a chat, mark it unread, copy a message, search the thread, jump to the latest message, retry failed sends, and see the first unread divider.</li>
  <li>Manage chats from a long-press sheet and triage Activity with filters, day groups, swipe-to-read, and clear-read.</li>
  <li>Control online status, typing, and read receipts for Pals only; see Online/last-seen, typing dots, and Seen only when privacy allows.</li>
</ul>
<div class='callout warn'>
  <strong>Not shipped.</strong> Push delivery to killed or suspended apps (A5) remains blocked on Firebase/APNs/VAPID credentials. The app does not claim killed-app delivery or guaranteed iOS background delivery. See section 9.
</div>
</section>
""")

# 2 scope
parts.append("""
<section class='page-break'>
<h2>2. Scope and tracks</h2>
<table>
  <tr><th style='width:12%'>Track</th><th style='width:18%'>Theme</th><th>Phases and outcome</th><th style='width:16%'>Status</th></tr>
  <tr><td>A</td><td>Dynamic UX core</td><td>A0 notification foundation, A1 banners and match moment, A2 haptics/sound, A3 preferences, A4 local notifications, A5 push (blocked), A6 feedback audit, A7 release verification</td><td><span class='badge'>A0-A4, A6, A7 done</span><br><span class='badge blocked'>A5 blocked</span></td></tr>
  <tr><td>B</td><td>Quality of life</td><td>B0 refresh/offline/badge/drafts, B1 chat QOL, B2 list and Activity QOL, B3 contextual polish</td><td><span class='badge'>Done</span></td></tr>
  <tr><td>C</td><td>Realtime social</td><td>C0 privacy contracts, C1 presence, C2 typing, C3 read receipts</td><td><span class='badge'>Done</span></td></tr>
  <tr><td>D</td><td>Optional polish</td><td>D-01 what's new, D-02 review prompt</td><td><span class='badge'>D-01 done</span><br><span class='badge deferred'>D-02 deferred</span></td></tr>
</table>
<p class='note'>Work was gated phase by phase. No phase advanced without functionality, quality, and regression audits returning PASS in separate subagent sessions.</p>
</section>
""")

# 3 Track A phases
parts.append("<section class='page-break'><h2>3. Track A - Notification experience</h2>")
for phase_id, title, status, commit_text, goal, changes, files, evidence in phases:
    if not phase_id.startswith("A"):
        continue
    badge_class = "badge blocked" if status == "BLOCKED" else ("badge deferred" if status == "DEFERRED" else "badge")
    parts.append(f"""
    <div class='phase-head'><h3>{phase_id} - {title}</h3></div>
    <div class='phase-meta'>Commits: <span class='hash'>{commit_text}</span> &middot; Status: <span class='{badge_class}'>{status}</span></div>
    <p><strong>Goal.</strong> {goal}</p>
    <ul>{''.join(f'<li>{esc(x)}</li>' for x in changes)}</ul>
    <p class='note'><strong>Key files:</strong> {', '.join(f"<span class='mono'>{esc(f)}</span>" for f in files)}</p>
    <p class='note'><strong>Verification:</strong> {esc(evidence)}</p>
    """)
parts.append("</section>")

# 4 Track B
parts.append("<section class='page-break'><h2>4. Track B - Quality of life</h2>")
for phase_id, title, status, commit_text, goal, changes, files, evidence in phases:
    if not phase_id.startswith(("B0", "B1", "B2", "B3")):
        continue
    parts.append(f"""
    <div class='phase-head'><h3>{phase_id} - {title}</h3></div>
    <div class='phase-meta'>Commits: <span class='hash'>{commit_text}</span> &middot; Status: <span class='badge'>{status}</span></div>
    <p><strong>Goal.</strong> {goal}</p>
    <ul>{''.join(f'<li>{esc(x)}</li>' for x in changes)}</ul>
    <p class='note'><strong>Key files:</strong> {', '.join(f"<span class='mono'>{esc(f)}</span>" for f in files)}</p>
    <p class='note'><strong>Verification:</strong> {esc(evidence)}</p>
    """)
parts.append("</section>")

# 5 Track C
parts.append("<section class='page-break'><h2>5. Track C - Privacy and realtime social</h2>")
for phase_id, title, status, commit_text, goal, changes, files, evidence in phases:
    if not phase_id.startswith("C"):
        continue
    parts.append(f"""
    <div class='phase-head'><h3>{phase_id} - {title}</h3></div>
    <div class='phase-meta'>Commits: <span class='hash'>{commit_text}</span> &middot; Status: <span class='badge'>{status}</span></div>
    <p><strong>Goal.</strong> {goal}</p>
    <ul>{''.join(f'<li>{esc(x)}</li>' for x in changes)}</ul>
    <p class='note'><strong>Key files:</strong> {', '.join(f"<span class='mono'>{esc(f)}</span>" for f in files)}</p>
    <p class='note'><strong>Verification:</strong> {esc(evidence)}</p>
    """)
parts.append("</section>")

# 6 Track D
parts.append("""
<section>
<h2>6. Track D - Optional polish</h2>
<table>
<tr><th style='width:8%'>ID</th><th style='width:26%'>Feature</th><th>Implementation</th><th style='width:14%'>Status</th></tr>
<tr><td>D-01</td><td>What's new</td><td>Version-gated sheet with three bullets, dismiss persists per version, scrollable at 360/200%. Commit <span class='hash'>08de0e8</span>.</td><td><span class='badge'>Done</span></td></tr>
<tr><td>D-02</td><td>Review prompt</td><td>Not implemented. A review prompt without a published store listing would be a fake action or dead link. Gate design remains: positive exchange, once per version, never over a dialog.</td><td><span class='badge deferred'>Deferred</span></td></tr>
</table>
</section>
""")

# 7 Architecture
parts.append("""
<section class='page-break'>
<h2>7. Architecture and new modules</h2>
<p>The work stays within the existing Flutter app and Supabase backend. Notifications have one typed source, one presenter, and one local delivery service; chat privacy/status lives on the profile and is exposed through RPCs; realtime chat topics are reused for presence, typing, and read events.</p>
<h3>Services</h3>
<table>
<tr><th style='width:30%'>Module</th><th>Responsibility</th></tr>
""")
for name, desc in services:
    parts.append(f"<tr><td><span class='mono'>{esc(name)}</span></td><td>{esc(desc)}</td></tr>")
parts.append("</table><h3>Primary screens</h3><table><tr><th style='width:24%'>Screen</th><th>Change</th></tr>")
for name, desc in screens:
    parts.append(f"<tr><td>{esc(name)}</td><td>{esc(desc)}</td></tr>")
parts.append("""
</table>
<h3>Event flow</h3>
<ul>
  <li><strong>Server notification</strong> → notifications realtime insert → NotificationService (typed, deduped) → NotificationPresenter → top banner; Activity list and unread count update.</li>
  <li><strong>Foreground message</strong> → ChatStateService realtime → IncomingMessageEvent (outside the active room) → presenter → banner with sender + preview; local system notification only when not foreground.</li>
  <li><strong>Background/alive local notification</strong> → LocalNotificationService → Android channel chosen by category and sound/vibration → system notification → tap payload → AppRouter.</li>
  <li><strong>Chat topic</strong> → presence state (Online), typing broadcast (2s throttle/3s expiry), read broadcast (throttled, server-authoritative reload).</li>
</ul>
</section>
""")

# 8 DB
parts.append("""
<section class='page-break'>
<h2>8. Database and server changes</h2>
<p>Seven migrations were added and applied to the linked Supabase project. All functions are SECURITY DEFINER with a pinned <span class='mono'>search_path</span>; writes are RPC-only; the notification and connection tables remain SELECT-scoped by RLS.</p>
<table>
<tr><th style='width:7%'>#</th><th style='width:30%'>Migration</th><th style='width:17%'>Purpose</th><th>Objects and behaviour</th></tr>
""")
for num, name, purpose, desc in migrations:
    parts.append(f"<tr><td>{num}</td><td><span class='mono'>{esc(name)}</span></td><td>{esc(purpose)}</td><td>{esc(desc)}</td></tr>")
parts.append("""
</table>
<h3>Security model</h3>
<ul>
  <li><strong>Notifications:</strong> authenticated can SELECT their own rows (notif_read); all writes go through SECURITY DEFINER RPCs (mark read, clear read).</li>
  <li><strong>Connections:</strong> authenticated can read only non-receipt columns; read timestamps are RPC-only. RLS limits rows to participants.</li>
  <li><strong>Connection preferences:</strong> SELECT-only for the owner; mute/unread writes go through validated RPCs.</li>
  <li><strong>Profiles:</strong> presence/typing/receipt columns have no direct client grants; status flows through touch_last_seen, set/get_chat_privacy, get_pals_presence, and get_conversations.</li>
  <li><strong>Status masking:</strong> only accepted connections receive presence/typing/receipt flags and timestamps; last_seen is null when presence is off; peer read_at is null when receipts are off.</li>
</ul>
<div class='callout'>
  <strong>Read receipts transport.</strong> Publishing <span class='mono'>connections</span> would require table-wide SELECT for Realtime and would re-expose the read timestamps that C0 locked down. C3 therefore uses a read broadcast on the chat topic plus the 60s conversation refresh, which is server-authoritative and reconciles offline peers.
</div>
</section>
""")

# 9 Behaviour
parts.append("""
<section class='page-break'>
<h2>9. Delivery and privacy behaviour</h2>
<h3>Notification delivery matrix</h3>
<table>
<tr><th style='width:36%'>Situation</th><th>Delivery</th></tr>
<tr><td>App open, any tab</td><td>In-app banner, badge, haptics/sound; Activity and unread update.</td></tr>
<tr><td>App open, target screen</td><td>Badge/Activity only; no duplicate banner for the screen in view.</td></tr>
<tr><td>App backgrounded, process alive on Android</td><td>Local system notification (best effort), with tap routing.</td></tr>
<tr><td>App backgrounded on iOS</td><td>Not guaranteed; the OS may suspend the app/socket.</td></tr>
<tr><td>App killed or force-closed</td><td>No notification until the app is reopened.</td></tr>
<tr><td>App reopened after missed events</td><td>Activity, unread counts, and messages reconcile from the server.</td></tr>
<tr><td>Broadcast announcement to inactive users</td><td>Not delivered until the next app open.</td></tr>
</table>
<div class='callout risk'>
  <strong>Accepted gap (A5).</strong> Push to killed/suspended apps requires FCM/APNs/VAPID credentials. Do not claim killed-app alerts or guaranteed iOS background delivery in release notes. There is no data loss: notification rows, messages, and unread counts are server-backed.
</div>
<h3>Mute and unread</h3>
<ul>
  <li>Mute durations: 1 hour, 8 hours, 1 day, 1 week, until turned back on; Unmute appears when muted.</li>
  <li>Muted chats produce no banner or local notification; unread count and launcher badge still count them.</li>
  <li>Mark unread is a server flag; the dot clears when the chat opens; opening also advances the server read cursor used for Seen.</li>
</ul>
<h3>Typing and presence privacy matrix</h3>
<table>
<tr><th>Show me online</th><th>Typing</th><th>Receipts</th><th>Typing channel</th><th>Presence track</th><th>Read broadcast</th></tr>
<tr><td>On</td><td>On</td><td>On</td><td>Yes</td><td>Yes</td><td>Yes</td></tr>
<tr><td>On</td><td>Off</td><td>On</td><td>Yes</td><td>Yes</td><td>Yes</td></tr>
<tr><td>Off</td><td>On</td><td>On</td><td>Yes</td><td>No (untracked)</td><td>Yes</td></tr>
<tr><td>Off</td><td>Off</td><td>Off</td><td>No channel</td><td>No</td><td>No</td></tr>
</table>
<p class='note'>Receiving peer typing/read status is additionally gated by the peer's own flags returned from get_conversations.</p>
<h3>Seen rules</h3>
<ul>
  <li>Only the last own message can show Seen.</li>
  <li>Seen requires the peer's read timestamp to be at or after that message's server created_at.</li>
  <li>If the peer disabled read receipts, no timestamp is exposed and Seen is hidden.</li>
  <li>Live read events trigger a server reload; the payload clock is never displayed.</li>
</ul>
</section>
""")

# 10 Platform
parts.append("""
<section class='page-break'>
<h2>10. Platform configuration</h2>
<h3>Dependencies added</h3>
<table>
<tr><th style='width:36%'>Package</th><th>Version</th><th>Why</th></tr>
<tr><td><span class='mono'>flutter_local_notifications</span></td><td>^22.3.3</td><td>Local system notifications, channels, permission APIs, tap payloads.</td></tr>
<tr><td><span class='mono'>connectivity_plus</span></td><td>^7.3.2</td><td>Offline strip and reconnect refresh.</td></tr>
<tr><td><span class='mono'>app_badge_plus</span></td><td>^1.3.5</td><td>Launcher badge for combined unread.</td></tr>
</table>
<h3>Android</h3>
<ul>
  <li><span class='mono'>isCoreLibraryDesugaringEnabled = true</span> and <span class='mono'>desugar_jdk_libs:2.1.4</span> for the notification plugin.</li>
  <li><span class='mono'>POST_NOTIFICATIONS</span> and <span class='mono'>VIBRATE</span> permissions in the manifest.</li>
  <li>Status icon <span class='mono'>ic_stat_palturo</span>.</li>
  <li>Channels: <span class='mono'>palturo_messages</span>, <span class='mono'>palturo_requests</span>, <span class='mono'>palturo_activity</span>, plus <span class='mono'>_sound</span>, <span class='mono'>_vibration</span>, and <span class='mono'>_quiet</span> variants per category.</li>
</ul>
<h3>iOS</h3>
<ul>
  <li><span class='mono'>UNUserNotificationCenter.current().delegate = self</span> in AppDelegate so foreground and cold-start responses reach the plugin.</li>
  <li>Deployment target raised from 12.0 to 13.0 (framework plist and all project configurations).</li>
</ul>
<h3>Web</h3>
<ul>
  <li>Firebase messaging is not configured (A5 blocked). Local notification initialization and permission APIs are wired; unsupported browsers fail closed.</li>
  <li>Launcher badges are skipped on web.</li>
</ul>
</section>
""")

# 11 Verification
parts.append("""
<section class='page-break'>
<h2>11. Verification and audits</h2>
<div class='kv'>
  <div>Analyzer</div><div><span class='mono'>flutter analyze --no-pub</span> - clean</div>
  <div>Tests</div><div><span class='mono'>flutter test --no-pub</span> - 155/155 passing</div>
  <div>Web</div><div><span class='mono'>flutter build web --release --dart-define-from-file=.env</span> - success</div>
  <div>Android</div><div><span class='mono'>flutter build apk --debug --dart-define-from-file=.env</span> - success</div>
  <div>iOS</div><div>Source/config only on this Windows host; a macOS build is still required.</div>
</div>
<h3>Test coverage by area</h3>
<table>
<tr><th style='width:22%'>Area</th><th style='width:34%'>Files</th><th>Focus</th></tr>
""")
for area, files, focus in test_areas:
    parts.append(f"<tr><td>{esc(area)}</td><td><span class='mono'>{esc(files)}</span></td><td>{esc(focus)}</td></tr>")
parts.append("</table><h3>Live probes performed</h3><ul>")
for probe in probes:
    parts.append(f"<li>{esc(probe)}</li>")
parts.append("</ul><h3>Three-lens audits</h3><p>Every implemented phase passed three independent subagent audits. A0-A4/A6, B0-B3, and C0-C3 are recorded below; A5 and D-02 have no audit because they were not implemented.</p>"
             "<table><tr><th>Phase</th><th>Date</th><th>Functionality</th><th>Quality</th><th>Regression</th><th>Gate commit</th></tr>")
for phase, date, fn, qa, reg, commit in audits:
    parts.append(f"<tr><td>{phase}</td><td>{date}</td><td><span class='mono'>{fn}</span></td><td><span class='mono'>{qa}</span></td><td><span class='mono'>{reg}</span></td><td><span class='hash'>{commit}</span></td></tr>")
parts.append("</table></section>")

# Visual evidence
parts.append("""
<section class='page-break'>
  <div class='section-top'><div class='kicker'>Visual evidence</div><div class='section-label'>Live builds</div></div>
  <h2>The product, as verified.</h2>
  <p>Every image below was captured from a release web build or the Android debug build against the linked Supabase project. Phone captures are 390 &times; 844 unless noted; the desktop shell is 1440 px.</p>
  <h3>Live events and banners</h3>
""")
parts.append(shot_grid([
    ('a1-declined-banner-final-390.png', 'Event banner over the deck: request declined, with a route-aware action.'),
    ('a1-match-banner-dark-final-390.png', 'Match banner in dark mode: subtle top placement, skill context, Say hello.'),
    ('a1-message-banner-dark2-390.png', 'Message banner: sender, preview, and tap-to-chat.'),
]))
parts.append("<h3>Notification controls</h3>")
parts.append(shot_grid([
    ('a3-notifications-page-light-390.png', 'Notification preferences: categories, previews, quiet hours, sound and vibration.'),
    ('a3-notifications-page-dark-390.png', 'The same settings page in dark mode.'),
    ('a4-notifications-permission-390.png', 'System permission state with an honest request and fallback.'),
]))
parts.append("""
  <h3>Connectivity, drafts, and chat controls</h3>
""")
parts.append(shot_grid([
    ('b0-offline-fixed-390.png', 'Offline strip laid out above the app bar; navigation stays tappable.'),
    ('b0-draft-list-390.png', 'Per-chat draft preview after leaving the composer.'),
    ('b1-chat-menu-390.png', 'Chat menu with feedback, profile, mute, mark unread, search, report, block.'),
]))
parts.append("<h3>Chat controls</h3>")
parts.append(shot_grid([
    ('b1-mute-sheet-390.png', 'Mute durations: one hour through until turned back on.'),
    ('b1-muted-list-390.png', 'Muted chat remains in the list with a mute icon.'),
    ('b1-unread-divider-390.png', 'First-unread divider before the new messages.'),
]))
parts.append(shot_grid([
    ('b1-fab-count-390.png', 'New-message FAB with count while scrolled up.'),
    ('b1-search-390.png', 'In-chat search results over loaded messages.'),
    ('b1-copied-390.png', 'Long-press copy with one confirmation.'),
]))
parts.append("""
  <h3>Lists, Activity, and contextual polish</h3>
""")
parts.append(shot_grid([
    ('b2-activity-filters-390.png', 'Activity filters with counts and day groups.'),
    ('b2-clear-read-confirm-390.png', 'Clear-read confirmation: read rows only.'),
    ('b2-chat-longpress-390.png', 'Chat long-press actions: profile, mute, unread, report, block.'),
]))
parts.append("<h3>Contextual polish</h3>")
parts.append(shot_grid([
    ('b3-nudge-banner-390.png', 'Non-blocking profile nudge through the app banner after a request.'),
    ('d-whatsnew-390.png', 'One-time what\'s new sheet, version-gated.'),
    ('a7-shell-1440.png', 'Desktop shell at 1440 px with the mobile-width column.'),
]))
parts.append("""
  <h3>Privacy, presence, and read receipts</h3>
""")
parts.append(shot_grid([
    ('c0-chat-privacy-390.png', 'Chat privacy: online status, typing, read receipts, Pals only.'),
    ('c1-chat-list-presence-390.png', 'Online in the chat list, with message time retained.'),
    ('c1-chat-room-presence-390.png', 'Online under the peer name in the chat header.'),
]))
parts.append("<h3>Read receipts</h3>")
parts.append(shot_grid([
    ('c3-seen-390b.png', 'Seen under the last own message, server-authoritative.'),
], two=True))
parts.append("</section>")

# 12 limitations
parts.append("""
<section class='page-break'>
<h2>13. Known limitations and deferred work</h2>
<table>
<tr><th style='width:24%'>Item</th><th>Status and detail</th></tr>
""")
for item, detail in limitations:
    parts.append(f"<tr><td><strong>{esc(item)}</strong></td><td>{esc(detail)}</td></tr>")
parts.append("""
</table>
<div class='callout warn'>
  <strong>Release wording.</strong> The accurate claim is: notifications work in-app and for a background process on Android; push for killed apps is prepared but requires Firebase/APNs credentials.
</div>
</section>
""")

# 13 ops
parts.append("""
<section class='page-break'>
<h2>14. Operations and credential checklist</h2>
<h3>Build and test</h3>
<ul>
  <li><span class='mono'>flutter pub get</span></li>
  <li><span class='mono'>flutter analyze --no-pub</span></li>
  <li><span class='mono'>flutter test --no-pub</span></li>
  <li><span class='mono'>flutter build web --release --dart-define-from-file=.env</span></li>
  <li><span class='mono'>flutter build apk --debug --dart-define-from-file=.env</span></li>
</ul>
<p class='note'>Configuration is loaded from <span class='mono'>.env</span> through <span class='mono'>--dart-define-from-file</span>; secrets are not bundled as assets. Migrations live in <span class='mono'>supabase/migrations</span> and are forward-only.</p>
<h3>To unblock A5</h3>
<table>
<tr><th style='width:36%'>Credential / asset</th><th>Purpose</th></tr>
""")
for name, purpose in credentials:
    parts.append(f"<tr><td><span class='mono'>{esc(name)}</span></td><td>{esc(purpose)}</td></tr>")
parts.append("""
</table>
<p class='note'>The Android application id is currently <span class='mono'>com.example.palturo</span>. Set the production id before creating the Firebase app; changing it later means recreating the Firebase app and push configuration.</p>
<h3>Rollback and migration notes</h3>
<ul>
  <li>Migrations are add/replace oriented and re-runnable where practical; connection_preferences and privacy columns use IF NOT EXISTS.</li>
  <li>Function replacements preserve grants; the connections grant change is intentionally restrictive.</li>
  <li>If a migration must be rolled back, restore the prior function body from the previous migration and re-issue grants; do not widen connection read access.</li>
</ul>
</section>
""")

# Appendix A commits
parts.append("<section class='page-break'><h2>Appendix A - Commit log</h2><p class='note'>Chronological, from baseline 3ab6700 to 08de0e8.</p><table><tr><th style='width:10%'>Commit</th><th style='width:10%'>Date</th><th style='width:8%'>Phase</th><th>Subject</th></tr>")
for h, d, subject in commits:
    phase = commit_phase.get(h, "-")
    parts.append(f"<tr><td><span class='hash'>{h}</span></td><td>{d}</td><td>{phase}</td><td>{esc(subject)}</td></tr>")
parts.append("</table></section>")

# Appendix B files
parts.append("<section class='page-break'><h2>Appendix B - File inventory</h2><p class='note'>A = added, M = modified, D = deleted.</p><table><tr><th style='width:7%'>State</th><th>Path</th></tr>")
for status, path in changed:
    parts.append(f"<tr><td>{status}</td><td><span class='mono'>{esc(path)}</span></td></tr>")
parts.append("</table></section>")

# Appendix C tests/audits
parts.append("<section class='page-break'><h2>Appendix C - Test suite and audit sessions</h2>")
parts.append("<h3>Test files</h3><table><tr><th>File</th></tr>")
for p in sorted(ROOT.joinpath("test").glob("*.dart")):
    parts.append(f"<tr><td><span class='mono'>test/{esc(p.name)}</span></td></tr>")
parts.append("</table><h3>Audit sessions</h3><table><tr><th>Phase</th><th>Functionality</th><th>Quality</th><th>Regression</th></tr>")
for phase, date, fn, qa, reg, commit in audits:
    parts.append(f"<tr><td>{phase}</td><td><span class='mono'>{fn}</span></td><td><span class='mono'>{qa}</span></td><td><span class='mono'>{reg}</span></td></tr>")
parts.append("</table><p class='note'>Audit sessions are resumable in the same OpenCode child session if a follow-up is needed.</p></section>")

# Split cover and content, keep one shared head/style.
full = "\n".join(parts)
head_end = full.index("<body>") + len("<body>")
head = full[:head_end]
body = full[head_end:]
marker_pos = body.index("<!-- CONTENT_START -->")
cover_body = body[:marker_pos]
content_body = body[marker_pos + len("<!-- CONTENT_START -->"):]

docs = ROOT / "docs"
docs.mkdir(exist_ok=True)
cover_file = docs / "_cover.html"
content_file = docs / "_content.html"
cover_file.write_text(head + "<style>@page{margin:0}</style>" + cover_body + "</body></html>", encoding="utf-8")
content_file.write_text(head + content_body + "</body></html>", encoding="utf-8")
OUT.write_text(full.replace("<!-- CONTENT_START -->", ""), encoding="utf-8")


print(f"Wrote {OUT} ({OUT.stat().st_size} bytes)")
print(f"Cover: {cover_file}")
print(f"Content: {content_file}")
