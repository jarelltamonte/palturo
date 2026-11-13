# -*- coding: utf-8 -*-
"""Build the PalTuro visual audit report (A4, fixed pages)."""
import base64
import html
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TMP = Path.home() / "AppData" / "Local" / "Temp" / "opencode"
OUT = ROOT / "docs" / "PalTuro-Visual-Audit-2026-11-05.html"
TOTAL = 10


def esc(value):
    return html.escape(str(value))


def image(name):
    path = TMP / name
    if not path.exists():
        path = ROOT / name
    return "data:image/png;base64," + base64.b64encode(path.read_bytes()).decode()


def shot(name, caption, width=None):
    style = f" style='width:{width}mm'" if width else ""
    return (
        f"<figure class='shot'{style}><img src='{image(name)}' alt=''>"
        f"<figcaption>{esc(caption)}</figcaption></figure>"
    )


def page(content, n, cls=""):
    return (
        f"<section class='page {cls}'><div class='inner'>{content}</div>"
        f"<div class='footer'><span>PalTuro · visual audit · 5 November 2026</span>"
        f"<span class='num'>{n:02d} / {TOTAL:02d}</span></div></section>"
    )


CSS = """
@page { size: 210mm 297mm; margin: 0; }
* { box-sizing: border-box; }
body { margin:0; font-family:'Segoe UI','Inter',Arial,sans-serif; color:#1b1d17; background:#d6d3c8; font-size:9.4pt; line-height:1.45; }
.page { position:relative; width:210mm; height:297mm; background:#f6f4ed; overflow:hidden; page-break-after:always; }
.page:last-child { page-break-after:auto; }
.inner { position:absolute; inset:0; padding:15mm 16mm 17mm; }
.footer { position:absolute; left:16mm; right:16mm; bottom:7mm; border-top:.25mm solid #d8d5c8; padding-top:2mm; display:flex; justify-content:space-between; font-size:5.8pt; letter-spacing:.1em; text-transform:uppercase; color:#66695e; }
.footer .num { font-weight:700; color:#31342b; }
h1,h2,h3 { font-family:'Inter','Segoe UI',sans-serif; margin:0; letter-spacing:-.03em; }
h1 { font-size:31pt; line-height:1.02; }
h2 { font-size:18pt; line-height:1.08; margin:0 0 3mm; }
h3 { font-size:10.2pt; margin:0 0 1.8mm; }
p { margin:0 0 2.6mm; }
ul { margin:0 0 2mm; padding-left:4mm; }
li { margin-bottom:1.2mm; }
.kicker { font-size:6.2pt; letter-spacing:.18em; text-transform:uppercase; color:#5c6b00; font-weight:700; margin-bottom:2.2mm; }
.label { font-size:5.9pt; letter-spacing:.15em; text-transform:uppercase; color:#5c6b00; font-weight:700; margin-bottom:1.5mm; }
.muted { color:#66695e; }
.small { font-size:7.7pt; line-height:1.4; }
.tiny { font-size:6.5pt; line-height:1.35; }
.mono { font-family:'Cascadia Mono',Consolas,monospace; font-size:6.8pt; color:#5c6b00; }
.top { display:flex; justify-content:space-between; border-bottom:.35mm solid #d8d5c8; padding-bottom:2mm; margin-bottom:5mm; font-size:6pt; letter-spacing:.16em; text-transform:uppercase; color:#66695e; }
.top b { color:#5c6b00; }
.sec-head { display:flex; justify-content:space-between; gap:8mm; align-items:flex-end; margin-bottom:4mm; }
.sec-head h2 { max-width:142mm; margin:0; }
.sec-head .side { max-width:50mm; margin:0; text-align:right; font-size:7.1pt; color:#66695e; }
.rule { height:.3mm; background:#d8d5c8; margin:4mm 0; }
.grid-2 { display:grid; grid-template-columns:1fr 1fr; gap:5mm; }
.grid-3 { display:grid; grid-template-columns:repeat(3,1fr); gap:4mm; }
.grid-4 { display:grid; grid-template-columns:repeat(4,1fr); gap:3mm; }
.card { background:#fffefa; border:.3mm solid #d8d5c8; border-radius:2.6mm; padding:4mm; }
.card.tint { background:#eeece2; }
.callout { background:linear-gradient(120deg,#e9f6a8,#f4f9d7); border-left:1.8mm solid #c4df00; padding:3.8mm 4.6mm; border-radius:1mm; margin:3mm 0; }
.callout.warn { background:#fbf2dd; border-left-color:#c58a2b; }
.callout.risk { background:#f9e8e5; border-left-color:#a2453a; }
.metric-grid { display:grid; grid-template-columns:repeat(4,1fr); gap:3mm; margin:4mm 0; }
.metric { background:#eeece2; border:.3mm solid #d8d5c8; border-radius:2.6mm; padding:3.4mm; }
.metric .n { font-size:20pt; line-height:1; font-weight:700; }
.metric .n em { font-style:normal; font-size:9pt; color:#5c6b00; }
.metric .t { font-size:5.9pt; letter-spacing:.12em; text-transform:uppercase; color:#66695e; margin-top:1.6mm; line-height:1.3; }
table { width:100%; border-collapse:collapse; }
th { font-size:5.8pt; letter-spacing:.1em; text-transform:uppercase; text-align:left; color:#66695e; border-bottom:.35mm solid #c7c4b5; padding:1.6mm 1.2mm; }
td { font-size:7.2pt; line-height:1.32; border-bottom:.2mm solid #d8d5c8; padding:1.5mm 1.2mm; vertical-align:top; }
tr:last-child td { border-bottom:none; }
.pill { display:inline-block; padding:.6mm 1.9mm; border-radius:9mm; font-size:5.2pt; font-weight:700; letter-spacing:.07em; text-transform:uppercase; white-space:nowrap; }
.pill.high { background:#f7dfdb; color:#8d332a; border:.2mm solid #dfb3ac; }
.pill.med { background:#f6ecd2; color:#7a5a00; border:.2mm solid #ddc48c; }
.pill.low { background:#eeece2; color:#66695e; border:.2mm solid #d8d5c8; }
.pill.pass { background:#eef6c9; color:#4f6000; border:.2mm solid #c8d88f; }
.shot { margin:0; background:#fff; border:.35mm solid #c7c4b5; border-radius:3mm; padding:1.8mm; page-break-inside:avoid; }
.shot img { display:block; width:100%; border-radius:2mm; }
.shot figcaption { font-size:6.2pt; line-height:1.3; color:#66695e; padding:1.3mm .5mm 0; }
.row { display:grid; gap:3mm; align-items:start; }
.row.two { grid-template-columns:1fr 1fr; }
.row.three { grid-template-columns:repeat(3,1fr); }
.split { display:grid; grid-template-columns:1.08fr .92fr; gap:6mm; align-items:start; }
.kv { display:grid; grid-template-columns:32mm 1fr; gap:1.5mm 3mm; font-size:7.5pt; }
.kv .k { font-size:5.9pt; letter-spacing:.11em; text-transform:uppercase; color:#66695e; }
.kv .v { font-weight:700; }
.cover { background:radial-gradient(circle at 92% 88%,rgba(191,225,9,.2),transparent 34%),#1a1c16; color:#f6f4ed; }
.cover .inner { padding:18mm; }
.cover .logo { width:48mm; margin-bottom:30mm; }
.cover h1 { font-size:40pt; color:#fff; max-width:120mm; }
.cover h1 .lime { color:#d8f400; }
.cover .sub { font-size:15pt; line-height:1.2; color:#d7d9cc; margin-top:5mm; max-width:110mm; }
.cover .desc { font-size:8.8pt; line-height:1.5; color:#b3b6a8; max-width:106mm; margin-top:5mm; }
.cover .metrics { display:flex; gap:3.5mm; margin-top:10mm; width:106mm; }
.cover .metric { background:rgba(255,255,255,.06); border:.3mm solid rgba(255,255,255,.14); border-radius:2mm; padding:3mm; flex:1; }
.cover .metric .n { color:#d8f400; font-size:17pt; }
.cover .metric .t { color:#b7baab; }
.cover .phone { position:absolute; right:16mm; top:44mm; width:60mm; border:.5mm solid #4b4e3e; border-radius:6mm; overflow:hidden; box-shadow:0 12mm 26mm rgba(0,0,0,.5); transform:rotate(1.5deg); }
.cover .phone img { display:block; width:100%; }
.cover .meta { position:absolute; left:18mm; bottom:22mm; right:18mm; display:flex; gap:10mm; border-top:.25mm solid #3a3a3a; padding-top:3mm; font-size:6.5pt; color:#9a9e92; }
.cover .meta b { display:block; color:#f6f4ed; margin-top:1mm; }
.cover-toc { position:absolute; left:18mm; right:18mm; bottom:78mm; display:grid; grid-template-columns:repeat(3,1fr); gap:5mm; border-top:.25mm solid #3a3a3a; padding-top:3.5mm; }
.cover-toc div { font-size:6.4pt; letter-spacing:.12em; text-transform:uppercase; color:#8f9387; }
.cover-toc span { display:block; color:#d8f400; font-size:5.8pt; margin-bottom:1.4mm; }
.cover-toc b { display:block; color:#e8eadf; font-size:8.2pt; letter-spacing:0; text-transform:none; font-weight:600; margin-bottom:.8mm; }
.cover-toc em { font-style:normal; color:#9ca092; letter-spacing:.06em; }
"""


