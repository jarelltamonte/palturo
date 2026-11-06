# -*- coding: utf-8 -*-
"""Data contracts, ledgers, verification, galleries and acceptance."""
from change_docs_common import esc, page, phone, sec_head, src
from change_docs_data import (
    audits, changed, commits, commit_phase, credentials, limitations,
    migrations, probes, test_areas,
)
from change_docs_style import LOGO_WHITE


def migrations_page(n, total):
    rows = "".join(
        f'<tr><td class="case">{esc(mid)}</td><td class="mono" style="font-size:6.2pt">{esc(slug)}</td>'
        f'<td><b>{esc(title)}</b><br><span class="tiny muted">{esc(detail)}</span></td>'
        f'<td class="mono" style="font-size:6.3pt">{esc(contract)}</td></tr>'
        for mid, slug, title, detail, contract in [
            (m[0], m[1].replace("2026110500", "").replace(".sql", ""), m[2], m[3],
             {"001": "notifications → realtime", "002": "list_notifications", "003": "connection_preferences",
              "004": "clear_read_notifications", "005": "chat_privacy RPCs", "006": "get_conversations",
              "007": "connections grants"}[m[0]])
            for m in migrations
        ]
    )
    return page(f'''
{sec_head("Data contracts", "Seven migrations make the interface true.", "All applied live.<br>All committed.")}
<p class="lead" style="width:158mm">The UI is only trustworthy because the database owns the hard rules: who may see a status, which read timestamp is exposed, what a mute stores, and whether a clear-read operation can touch another user's rows.</p>
<table style="margin-top:4mm"><thead><tr><th style="width:10mm">ID</th><th style="width:36mm">Migration</th><th>Purpose</th><th style="width:38mm">Contract</th></tr></thead><tbody>{rows}</tbody></table>
<div class="grid-3" style="margin-top:4mm">
  <div class="metric"><div class="n">7<em>/7</em></div><div class="t">applied live</div></div>
  <div class="metric"><div class="n">0</div><div class="t">invalid live paths</div></div>
  <div class="metric"><div class="n">3</div><div class="t">privacy migrations</div></div>
</div>
<div class="callout warn" style="margin-top:2mm"><p class="small" style="margin:0"><b>Known boundary:</b> the management role cannot alter <span class="mono">realtime.messages</span>, which is owned by <span class="mono">supabase_realtime_admin</span>. Chat topics rely on unguessable connection UUIDs and client-side privacy gating; a dashboard-authored realtime ACL would be required for server-side topic authorization.</p></div>
<div class="rule"></div>
<div class="grid-2"><div><div class="label">Read-only by design</div><p class="small" style="margin:0">Notification reads are scoped by the existing <span class="mono">notif_read</span> policy. Connection read timestamps are not in the table grant at all; they are reachable only through the RPCs that apply the receipt toggle.</p></div><div><div class="label">Write path</div><p class="small" style="margin:0">Mute, manual unread, privacy switches and clear-read are all RPCs. The client does not construct arbitrary updates against these tables.</p></div></div>
''', n, total, right="Data contracts")


def behaviour_page(n, total):
    return page(f'''
{sec_head("Behaviour", "One event, defined for every surface.", "In-app, system, badge.<br>Suppression is explicit.")}
<p class="lead" style="width:158mm">The same event kind produces a predictable set of outputs. The matrix below is the contract the presenter and local-notification service implement; if a row cannot be satisfied, the event is suppressed rather than partially delivered.</p>
<table class="compact" style="margin-top:3mm"><thead><tr><th style="width:30mm">Event</th><th>In-app banner</th><th>Local alert</th><th>Badge</th><th style="width:42mm">Suppressed when</th></tr></thead><tbody>
<tr><td><b>Request</b></td><td>4s, route to Requests</td><td>Category-gated</td><td>+1 activity</td><td>Requests screen is open</td></tr>
<tr><td><b>Accepted</b></td><td>Match banner, ~7s</td><td>Category-gated</td><td>+1 activity</td><td>Active chat for that connection</td></tr>
<tr><td><b>Declined</b></td><td>4s, route to Requests</td><td>Category-gated</td><td>+1 activity</td><td>Requests screen is open</td></tr>
<tr><td><b>Message</b></td><td>Preview or “New message”</td><td>Channel per category</td><td>+1 chat</td><td>That room is active</td></tr>
<tr><td><b>Feedback</b></td><td>4s, route to Activity</td><td>Activity category</td><td>+1 activity</td><td>Activity is open</td></tr>
<tr><td><b>Moderation</b></td><td>4s, route to Activity</td><td>Activity category</td><td>+1 activity</td><td>Activity is open</td></tr>
<tr><td><b>Unknown</b></td><td>Neutral row only</td><td>Never</td><td>No change</td><td>Always</td></tr>
</tbody></table>
<div class="grid-2" style="margin-top:3mm">
  <div class="card tint"><div class="label">Quiet hours</div><p class="small" style="margin:0">Banners still appear; sound and haptics are suppressed. The window is local to the device and does not change server read state.</p></div>
  <div class="card tint"><div class="label">Previews off</div><p class="small" style="margin:0">Message text is replaced with “New message” in both the banner and the system alert. The sender name remains.</p></div>
</div>
<div class="label" style="margin-top:4mm">Desktop shell · 1440 × 900</div>
<div class="wide"><img src="{src('a7-shell-1440.png')}" alt="PalTuro desktop shell at 1440"></div>
<div class="cap"><b>The centred mobile surface is unchanged.</b>At 1440 the app remains a focused 480px column; the dynamic UX work did not introduce a second layout.</div>
''', n, total, right="Behaviour and platform")


