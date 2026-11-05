# -*- coding: utf-8 -*-
"""Cover, front matter, architecture, and the A/B/C/D work records."""
from change_docs_common import esc, page, phone, sec_head, src
from change_docs_data import phases as PHASES, services as SERVICES
from change_docs_style import LOGO_WHITE


def _status_pill(status):
    if status == "VERIFIED":
        return '<span class="ok">Verified</span>'
    if status == "BLOCKED":
        return '<span class="blocked">Blocked</span>'
    return '<span class="deferred">Deferred</span>'


def cover(n, total):
    return f'''
<section class="page cover">
  <div class="inner">
    <img class="logo" src="{LOGO_WHITE}" alt="PalTuro">
    <div class="kicker" style="color:#d8f400">Implementation &amp; verification · 5 November 2026</div>
    <div class="title">Dynamic UX,<br><span class="lime">QOL &amp; Social</span><br>Presence</div>
    <div class="sub">What changed, how it was audited, and what is ready to ship.</div>
    <div class="desc">A complete record of the notification, banner, feedback, chat quality-of-life, privacy, presence, typing and read-receipt work — from the first typed event to the final release gate.</div>
    <div class="metrics">
      <div class="metric"><div class="n">54</div><div class="t">commits</div></div>
      <div class="metric"><div class="n">155</div><div class="t">tests passing</div></div>
      <div class="metric"><div class="n">16</div><div class="t">phases verified</div></div>
      <div class="metric"><div class="n">7</div><div class="t">live migrations</div></div>
    </div>
    <div class="meta">
      <div><span>Branch</span><b>ui-features @ 08de0e8</b></div>
      <div><span>Prepared for</span><b>PalTuro product team</b></div>
      <div><span>Method</span><b>3 independent audits per phase</b></div>
      <div><span>Scope</span><b>94 files · 9,635 insertions</b></div>
    </div>
  </div>
  <div class="phone"><img src="{src('a1-match-banner-dark-final-390.png')}" alt="PalTuro match banner"></div>
  <div class="ring one"></div><div class="ring two"></div><div class="ring three"></div>
  <div class="quote-line">The interface is no longer<br>a set of screens. <span class="lime">It is one<br>event system.</span></div>
  <div class="tracks">
    <div><b>Track A</b>Notification experience</div>
    <div><b>Track B</b>Quality of life</div>
    <div><b>Track C</b>Privacy and presence</div>
    <div><b>Track D</b>Optional polish</div>
  </div>
  <div class="footer"><span>PalTuro · community-based Filipino skill exchange</span><span class="num">{n:02d} / {total:02d}</span></div>
</section>'''


def contents(n, total, toc):
    left_groups = [
        ("Position", [("01", "Executive summary", "exec")]),
        ("Scope", [("02", "Scope and tracks", "scope"), ("03", "Architecture", "arch")]),
        ("Track A — notification experience", [
            ("04", "A0 · Notification foundation", "A0"),
            ("05", "A1 · In-app dynamic UX", "A1"),
            ("06", "A2 · A6 · Feedback layer", "A2A6"),
            ("07", "A3 · Notification preferences", "A3"),
            ("08", "A4 · Local notifications", "A4"),
            ("09", "A5 · A7 · Push boundary", "A5A7"),
        ]),
        ("Track B — quality of life", [
            ("10", "B0 · QOL primitives", "B0"),
            ("11", "B1 · Chat QOL", "B1"),
            ("12", "B2 · Lists and Activity", "B2"),
            ("13", "B3 · Contextual polish", "B3"),
        ]),
    ]
    right_groups = [
        ("Track C — privacy and presence", [
            ("14", "C0 · Privacy contracts", "C0"),
            ("15", "C1 · C2 · Presence and typing", "C1C2"),
            ("16", "C3 · Read receipts", "C3"),
        ]),
        ("Track D and evidence", [
            ("17", "D · Optional polish", "D"),
            ("18", "Data contracts", "migrations"),
            ("19", "Behaviour", "behaviour"),
            ("20", "Platform and release", "platform"),
            ("21", "Test coverage", "tests"),
            ("22", "Commit ledger", "commits"),
            ("23", "File inventory", "files"),
            ("24", "Limitations", "limitations"),
            ("25", "Operations", "operations"),
            ("26", "Audit ledger", "audit"),
            ("27", "Visual evidence", "gallery"),
            ("28", "Acceptance", "acceptance"),
        ]),
    ]

    def column(groups):
        out = []
        for group, items in groups:
            out.append(f'<div class="toc-group">{group}</div>')
            for no, title, key in items:
                out.append(
                    f'<div class="toc-row"><div class="t"><span class="no">{no}</span>'
                    f'<span>{title}</span></div><span class="p">{toc[key]:02d}</span></div>'
                )
        return "".join(out)

    toc_html = f'<div>{column(left_groups)}</div><div>{column(right_groups)}</div>'
    return page(f'''
{sec_head("Contents", "Every section, in reading order.", "Thirty-seven fixed pages.<br>No blank spreads, no orphaned sections.")}
<div class="toc">{toc_html}</div>
<div class="grid-2" style="margin-top:7mm">
  <div class="card"><div class="label">Status language</div>
    <p class="small" style="margin-bottom:2mm"><span class="ok">Verified</span> shipped, tested and audited. <span class="blocked">Blocked</span> waiting on an external dependency. <span class="deferred">Deferred</span> intentionally not built.</p>
    <p class="small" style="margin:0">A phase is only marked verified after the full suite passes and three independent reviews agree.</p>
  </div>
  <div class="card tint"><div class="label">How to read the evidence</div>
    <ul class="tight small" style="margin:0"><li>Scope is frozen at <b>08de0e8</b>; documentation commits are excluded.</li><li>Every screenshot is a live build capture, not a mockup.</li><li>Audit session IDs are recorded verbatim in section 16.</li><li>Push delivery (A5) is described as blocked, never as shipped.</li></ul>
  </div>
</div>
<div class="callout" style="margin-top:6mm"><p class="quote" style="font-size:12pt;margin-bottom:1.2mm">The interface is no longer a set of screens. It is one event system with a shared privacy contract.</p><p class="small muted" style="margin:0">This document records what was built, what was measured, and what remains outside the release.</p></div>
''', n, total, right="Contents")


def executive(n, total):
    return page(f'''
{sec_head("Release position", "The app now reacts to the moment.", "Live events, chat management and presence share one privacy-aware system.")}
<p class="lead" style="width:158mm">Fifty-four commits replaced polling and silent state changes with a typed notification backbone, contextual banners, honest preference controls, everyday chat tools, and a server-enforced privacy model for online status, typing and read receipts. The work was delivered in four tracks and closed with 155 passing tests.</p>
<div class="metric-grid">
  <div class="metric"><div class="n">54</div><div class="t">commits in scope</div></div>
  <div class="metric"><div class="n">94</div><div class="t">files changed</div></div>
  <div class="metric"><div class="n">155<em>/155</em></div><div class="t">tests passing</div></div>
  <div class="metric"><div class="n">1</div><div class="t">external blocker</div></div>
</div>
<div class="grid-3">
  <div class="card"><div class="label">One event model</div><h3>Notifications are typed, deduplicated and routable.</h3><p>A single service now feeds Activity, in-app banners, local system alerts, the launcher badge and cold-start routing. Unknown payloads fail closed instead of leaking technical text.</p></div>
  <div class="card"><div class="label">Quiet by default</div><h3>Users choose what reaches them, and when.</h3><p>Master switch, per-category gates, preview privacy, quiet hours, sound and vibration are all observable and persisted. Presence, typing and receipts are separate, server-backed permissions.</p></div>
  <div class="card"><div class="label">Everyday chat</div><h3>The small actions now exist.</h3><p>Mute windows, manual unread, drafts, unread divider, scroll-to-bottom count, search, copy, retry and clear-read turn the chat list into a usable inbox.</p></div>
</div>
<div class="label" style="margin-top:4mm">Programme at a glance</div>
<table class="compact"><thead><tr><th style="width:10mm">Track</th><th style="width:38mm">Theme</th><th style="width:22mm">Items</th><th>Evidence at close</th></tr></thead><tbody>
<tr><td class="case">A</td><td>Notification experience</td><td>8 · 1 blocked</td><td>122 tests · web release · Android APK · 360/390/1440</td></tr>
<tr><td class="case">B</td><td>Quality of life</td><td>4 verified</td><td>145 tests · live mute, draft, divider, filter and nudge probes</td></tr>
<tr><td class="case">C</td><td>Privacy and presence</td><td>4 verified</td><td>154 tests · live ACL, masking, presence and Seen probes</td></tr>
<tr><td class="case">D</td><td>Optional polish</td><td>2 · 1 deferred</td><td>155 tests · once-per-version live probe</td></tr>
</tbody></table>
<div class="grid-2" style="margin-top:2mm">
  <div class="card" style="padding:3.2mm"><h4>What users will notice</h4><p class="tiny" style="margin:0;color:#66695e">Banners that appear in context, a chat list that can be managed, and status controls that actually remove the status.</p></div>
  <div class="card tint" style="padding:3.2mm"><h4>What stayed the same</h4><p class="tiny" style="margin:0;color:#66695e">The five-tab shell, the lime navigation, the system theme default and the Pals count treatment were not redesigned.</p></div>
</div>
<div class="callout" style="margin-top:5mm"><p class="quote" style="font-size:12.6pt;margin-bottom:1.2mm">Sixteen phases verified. One credential-dependent gap. No unresolved defect inside the shipped scope.</p><p class="small" style="margin:0">Verified with analyzer, 155 tests, a release web build, an Android debug APK, seven live migrations, three independent audits per phase, and captures at 360, 390 and 1440 in light and dark.</p></div>
<div class="rule"></div>
<div class="grid-4"><div><div class="label">Branch</div><p class="small" style="margin:0">ui-features @ 08de0e8</p></div><div><div class="label">Web build</div><p class="small" style="margin:0">release, current source</p></div><div><div class="label">Database</div><p class="small" style="margin:0">7 migrations applied</p></div><div><div class="label">Working tree</div><p class="small" style="margin:0">clean after push</p></div></div>
''', n, total, right="Executive summary")