def cover():
    return f"""
<section class='page cover'><div class='inner'>
  <img class='logo' src='{image("assets/images/hlogo_white.png")}' alt='PalTuro'>
  <div class='kicker' style='color:#d8f400'>Product &amp; interface review · 5 November 2026</div>
  <h1>Visual <span class='lime'>audit</span><br>and consistency review</h1>
  <div class='sub'>What looks broken, what is merely inconsistent, and what to fix first.</div>
  <div class='desc'>A Playwright audit of the live auth page and the current app at 390 px, 1440 px, light and dark. Evidence includes screen captures, measured positions, and source references.</div>
  <div class='metrics'>
    <div class='metric'><div class='n'>12</div><div class='t'>surfaces reviewed</div></div>
    <div class='metric'><div class='n'>8</div><div class='t'>findings</div></div>
    <div class='metric'><div class='n'>2</div><div class='t'>high severity</div></div>
    <div class='metric'><div class='n'>0</div><div class='t'>crash paths</div></div>
  </div>
  <div class='phone'><img src='{image("audit-home-loaded.png")}' alt='PalTuro home'></div>
  <div class='cover-toc'>
    <div><span>01</span><b>Executive summary</b><em>page 02</em></div>
    <div><span>02</span><b>Findings V-01 – V-08</b><em>pages 03–09</em></div>
    <div><span>03</span><b>Remediation order</b><em>page 10</em></div>
  </div>
  <div class='meta'>
    <div>BRANCH<b>ui-features</b></div>
    <div>METHOD<b>Playwright · 390 / 1440</b></div>
    <div>ACCOUNT<b>fresh, profile incomplete</b></div>
    <div>PREPARED FOR<b>PalTuro product team</b></div>
  </div>
</div></section>"""