def platform_page(n, total):
    return page(f'''
{sec_head("Platform and release", "Capability is stated per platform.", "No shared promise that the code cannot keep.")}
<div class="label">Platform matrix</div>
<table class="compact"><thead><tr><th style="width:44mm">Capability</th><th style="width:34mm">Android</th><th style="width:38mm">iOS</th><th>Web</th></tr></thead><tbody>
<tr><td>In-app banners</td><td><span class="ok">Full</span></td><td><span class="ok">Full</span></td><td><span class="ok">Full</span></td></tr>
<tr><td>Activity + unread</td><td><span class="ok">Full</span></td><td><span class="ok">Full</span></td><td><span class="ok">Full</span></td></tr>
<tr><td>Local notifications</td><td><span class="ok">4 channels</span></td><td><span class="ok">Delegate set</span></td><td><span class="neutral">Best effort</span></td></tr>
<tr><td>Permission request</td><td><span class="ok">Runtime</span></td><td><span class="ok">Runtime</span></td><td><span class="neutral">Browser</span></td></tr>
<tr><td>Launcher badge</td><td><span class="ok">Supported</span></td><td><span class="ok">Supported</span></td><td><span class="neutral">Skipped</span></td></tr>
<tr><td>Presence / typing / receipts</td><td><span class="ok">Full</span></td><td><span class="ok">Source only</span></td><td><span class="ok">Full</span></td></tr>
<tr><td>Killed-app push</td><td><span class="blocked">Blocked</span></td><td><span class="blocked">Blocked</span></td><td><span class="blocked">Blocked</span></td></tr>
</tbody></table>
<div class="label" style="margin-top:5mm">Final gates</div>
<table class="compact"><thead><tr><th style="width:38mm">Gate</th><th>Observed result</th><th style="width:22mm">State</th></tr></thead><tbody>
<tr><td>Analyzer</td><td><span class="mono">flutter analyze --no-pub</span> — clean</td><td><span class="ok">Pass</span></td></tr>
<tr><td>Tests</td><td><span class="mono">flutter test --no-pub</span> — 155/155</td><td><span class="ok">Pass</span></td></tr>
<tr><td>Release web</td><td><span class="mono">flutter build web --release</span> with env defines</td><td><span class="ok">Pass</span></td></tr>
<tr><td>Android debug</td><td><span class="mono">flutter build apk --debug</span> with env defines</td><td><span class="ok">Pass</span></td></tr>
<tr><td>iOS</td><td>Source and config only on this Windows host</td><td><span class="deferred">Mac required</span></td></tr>
<tr><td>Working tree</td><td>Clean after push to <span class="mono">origin/ui-features</span></td><td><span class="ok">Pass</span></td></tr>
</tbody></table>
<div class="grid-3" style="margin-top:4mm">
  <div class="metric"><div class="n">155<em>/155</em></div><div class="t">tests passing</div></div>
  <div class="metric"><div class="n">0</div><div class="t">analyzer issues</div></div>
  <div class="metric"><div class="n">7</div><div class="t">migrations applied</div></div>
</div>
<div class="callout" style="margin-top:2mm"><p class="small" style="margin:0"><b>Verification matrix:</b> 360 / 390 / 1440 · light and dark · 200% text. Home, Activity, Chats, Chat room, Requests, Browse, Profile, Notifications, Chat privacy and the banner surfaces were all exercised.</p></div>
<div class="split" style="margin-top:3mm">
  <div><div class="label">Build artifacts</div>
    <table class="compact"><thead><tr><th style="width:38mm">Artifact</th><th>Source</th><th style="width:24mm">Result</th></tr></thead><tbody>
      <tr><td>Release web</td><td class="mono">08de0e8 + env defines</td><td><span class="ok">Built</span></td></tr>
      <tr><td>Android debug APK</td><td class="mono">08de0e8 + env defines</td><td><span class="ok">Built</span></td></tr>
      <tr><td>iOS source</td><td class="mono">AppDelegate + target 13.0</td><td><span class="deferred">Not compiled</span></td></tr>
      <tr><td>Test binary</td><td class="mono">155 tests</td><td><span class="ok">Pass</span></td></tr>
    </tbody></table>
  </div>
  <div class="grid-2" style="gap:3mm">
    <div class="card" style="padding:3.2mm"><h4>Windows host</h4><p class="tiny" style="margin:0;color:#66695e">Web and Android were built locally. iOS source is verified, but a macOS toolchain is required for a real compile.</p></div>
    <div class="card" style="padding:3.2mm"><h4>Device pass</h4><p class="tiny" style="margin:0;color:#66695e">VoiceOver and TalkBack remain a recommended manual activity; automated semantics and 200% tests are not a substitute.</p></div>
  </div>
</div>
<div class="callout" style="margin-top:2mm"><p class="small" style="margin:0"><b>What the matrix means:</b> a capability marked full has a code path and a test or live probe. A capability marked blocked is intentionally absent and is never described as available.</p></div>
''', n, total, right="Behaviour and platform")