def scope(n, total):
    track_rows = [
        ("A", "Notification experience", "A0–A7", "6 verified · 1 blocked", '<span class="blocked">A5 blocked</span>'),
        ("B", "Quality of life", "B0–B3", "4 verified", '<span class="ok">Complete</span>'),
        ("C", "Privacy, presence, receipts", "C0–C3", "4 verified", '<span class="ok">Complete</span>'),
        ("D", "Optional polish", "D-01–D-02", "1 verified · 1 deferred", '<span class="deferred">D-02 deferred</span>'),
    ]
    track_html = "".join(
        f'<tr><td class="case">{a}</td><td><b>{b}</b></td><td class="mono">{c}</td><td>{d}</td><td>{e}</td></tr>'
        for a, b, c, d, e in track_rows
    )
    items = [
        ("A0", "Notification foundation"), ("A1", "In-app dynamic UX"), ("A2", "Haptics and sound"),
        ("A3", "Notification preferences"), ("A4", "Local notifications"), ("A5", "Push delivery"),
        ("A6", "Feedback audit"), ("A7", "Release 1 verification"), ("B0", "QOL primitives"),
        ("B1", "Chat QOL"), ("B2", "List and Activity QOL"), ("B3", "Contextual polish"),
        ("C0", "Privacy contracts"), ("C1", "Presence"), ("C2", "Typing indicators"),
        ("C3", "Read receipts"), ("D-01", "What's new"), ("D-02", "Review prompt"),
    ]
    item_rows = "".join(
        f'<tr><td class="case">{esc(pid)}</td><td>{esc(title)}</td><td>{_status_pill(status)}</td>'
        f'<td class="mono">{esc(commits)}</td></tr>'
        for pid, title, status, commits, *_rest in PHASES
    )
    return page(f'''
{sec_head("Scope", "Four tracks, eighteen work items.", "Frozen at 08de0e8.<br>Documentation commits are outside the count.")}
<p class="lead" style="width:158mm">The programme was planned as a notification track, a quality-of-life track, a privacy and presence track, and a small optional polish track. Each item has a commit range, a verification note and a recorded audit.</p>
<table style="margin-top:4mm"><thead><tr><th style="width:9mm">Track</th><th style="width:40mm">Theme</th><th style="width:18mm">Items</th><th style="width:34mm">Outcome</th><th>Status</th></tr></thead><tbody>{track_html}</tbody></table>
<div class="label" style="margin-top:5mm">Work-item ledger</div>
<table class="compact"><thead><tr><th style="width:12mm">ID</th><th>Work item</th><th style="width:22mm">Status</th><th style="width:48mm">Commits</th></tr></thead><tbody>{item_rows}</tbody></table>
<div class="callout warn" style="margin-top:4mm"><p class="small" style="margin:0"><b>Boundary:</b> A5 push delivery is prepared as a dependency list, not as shipped behaviour. D-02 is deferred because no store listing exists. Neither gap is counted as a completed phase.</p></div>
''', n, total, right="Scope and tracks")


def architecture(n, total):
    return page(f'''
{sec_head("Architecture", "One event path from Postgres to the screen.", "Services own state.<br>Widgets only render it.")}
<p class="lead" style="width:158mm">The notification and chat systems were deliberately split: durable events arrive through Supabase, ephemeral signals travel over the chat channel, and every surface consumes the same typed state rather than subscribing independently.</p>
<div class="arch">
  <div style="display:grid;grid-template-columns:1fr 5mm 1fr 5mm 1fr 5mm 1fr;gap:0;align-items:stretch">
    <div class="arch-node"><div class="n">Durable</div><b>notifications</b><span>Realtime publication, SELECT scoped by <span class="mono">notif_read</span>.</span></div>
    <div class="arch-arrow">→</div>
    <div class="arch-node"><div class="n">Service</div><b>NotificationService</b><span>Dedupe, unread count, mark read, lifecycle, reconnect.</span></div>
    <div class="arch-arrow">→</div>
    <div class="arch-node"><div class="n">Policy</div><b>NotificationPresenter</b><span>Category, preview, quiet-hours and route gates.</span></div>
    <div class="arch-arrow">→</div>
    <div class="arch-node"><div class="n">Surface</div><b>Banner · Activity<br>Local · Badge</b><span>One event, four renderers, one source.</span></div>
  </div>
  <div class="arch-split">
    <div><b>In-app banner</b>Queued, 4s default, swipe/close, live-region semantics.</div>
    <div><b>Activity</b>Typed list, filters, day groups, swipe-to-read.</div>
    <div><b>System alert</b>Four Android channel combinations by category.</div>
    <div><b>Launcher badge</b>Activity plus chat unread, preference-gated.</div>
  </div>
</div>
<div class="grid-2" style="margin-top:3mm">
  <div class="card"><div class="label">Ephemeral chat channel</div><p class="small">Presence, typing and read signals travel on <span class="mono">chat:&lt;connectionId&gt;</span>. The client tracks only when the peer allows presence, broadcasts typing with a 2s throttle, and treats read events as hints until the server timestamp is reloaded.</p><div class="tiny muted" style="margin-top:2mm">No database writes for typing. No client-clock authority for Seen.</div></div>
  <div class="card tint"><div class="label">Failure posture</div><p class="small">Realtime joins refresh an expired session first, then retry with backoff. Privacy state that has not loaded disables the related controls. Unsupported platforms no-op instead of throwing, and sign-out resets every service.</p></div>
</div>
<div class="label" style="margin-top:5mm">Service inventory</div>
<div class="grid-3">{''.join(f'<div class="card" style="padding:2.8mm"><h4>{esc(name)}</h4><p class="tiny" style="margin:0;color:#66695e">{esc(desc)}</p></div>' for name, desc in SERVICES)}</div>
<div class="callout" style="margin-top:4mm"><p class="small" style="margin:0"><b>Rule:</b> no widget talks to Supabase for notification or presence state. Widgets observe a service; the service owns retries, gating and teardown.</p></div>
''', n, total, right="Architecture")


def a0(n, total):
    return page(f'''
{sec_head("Track A / A0", "A typed event backbone.", "One source of truth for Activity, banners, local alerts and badges.")}
<p class="lead" style="width:158mm">Before A0, unread state was assembled ad hoc and every surface interpreted notification payloads differently. The foundation introduced a typed model, a single realtime service and a router that can act before or after the first frame.</p>
<div class="split">
  <div><div class="label">What shipped</div><ul class="small">
    <li><b>AppNotification</b> with known kinds, defensive parsing, payload fallbacks, read state and copy/row adapters.</li>
    <li><b>NotificationService</b> owns the realtime channel, dedupe by id, unread count, mark-one/all, lifecycle refresh, sign-out reset and reconnect.</li>
    <li><b>AppRouter</b> and a global navigator key let banners, Activity, local alerts and cold starts route to Activity, Requests, Chat or Profile.</li>
    <li><b>ActivityService replaced</b> and every caller migrated.</li>
    <li><b>Server:</b> notifications added to the realtime publication with SELECT scoped by the existing read policy; list RPC enriched with actor, skill, role and connection status.</li>
  </ul></div>
  <div class="card tint"><div class="label">AppNotification contract</div>
    <div class="kv" style="grid-template-columns:24mm 1fr;font-size:7.2pt">
      <div class="k">Kinds</div><div class="v">request · accepted · declined · feedback · moderation · unknown</div>
      <div class="k">Parsing</div><div class="v">defensive, unknown-safe</div>
      <div class="k">Fallbacks</div><div class="v">payload → row columns</div>
      <div class="k">State</div><div class="v">read / unread, copyWith</div>
      <div class="k">Adapters</div><div class="v">toRow for tests and seeds</div>
    </div>
    <div class="rule" style="margin:3mm 0"></div>
    <p class="tiny" style="margin:0;color:#66695e">An unknown kind renders as a neutral Activity row. It never throws and never prints raw SQL or payload text.</p>
  </div>
</div>
<div class="label" style="margin-top:3mm">Event routing</div>
<table class="compact"><thead><tr><th style="width:26mm">Kind</th><th>Default destination</th><th style="width:44mm">Context carried</th></tr></thead><tbody>
<tr><td class="case">request</td><td>Requests · incoming</td><td class="mono">connection_id, actor</td></tr>
<tr><td class="case">accepted</td><td>Chat room</td><td class="mono">connection_id, peer, role</td></tr>
<tr><td class="case">declined</td><td>Requests · incoming</td><td class="mono">connection_id</td></tr>
<tr><td class="case">feedback</td><td>Activity</td><td class="mono">notification_id</td></tr>
<tr><td class="case">moderation</td><td>Activity</td><td class="mono">notification_id</td></tr>
</tbody></table>
<div class="callout" style="margin-top:3mm"><p class="small" style="margin:0"><b>Why it mattered:</b> A1, A3, A4, B2 and C3 all attach to this one model. Without it, each surface would have grown its own parser and its own definition of unread.</p></div>
<div class="label" style="margin-top:4mm">Realtime lifecycle</div>
<div class="grid-3">
  <div class="card" style="padding:3.2mm"><h4>Join</h4><p class="tiny" style="margin:0;color:#66695e">Refresh an expired session, open the channel, then mark joined only after the subscription acknowledges.</p></div>
  <div class="card" style="padding:3.2mm"><h4>Recover</h4><p class="tiny" style="margin:0;color:#66695e">Back off on JWT or channel errors, resubscribe, and refresh the unread list on success.</p></div>
  <div class="card" style="padding:3.2mm"><h4>Reset</h4><p class="tiny" style="margin:0;color:#66695e">Sign-out clears unread state, cancels the channel and resets the router so the next account starts clean.</p></div>
</div>
<div class="label" style="margin-top:3mm">Migration contract</div>
<table class="compact"><thead><tr><th style="width:16mm">ID</th><th>Guarantee</th><th style="width:42mm">Failure mode</th></tr></thead><tbody>
<tr><td class="case">001</td><td>Realtime insert visible only to the owning user</td><td>Row stays in Activity after refresh</td></tr>
<tr><td class="case">002</td><td>Activity carries actor, skill, role and status</td><td>Neutral row, no technical text</td></tr>
</tbody></table>
<div class="callout" style="margin-top:2mm"><p class="small" style="margin:0"><b>Contract:</b> the payload remains the source of ids; joins only decorate. A missing actor or skill degrades the row, never the unread count.</p></div>
<div class="rule"></div>
<div class="grid-4"><div><div class="label">Commits</div><div class="mono" style="font-size:8pt">8e0f5f3 · 5aed01e</div></div><div><div class="label">Tests at close</div><div class="quote" style="font-family:Comfortaa;font-size:16pt">91</div></div><div><div class="label">Migrations</div><div class="quote" style="font-family:Comfortaa;font-size:16pt">2</div></div><div><div class="label">Audits</div><div class="quote" style="font-family:Comfortaa;font-size:16pt">3/3</div></div></div>
''', n, total, right="Track A / A0")