def p2():
    return page(f"""
{head("Release position", "The core flows work. First-run onboarding and loading are the weak points.", "A visual review, not a code-change report.", "Executive summary")}
<p>Twelve surfaces were reviewed with Playwright at 390 × 844 and 1440 × 900, including the live auth page. The account was freshly created and onboarding was skipped, so the audit reflects a new user as well as the empty-state system.</p>
<div class='metric-grid'>
  <div class='metric'><div class='n'>2</div><div class='t'>high severity</div></div>
  <div class='metric'><div class='n'>4</div><div class='t'>medium severity</div></div>
  <div class='metric'><div class='n'>2</div><div class='t'>low / copy</div></div>
  <div class='metric'><div class='n'>0</div><div class='t'>horizontal overflow</div></div>
</div>
<table><thead><tr><th style='width:12mm'>ID</th><th style='width:22mm'>Severity</th><th>Finding</th><th style='width:28mm'>Surface</th></tr></thead><tbody>
<tr><td class='mono'>V-01</td><td><span class='pill high'>High</span></td><td>Role cards stretch to fill the page, leaving three tall empty columns.</td><td>Onboarding</td></tr>
<tr><td class='mono'>V-02</td><td><span class='pill high'>High</span></td><td>Home shows a large skeleton for roughly 10–12 seconds before the deck appears.</td><td>For You</td></tr>
<tr><td class='mono'>V-03</td><td><span class='pill med'>Medium</span></td><td>Empty states sit at different vertical positions on Chats, Requests, and Activity.</td><td>Lists</td></tr>
<tr><td class='mono'>V-04</td><td><span class='pill med'>Medium</span></td><td>Profile header wraps long names and leaves empty skill cards.</td><td>Profile</td></tr>
<tr><td class='mono'>V-05</td><td><span class='pill med'>Medium</span></td><td>Top-right icon centers and target sizes differ by 2–4 px.</td><td>Chrome</td></tr>
<tr><td class='mono'>V-06</td><td><span class='pill med'>Medium</span></td><td>Browse content runs under the floating bottom navigation.</td><td>Browse</td></tr>
<tr><td class='mono'>V-07</td><td><span class='pill low'>Low</span></td><td>Notification settings ends mid-section at 844 px with no bottom breathing room.</td><td>Settings</td></tr>
<tr><td class='mono'>V-08</td><td><span class='pill low'>Low</span></td><td>“Pal 0” copy, Activity empty-state hierarchy, onboarding hyphen, media crop.</td><td>Multiple</td></tr>
</tbody></table>
<div class='callout'><p class='small' style='margin:0'><b>Verdict:</b> the visual system is coherent in Settings, Account, Chat privacy, and the auth page. The failures are concentrated in onboarding and the first Home load, plus a set of small chrome/empty-state drifts.</p></div>
<div class='grid-3' style='margin-top:4mm'>
  <div class='card'><div class='label'>Method</div><p class='small'>Playwright + Chrome, semantic tree navigation, screenshots, DOM/geometry measurements.</p></div>
  <div class='card'><div class='label'>Evidence</div><p class='small'>Live pages, 390/1440 captures, console timing, and source references.</p></div>
  <div class='card'><div class='label'>Limits</div><p class='small'>No iOS build; no physical device pass; deck was reached but not swiped for every card.</p></div>
</div>
<h3 style='margin-top:5mm'>Severity definitions</h3>
<div class='grid-4'>
  <div class='card'><div class='label'>High</div><p class='small'>Blocks comprehension or first-run trust. Fix before release.</p></div>
  <div class='card'><div class='label'>Medium</div><p class='small'>Visible inconsistency on a common path. Fix in the next pass.</p></div>
  <div class='card'><div class='label'>Low</div><p class='small'>Copy or composition polish. Batch with adjacent work.</p></div>
  <div class='card tint'><div class='label'>Info</div><p class='small'>Working surface recorded as evidence, not a defect.</p></div>
</div>
<div class='callout' style='margin-top:4mm'><p class='small' style='margin:0'><b>How to read this report.</b> Each finding has an ID (V-01 to V-08), a severity, measured evidence, a likely root cause, and a recommendation. Page 10 orders the fixes by user impact. Screenshots come from the current build; no source files were changed in this pass.</p></div>
""", 2)