def tests_page(n, total):
    rows = "".join(
        f'<tr><td><b>{esc(area)}</b></td><td class="mono" style="font-size:6.3pt">{esc(files)}</td><td>{esc(focus)}</td></tr>'
        for area, files, focus in test_areas
    )
    return page(f'''
{sec_head("Test coverage", "155 tests across the new surface.", "Unit, widget, semantics and negative paths.")}
<p class="lead" style="width:158mm">The suite grew from 80 tests at the start of the work to 155 at D-01. Coverage follows risk: event parsing and gating, banner lifecycle, chat state, privacy masking, and the text/width combinations most likely to break.</p>
<table style="margin-top:4mm"><thead><tr><th style="width:38mm">Area</th><th style="width:54mm">Files</th><th>Focus</th></tr></thead><tbody>{rows}</tbody></table>
<div class="grid-4" style="margin-top:3mm">
  <div class="metric"><div class="n">155</div><div class="t">tests total</div></div>
  <div class="metric"><div class="n">75</div><div class="t">added in scope</div></div>
  <div class="metric"><div class="n">10</div><div class="t">test areas</div></div>
  <div class="metric"><div class="n">0</div><div class="t">skipped</div></div>
</div>
<div class="grid-2" style="margin-top:2mm">
  <div class="card"><div class="label">Negative paths covered</div><ul class="checks" style="margin:0"><li>Raw SQL and Postgrest text rejected</li><li>Failed clears do not report success</li><li>Privacy load failure disables controls</li><li>Malformed notification payload fails closed</li></ul></div>
  <div class="card tint"><div class="label">Known test boundary</div><p class="small" style="margin:0">Some interaction paths (name sheet in the earlier release, several request flows, and live presence) are verified by audit and live probes rather than full widget tests. Manual VoiceOver/TalkBack remains a device activity.</p></div>
</div>
<div class="callout" style="margin-top:3mm"><p class="small" style="margin:0"><b>Live probes:</b> {esc(' · '.join(probes))}</p></div>
''', n, total, right="Test coverage")


def commits_page(n, total, part):
    per_page = 27
    start = (part - 1) * per_page
    subset = commits[start:start + per_page]
    rows = []
    for i, (h, date, subject) in enumerate(subset, start=start + 1):
        phase = commit_phase.get(h, "—")
        rows.append(
            f'<tr><td class="mono" style="font-size:6.1pt;color:#66695e">{i:02d}</td>'
            f'<td class="mono" style="font-size:6.3pt">{esc(h)}</td>'
            f'<td class="mono" style="font-size:6pt;color:#66695e">{esc(date)}</td>'
            f'<td class="case" style="font-size:6.4pt">{esc(phase)}</td>'
            f'<td style="font-size:6.6pt">{esc(subject)}</td></tr>'
        )
    if part == 1:
        extra = '''
<div class="split" style="margin-top:2mm">
  <div><div class="label">Commits by track</div>
    <table class="compact"><thead><tr><th style="width:10mm">Track</th><th style="width:22mm">Commits</th><th>Phases</th></tr></thead><tbody>
      <tr><td class="case">A</td><td>19</td><td>A0–A6 · foundation, banners, feedback, local delivery</td></tr>
      <tr><td class="case">B</td><td>16</td><td>B0–B3 · primitives, chat, lists, polish</td></tr>
      <tr><td class="case">C</td><td>18</td><td>C0–C3 · contracts, presence, typing, receipts</td></tr>
      <tr><td class="case">D</td><td>1</td><td>D-01 · what's new</td></tr>
    </tbody></table>
  </div>
  <div class="card tint"><div class="label">Reading the ledger</div><p class="small" style="margin:0">Hashes are abbreviated, dates are author dates, and the phase column maps each commit to the work item that closed it. The range is frozen at <span class="mono">08de0e8</span>; documentation commits are deliberately absent.</p></div>
</div>
<div class="callout" style="margin-top:2mm"><p class="small" style="margin:0"><b>Counts reconcile:</b> 19 Track A commits + 16 Track B + 18 Track C + 1 Track D = 54. A7 is verification-only and contributes no commit.</p></div>'''
    else:
        extra = '''
<div class="grid-3" style="margin-top:2mm">
  <div class="card" style="padding:3.2mm"><div class="label">Largest phase</div><h4>B3 · seven commits</h4><p class="tiny" style="margin:0;color:#66695e">Contextual polish carried the most commit-level iteration because it touched six screens and three empty-state families.</p></div>
  <div class="card" style="padding:3.2mm"><div class="label">Test growth</div><h4>80 → 155</h4><p class="tiny" style="margin:0;color:#66695e">Seventy-five tests were added across ten areas; no test was skipped and the suite was green at every phase close.</p></div>
  <div class="card" style="padding:3.2mm"><div class="label">Scope boundary</div><h4>Source only</h4><p class="tiny" style="margin:0;color:#66695e">The HTML, PDF and generator commits that follow this range are documentation and are not counted as product work.</p></div>
</div>
<div class="callout" style="margin-top:3mm"><p class="small" style="margin:0"><b>Traceability:</b> every phase page in this record names its commits; every commit in this ledger maps back to a phase. Nothing in the range is unexplained.</p></div>'''

    return page(f'''
{sec_head(f"Commit ledger {'I' if part == 1 else 'II'}", f"Commits {start + 1}–{start + len(subset)} of 54.", f"3ab6700..08de0e8<br>Newest last.")}
<table class="ledger" style="margin-top:2mm"><thead><tr><th style="width:8mm">#</th><th style="width:20mm">Hash</th><th style="width:19mm">Date</th><th style="width:12mm">Phase</th><th>Subject</th></tr></thead><tbody>{''.join(rows)}</tbody></table>
<div class="rule"></div>
<div class="grid-3"><div><div class="label">Range</div><p class="small" style="margin:0"><span class="mono">3ab6700..08de0e8</span></p></div><div><div class="label">Total</div><p class="small" style="margin:0">54 commits · 94 files</p></div><div><div class="label">Docs excluded</div><p class="small" style="margin:0">Pages after 08de0e8 are documentation only.</p></div></div>
{extra}
''', n, total, right="Commit ledger")