def a1(n, total):
    return page(f'''
{sec_head("Track A / A1", "Live events, without leaving the screen.", "One banner at a time.<br>Route-aware, never over the active chat.")}
<p class="lead" style="width:158mm">A1 made live activity visible in context. The old bottom match sheet was replaced by a top banner system that queues, coalesces and suppresses itself on screens where it would interrupt the task.</p>
<div class="grid-3">
  <div class="card"><div class="label">Standard banner</div><h3>Request, decline, feedback.</h3><p>Four-second default, close or swipe to dismiss, tap to route, live-region semantics and reduced-motion support. Grouped per conversation so a burst never becomes a stack.</p></div>
  <div class="card"><div class="label">Match banner</div><h3>“You're now Pals with X.”</h3><p>Skill line and Say hello action, about seven seconds, once per connection, persisted across restarts. It pre-empts a standard banner and restores the queue afterwards.</p></div>
  <div class="card"><div class="label">Message banner</div><h3>Sender, preview, tap to chat.</h3><p>Emitted only for messages outside the active room and not authored by the current user. Same-conversation messages coalesce instead of stacking.</p></div>
</div>
<div class="label" style="margin-top:4mm">Suppression matrix</div>
<table class="compact"><thead><tr><th style="width:44mm">Current surface</th><th>Behaviour</th><th style="width:34mm">Why</th></tr></thead><tbody>
<tr><td><b>Activity</b></td><td>Notification banners suppressed</td><td>The list is already visible.</td></tr>
<tr><td><b>Requests (pushed)</b></td><td>Request banners suppressed</td><td>Avoid duplicate decisions.</td></tr>
<tr><td><b>Active chat room</b></td><td>That conversation's banners suppressed</td><td>Messages are on screen.</td></tr>
<tr><td><b>Any other surface</b></td><td>Banner shown and queued</td><td>Keep the user in context.</td></tr>
</tbody></table>
<div class="grid-2" style="margin-top:3mm">
  <div class="card tint"><div class="label">Realtime hardening</div><ul class="checks" style="margin:0"><li>Expired session refreshed before join</li><li>Backoff on JWT/channel errors</li><li>Joined state tracked explicitly</li><li>Recovery on token refresh and resume</li></ul></div>
  <div class="card"><div class="label">Accessibility</div><p class="small" style="margin:0">Banners use a polite live region, expose one primary action, keep 44px targets, and switch to a static presentation when animations are disabled. 360px and 200% text are covered by widget tests.</p></div>
</div>
<div class="split" style="margin-top:3mm">
  <div><div class="label">Timing and queue</div>
    <table class="compact"><thead><tr><th style="width:30mm">Banner</th><th style="width:16mm">Dwell</th><th>Queue rule</th></tr></thead><tbody>
      <tr><td>Standard</td><td>4s</td><td>One visible; next waits</td></tr>
      <tr><td>Match</td><td>~7s</td><td>Pre-empts; previous restored</td></tr>
      <tr><td>Message</td><td>4s</td><td>Coalesces per conversation</td></tr>
      <tr><td>Nudge</td><td>10s</td><td>Queued behind the active banner</td></tr>
    </tbody></table>
  </div>
  <div class="card tint"><div class="label">Reduced motion</div><p class="small" style="margin:0">When animations are disabled, the banner appears without translation and the match moment uses the static presentation. Grouping still applies, so a burst of messages produces one update rather than a strobe.</p></div>
</div>
<div class="grid-2" style="margin-top:2mm">
  <div class="card" style="padding:3.2mm"><h4>Match persistence</h4><p class="tiny" style="margin:0;color:#66695e">A match banner is shown once per connection and remembered across restarts, so reopening the app cannot replay the celebration.</p></div>
  <div class="card tint" style="padding:3.2mm"><h4>Message coalescing</h4><p class="tiny" style="margin:0;color:#66695e">Several messages from one conversation update the visible banner instead of queuing one per message; different conversations still queue.</p></div>
</div>
<div class="rule"></div>
<div class="grid-4"><div><div class="label">Commits</div><div class="mono" style="font-size:7.5pt">45cf7e7 · be90c0d<br>de4046e · c480fa7 · 06f10d8</div></div><div><div class="label">Tests at close</div><div class="quote" style="font-family:Comfortaa;font-size:16pt">99</div></div><div><div class="label">Banner types</div><div class="quote" style="font-family:Comfortaa;font-size:16pt">3</div></div><div><div class="label">Audits</div><div class="quote" style="font-family:Comfortaa;font-size:16pt">3/3</div></div></div>
''', n, total, right="Track A / A1")


def a2_a6(n, total):
    return page(f'''
{sec_head("Track A / A2 · A6", "Feedback feels intentional, never technical.", "Physical cues and one snackbar contract.<br>Preferences always win.")}
<p class="lead" style="width:158mm">Two phases closed the feedback layer. A2 replaced raw haptics with named intents and added gated sound; A6 replaced ad-hoc snackbars and raw error strings with a single feedback helper and a friendly-error allowlist.</p>
<div class="grid-2">
  <div class="card"><div class="label">A2 · Haptics and sound</div><h3>Named cues, throttled and gated.</h3><ul class="small" style="margin-bottom:0"><li>Intents: selection, tap, toggle, impact, success, warning, error, match.</li><li>50ms per-intent throttle; web/desktop no-op; vibration preference gate.</li><li>SoundService reuses <span class="mono">messages.wav</span>, <span class="mono">newmatch.wav</span> and <span class="mono">splash.wav</span>.</li><li>150ms debounce, serialized init, stop on route change, lifecycle gate.</li><li>Enabling sound or vibration in Settings previews the choice.</li></ul></div>
  <div class="card"><div class="label">A6 · AppFeedback</div><h3>One snackbar contract.</h3><ul class="small" style="margin-bottom:0"><li>Info, success and error tones with icon and duration (4s / 3s / 6s).</li><li>One action, <span class="mono">clearSnackBars</span>, and a dialog-scoped variant.</li><li>Adopted across home, chat, matches, requests, block list, explore, account and settings.</li><li>Undo snackbars use an explicit five-second duration.</li><li>Technical leakage rejected before the friendly allowlist.</li></ul></div>
</div>
<div class="label" style="margin-top:4mm">Cue matrix</div>
<table class="compact"><thead><tr><th style="width:42mm">Event</th><th style="width:32mm">Haptic</th><th style="width:38mm">Sound</th><th>Gate</th></tr></thead><tbody>
<tr><td>New match</td><td>match pattern</td><td>newmatch.wav</td><td>category + quiet hours</td></tr>
<tr><td>Incoming message</td><td>impact</td><td>messages.wav</td><td>preview / quiet hours</td></tr>
<tr><td>Request sent or accepted</td><td>success</td><td>—</td><td>vibration preference</td></tr>
<tr><td>Decline or undo</td><td>warning</td><td>—</td><td>single cue only</td></tr>
<tr><td>Destructive confirmation</td><td>error</td><td>—</td><td>vibration preference</td></tr>
<tr><td>Toggle, chip, tab</td><td>selection / tap</td><td>—</td><td>50ms throttle</td></tr>
</tbody></table>
<div class="callout risk" style="margin-top:3mm"><p class="small" style="margin:0"><b>Leak guard:</b> Postgrest text, SQLSTATE codes, <span class="mono">varying()</span> errors and auth internals are rejected before the allowlist. Validation copy — including password digit rules and account-deletion messages — is preserved verbatim.</p></div>
<div class="split" style="margin-top:3mm">
  <div><div class="label">Sound assets</div>
    <table class="compact"><thead><tr><th style="width:34mm">Asset</th><th>Used for</th></tr></thead><tbody>
      <tr><td class="mono">newmatch.wav</td><td>Match moment only</td></tr>
      <tr><td class="mono">messages.wav</td><td>Incoming message while outside the room</td></tr>
      <tr><td class="mono">splash.wav</td><td>Startup, once</td></tr>
    </tbody></table>
  </div>
  <div class="grid-2" style="gap:3mm">
    <div class="card" style="padding:3.2mm"><h4>Single cue</h4><p class="tiny" style="margin:0;color:#66695e">Raw haptics were removed from request cards, so a preference cannot be bypassed and decline does not double-cue.</p></div>
    <div class="card" style="padding:3.2mm"><h4>Preview</h4><p class="tiny" style="margin:0;color:#66695e">Enabling sound or vibration in Settings plays the cue once, confirming the choice without a test screen.</p></div>
  </div>
</div>
<div class="callout" style="margin-top:2mm"><p class="small" style="margin:0"><b>One path:</b> every cue goes through the same preference check. There is no raw platform call left in a widget that could bypass a disabled sound or vibration setting.</p></div>
<div class="rule"></div>
<div class="grid-4"><div><div class="label">A2 commits</div><div class="mono" style="font-size:8pt">b96c571 · 4de648a</div></div><div><div class="label">A6 commits</div><div class="mono" style="font-size:7.5pt">8d8f9e6 · 445c4c9<br>5b97786 · da7ff16</div></div><div><div class="label">Tests at close</div><div class="quote" style="font-family:Comfortaa;font-size:16pt">122</div></div><div><div class="label">Audits</div><div class="quote" style="font-family:Comfortaa;font-size:16pt">6/6</div></div></div>
''', n, total, right="Track A / A2 · A6")