def head(kicker, title, side, top="Visual audit"):
    return f"<div class='top'><span>PalTuro / visual audit</span><span><b>{esc(top)}</b></span></div><div class='sec-head'><div><div class='kicker'>{kicker}</div><h2>{title}</h2></div><p class='side'>{side}</p></div>"


def p3():
    return page(f"""
{head("V-01 / onboarding", "The role cards fill the page with empty space.", "High severity · step 1 of 4")}
<p>At 390 × 844 the three role cards run from about <b>107 px to 757 px</b> — roughly <b>650 px tall and 105 px wide</b>. The icon and label sit near the bottom third, leaving about <b>358 px of empty card above</b> and <b>227 px below</b>. It reads as three empty columns, not three choices.</p>
<div class='split' style='margin-top:3mm'>
  <div>
    <div class='label'>What the user sees</div>
    <ul class='small'>
      <li>Card top: ~107 px; card bottom: ~757 px.</li>
      <li>Card width: ~105 px; gap: 6 px.</li>
      <li>Icon/label near 465–530 px.</li>
      <li>Continue and “Do this later” stay pinned at 768/818 px.</li>
    </ul>
    <div class='callout risk' style='margin-top:3mm'><p class='small' style='margin:0'><b>Root cause:</b> <span class='mono'>onboarding_scaffold.dart:140</span> gives the step body an <span class='mono'>Expanded(Center(child))</span>; the role row then lets each <span class='mono'>AnimatedContainer</span> fill the available height. The card has no content-height constraint.</p></div>
    <div class='label' style='margin-top:4mm'>Recommendation</div>
    <ul class='small'>
      <li>Constrain the role group to a content height (about 150–190 px) or use <span class='mono'>IntrinsicHeight</span>.</li>
      <li>Center the row vertically as a group, not each card to the page.</li>
      <li>At narrow widths, consider three compact horizontal cards or a 2 + 1 grid.</li>
      <li>Keep the primary button area unchanged.</li>
    </ul>
    <div class='label' style='margin-top:4mm'>Measured vs target</div>
    <table><thead><tr><th>Attribute</th><th style='width:26mm'>Now</th><th style='width:26mm'>Target</th></tr></thead><tbody>
      <tr><td>Card height</td><td>~650 px</td><td>≤ 200 px</td></tr>
      <tr><td>Card width</td><td>~105 px</td><td>≥ 160 px</td></tr>
      <tr><td>Empty card above</td><td>~358 px</td><td>0 px</td></tr>
      <tr><td>Group vertical center</td><td>page center</td><td>content center</td></tr>
    </tbody></table>
  </div>
  <div>{shot("ob-1.png", "Onboarding role step at 390 × 844. Three tall columns, content pinned low.", 82)}</div>
</div>
<div class='callout warn' style='margin-top:2mm'><p class='small' style='margin:0'><b>Severity:</b> High. This is the first substantive screen after login and the most visibly broken layout in the audit.</p></div>
<div class='grid-3' style='margin-top:3mm'>
  <div class='card'><div class='label'>Option A</div><p class='small'>Content-height cards, centred as a group. Smallest change.</p></div>
  <div class='card'><div class='label'>Option B</div><p class='small'>Two cards on top, one full-width below. Best for narrow screens.</p></div>
  <div class='card tint'><div class='label'>Option C</div><p class='small'>Full-width horizontal rows with icon at left. Most scannable.</p></div>
</div>
""", 3)