def files_page(n, total, part):
    per_page = 47
    start = (part - 1) * per_page
    subset = changed[start:start + per_page]
    rows = []
    for status, path in subset:
        area = path.split("/")[0] if "/" in path else "root"
        rows.append(
            f'<tr><td class="case" style="font-size:6.1pt">{esc(status)}</td>'
            f'<td>{esc(path)}</td><td class="area">{esc(area)}</td></tr>'
        )
    return page(f'''
{sec_head(f"File inventory {'I' if part == 1 else 'II'}", f"Paths {start + 1}–{start + len(subset)} of 94.", f"A/M/D as recorded<br>by the source diff.")}
<table class="files" style="margin-top:2mm"><thead><tr><th style="width:11mm">Status</th><th>Path</th><th style="width:24mm">Area</th></tr></thead><tbody>{''.join(rows)}</tbody></table>
<div class="rule"></div>
<div class="grid-3"><div><div class="label">Source of truth</div><p class="small" style="margin:0"><span class="mono">git diff --name-status 3ab6700..08de0e8</span></p></div><div><div class="label">Files</div><p class="small" style="margin:0">94 changed · 9,635 insertions · 1,301 deletions</p></div><div><div class="label">Scope</div><p class="small" style="margin:0">Documentation commits after the source freeze are excluded.</p></div></div>
''', n, total, right="File inventory")


def limitations_page(n, total):
    rows = "".join(
        f'<tr><td><b>{esc(item)}</b></td><td>{esc(detail)}</td></tr>'
        for item, detail in limitations
    )
    return page(f'''
{sec_head("Limitations", "What is explicitly not claimed.", "Documented, owned, outside the shipped scope.")}
<p class="lead" style="width:158mm">The release has one external blocker and five accepted boundaries. None is an unresolved defect inside the sixteen verified phases, but each changes what the product may safely promise.</p>
<table style="margin-top:4mm"><thead><tr><th style="width:42mm">Item</th><th>Status and handling</th></tr></thead><tbody>{rows}</tbody></table>
<div class="callout risk" style="margin-top:4mm"><p style="font-family:Comfortaa;font-size:12pt;line-height:1.24;margin-bottom:1.2mm">Release hold: none inside the shipped scope.</p><p class="small" style="margin:0">A5 is a delivery gap, not a hidden failure. The correct public claim is in-app notifications, Activity, badges and local alerts while the process is alive — not killed-app push.</p></div>
<div class="rule"></div>
<div class="grid-2"><div><div class="label">Operational follow-ups</div><ul class="tight small" style="margin:0"><li>Add Firebase, APNs, VAPID and a service account to unblock A5.</li><li>Compile and device-test iOS on macOS.</li><li>Add a dashboard realtime topic policy if server-side ACLs are required.</li></ul></div><div><div class="label">Product follow-ups</div><ul class="tight small" style="margin:0"><li>D-02 waits for a real store listing.</li><li>Background receipts reconcile within the next poll.</li><li>Consider a broader read for presence if product wants roots, not leaves.</li></ul></div></div>
<div class="label" style="margin-top:4mm">Safe release wording</div>
<table class="compact"><thead><tr><th style="width:52mm">Claim</th><th style="width:22mm">State</th><th>Use instead</th></tr></thead><tbody>
<tr><td>Killed-app push</td><td><span class="blocked">Not shipped</span></td><td>“Notifications work in-app and while the Android process is alive.”</td></tr>
<tr><td>Guaranteed iOS background</td><td><span class="blocked">Not shipped</span></td><td>“Local alerts are wired; device delivery still needs a macOS build.”</td></tr>
<tr><td>Server-side realtime ACL</td><td><span class="deferred">Partial</span></td><td>“Topics use unguessable connection ids and client privacy gating.”</td></tr>
<tr><td>Store review prompt</td><td><span class="deferred">Deferred</span></td><td>“Planned once a published store listing exists.”</td></tr>
</tbody></table>
<div class="grid-2" style="margin-top:2mm">
  <div class="card" style="padding:3.2mm"><h4>A5 unblock checklist</h4><p class="tiny" style="margin:0;color:#66695e">Firebase project · Android/iOS/web apps · APNs .p8 · VAPID key · service account. No client redesign is required.</p></div>
  <div class="card tint" style="padding:3.2mm"><h4>Device QA</h4><p class="tiny" style="margin:0;color:#66695e">A macOS build and a physical VoiceOver/TalkBack pass remain recommended before public release.</p></div>
</div>
<div class="callout" style="margin-top:2mm"><p class="small" style="margin:0"><b>What is not on this list:</b> crashes, data loss, unrecoverable states or silent write failures inside the shipped surfaces. The limitations are scope boundaries and external dependencies, not hidden defects.</p></div>
''', n, total, right="Limitations")