def a3(n, total):
    return page(f'''
{sec_head("Track A / A3", "Notification preferences that tell the truth.", "Every switch maps to a real gate.<br>No fictional OS copy.")}
<p class="lead" style="width:150mm">A3 turned a thin preference store into an observable model and gave it a dedicated settings page. Each category, preview, quiet-hours window, sound and vibration choice is applied by the presenter before anything reaches a surface.</p>
<div class="split">
  <div>
    <div class="label">What shipped</div>
    <ul class="small">
      <li><b>Master switch</b> plus messages, requests/matches, activity, previews, quiet hours, sound and vibration.</li>
      <li><b>Presenter gates</b> each event kind; quiet hours suppress sound and haptics while banners still appear.</li>
      <li><b>Preview privacy</b> replaces message text with “New message” when previews are off.</li>
      <li><b>Settings page</b> with delivery state, permission status, categories, preview example, adaptive time pickers and Pals-only context.</li>
      <li><b>Master off</b> disables categories without erasing their saved values; the Settings root summary stays accurate.</li>
    </ul>
    <div class="callout" style="margin-top:3mm;padding:3.4mm 4mm"><p class="small" style="margin:0"><b>Honesty fix:</b> fictional OS-permission copy was removed. The page reports the actual permission state and never promises delivery it cannot provide.</p></div>
  </div>
  <div style="width:54mm;margin-left:auto">{phone('a3-notifications-page-light-390.png', 'Notification preferences', 'Delivery, permission, categories, preview, sound, vibration and quiet hours.')}</div>
</div>
<table class="compact" style="margin-top:1mm"><thead><tr><th style="width:34mm">Control</th><th>Effect</th><th style="width:34mm">When master off</th></tr></thead><tbody>
<tr><td><b>Messages</b></td><td>Message banners and local alerts</td><td>Gated off, value retained</td></tr>
<tr><td><b>Requests / matches</b></td><td>Request, decline and match events</td><td>Gated off, value retained</td></tr>
<tr><td><b>Activity</b></td><td>Feedback and moderation rows</td><td>Gated off, value retained</td></tr>
<tr><td><b>Preview</b></td><td>Message body versus “New message”</td><td>Preview hidden</td></tr>
<tr><td><b>Quiet hours</b></td><td>No sound or haptics; banners remain</td><td>No effect</td></tr>
</tbody></table>
<div class="grid-2" style="margin-top:2mm">
  <div class="card" style="padding:3.2mm"><h4>Quiet-hours behaviour</h4><p class="tiny" style="margin:0;color:#66695e">The window is evaluated per event on the device. It suppresses audio and haptics only; it does not mark anything read or hide the banner.</p></div>
  <div class="card" style="padding:3.2mm"><h4>Preview privacy</h4><p class="tiny" style="margin:0;color:#66695e">With previews off, the banner and system alert both read “New message”. The sender remains so the user can decide whether to open the chat.</p></div>
</div>
<div class="rule"></div>
<div class="grid-4"><div><div class="label">Commits</div><div class="mono" style="font-size:7.5pt">75b1ff8 · 72fe744<br>f89f540</div></div><div><div class="label">Tests at close</div><div class="quote" style="font-family:Comfortaa;font-size:16pt">114</div></div><div><div class="label">Widths</div><div class="quote" style="font-family:Comfortaa;font-size:15pt">360 · 200%</div></div><div><div class="label">Audits</div><div class="quote" style="font-family:Comfortaa;font-size:16pt">3/3</div></div></div>
''', n, total, right="Track A / A3")


def a4(n, total):
    return page(f'''
{sec_head("Track A / A4", "System notifications while the process is alive.", "Permissions, channels and tap routing.<br>No claim beyond that.")}
<p class="lead" style="width:150mm">A4 added local system notifications with real Android channels and a permission model that distinguishes “not asked” from “denied”. Taps and cold-start payloads route into the correct surface with peer context.</p>
<div class="split">
  <div>
    <div class="label">Platform contract</div>
    <table class="compact"><thead><tr><th style="width:22mm">Platform</th><th>Behaviour</th></tr></thead><tbody>
      <tr><td><b>Android</b></td><td>Four channel combinations per category (sound × vibration). <span class="mono">POST_NOTIFICATIONS</span> and <span class="mono">VIBRATE</span> declared; status icon present.</td></tr>
      <tr><td><b>iOS</b></td><td><span class="mono">UNUserNotificationCenter</span> delegate set in AppDelegate; deployment target raised to 13.0. Compiled on macOS still required.</td></tr>
      <tr><td><b>Web</b></td><td>Initialization and permission APIs wired; unsupported browsers fail closed and skip silently.</td></tr>
    </tbody></table>
    <div class="grid-2" style="margin-top:3mm">
      <div class="card" style="padding:3.2mm"><div class="label">Permission state</div><p class="tiny" style="margin:0">Not asked vs denied vs granted. Request from Settings; denied opens system settings; state refreshes on resume.</p></div>
      <div class="card" style="padding:3.2mm"><div class="label">Tap routing</div><p class="tiny" style="margin:0">Chat, Requests, Activity or Profile, including cold start, with the peer and connection context carried in the payload.</p></div>
    </div>
  </div>
  <div style="width:54mm;margin-left:auto">{phone('a4-notifications-permission-390.png', 'Permission state', 'The page reports the real system state and offers the correct next action.')}</div>
</div>
<div class="grid-3" style="margin-top:2mm">
  <div class="card tint"><div class="label">Foreground</div><p class="tiny" style="margin:0">In-app banner is the primary cue; a duplicate system alert is suppressed while the app is visible.</p></div>
  <div class="card tint"><div class="label">Background process</div><p class="tiny" style="margin:0">Local alerts fire while the process is alive. Cancelled on logout and gated by category, quiet hours and previews.</p></div>
  <div class="card tint"><div class="label">Killed app</div><p class="tiny" style="margin:0">Not covered. That requires A5 push credentials and is explicitly outside this release claim.</p></div>
</div>
<div class="callout warn" style="margin-top:3mm"><p class="small" style="margin:0"><b>Release wording:</b> notifications work in-app and through a background process on Android. Push for killed apps is prepared but not delivered.</p></div>
<div class="rule"></div>
<div class="grid-4"><div><div class="label">Commits</div><div class="mono" style="font-size:7.5pt">dc5c03c · a2c3fc6<br>ed9c0ed</div></div><div><div class="label">Tests at close</div><div class="quote" style="font-family:Comfortaa;font-size:16pt">120</div></div><div><div class="label">Builds</div><div class="quote" style="font-family:Comfortaa;font-size:13pt">Web + APK</div></div><div><div class="label">Audits</div><div class="quote" style="font-family:Comfortaa;font-size:16pt">3/3</div></div></div>
''', n, total, right="Track A / A4")