def p4():
    return page(f"""
{head("V-02 / first load", "Home shows a giant skeleton for 10–12 seconds.", "High severity · For You")}
<p>The fresh account lands on a <b>328 × 690 px</b> grey skeleton with the copy “Loading recommendations”. The deck only appears after roughly <b>10–12 seconds</b>. Console output confirms two match requests and 14 people, so the data path works — the feedback does not.</p>
<div class='row two' style='margin-top:3mm'>
  {shot("audit-home-after-outside.png", "First paint: a full-card skeleton, no progress, no timeout.", 45)}
  {shot("audit-home-loaded.png", "After ~12 s: the real deck. The card is 328 × 690.", 45)}
</div>
<div class='grid-3' style='margin-top:3mm'>
  <div class='card'><div class='label'>Measured</div><p class='small'>Skeleton card 328 × 690. Deck 328 × 690. No horizontal overflow.</p></div>
  <div class='card'><div class='label'>Timing</div><p class='small'>Data arrived after ~12 s; no visible timeout or retry before that.</p></div>
  <div class='card'><div class='label'>Root cause</div><p class='small'><span class='mono'>home_page.dart:774</span> shows the skeleton while <span class='mono'>_loading</span>; the fetch has no short timeout or progressive state.</p></div>
</div>
<div class='callout warn' style='margin-top:3mm'><p class='small' style='margin:0'><b>Recommendation:</b> add a request timeout and a staged state: skeleton for ~1.5 s, then “Still looking…” with a retry, then empty/error. Cache the previous deck and render it immediately on return.</p></div>
<div class='callout' style='margin-top:2mm'><p class='small' style='margin:0'><b>Why it matters:</b> a new user’s first impression is a blank grey card. The deck itself is visually strong once it appears.</p></div>
<h3 style='margin-top:4mm'>Observed load timeline</h3>
<div class='grid-4'>
  <div class='card'><div class='label'>0-2 s</div><p class='small'>Full-card skeleton, no progress label beyond "Loading recommendations".</p></div>
  <div class='card'><div class='label'>2-4 s</div><p class='small'>No change; the screen still reads as broken or empty.</p></div>
  <div class='card'><div class='label'>4-10 s</div><p class='small'>No retry or fallback. The skeleton remains the only feedback.</p></div>
  <div class='card tint'><div class='label'>~12 s</div><p class='small'>Deck appears with 14 people. The data was available after two match calls.</p></div>
</div>
""", 4)


def p5():
    return page(f"""
{head("V-03 / empty states", "The same empty state sits at three different heights.", "Medium severity · Chats, Requests, Activity")}
<p>Chats centers its ghost around <b>y ≈ 500 px</b>. Requests places the same ghost around <b>y ≈ 700 px</b>. Activity has no illustration at all and centers its text around <b>y ≈ 430 px</b>. The patterns are related but not one system.</p>
<div class='row three' style='margin-top:3mm'>
  {shot("audit-tab-chats.png", "Chats: ghost + copy + Start swiping.", 43)}
  {shot("audit-tab-requests.png", "Requests: ghost pushed low, Refresh below.", 43)}
  {shot("audit-activity.png", "Activity: text only, no illustration.", 43)}
</div>
<div class='grid-2' style='margin-top:3mm'>
  <div class='card'><div class='label'>Difference</div><p class='small'>Chats and Requests use the same ghost asset but different layout containers. Activity uses a different component entirely.</p></div>
  <div class='card tint'><div class='label'>Recommendation</div><p class='small'>Create one <span class='mono'>EmptyState</span> widget: optional illustration, one heading, one body, one action, centered in the remaining viewport with the same 32 px horizontal inset.</p></div>
</div>
<div class='callout' style='margin-top:3mm'><p class='small' style='margin:0'><b>Target:</b> Chats, Requests, Activity, Pals, Activity filters, and Browse empty states should share the same vertical rhythm and action placement.</p></div>
<h3 style='margin-top:4mm'>Measured empty states</h3>
<table><thead><tr><th style='width:28mm'>Surface</th><th style='width:28mm'>Visual center</th><th style='width:34mm'>Illustration</th><th>Action</th></tr></thead><tbody>
<tr><td><b>Chats</b></td><td>y = 500</td><td>Ghost</td><td>Start swiping</td></tr>
<tr><td><b>Requests</b></td><td>y = 700</td><td>Ghost</td><td>Refresh</td></tr>
<tr><td><b>Activity</b></td><td>y = 430</td><td>None</td><td>View requests</td></tr>
<tr><td><b>Pals / filters</b></td><td>varies</td><td>varies</td><td>varies</td></tr>
</tbody></table>
""", 5)