def operations_page(n, total):
    rows = "".join(
        f'<tr><td class="mono" style="font-size:6.6pt">{esc(name)}</td><td>{esc(detail)}</td></tr>'
        for name, detail in credentials
    )
    return page(f'''
{sec_head("Operations", "What the credentials unlock.", "A5 is an infrastructure task, not a redesign.")}
<p class="lead" style="width:158mm">Nothing in the client needs to be re-architected for push. The remaining work is identity: a Firebase project, platform configuration files, an APNs key, a web VAPID key and a service account for the sender.</p>
<div class="split">
  <div><div class="label">Required inputs</div>
    <table class="compact"><thead><tr><th style="width:50mm">Credential</th><th>Purpose</th></tr></thead><tbody>{rows}</tbody></table>
  </div>
  <div class="card tint"><div class="label">Safe state today</div><ul class="checks" style="margin:0"><li>In-app banners route correctly</li><li>Activity receives realtime inserts</li><li>Local alerts work while alive</li><li>Badges reflect unread totals</li><li>Resume reconciles missed events</li><li>No killed-app claim is made</li></ul></div>
</div>
<div class="label" style="margin-top:4mm">When credentials arrive</div>
<div class="steps">
  <div class="step"><div class="no">01</div><h3>Register the apps</h3><p>Create the Firebase project and register the release application id for Android, iOS and web.</p></div>
  <div class="step"><div class="no">02</div><h3>Place identity files</h3><p>Add <span class="mono">google-services.json</span>, <span class="mono">GoogleService-Info.plist</span>, APNs .p8 and the VAPID key.</p></div>
  <div class="step"><div class="no">03</div><h3>Deploy the sender</h3><p>Add the service account to the edge function and send through FCM HTTP v1 with the same event kinds.</p></div>
</div>
<div class="callout" style="margin-top:3mm"><p class="small" style="margin:0"><b>Order matters:</b> the topic, payload and routing contract already exist. A5 should reuse them; it should not invent a second notification model.</p></div>
<div class="label" style="margin-top:4mm">Rollout sequence</div>
<div class="timeline" style="grid-template-columns:repeat(4,1fr)">
  <div class="t"><div class="no">01</div><b>Configure</b>Firebase project and the three app registrations.</div>
  <div class="t"><div class="no">02</div><b>Install identity</b>Place the Android, iOS and web credential files.</div>
  <div class="t"><div class="no">03</div><b>Send</b>Deploy the FCM HTTP v1 edge function and token refresh.</div>
  <div class="t"><div class="no">04</div><b>Verify</b>Test killed-app delivery on Android and iOS before claiming it.</div>
</div>
<div class="label" style="margin-top:3mm">Post-rollout verification</div>
<table class="compact"><thead><tr><th style="width:44mm">Check</th><th>Pass condition</th></tr></thead><tbody>
<tr><td>Token registration</td><td>Token stored, refreshed, and removed on sign-out</td></tr>
<tr><td>Foreground</td><td>One alert only; in-app banner remains primary</td></tr>
<tr><td>Background</td><td>Local alert follows the same category and quiet-hours gates</td></tr>
<tr><td>Killed app</td><td>Push received and routed to the correct surface</td></tr>
</tbody></table>
<div class="rule"></div>
<div class="grid-3"><div><div class="label">Client changes</div><p class="small" style="margin:0">Small: token registration and foreground handler.</p></div><div><div class="label">Server changes</div><p class="small" style="margin:0">One sender path in an edge function.</p></div><div><div class="label">Release claim</div><p class="small" style="margin:0">Update only after device verification.</p></div></div>
''', n, total, right="Operations")


def audit_page(n, total):
    rows = "".join(
        f'<tr><td class="case">{esc(phase)}</td><td class="mono" style="font-size:5.8pt;color:#66695e">{esc(date)}</td>'
        f'<td class="mono" style="font-size:5.35pt">{esc(a)}</td>'
        f'<td class="mono" style="font-size:5.35pt">{esc(b)}</td>'
        f'<td class="mono" style="font-size:5.35pt">{esc(c)}</td>'
        f'<td class="mono" style="font-size:6.1pt">{esc(commit)}</td></tr>'
        for phase, date, a, b, c, commit in audits
    )
    return page(f'''
{sec_head("Audit ledger", "Every phase has three independent sessions.", "Functionality, quality, regression.<br>No phase advanced until all three agreed.")}
<p class="lead" style="width:158mm">Audits were read-only. Each reviewer inspected the implemented tree, the tests and the live state without editing files. Session IDs are recorded verbatim below so the review trail can be reopened.</p>
<table class="ledger" style="margin-top:3mm"><thead><tr><th style="width:10mm">Phase</th><th style="width:16mm">Date</th><th>Functionality</th><th>Quality</th><th>Regression</th><th style="width:16mm">Commit</th></tr></thead><tbody>{rows}</tbody></table>
<div class="grid-3" style="margin-top:3mm">
  <div class="metric"><div class="n">42</div><div class="t">audit sessions</div></div>
  <div class="metric"><div class="n">14</div><div class="t">phases reviewed</div></div>
  <div class="metric"><div class="n">0</div><div class="t">blocking findings</div></div>
</div>
<div class="callout" style="margin-top:2mm"><p class="small" style="margin:0"><b>Coverage note:</b> D-01 closed on the full suite and a live once-per-version probe. A7 was verification-only and has no separate audit triplet; its gates are recorded in the release section.</p></div>
<div class="rule"></div>
<div class="grid-2"><div><div class="label">What auditors checked</div><ul class="tight small" style="margin:0"><li>Acceptance intent, primary and failure paths</li><li>Real server contracts and live probes</li><li>Dark mode, 200% text, 360/390/1440</li><li>Adjacent flows and regression suite</li></ul></div><div><div class="label">What closed a finding</div><ul class="tight small" style="margin:0"><li>A reproducing test or live probe</li><li>A fix in the same phase</li><li>Re-run of the full suite</li><li>A second reviewer pass</li></ul></div></div>
<div class="label" style="margin-top:4mm">Audit outcomes</div>
<table class="compact"><thead><tr><th style="width:30mm">Result</th><th>Meaning</th><th style="width:26mm">Count</th></tr></thead><tbody>
<tr><td><b>Pass</b></td><td>All three lenses agreed; phase closed</td><td>14 phases</td></tr>
<tr><td><b>Fix + re-audit</b></td><td>Blocking finding fixed before close</td><td>Recorded in phase pages</td></tr>
<tr><td><b>Verification only</b></td><td>A7 gates, no separate audit triplet</td><td>1 phase</td></tr>
<tr><td><b>Blocked</b></td><td>A5 credentials absent; not reviewed as shipped</td><td>1 item</td></tr>
</tbody></table>
<div class="callout" style="margin-top:2mm"><p class="small" style="margin:0"><b>Independence:</b> the three reviews were read-only and did not edit the tree. A phase only advanced when functionality, quality and regression all passed.</p></div>
''', n, total, right="Audit ledger")