def a5_a7(n, total):
    return page(f'''
{sec_head("Track A / A5 · A7", "Push is prepared, not claimed.", "A7 closed release 1 with A5 still blocked.")}
<div class="callout risk" style="margin-top:0"><p style="font-family:Comfortaa;font-size:12pt;line-height:1.24;margin-bottom:1.2mm">No Firebase project exists. No APNs key exists. Killed-app delivery is not shipped.</p><p class="small" style="margin:0">A5 is blocked on external credentials, not on application code. The release must not promise killed-app alerts or guaranteed iOS background delivery.</p></div>
<div class="grid-2" style="margin-top:3mm">
  <div><div class="label">Required to unblock A5</div>
    <table class="compact"><tbody>
      <tr><td><b>Firebase project</b></td><td>Android, iOS and web apps registered to the release application id.</td></tr>
      <tr><td class="mono">google-services.json</td><td>Android Firebase identity.</td></tr>
      <tr><td class="mono">GoogleService-Info.plist</td><td>iOS Firebase identity.</td></tr>
      <tr><td><b>APNs .p8</b></td><td>Key ID and Team ID for Apple push authorization.</td></tr>
      <tr><td><b>Web VAPID</b></td><td>Public key for browser push subscriptions.</td></tr>
      <tr><td><b>Service account</b></td><td>Edge function authentication to FCM HTTP v1.</td></tr>
    </tbody></table>
  </div>
  <div class="card tint"><div class="label">What still works without A5</div><ul class="checks" style="margin:0"><li>In-app banners while the app is open</li><li>Activity list with realtime inserts</li><li>Launcher badge from unread counts</li><li>Local system alerts while the process is alive</li><li>Server reconciliation on resume and reconnect</li></ul><div class="rule" style="margin:3mm 0"></div><p class="tiny" style="margin:0;color:#66695e">The honest product statement is “notifications work in-app and for a background process on Android.”</p></div>
</div>
<div class="label" style="margin-top:4mm">A7 · Release 1 verification</div>
<table class="compact"><thead><tr><th style="width:36mm">Gate</th><th>Result</th><th style="width:24mm">State</th></tr></thead><tbody>
<tr><td>Analyzer</td><td><span class="mono">flutter analyze --no-pub</span> — clean</td><td><span class="ok">Pass</span></td></tr>
<tr><td>Tests</td><td><span class="mono">flutter test --no-pub</span> — 122/122</td><td><span class="ok">Pass</span></td></tr>
<tr><td>Release web</td><td><span class="mono">flutter build web --release</span> — success</td><td><span class="ok">Pass</span></td></tr>
<tr><td>Android debug</td><td><span class="mono">flutter build apk --debug</span> — success</td><td><span class="ok">Pass</span></td></tr>
<tr><td>Visual matrix</td><td>360/390/1440, dark, home, settings, Activity, banners</td><td><span class="ok">Pass</span></td></tr>
<tr><td>Live probes</td><td>Request, match, message and permission states</td><td><span class="ok">Pass</span></td></tr>
</tbody></table>
<div class="callout" style="margin-top:3mm"><p class="small" style="margin:0"><b>A7 outcome:</b> the A track was accepted as release-ready with one documented delivery gap. B and C work continued without pretending the gap was closed.</p></div>
<div class="label" style="margin-top:4mm">A5 delivery plan</div>
<table class="compact"><thead><tr><th style="width:8mm">Step</th><th>Change</th><th style="width:38mm">Verification</th></tr></thead><tbody>
<tr><td class="case">01</td><td>Register the release application id in Firebase for Android, iOS and web.</td><td>Config files resolve at build</td></tr>
<tr><td class="case">02</td><td>Register device tokens and the foreground handler in the client.</td><td>Token refresh and logout</td></tr>
<tr><td class="case">03</td><td>Send through FCM HTTP v1 from an edge function using the existing event kinds.</td><td>Killed-app device test</td></tr>
<tr><td class="case">04</td><td>Update the public claim only after Android and iOS device verification.</td><td>Release wording review</td></tr>
</tbody></table>
<div class="grid-2" style="margin-top:2mm">
  <div class="card" style="padding:3.2mm"><h4>Do not claim</h4><p class="tiny" style="margin:0;color:#66695e">Killed-app delivery, guaranteed iOS background delivery, or a notification that survives force-stop. None of these is true today.</p></div>
  <div class="card tint" style="padding:3.2mm"><h4>Reuse, don't rebuild</h4><p class="tiny" style="margin:0;color:#66695e">The event kinds, payload and routing contract already exist. A5 adds transport, not a second notification model.</p></div>
</div>
''', n, total, right="Track A / A5 · A7")


def b0(n, total):
    return page(f'''
{sec_head("Track B / B0", "The app survives a bad connection.", "Refresh keeps content.<br>Offline is visible, not modal.")}
<p class="lead" style="width:158mm">B0 added the primitives that every later quality-of-life feature depends on: pull-to-refresh that preserves state, a persistent offline strip, a correct launcher badge, and per-conversation drafts.</p>
<div class="grid-4">
  <div class="card"><div class="big-no">01</div><h3>Pull to refresh</h3><p class="tiny">Chats, Activity, Requests (incoming and sent) and Browse. On failure the list stays and a snackbar explains the problem.</p></div>
  <div class="card"><div class="big-no">02</div><h3>Offline strip</h3><p class="tiny">Persistent, laid out above app content rather than over the app bar. Reconnect refreshes notifications and conversations.</p></div>
  <div class="card"><div class="big-no">03</div><h3>Launcher badge</h3><p class="tiny">Activity unread plus chat unread, master-preference gated, serialized writes, reset on sign-out, skipped on web.</p></div>
  <div class="card"><div class="big-no">04</div><h3>Drafts</h3><p class="tiny">Per conversation, 350ms debounce, restored on open, cleared on send or sign-out, previewed as “Draft:” in the list.</p></div>
</div>
<div class="label" style="margin-top:4mm">Draft lifecycle</div>
<table class="compact"><thead><tr><th style="width:34mm">Moment</th><th>Behaviour</th><th style="width:44mm">Guarantee</th></tr></thead><tbody>
<tr><td><b>Typing</b></td><td>Debounced write after 350ms of inactivity</td><td>No write per keystroke</td></tr>
<tr><td><b>Leaving chat</b></td><td>Draft persists and appears in the list preview</td><td>Survives navigation</td></tr>
<tr><td><b>Reopening</b></td><td>Composer restores the draft at the cursor end</td><td>No lost text</td></tr>
<tr><td><b>Sending</b></td><td>Draft cleared only after the send is accepted</td><td>No empty composer on failure</td></tr>
<tr><td><b>Sign-out</b></td><td>All drafts cleared</td><td>No cross-account leakage</td></tr>
</tbody></table>
<div class="grid-2" style="margin-top:3mm">
  <div class="card tint"><div class="label">Offline behaviour</div><p class="small" style="margin:0">The strip occupies layout space, so it cannot cover the app bar or intercept taps. Reconnect triggers a notification refresh and a conversation reload instead of waiting for the next manual pull.</p></div>
  <div class="card"><div class="label">Badge arithmetic</div><p class="small" style="margin:0"><span class="mono">activity unread + chat unread</span>, capped by the platform, written serially, and reset on sign-out. Web and unsupported launchers are a no-op rather than a crash.</p></div>
</div>
<div class="split" style="margin-top:3mm">
  <div><div class="label">Connectivity transitions</div>
    <table class="compact"><thead><tr><th style="width:32mm">Transition</th><th>Behaviour</th></tr></thead><tbody>
      <tr><td>Online → offline</td><td>Strip appears above content; current list stays</td></tr>
      <tr><td>Offline → online</td><td>Notifications and conversations refresh</td></tr>
      <tr><td>Refresh failure</td><td>Content retained; snackbar explains</td></tr>
      <tr><td>Cold start offline</td><td>Cached shell renders; actions report</td></tr>
    </tbody></table>
  </div>
  <div class="card tint"><div class="label">No silent loss</div><p class="small" style="margin:0">A failed refresh never blanks a populated list, and a failed send keeps the draft and the pending row. The user sees the failure and can retry; nothing is quietly discarded.</p></div>
</div>
<div class="label" style="margin-top:3mm">Draft edge cases</div>
<table class="compact"><thead><tr><th style="width:40mm">Case</th><th>Behaviour</th></tr></thead><tbody>
<tr><td>Send fails</td><td>Draft is retained alongside the pending message</td></tr>
<tr><td>Account switch</td><td>Drafts are cleared before the next account loads</td></tr>
<tr><td>Conversation deleted</td><td>Draft is dropped with the thread</td></tr>
</tbody></table>
<div class="callout" style="margin-top:2mm"><p class="small" style="margin:0"><b>Refresh rule:</b> keep what is on screen, fetch in place, and report failure. A spinner that replaces content is treated as a regression.</p></div>
<div class="rule"></div>
<div class="grid-4"><div><div class="label">Commits</div><div class="mono" style="font-size:7.5pt">cb7b96a · 27c3355<br>9df1965</div></div><div><div class="label">Tests at close</div><div class="quote" style="font-family:Comfortaa;font-size:16pt">131</div></div><div><div class="label">Surfaces</div><div class="quote" style="font-family:Comfortaa;font-size:16pt">4</div></div><div><div class="label">Audits</div><div class="quote" style="font-family:Comfortaa;font-size:16pt">3/3</div></div></div>
''', n, total, right="Track B / B0")