def p6():
    return page(f"""
{head("V-04 / profile", "The header grows around the name instead of clamping it.", "Medium severity · Profile and Account")}
<p>The test account’s display name wraps onto two lines and pushes “Edit” against the first line. The avatar is a <b>95 px</b> circle, and the Skills to Learn / Skills to Teach sections render as large empty cards with only a heading.</p>
<div class='row two' style='margin-top:3mm'>
  {shot("audit-tab-profile.png", "Profile: wrapped name, Edit beside line one, empty skill cards.", 45)}
  {shot("audit-account2.png", "Account: long email and display name still fit, but row height grows.", 45)}
</div>
<div class='grid-2' style='margin-top:3mm'>
  <div class='card'><div class='label'>What is wrong</div><ul class='small'><li>Name has no line clamp or ellipsis.</li><li>Edit is vertically aligned to the first line, not the header block.</li><li>Empty skills cards have no empty-state copy or CTA.</li><li>Avatar dominates the card at 95 px.</li></ul></div>
  <div class='card tint'><div class='label'>Recommendation</div><ul class='small'><li>Clamp the name to one line with ellipsis (or a fixed two-line box).</li><li>Place Edit at the top-right of the card, independent of wrapping.</li><li>Reduce avatar to 72–80 px.</li><li>Empty skills: “Add skills” action inside the section.</li></ul></div>
</div>
<div class='callout' style='margin-top:3mm'><p class='small' style='margin:0'><b>Note:</b> the long email is test data, but the layout must survive a 25-character name. It currently changes the card height.</p></div>
<h3 style='margin-top:4mm'>Name stress matrix</h3>
<table><thead><tr><th style='width:20mm'>Length</th><th>Observed</th><th style='width:34mm'>Expected</th></tr></thead><tbody>
<tr><td>12 chars</td><td>Single line; fits.</td><td>Single line.</td></tr>
<tr><td>20 chars</td><td>Still single line.</td><td>Single line or ellipsis.</td></tr>
<tr><td>25 chars</td><td>Wraps into two lines; card grows.</td><td>Ellipsis or fixed two-line box.</td></tr>
<tr><td>40 chars</td><td>Would wrap further; Edit remains on line one.</td><td>Clamp; Edit anchored top-right.</td></tr>
</tbody></table>
""", 6)


def p7():
    return page(f"""
{head("V-05 / chrome", "The trailing icons are close, but not the same system.", "Medium severity · page chrome")}
<p>The rightmost action is centered at <b>350 px</b> on Browse and Profile and <b>352 px</b> on Home, Chats, and Requests. The target is 48 px on some bars and 44 px on others. The 2 px drift is small, but it is visible when moving between tabs.</p>
<table style='margin-top:2mm'><thead><tr><th style='width:34mm'>Screen</th><th>Rightmost center</th><th>Target</th><th>Other actions</th></tr></thead><tbody>
<tr><td><b>Home</b></td><td>352 px</td><td>44</td><td>264, 308</td></tr>
<tr><td><b>Browse</b></td><td>350 px</td><td>48</td><td>—</td></tr>
<tr><td><b>Chats</b></td><td>352 px</td><td>44</td><td>304</td></tr>
<tr><td><b>Requests</b></td><td>352 px</td><td>44</td><td>306</td></tr>
<tr><td><b>Profile</b></td><td>350 px</td><td>48</td><td>—</td></tr>
<tr><td><b>Activity</b></td><td>—</td><td>48</td><td>conditional</td></tr>
</tbody></table>
<div class='row two' style='margin-top:2mm'>
  {shot("audit-tab-browse.png", "Browse: help at 350, 48 px target.", 42)}
  {shot("audit-tab-chats.png", "Chats: search 304, filter 352, 44 px targets.", 42)}
</div>
<div class='callout warn' style='margin-top:2mm'><p class='small' style='margin:0'><b>Recommendation:</b> use <span class='mono'>AppChrome.iconAction</span> for every trailing action and one 48 px target. The two-pixel drift is a symptom of hand-rolled 44 px boxes, not a spacing-token problem.</p></div>
<h3 style='margin-top:3mm'>Action spacing</h3>
<table><thead><tr><th style='width:30mm'>Bar</th><th>First action</th><th>Second</th><th>Gap</th></tr></thead><tbody>
<tr><td><b>Home</b></td><td>264</td><td>308 / 352</td><td>44</td></tr>
<tr><td><b>Chats</b></td><td>304</td><td>352</td><td>48</td></tr>
<tr><td><b>Requests</b></td><td>306</td><td>352</td><td>46</td></tr>
<tr><td><b>Browse / Profile</b></td><td>350</td><td>-</td><td>-</td></tr>
</tbody></table>
""", 7)