def gallery_1(n, total):
    return page(f'''
{sec_head("Visual evidence 01 / 05", "Live events and notification controls.", "Captured from release and debug builds.<br>390 × 844 unless noted.")}
<p class="small" style="width:166mm;color:#66695e;margin-bottom:2mm">Three banner states and the notification preferences page in both themes. Banners sit at the top, preserve the current screen, and expose one route-aware action.</p>
<div class="gallery">
  {phone('a1-declined-banner-final-390.png', 'Request declined', 'Top banner with a route back to Requests.')}
  {phone('a1-match-banner-dark-final-390.png', 'New match, dark', 'Skill line and Say hello; once per connection.')}
  {phone('a1-message-banner-dark2-390.png', 'New message', 'Sender, preview and tap-to-chat.')}
  {phone('a3-notifications-page-light-390.png', 'Preferences, light', 'Delivery, categories, preview, sound, quiet hours.')}
  {phone('a3-notifications-page-dark-390.png', 'Preferences, dark', 'The same hierarchy in the charcoal theme.')}
  <div class="note-card"><h4>What to look for</h4><ul><li>Banner clears the status bar and app bar.</li><li>Exactly one primary action per banner.</li><li>Dark mode keeps the lime accent and contrast.</li><li>Settings reports real permission state, not a promise.</li></ul><p class="tiny" style="margin:3mm 0 0;color:#66695e">Frames are ordered as captured. No state was reconstructed for this document.</p><div class="label" style="margin-top:3mm">Frame index</div><table><tbody><tr><td>01</td><td>Declined banner</td></tr><tr><td>02</td><td>Match, dark</td></tr><tr><td>03</td><td>Message, dark</td></tr><tr><td>04</td><td>Preferences, light</td></tr><tr><td>05</td><td>Preferences, dark</td></tr></tbody></table><div class="tiny" style="margin-top:auto;padding-top:3mm;border-top:.2mm solid #d8d5c8;color:#66695e;line-height:1.5">Capture set · 5 frames<br>390 × 844 · release web<br>5 November 2026</div></div>
</div>
''', n, total, right="Visual evidence")


def gallery_2(n, total):
    return page(f'''
{sec_head("Visual evidence 02 / 05", "Permissions, connectivity and drafts.", "States that are easy to fake.<br>These are captured from real transitions.")}
<p class="small" style="width:166mm;color:#66695e;margin-bottom:2mm">The permission surface distinguishes not-asked from denied; the offline strip occupies layout space above the app bar; drafts survive leaving the composer; the chat menu exposes the full action set.</p>
<div class="gallery">
  {phone('a4-notifications-permission-390.png', 'Permission state', 'Real system state with the correct next action.')}
  {phone('b0-offline-fixed-390.png', 'Offline strip', 'Above the app bar; navigation stays tappable.')}
  {phone('b0-draft-list-390.png', 'Draft preview', 'Per-chat draft after leaving the composer.')}
  {phone('b1-chat-menu-390.png', 'Chat menu', 'Profile, feedback, mute, unread, search, report, block.')}
  {phone('b1-mute-sheet-390.png', 'Mute durations', 'One hour through until turned back on.')}
  <div class="note-card"><h4>State honesty</h4><ul><li>Permission copy changes with the OS answer.</li><li>Offline never covers a control.</li><li>Draft text is scoped to one conversation.</li><li>Mute is server-persisted, not a local flag.</li></ul><p class="tiny" style="margin:3mm 0 0;color:#66695e">Each frame is a live transition, not a mocked screen. Demo profiles are fictional.</p><div class="label" style="margin-top:3mm">Frame index</div><table><tbody><tr><td>01</td><td>Permission state</td></tr><tr><td>02</td><td>Offline strip</td></tr><tr><td>03</td><td>Draft preview</td></tr><tr><td>04</td><td>Chat menu</td></tr><tr><td>05</td><td>Mute durations</td></tr></tbody></table><div class="tiny" style="margin-top:auto;padding-top:3mm;border-top:.2mm solid #d8d5c8;color:#66695e;line-height:1.5">Capture set · 5 frames<br>390 × 844 · Android debug<br>5 November 2026</div></div>
</div>
''', n, total, right="Visual evidence")


def gallery_3(n, total):
    return page(f'''
{sec_head("Visual evidence 03 / 05", "Chat controls in use.", "Mute, unread, navigation, search, copy.<br>All from the same room.")}
<p class="small" style="width:166mm;color:#66695e;margin-bottom:2mm">The room now carries the management affordances that make a long thread navigable: a muted-state list, a first-unread divider, a counted scroll FAB, in-room search and a single copy confirmation.</p>
<div class="gallery">
  {phone('b1-muted-list-390.png', 'Muted chat', 'Mute icon retained; unread still counts.')}
  {phone('b1-unread-divider-390.png', 'Unread divider', 'The first unread message gets a boundary.')}
  {phone('b1-fab-count-390.png', 'Scroll FAB', 'New-message count while scrolled up.')}
  {phone('b1-search-390.png', 'In-chat search', 'Results over the loaded message window.')}
  {phone('b1-copied-390.png', 'Copy confirmation', 'One snackbar after the clipboard write.')}
  <div class="note-card"><h4>Room rules</h4><ul><li>Auto-scroll only when already at the bottom.</li><li>Muted chats suppress alerts, not unread.</li><li>Search states its scope.</li><li>Copy does not double-toast.</li></ul><p class="tiny" style="margin:3mm 0 0;color:#66695e">The room is shown at 390 with the real composer and navigation present.</p><div class="label" style="margin-top:3mm">Frame index</div><table><tbody><tr><td>01</td><td>Muted list</td></tr><tr><td>02</td><td>Unread divider</td></tr><tr><td>03</td><td>Scroll FAB</td></tr><tr><td>04</td><td>In-chat search</td></tr><tr><td>05</td><td>Copy confirmation</td></tr></tbody></table><div class="tiny" style="margin-top:auto;padding-top:3mm;border-top:.2mm solid #d8d5c8;color:#66695e;line-height:1.5">Capture set · 5 frames<br>390 × 844 · release web<br>5 November 2026</div></div>
</div>
''', n, total, right="Visual evidence")