def b1(n, total):
    return page(f'''
{sec_head("Track B / B1", "Chat does the small things.", "Mute, unread, drafts, divider, search, copy, retry.")}
<p class="lead" style="width:158mm">B1 turned the chat room from a message list into a manageable inbox. Every action is server-persisted where it must survive a reinstall, and purely local where it does not.</p>
<div class="grid-3">
  <div class="card"><div class="label">Mute</div><h3>Quiet one conversation.</h3><p class="tiny">1h, 8h, 1d, 1w or always. Muted chats suppress banners and local alerts but still count unread; the list keeps a mute icon.</p></div>
  <div class="card"><div class="label">Mark unread</div><h3>Return to it later.</h3><p class="tiny">Server flag, red dot in the list, cleared when the room opens. It does not fabricate a push notification.</p></div>
  <div class="card"><div class="label">Scroll FAB</div><h3>New messages below.</h3><p class="tiny">Appears with a count while scrolled up. Auto-scroll only happens when the user is already at the bottom.</p></div>
  <div class="card"><div class="label">Copy</div><h3>Long-press, one confirmation.</h3><p class="tiny">Clipboard write plus a single snackbar. No duplicate system toast.</p></div>
  <div class="card"><div class="label">Search</div><h3>Find inside the loaded room.</h3><p class="tiny">Results with highlight and jump. Scope is the loaded message window, stated in the sheet.</p></div>
  <div class="card"><div class="label">Unread divider</div><h3>A visible boundary.</h3><p class="tiny">First unread message gets a divider, so returning to a long thread has an obvious anchor.</p></div>
</div>
<div class="split" style="margin-top:3mm">
  <div><div class="label">Mute windows</div>
    <table class="compact"><thead><tr><th style="width:26mm">Duration</th><th>Stored as</th><th style="width:40mm">Expiry</th></tr></thead><tbody>
      <tr><td>1 hour</td><td class="mono">muted_until = now + 1h</td><td>Re-evaluated on read</td></tr>
      <tr><td>8 hours</td><td class="mono">muted_until = now + 8h</td><td>List icon disappears</td></tr>
      <tr><td>1 day</td><td class="mono">muted_until = now + 1d</td><td>Banners resume</td></tr>
      <tr><td>1 week</td><td class="mono">muted_until = now + 7d</td><td>Banners resume</td></tr>
      <tr><td>Always</td><td class="mono">muted_until = null</td><td>Until unmuted</td></tr>
    </tbody></table>
  </div>
  <div class="card tint"><div class="label">Retry</div><p class="small">Failed pending messages retry sequentially and stop at the first renewed failure, so a dead connection does not spin. Reconnect triggers the same path automatically.</p><div class="rule" style="margin:2.6mm 0"></div><p class="tiny" style="margin:0;color:#66695e">Draft integration keeps the composer and the list preview in sync throughout.</p></div>
</div>
<div class="label" style="margin-top:3mm">Action persistence</div>
<table class="compact"><thead><tr><th style="width:36mm">Action</th><th style="width:38mm">Stored where</th><th>Survives reinstall</th><th style="width:36mm">Cleared when</th></tr></thead><tbody>
<tr><td>Mute</td><td class="mono">connection_preferences</td><td>Yes</td><td>Expiry or unmute</td></tr>
<tr><td>Manual unread</td><td class="mono">connection_preferences</td><td>Yes</td><td>Room opens</td></tr>
<tr><td>Draft</td><td>Local per conversation</td><td>No</td><td>Send or sign-out</td></tr>
<tr><td>Unread divider</td><td>Derived from read state</td><td>Yes</td><td>Next read</td></tr>
</tbody></table>
<div class="grid-2" style="margin-top:2mm">
  <div class="card" style="padding:3.2mm"><h4>Search scope</h4><p class="tiny" style="margin:0;color:#66695e">Search runs over the loaded message window and says so. It does not imply full-history search that the client cannot guarantee.</p></div>
  <div class="card" style="padding:3.2mm"><h4>Copy behaviour</h4><p class="tiny" style="margin:0;color:#66695e">Long-press writes to the clipboard and raises one snackbar. There is no second system toast and no silent failure.</p></div>
</div>
<div class="callout" style="margin-top:2mm"><p class="small" style="margin:0"><b>Persistence:</b> mute and manual unread survive a reinstall because they are server rows. Drafts stay on the device and are cleared on sign-out; they are deliberately not synced across devices.</p></div>
<div class="rule"></div>
<div class="grid-4"><div><div class="label">Commits</div><div class="mono" style="font-size:7.5pt">a24048f · 4b18f8a<br>fdd641b</div></div><div><div class="label">Tests at close</div><div class="quote" style="font-family:Comfortaa;font-size:16pt">138</div></div><div><div class="label">Migration</div><div class="quote" style="font-family:Comfortaa;font-size:13pt">003</div></div><div><div class="label">Audits</div><div class="quote" style="font-family:Comfortaa;font-size:16pt">3/3</div></div></div>
''', n, total, right="Track B / B1")


def b2(n, total):
    return page(f'''
{sec_head("Track B / B2", "Lists and Activity carry the same rules.", "One long-press vocabulary.<br>One clear-read contract.")}
<p class="lead" style="width:158mm">B2 pushed chat management and Activity triage to the list level. Actions that were buried in the room became available from the row, and clearing read notifications became a server-side, caller-scoped operation.</p>
<div class="grid-2">
  <div class="card"><div class="label">Chat long-press</div><h3>View profile · Mute · Mark unread · Report · Block.</h3><p class="small">The profile dialog keeps its own block and report paths. Mute and unread reuse the same services as the room, so the list and the thread never disagree.</p></div>
  <div class="card"><div class="label">Activity filters</div><h3>All · Unread · Requests · Updates.</h3><p class="small">Counts on each filter, day groups (Today, Yesterday, date), a filtered empty state, and clear-search recovery. Realtime inserts land in the right group.</p></div>
</div>
<div class="label" style="margin-top:4mm">Clear-read semantics</div>
<table class="compact"><thead><tr><th style="width:38mm">Row state</th><th>What Clear read does</th><th style="width:34mm">Server guarantee</th></tr></thead><tbody>
<tr><td><b>Read</b></td><td>Deleted for the caller</td><td class="mono">read_at is not null</td></tr>
<tr><td><b>Unread</b></td><td>Kept, still counted</td><td>Never touched</td></tr>
<tr><td><b>Other user's rows</b></td><td>Invisible</td><td class="mono">user_id = auth.uid()</td></tr>
<tr><td><b>Failure</b></td><td>List unchanged, error surfaced</td><td>No false success</td></tr>
</tbody></table>
<div class="grid-2" style="margin-top:3mm">
  <div class="card tint"><div class="label">Swipe to read</div><p class="small" style="margin:0">An unread row can be marked read by swipe. The row updates immediately and reconciles with the server; a failure restores the unread state and reports it.</p></div>
  <div class="card"><div class="label">Saved filters</div><p class="small" style="margin:0">Chat role/status and request incoming/sent filters persist per screen, restore on open, and reset through an explicit clear action. A filter can never strand a tab in an empty state with no way back.</p></div>
</div>
<div class="callout" style="margin-top:3mm"><p class="small" style="margin:0"><b>Failure honesty:</b> clear, mute and mark-unread report errors instead of pretending success. The previous optimistic-only paths were replaced with a result the surface can render.</p></div>
<div class="split" style="margin-top:3mm">
  <div><div class="label">Activity group rules</div>
    <table class="compact"><thead><tr><th style="width:26mm">Group</th><th>Rule</th></tr></thead><tbody>
      <tr><td>Today</td><td>Local calendar day</td></tr>
      <tr><td>Yesterday</td><td>Previous local day</td></tr>
      <tr><td>Date</td><td>Absolute date, oldest last</td></tr>
    </tbody></table>
  </div>
  <div class="grid-2" style="gap:3mm">
    <div class="card" style="padding:3.2mm"><h4>Counts</h4><p class="tiny" style="margin:0;color:#66695e">Filter counts come from the same list that is rendered, so a badge cannot disagree with the rows beneath it.</p></div>
    <div class="card" style="padding:3.2mm"><h4>Reset</h4><p class="tiny" style="margin:0;color:#66695e">Clear filters restores the default view and the saved filter is removed, not just visually bypassed.</p></div>
  </div>
</div>
<div class="label" style="margin-top:3mm">Filter persistence</div>
<table class="compact"><thead><tr><th style="width:40mm">Screen</th><th>Saved state</th><th style="width:40mm">Restored</th></tr></thead><tbody>
<tr><td>Chats</td><td>Role and status</td><td>On open</td></tr>
<tr><td>Requests</td><td>Incoming or sent, skill, domain, sort</td><td>On open</td></tr>
<tr><td>Any filtered list</td><td>Explicit clear removes the saved value</td><td>Next open</td></tr>
</tbody></table>
<div class="rule"></div>
<div class="grid-4"><div><div class="label">Commits</div><div class="mono" style="font-size:7.5pt">a25dacd · b8419ca<br>af0f3c4</div></div><div><div class="label">Tests at close</div><div class="quote" style="font-family:Comfortaa;font-size:16pt">141</div></div><div><div class="label">Migration</div><div class="quote" style="font-family:Comfortaa;font-size:13pt">004</div></div><div><div class="label">Audits</div><div class="quote" style="font-family:Comfortaa;font-size:16pt">3/3</div></div></div>
''', n, total, right="Track B / B2")