def p8():
    return page(f"""
{head("V-06 / V-07", "Two content edges still need work.", "Medium + low · Browse and Settings")}
<p><b>Browse</b> scrolls its last row under the floating bottom navigation. There is no visible bottom inset, so a category looks cut off even though the page can scroll. <b>Notifications</b> ends mid-section at 844 px: “Quiet hours” is below the fold with no bottom breathing room.</p>
<div class='row two' style='margin-top:3mm'>
  {shot("audit-tab-browse.png", "Browse: last row meets the floating nav.", 45)}
  {shot("audit-notif-settings2.png", "Notifications: content ends at the viewport edge mid-section.", 45)}
</div>
<div class='grid-2' style='margin-top:3mm'>
  <div class='card'><div class='label'>Browse fix</div><p class='small'>Add bottom padding equal to the nav height + 16 px to the scrollable list, or make the nav part of the layout rather than an overlay.</p></div>
  <div class='card tint'><div class='label'>Settings fix</div><p class='small'>Use the same 24 px section rhythm and a 24–32 px bottom inset. Keep “Quiet hours” visible as a section start, not a clipped fragment.</p></div>
</div>
<div class='callout' style='margin-top:3mm'><p class='small' style='margin:0'><b>Pattern:</b> both are bottom-inset problems, not hierarchy problems. A shared page scroll padding token would close them.</p></div>
<h3 style='margin-top:4mm'>Shared bottom-inset spec</h3>
<table><thead><tr><th style='width:34mm'>Element</th><th>Current</th><th style='width:40mm'>Target</th></tr></thead><tbody>
<tr><td>Browse list bottom</td><td>No nav-aware inset</td><td>Nav height + 16</td></tr>
<tr><td>Settings / Notifications</td><td>16 px</td><td>32 px</td></tr>
<tr><td>Section rhythm</td><td>20 / 24 mixed</td><td>24</td></tr>
<tr><td>Activity / Chats empty</td><td>Different centers</td><td>Shared EmptyState</td></tr>
</tbody></table>
""", 8)


def p9():
    return page(f"""
{head("V-08 / low findings", "Small copy and composition issues.", "Low severity · multiple")}
<div class='grid-2'>
  <div class='card'><div class='label'>Copy</div><ul class='small'><li><b>Profile:</b> “Pal 0” should be “0 Pals” or “Pals 0”.</li><li><b>Onboarding:</b> “Step 1 of 4 - Role” uses a hyphen; use an en dash or a stacked label.</li><li><b>Activity:</b> empty state has no illustration while Chats and Requests do.</li></ul></div>
  <div class='card tint'><div class='label'>Composition</div><ul class='small'><li><b>Home media:</b> the card image is extremely cropped (DRAFT fills the frame); choose a focal point or a softer fit for portrait media.</li><li><b>Auth:</b> the browser form is consistent at 390 and 1440; no finding.</li><li><b>Shell:</b> 1440 keeps the 480 px centred column; no overflow.</li></ul></div>
</div>
<h3 style='margin-top:5mm'>What works</h3>
<div class='grid-3'>
  <div class='card'><div class='label'>Auth page</div><p class='small'>Form, inline errors, light/dark, and 390/1440 all hold. The reset page is the strongest surface in the audit.</p></div>
  <div class='card'><div class='label'>Settings system</div><p class='small'>Settings, Account, Notifications, and Chat privacy share the same row rhythm and icon language.</p></div>
  <div class='card'><div class='label'>Chrome</div><p class='small'>Pushed pages start titles at 64 px; root tabs at 16 px. The bottom nav is consistent across tabs.</p></div>
</div>
<div class='row two' style='margin-top:3mm'>
  {shot("ctx-auth-dark.png", "Auth page, dark, desktop.", 44)}
  {shot("audit-settings.png", "Settings hierarchy at 390.", 34)}
</div>
<h3 style='margin-top:4mm'>Coverage and status</h3>
<table><thead><tr><th style='width:38mm'>Surface</th><th style='width:24mm'>390 px</th><th style='width:24mm'>1440 px</th><th>Result</th></tr></thead><tbody>
<tr><td><b>Auth / reset</b></td><td>Pass</td><td>Pass</td><td>No finding; strongest surface.</td></tr>
<tr><td><b>Onboarding</b></td><td>Fail</td><td>Pass</td><td>V-01 role cards.</td></tr>
<tr><td><b>For You</b></td><td>Fail</td><td>Pass</td><td>V-02 first load; V-08 media.</td></tr>
<tr><td><b>Browse</b></td><td>Fail</td><td>Pass</td><td>V-06 bottom inset.</td></tr>
<tr><td><b>Chats / Requests / Activity</b></td><td>Partial</td><td>Pass</td><td>V-03 empty-state drift.</td></tr>
<tr><td><b>Profile / Account</b></td><td>Fail</td><td>Pass</td><td>V-04 name wrap; V-08 copy.</td></tr>
<tr><td><b>Settings / Notifications</b></td><td>Partial</td><td>Pass</td><td>V-07 bottom breathing room.</td></tr>
<tr><td><b>Chat privacy</b></td><td>Pass</td><td>Pass</td><td>No finding.</td></tr>
</tbody></table>
""", 9)