def gallery_4(n, total):
    return page(f'''
{sec_head("Visual evidence 04 / 05", "Lists, Activity and contextual polish.", "Triage from the row.<br>One prompt at a time.")}
<p class="small" style="width:166mm;color:#66695e;margin-bottom:2mm">Activity filters and clear-read act on real rows; the chat row exposes the same actions as the room; the profile nudge and the version-gated what's-new sheet stay non-blocking.</p>
<div class="gallery">
  {phone('b2-activity-filters-390.png', 'Activity filters', 'All, unread, requests and updates with counts.')}
  {phone('b2-clear-read-confirm-390.png', 'Clear read', 'Confirmation; unread rows are never deleted.')}
  {phone('b2-chat-longpress-390.png', 'Chat long-press', 'Profile, mute, unread, report and block.')}
  {phone('b3-nudge-banner-390.png', 'Profile nudge', 'After a committed request; once per session.')}
  {phone('d-whatsnew-390.png', "What's new", 'One sheet per version, dismiss persists.')}
  <div class="note-card"><h4>Prompt discipline</h4><ul><li>Never block a completed action.</li><li>Never stack two completion prompts.</li><li>Every empty state has one action.</li><li>Dismissal is scoped per user or version.</li></ul><p class="tiny" style="margin:3mm 0 0;color:#66695e">List and prompt states are shown together to make the interruption budget visible.</p><div class="label" style="margin-top:3mm">Frame index</div><table><tbody><tr><td>01</td><td>Activity filters</td></tr><tr><td>02</td><td>Clear read</td></tr><tr><td>03</td><td>Chat long-press</td></tr><tr><td>04</td><td>Profile nudge</td></tr><tr><td>05</td><td>What's new</td></tr></tbody></table><div class="tiny" style="margin-top:auto;padding-top:3mm;border-top:.2mm solid #d8d5c8;color:#66695e;line-height:1.5">Capture set · 5 frames<br>390 × 844 · release web<br>5 November 2026</div></div>
</div>
''', n, total, right="Visual evidence")


def gallery_5(n, total):
    return page(f'''
{sec_head("Visual evidence 05 / 05", "Privacy, presence and read receipts.", "The status layer, as a peer sees it.<br>Masked at the server.")}
<div class="gallery-wide">
  {phone('c0-chat-privacy-390.png', 'Chat privacy', 'Online, typing, receipts, Pals only.')}
  {phone('c1-chat-list-presence-390.png', 'Online in the list', 'Message time remains visible.')}
  {phone('c1-chat-room-presence-390.png', 'Online in the room', 'Under the peer name.')}
  {phone('c3-seen-390b.png', 'Seen', 'Only the last own message, server time.')}
</div>
<div class="grid-2" style="margin-top:6mm">
  <div class="card tint"><div class="label">Presence state machine</div>
    <table class="compact" style="margin-top:1mm"><tbody>
      <tr><td><b>Allowed</b></td><td>Track; heartbeat every 60s; show Online or last active.</td></tr>
      <tr><td><b>Off</b></td><td>No track, no heartbeat, no status returned.</td></tr>
      <tr><td><b>Not loaded</b></td><td>Controls disabled; no optimistic track.</td></tr>
      <tr><td><b>Leave / pause</b></td><td>Remove channel; stop heartbeat.</td></tr>
      <tr><td><b>Error</b></td><td>Teardown once; retry without re-entrancy.</td></tr>
    </tbody></table>
  </div>
  <div class="card"><div class="label">Receipt rules</div><ul class="checks" style="margin:0"><li>Seen only under the last own message.</li><li>Only when the peer allows receipts.</li><li>Only when the server timestamp covers it.</li><li>Broadcast is a hint; server reload is the source.</li><li>Backgrounded broadcasts pause; 60s refresh reconciles.</li></ul></div>
</div>
<div class="callout" style="margin-top:3mm"><p class="small" style="margin:0"><b>Consistency:</b> the privacy page, the list and the room all read the same server-masked contract. Turning presence off removes the status everywhere, not just where the toggle was rendered.</p></div>
<div class="split" style="margin-top:2mm">
  <div><div class="label">Visibility by setting</div>
    <table class="compact"><thead><tr><th style="width:30mm">Setting</th><th>List</th><th>Room</th><th>Receipts</th></tr></thead><tbody>
      <tr><td>All on</td><td>Online / Active</td><td>Online</td><td>Seen</td></tr>
      <tr><td>Presence off</td><td>Message time</td><td>No status</td><td>Seen if allowed</td></tr>
      <tr><td>Typing off</td><td>—</td><td>No dots</td><td>Seen if allowed</td></tr>
      <tr><td>Receipts off</td><td>—</td><td>No Seen</td><td>Hidden</td></tr>
    </tbody></table>
  </div>
  <div class="grid-2" style="gap:3mm">
    <div class="card" style="padding:3.2mm"><h4>Peer view</h4><p class="tiny" style="margin:0;color:#66695e">The list and room never show a status the server did not return for that viewer.</p></div>
    <div class="card" style="padding:3.2mm"><h4>Local view</h4><p class="tiny" style="margin:0;color:#66695e">The owner always sees their own switch state, even when the peer sees nothing.</p></div>
  </div>
</div>
<div class="card tint" style="margin-top:2mm;padding:3.2mm"><h4>One contract, three surfaces</h4><p class="tiny" style="margin:0;color:#66695e">The privacy page writes the flags, the conversation RPC masks them per viewer, and the list and room render only what the RPC returned. There is no local “pretend offline” path.</p></div>
''', n, total, right="Visual evidence")