def b3(n, total):
    return page(f'''
{sec_head("Track B / B3", "The next step, without the nag.", "One prompt at a time.<br>Every empty state has an action.")}
<p class="lead" style="width:158mm">B3 handled the moments after a request, after onboarding, and after a filter returns nothing. The rule was consistent: surface one useful next step, never block the committed action, and never stack two completion prompts.</p>
<div class="grid-3">
  <div class="card"><div class="label">Continue setup</div><h3>Only when setup is incomplete.</h3><p class="small">Appears when onboarding was skipped or a draft exists. Resume restores the review step; dismiss persists per user and the card returns if setup is skipped again.</p></div>
  <div class="card"><div class="label">Profile nudge</div><h3>After the request is committed.</h3><p class="small">Uses the app banner: non-blocking, SafeArea, queued, closable, ten seconds, at most once per session. It never interrupts the send.</p></div>
  <div class="card"><div class="label">Empty states</div><h3>One clear action each.</h3><p class="small">Start swiping, view sent requests or refresh, view requests or show all, update skills or refresh categories. No dead-end copy.</p></div>
</div>
<div class="label" style="margin-top:4mm">Trigger matrix</div>
<table class="compact"><thead><tr><th style="width:40mm">Surface</th><th style="width:52mm">Condition</th><th>Action</th></tr></thead><tbody>
<tr><td><b>Home</b></td><td>Setup incomplete, skipped or draft exists</td><td>Resume review · dismiss per user</td></tr>
<tr><td><b>After request</b></td><td>Send succeeded, profile incomplete</td><td>Profile nudge, once per session</td></tr>
<tr><td><b>Chats filtered empty</b></td><td>Filter returns no rows</td><td>Clear filters or start a chat</td></tr>
<tr><td><b>Requests sent empty</b></td><td>No outgoing requests</td><td>View incoming or refresh</td></tr>
<tr><td><b>Explore empty</b></td><td>No categories for the role</td><td>Update skills or refresh categories</td></tr>
</tbody></table>
<div class="callout" style="margin-top:3mm"><p class="small" style="margin:0"><b>One-prompt rule:</b> Profile shows only one completion prompt at a time. Requests never leaves the tab trapped in the sent view; back always returns to a meaningful screen.</p></div>
<div class="split" style="margin-top:3mm">
  <div><div class="label">Dismissal scope</div>
    <table class="compact"><thead><tr><th style="width:38mm">Prompt</th><th>Stored per</th><th style="width:36mm">Returns when</th></tr></thead><tbody>
      <tr><td>Continue setup</td><td>User</td><td>Setup skipped again</td></tr>
      <tr><td>Profile nudge</td><td>Session</td><td>Next session, once</td></tr>
      <tr><td>What's new</td><td>Version</td><td>New version</td></tr>
    </tbody></table>
  </div>
  <div class="grid-2" style="gap:3mm">
    <div class="card" style="padding:3.2mm"><h4>Resume path</h4><p class="tiny" style="margin:0;color:#66695e">Resume restores the review step with its saved draft; it does not restart onboarding.</p></div>
    <div class="card" style="padding:3.2mm"><h4>Nudge timing</h4><p class="tiny" style="margin:0;color:#66695e">The request is already committed before the nudge appears, so dismissing it never cancels the send.</p></div>
  </div>
</div>
<div class="grid-2" style="margin-top:2mm">
  <div class="card" style="padding:3.2mm"><h4>Dismissal is not failure</h4><p class="tiny" style="margin:0;color:#66695e">Dismissing the resume card hides the prompt, not the draft. The setup data stays until the user completes or clears it.</p></div>
  <div class="card tint" style="padding:3.2mm"><h4>One prompt at a time</h4><p class="tiny" style="margin:0;color:#66695e">Profile calculates which completion prompt to show and renders one; two prompts never compete for the same space.</p></div>
</div>
<div class="callout" style="margin-top:2mm"><p class="small" style="margin:0"><b>Dead-end rule:</b> every empty state names the next action and the action is reachable without leaving the current tab.</p></div>
<div class="rule"></div>
<div class="grid-4"><div><div class="label">Commits</div><div class="mono" style="font-size:7.2pt">2491fc3 · 8110b51 · 3e11df1<br>12afa6e · 26d38a0 · 708316e · bb54994</div></div><div><div class="label">Tests at close</div><div class="quote" style="font-family:Comfortaa;font-size:16pt">145</div></div><div><div class="label">Widths</div><div class="quote" style="font-family:Comfortaa;font-size:15pt">360 · 200%</div></div><div><div class="label">Audits</div><div class="quote" style="font-family:Comfortaa;font-size:16pt">3/3</div></div></div>
''', n, total, right="Track B / B3")


def c0(n, total):
    return page(f'''
{sec_head("Track C / C0", "Privacy is a contract, not a toggle.", "Define the data before showing it.<br>Mask at the server, not the widget.")}
<p class="lead" style="width:158mm">C0 added the status fields and then closed the paths that would have leaked them. The client cannot read connection read timestamps directly, and every presence or receipt value is masked to accepted Pals with the relevant permission on.</p>
<div class="label">Contracts added</div>
<table class="compact"><thead><tr><th style="width:38mm">Contract</th><th>Purpose</th><th style="width:42mm">Access</th></tr></thead><tbody>
<tr><td class="mono">last_seen_at</td><td>Presence timestamp on the profile</td><td>self only, via RPC</td></tr>
<tr><td class="mono">presence_enabled</td><td>Peer may see online / last active</td><td>self write, masked read</td></tr>
<tr><td class="mono">typing_enabled</td><td>Peer may see typing</td><td>self write, masked read</td></tr>
<tr><td class="mono">read_receipts_enabled</td><td>Peer may see Seen</td><td>self write, masked read</td></tr>
<tr><td class="mono">touch_last_seen</td><td>Self-only heartbeat</td><td>SECURITY DEFINER</td></tr>
<tr><td class="mono">get_pals_presence</td><td>Accepted Pals only; mask when off</td><td>authenticated</td></tr>
<tr><td class="mono">set/get_chat_privacy</td><td>Three switches, server-backed</td><td>authenticated</td></tr>
</tbody></table>
<div class="grid-2" style="margin-top:3mm">
  <div class="card"><div class="label">Client may read</div><ul class="checks" style="margin:0"><li>Own privacy settings</li><li>Peer status for accepted Pals when enabled</li><li>Peer read timestamp when receipts are on</li><li>Conversation metadata without receipt columns</li></ul></div>
  <div class="card"><div class="label">Client may not read</div><ul class="checks neg" style="margin:0"><li>Connection table read timestamps directly</li><li>Status for non-Pals or declined connections</li><li>Last seen when presence is off</li><li>Receipts when the peer has them off</li></ul></div>
</div>
<div class="callout" style="margin-top:3mm"><p class="small" style="margin:0"><b>Closing the bypass:</b> migration 007 revokes table SELECT on <span class="mono">connections</span> and grants only id, participants, status, timestamps and skill columns. Read timestamps are reachable only through RPCs that apply the permission.</p></div>
<div class="label" style="margin-top:4mm">Masking matrix</div>
<table class="compact"><thead><tr><th style="width:34mm">Viewer</th><th>Presence off</th><th>Typing off</th><th>Receipts off</th><th>Not a Pal</th></tr></thead><tbody>
<tr><td>Accepted Pal</td><td>No status</td><td>No indicator</td><td>No Seen</td><td>—</td></tr>
<tr><td>Pending request</td><td>No status</td><td>No indicator</td><td>No Seen</td><td>Blocked</td></tr>
<tr><td>Declined</td><td>No status</td><td>No indicator</td><td>No Seen</td><td>Blocked</td></tr>
<tr><td>Self</td><td>Own value</td><td>Own value</td><td>Own value</td><td>—</td></tr>
</tbody></table>
<div class="grid-2" style="margin-top:2mm">
  <div class="card" style="padding:3.2mm"><h4>Load failure</h4><p class="tiny" style="margin:0;color:#66695e">Switches are disabled until server state loads. A failed load shows Retry and never assumes the permissive default.</p></div>
  <div class="card" style="padding:3.2mm"><h4>Reset</h4><p class="tiny" style="margin:0;color:#66695e">Sign-out resets the privacy service. The next account cannot inherit a previous session's switches.</p></div>
</div>
<div class="card tint" style="margin-top:2mm;padding:3.2mm"><h4>Why the server owns this</h4><p class="tiny" style="margin:0;color:#66695e">A client-side hide is a suggestion. The masking lives in the RPC and the grant, so a modified client still cannot read a status the peer turned off.</p></div>
<div class="rule"></div>
<div class="grid-4"><div><div class="label">Commits</div><div class="mono" style="font-size:7.2pt">a79ed63 · 5c1a4fd · 4aaaa02<br>4021a43 · 3fa4a45</div></div><div><div class="label">Tests at close</div><div class="quote" style="font-family:Comfortaa;font-size:16pt">149</div></div><div><div class="label">Migrations</div><div class="quote" style="font-family:Comfortaa;font-size:16pt">3</div></div><div><div class="label">Audits</div><div class="quote" style="font-family:Comfortaa;font-size:16pt">3/3</div></div></div>
''', n, total, right="Track C / C0")


def c1_c2(n, total):
    return page(f'''
{sec_head("Track C / C1 · C2", "Online, typing, and nothing more.", "Presence is a heartbeat.<br>Typing is a broadcast, never a write.")}
<p class="lead" style="width:158mm">Presence and typing were built on the existing chat channel. Both are gated by the peer's privacy flags, both tear down cleanly on leave, and neither exposes a status to someone who is not an accepted Pal.</p>
<div class="grid-2">
  <div class="card"><div class="label">C1 · Presence</div><h3>A 60-second foreground heartbeat.</h3><ul class="small" style="margin-bottom:0"><li>Heartbeat and conversation refresh while resumed.</li><li>Disabled when privacy has not loaded or presence is off.</li><li>Chat list shows green <b>Online</b> or muted <b>Active Nm/h/d</b>; message time stays visible.</li><li>Room subscribes to <span class="mono">chat:&lt;connectionId&gt;</span>, filters the peer by exact user id.</li><li>Channels removed on leave, privacy-off or error without re-entrant teardown.</li></ul></div>
  <div class="card"><div class="label">C2 · Typing</div><h3>Three dots, two seconds, zero rows.</h3><ul class="small" style="margin-bottom:0"><li>Broadcast on the existing chat channel with a 2s throttle.</li><li>Peer expiry after 3s; stop on empty, send or leave.</li><li>No database writes.</li><li>Gated by the local typing setting and the peer's typing flag.</li><li>Works with presence off: the channel joins without tracking presence.</li><li>Typing appears before the first message; the pre-first-message match card stays.</li></ul></div>
</div>
<div class="label" style="margin-top:4mm">Lifecycle</div>
<div class="timeline">
  <div class="t"><div class="no">01</div><b>Resume</b>Session refreshed; privacy state loaded before any track.</div>
  <div class="t"><div class="no">02</div><b>Heartbeat</b>Self last-seen advanced every 60s while presence is on.</div>
  <div class="t"><div class="no">03</div><b>Track</b>Room joins the channel and tracks only when allowed.</div>
  <div class="t"><div class="no">04</div><b>Signal</b>Typing and read broadcasts are throttled and peer-scoped.</div>
  <div class="t"><div class="no">05</div><b>Teardown</b>Leave, pause, privacy-off and error all remove the channel.</div>
</div>
<div class="grid-2" style="margin-top:3mm">
  <div class="card tint"><div class="label">Masking rules</div><p class="small" style="margin:0">When presence is off, the peer receives no online state and no last-seen value. When typing is off, the indicator never renders. When receipts are off, read timestamps are null even if the rows exist.</p></div>
  <div class="card"><div class="label">Edge cases covered</div><p class="small" style="margin:0">Re-enabling presence retracks; typing-only mode still joins; a failed channel recovers; a typing event can arrive before the first message without breaking the match card.</p></div>
</div>
<div class="label" style="margin-top:3mm">Signal rules</div>
<table class="compact"><thead><tr><th style="width:30mm">Signal</th><th style="width:26mm">Transport</th><th style="width:24mm">Cadence</th><th>Expiry / teardown</th></tr></thead><tbody>
<tr><td>Presence</td><td>Channel track</td><td>60s heartbeat</td><td>Leave, pause, privacy off</td></tr>
<tr><td>Typing</td><td>Broadcast</td><td>2s throttle</td><td>3s peer expiry</td></tr>
<tr><td>Receipt</td><td>Broadcast + reload</td><td>Trailing flush</td><td>60s refresh</td></tr>
<tr><td>Online label</td><td>Server contract</td><td>On list refresh</td><td>Masked when off</td></tr>
</tbody></table>
<div class="grid-2" style="margin-top:2mm">
  <div class="card" style="padding:3.2mm"><h4>No status leak</h4><p class="tiny" style="margin:0;color:#66695e">A peer who is not an accepted Pal never receives a track, a typing event or a read timestamp, regardless of the local toggle.</p></div>
  <div class="card tint" style="padding:3.2mm"><h4>No stale state</h4><p class="tiny" style="margin:0;color:#66695e">The 60s heartbeat and the conversation refresh mean a closed app becomes “Active Nm” rather than staying online forever.</p></div>
</div>
<div class="rule"></div>
<div class="grid-4"><div><div class="label">Commits</div><div class="mono" style="font-size:6.9pt">69bec41 · c8bb845 · 38949d7<br>b876970 · 487b85a · 5829b91<br>354ff68 · 8da9b57 · 5bb26dc</div></div><div><div class="label">Tests C1 / C2</div><div class="quote" style="font-family:Comfortaa;font-size:14pt">150 / 152</div></div><div><div class="label">Database writes</div><div class="quote" style="font-family:Comfortaa;font-size:16pt">0</div></div><div><div class="label">Audits</div><div class="quote" style="font-family:Comfortaa;font-size:16pt">6/6</div></div></div>
''', n, total, right="Track C / C1 · C2")