def p10():
    return page(f"""
{head("Remediation", "Fix the first-run experience before polishing the edges.", "Ordered by user impact")}
<table><thead><tr><th style='width:12mm'>Order</th><th style='width:26mm'>Finding</th><th>Action</th><th style='width:22mm'>Effort</th></tr></thead><tbody>
<tr><td class='mono'>1</td><td>V-01</td><td>Constrain RoleCardGroup height; center the group, not the cards. Add a 2 + 1 layout for narrow screens.</td><td>Small</td></tr>
<tr><td class='mono'>2</td><td>V-02</td><td>Add a short fetch timeout and staged loading state; cache the last deck; show Retry after ~4 s.</td><td>Medium</td></tr>
<tr><td class='mono'>3</td><td>V-03</td><td>Extract one EmptyState widget and apply it to Chats, Requests, Activity, Pals, and filters.</td><td>Small</td></tr>
<tr><td class='mono'>4</td><td>V-04</td><td>Clamp the name, anchor Edit, reduce avatar, add “Add skills” to empty sections.</td><td>Small</td></tr>
<tr><td class='mono'>5</td><td>V-05</td><td>Replace hand-rolled trailing actions with AppChrome.iconAction and one 48 px target.</td><td>Small</td></tr>
<tr><td class='mono'>6</td><td>V-06/V-07</td><td>Add shared bottom scroll padding; use it on Browse and Settings.</td><td>Small</td></tr>
<tr><td class='mono'>7</td><td>V-08</td><td>Copy pass: “0 Pals”, step label, Activity illustration, media fit.</td><td>Small</td></tr>
</tbody></table>
<div class='callout' style='margin-top:5mm'><p class='small' style='margin:0'><b>Acceptance frame:</b> the role screen should read as three choices, not three empty columns; Home should never show a blank skeleton for more than ~4 s without a retry path; every empty state should share one vertical rhythm.</p></div>
<div class='grid-2' style='margin-top:5mm'>
  <div class='card'><div class='label'>Verification</div><ul class='small'><li>Playwright at 390/1440, light/dark.</li><li>Measure role card height ≤ 200 px.</li><li>Measure rightmost icon center = 350 px.</li><li>Measure empty-state center within ±12 px.</li><li>Home first deck < 4 s or explicit retry.</li></ul></div>
  <div class='card tint'><div class='label'>Evidence</div><p class='small'>Screenshots and measurements in this report were captured from the current build at <span class='mono'>localhost:5317</span> and the live auth page at <span class='mono'>palturo.app</span> on 5 November 2026.</p></div>
</div>
<div class='rule'></div>
<div class='kv'><div class='k'>Report</div><div class='v'>PalTuro visual audit · 5 Nov 2026</div><div class='k'>Surfaces</div><div class='v'>Onboarding · Home · Browse · Chats · Requests · Profile · Settings · Notifications · Account · Chat privacy · Activity · Auth</div><div class='k'>Method</div><div class='v'>Playwright + Chrome · 390 × 844 @2x · 1440 × 900</div><div class='k'>Status</div><div class='v'>Findings only; no source changes in this pass</div></div>
<div class='grid-2' style='margin-top:5mm'>
  <div class='card'><div class='label'>Prepared by</div><p class='small'>PalTuro engineering · Playwright visual pass</p></div>
  <div class='card tint'><div class='label'>Next step</div><p class='small'>Fix V-01 and V-02 first, then batch V-03 to V-06 into the next UI pass.</p></div>
</div>
<div class='callout' style='margin-top:5mm'><p class='small' style='margin:0'><b>Bottom line.</b> PalTuro's visual language is already coherent. The release risk is concentrated in two first-run moments: the role step and the first Home load. Fix those, then V-03 to V-08 are a short, low-risk polish pass before the next external build.</p></div>
""", 10)


html_doc = f"""<!doctype html><html><head><meta charset='utf-8'><title>PalTuro Visual Audit — 5 November 2026</title><style>{CSS}</style></head><body>
{cover()}
{p2()}
{p3()}
{p4()}
{p5()}
{p6()}
{p7()}
{p8()}
{p9()}
{p10()}
</body></html>"""

OUT.write_text(html_doc, encoding="utf-8")
print(f"wrote {OUT} ({OUT.stat().st_size:,} bytes)")