def acceptance(n, total):
    return page(f'''
{sec_head("Acceptance", "Sixteen verified phases. One honest gap.", "Final position at 08de0e8.")}
<div class="big">16 / 16</div>
<div class="big-sub">verified phases accepted within the shipped scope</div>
<div class="grid-2">
  <div>
    <p class="lead">Every planned item except A5 and D-02 has a working implementation, a quality review, a regression review, a commit and recorded verification. The release build is current and the tree is clean.</p>
    <div class="kv" style="margin-top:4mm">
      <div class="k">Branch</div><div class="v">ui-features @ 08de0e8</div>
      <div class="k">Phases</div><div class="v">16 verified · 1 blocked · 1 deferred</div>
      <div class="k">Audits</div><div class="v">42 sessions · 0 blocking findings</div>
      <div class="k">Tests</div><div class="v">155 / 155</div>
      <div class="k">Analyzer</div><div class="v">clean</div>
      <div class="k">Migrations</div><div class="v">7 applied live</div>
      <div class="k">Commit range</div><div class="v">3ab6700..08de0e8 · 54 commits</div>
      <div class="k">Push delivery</div><div class="v">Blocked on credentials</div>
    </div>
  </div>
  <div class="card tint"><div class="label">Release statement</div><p class="small">Notifications work in-app and through a background process on Android. Activity, badges, banners, local alerts and server reconciliation are verified. Killed-app delivery and guaranteed iOS background delivery are not claimed.</p><div class="rule" style="margin:3mm 0"></div><p class="small" style="margin:0"><b>D-02</b> remains deferred until a store listing exists. <b>A5</b> remains blocked until Firebase, APNs, VAPID and a service account are supplied.</p></div>
</div>
<div class="callout" style="margin-top:5mm"><p class="quote" style="font-size:12.6pt;margin-bottom:1.2mm">The product is quieter, more legible, and more truthful about what it knows.</p><p class="small" style="margin:0">Acceptance is based on three independent audits per phase, live database probes, the final suite, both builds, and the captures in this record.</p></div>
<div class="label" style="margin-top:4mm">Release readiness</div>
<table class="compact"><thead><tr><th style="width:40mm">Area</th><th>State</th><th style="width:34mm">Evidence</th></tr></thead><tbody>
<tr><td>In-app notifications</td><td><span class="ok">Ready</span></td><td>Banner probes, widget tests</td></tr>
<tr><td>Activity and badge</td><td><span class="ok">Ready</span></td><td>Filters, clear-read, badge math</td></tr>
<tr><td>Chat quality of life</td><td><span class="ok">Ready</span></td><td>Mute, drafts, divider, search</td></tr>
<tr><td>Privacy and presence</td><td><span class="ok">Ready</span></td><td>ACL probes, masking tests</td></tr>
<tr><td>Killed-app push</td><td><span class="blocked">Blocked</span></td><td>A5 credentials</td></tr>
</tbody></table>
<div class="grid-2" style="margin-top:2mm">
  <div class="card" style="padding:3.2mm"><h4>Ships</h4><p class="tiny" style="margin:0;color:#66695e">Banners, Activity, local alerts while alive, badges, drafts, mute, unread, search, presence, typing, receipts and what's new.</p></div>
  <div class="card tint" style="padding:3.2mm"><h4>Does not ship</h4><p class="tiny" style="margin:0;color:#66695e">Killed-app push, guaranteed iOS background delivery and the store review prompt. Each is recorded with its dependency.</p></div>
</div>
<div class="sign">
  <div><div class="line"></div><div class="who">Product / design acceptance</div></div>
  <div><div class="line"></div><div class="who">Engineering verification · 5 November 2026</div></div>
</div>
''', n, total, right="Acceptance")


def back(n, total):
    return f'''
<section class="page dark">
  <div class="inner">
    <img src="{LOGO_WHITE}" alt="PalTuro" style="width:44mm;margin-bottom:24mm">
    <div class="kicker" style="color:#d8f400;margin-bottom:4mm">End of report</div>
    <div class="quote" style="font-size:29pt;line-height:1.06;width:128mm">One event system.<br><span style="color:#d8f400">Sixteen verified phases.</span></div>
    <div style="position:absolute;left:15mm;bottom:28mm;font-size:6.8pt;color:#aeb1a2">Dynamic UX, QOL &amp; social presence · implementation &amp; verification<br><b style="color:#f6f4ed;font-size:7.6pt">ui-features @ 08de0e8 · 5 November 2026</b></div>
  </div>
  <div class="ring" style="position:absolute;width:150mm;height:150mm;right:-60mm;top:-50mm;border:.35mm solid rgba(216,244,0,.24);border-radius:50%"></div>
  <div class="ring" style="position:absolute;width:95mm;height:95mm;right:-18mm;top:-12mm;border:.35mm solid rgba(216,244,0,.55);border-radius:50%"></div>
  <div class="footer"><span>PalTuro · community-based Filipino skill exchange</span><span class="num">{n:02d} / {total:02d}</span></div>
</section>'''