def c3(n, total):
    return page(f'''
{sec_head("Track C / C3", "Seen means the server says so.", "One label, under the last own message.<br>No device-clock authority.")}
<p class="lead" style="width:150mm">C3 added read receipts without reopening the bypass C0 closed. A throttled broadcast is only a hint; the displayed time is always reloaded from the server, so a skewed device clock cannot produce a false Seen.</p>
<div class="split">
  <div>
    <div class="label">Receipt path</div>
    <div class="steps" style="grid-template-columns:1fr;gap:2.4mm">
      <div class="step" style="padding:3mm"><div class="no">01</div><h3>Peer reads</h3><p>Mark-read commits on the server.</p></div>
      <div class="step" style="padding:3mm"><div class="no">02</div><h3>Broadcast hint</h3><p>A throttled read event with a trailing flush reaches the room.</p></div>
      <div class="step" style="padding:3mm"><div class="no">03</div><h3>Server reload</h3><p>The client reloads the conversation timestamp; the broadcast value is discarded.</p></div>
      <div class="step" style="padding:3mm"><div class="no">04</div><h3>Render</h3><p>Seen appears only under the last own message, when receipts are enabled and the timestamp covers it.</p></div>
    </div>
  </div>
  <div style="width:54mm;margin-left:auto">{phone('c3-seen-390b.png', 'Seen', 'Rendered under the last own message only, with server-authoritative time.')}</div>
</div>
<div class="label" style="margin-top:2mm">Gating</div>
<table class="compact"><thead><tr><th style="width:44mm">Condition</th><th>Result</th></tr></thead><tbody>
<tr><td>Peer receipts off</td><td>No Seen, even if the read row exists</td></tr>
<tr><td>Older own message</td><td>No label; only the last own message qualifies</td></tr>
<tr><td>Peer has not read that far</td><td>No label</td></tr>
<tr><td>App backgrounded</td><td>Read broadcasts paused; 60s refresh reconciles</td></tr>
</tbody></table>
<div class="callout" style="margin-top:3mm"><p class="small" style="margin:0"><b>Transport note:</b> receipts use a broadcast plus a 60-second conversation refresh instead of publishing <span class="mono">connections</span>, because C0 made read timestamps RPC-only. A read event can arrive before mark-read commits; the server refresh is the source of truth.</p></div>
<div class="rule"></div>
<div class="grid-4"><div><div class="label">Commits</div><div class="mono" style="font-size:7.5pt">879e593 · 3f468e5<br>98e3b59</div></div><div><div class="label">Tests at close</div><div class="quote" style="font-family:Comfortaa;font-size:16pt">154</div></div><div><div class="label">Clock source</div><div class="quote" style="font-family:Comfortaa;font-size:13pt">Server</div></div><div><div class="label">Audits</div><div class="quote" style="font-family:Comfortaa;font-size:16pt">3/3</div></div></div>
''', n, total, right="Track C / C3")


def d_track(n, total):
    return page(f'''
{sec_head("Track D / D-01 · D-02", "Ship the small wins; defer the fake ones.", "One useful sheet. One honest omission.")}
<p class="lead" style="width:158mm">The final track was intentionally small. D-01 tells returning users what changed once per version. D-02 was deferred because a review prompt without a store listing would lead to a dead link.</p>
<div class="grid-2">
  <div class="card"><div class="label">D-01 · Verified</div><h3>What's new, once per version.</h3><p class="small">A version-gated bottom sheet with three bullets and “Got it”. It is scrollable at 360 and 200%, dismissal persists per version, and the sheet does not appear again after reload.</p><div class="rule" style="margin:2.6mm 0"></div><ul class="checks" style="margin:0"><li>Version key stored locally</li><li>Scrollable at 360 and 200%</li><li>Dismiss persists per version</li><li>Live probe: shown → dismissed → absent after reload</li></ul></div>
  <div class="card"><div class="label">D-02 · Deferred</div><h3>A review prompt without a listing is a dead end.</h3><p class="small">No published store listing exists, so any prompt would be fake or lead nowhere. When a listing exists, the prompt should be gated on a positive feedback or exchange, once per version, and never over a dialog.</p><div class="callout warn" style="margin:2.6mm 0 0;padding:3mm"><p class="tiny" style="margin:0"><b>No code shipped.</b> This is a product decision, not an unfinished implementation.</p></div></div>
</div>
<div class="label" style="margin-top:4mm">Release 2 totals</div>
<table class="compact"><thead><tr><th style="width:44mm">Measure</th><th>Value</th><th style="width:44mm">Note</th></tr></thead><tbody>
<tr><td>Commits</td><td>54</td><td>3ab6700..08de0e8</td></tr>
<tr><td>Files changed</td><td>94</td><td>9,635 insertions · 1,301 deletions</td></tr>
<tr><td>Phases verified</td><td>16 of 18</td><td>A5 blocked · D-02 deferred</td></tr>
<tr><td>Tests</td><td>155 / 155</td><td>Full suite at D-01 close</td></tr>
<tr><td>Migrations</td><td>7</td><td>All applied live</td></tr>
</tbody></table>
<div class="callout" style="margin-top:3mm"><p class="quote" style="font-size:12pt;margin-bottom:1.2mm">The release is complete where it can be complete.</p><p class="small" style="margin:0">Nothing in the shipped scope is waiting on a missing decision. The two open items are external credentials and a store listing, and both are documented as such.</p></div>
<div class="split" style="margin-top:3mm">
  <div><div class="label">D-01 sheet contract</div>
    <table class="compact"><thead><tr><th style="width:36mm">Property</th><th>Behaviour</th></tr></thead><tbody>
      <tr><td>Trigger</td><td>First open of a new version</td></tr>
      <tr><td>Content</td><td>Three bullets, “Got it”</td></tr>
      <tr><td>Dismiss</td><td>Persists per version</td></tr>
      <tr><td>Layout</td><td>Scrollable at 360 and 200%</td></tr>
    </tbody></table>
  </div>
  <div class="grid-2" style="gap:3mm">
    <div class="card" style="padding:3.2mm"><h4>Version gate</h4><p class="tiny" style="margin:0;color:#66695e">The stored key is the version, so a patched release can introduce its own sheet without repeating the last one.</p></div>
    <div class="card" style="padding:3.2mm"><h4>Accessibility</h4><p class="tiny" style="margin:0;color:#66695e">The sheet is scrollable at large text and dismissible from the sheet itself, not only by tapping outside.</p></div>
  </div>
</div>
<div class="grid-2" style="margin-top:2mm">
  <div class="card" style="padding:3.2mm"><h4>Versioned, not global</h4><p class="tiny" style="margin:0;color:#66695e">The dismissal key includes the app version, so a new release can introduce a new sheet without repeating the previous one.</p></div>
  <div class="card tint" style="padding:3.2mm"><h4>Why D-02 waits</h4><p class="tiny" style="margin:0;color:#66695e">A review prompt needs a destination. Asking before a listing exists creates a dead link and a poor store signal.</p></div>
</div>
<div class="rule"></div>
<div class="grid-4"><div><div class="label">Commit</div><div class="mono" style="font-size:8pt">08de0e8</div></div><div><div class="label">Tests</div><div class="quote" style="font-family:Comfortaa;font-size:16pt">155</div></div><div><div class="label">Verified</div><div class="quote" style="font-family:Comfortaa;font-size:16pt">16</div></div><div><div class="label">Deferred</div><div class="quote" style="font-family:Comfortaa;font-size:16pt">1</div></div></div>
''', n, total, right="Track D / D-01 · D-02")
