# -*- coding: utf-8 -*-
"""Build the PalTuro implementation report (A4, fixed pages)."""
import base64
import html
import io
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
TMP = Path.home() / "AppData" / "Local" / "Temp" / "opencode"
OUT = ROOT / "docs" / "PalTuro-Implementation-Report-2026-11-06.html"
TOTAL = 14

_cache = {}


def image(name, width=520):
    key = (name, width)
    if key in _cache:
        return _cache[key]
    path = TMP / name
    if not path.exists():
        path = ROOT / name
    if not path.exists():
        raise FileNotFoundError(path)
    img = Image.open(path).convert("RGB")
    ratio = width / img.width
    img = img.resize((width, int(img.height * ratio)), Image.LANCZOS)
    buf = io.BytesIO()
    img.save(buf, "JPEG", quality=84, optimize=True)
    data = "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode()
    _cache[key] = data
    return data


def esc(value):
    return html.escape(str(value))


def shot(name, caption, width=48, tag=None):
    badge = (
        f"<span class='badge {tag.lower()}'>{esc(tag)}</span>" if tag else ""
    )
    return (
        f"<figure class='shot' style='width:{width}mm'>{badge}"
        f"<img src='{image(name)}' alt=''>"
        f"<figcaption>{esc(caption)}</figcaption></figure>"
    )


def page(content, n, cls=""):
    return (
        f"<section class='page {cls}'><div class='inner'>{content}</div>"
        f"<div class='footer'><span>PalTuro · implementation report · 6 November 2026</span>"
        f"<span class='num'>{n:02d} / {TOTAL:02d}</span></div></section>"
    )


def head(kicker, title, side):
    return (
        f"<div class='top'><span>PalTuro / implementation report</span>"
        f"<span><b>{esc(side)}</b></span></div>"
        f"<div class='sec-head'><div><div class='kicker'>{kicker}</div>"
        f"<h2>{title}</h2></div></div>"
    )


CSS = """
@page { size: 210mm 297mm; margin: 0; }
* { box-sizing: border-box; }
body { margin:0; font-family:'Segoe UI','Inter',Arial,sans-serif; color:#1b1d17; background:#d6d3c8; font-size:9.3pt; line-height:1.45; }
.page { position:relative; width:210mm; height:297mm; background:#f6f4ed; overflow:hidden; page-break-after:always; }
.page:last-child { page-break-after:auto; }
.inner { position:absolute; inset:0; padding:15mm 16mm 17mm; }
.footer { position:absolute; left:16mm; right:16mm; bottom:7mm; border-top:.25mm solid #d8d5c8; padding-top:2mm; display:flex; justify-content:space-between; font-size:5.8pt; letter-spacing:.1em; text-transform:uppercase; color:#66695e; }
.footer .num { font-weight:700; color:#31342b; }
h1,h2,h3 { font-family:'Inter','Segoe UI',sans-serif; margin:0; letter-spacing:-.03em; }
h1 { font-size:31pt; line-height:1.02; }
h2 { font-size:17.5pt; line-height:1.1; margin:0 0 3mm; }
h3 { font-size:10pt; margin:0 0 1.6mm; }
p { margin:0 0 2.4mm; }
ul { margin:0 0 2mm; padding-left:4mm; }
li { margin-bottom:1.1mm; }
.kicker { font-size:6.2pt; letter-spacing:.18em; text-transform:uppercase; color:#5c6b00; font-weight:700; margin-bottom:2mm; }
.label { font-size:5.8pt; letter-spacing:.14em; text-transform:uppercase; color:#5c6b00; font-weight:700; margin-bottom:1.4mm; }
.muted { color:#66695e; }
.small { font-size:7.6pt; line-height:1.4; }
.tiny { font-size:6.4pt; line-height:1.35; }
.mono { font-family:'Cascadia Mono',Consolas,monospace; font-size:6.7pt; color:#5c6b00; }
.top { display:flex; justify-content:space-between; border-bottom:.35mm solid #d8d5c8; padding-bottom:2mm; margin-bottom:4.5mm; font-size:6pt; letter-spacing:.16em; text-transform:uppercase; color:#66695e; }
.top b { color:#5c6b00; }
.sec-head { display:flex; justify-content:space-between; gap:8mm; align-items:flex-end; margin-bottom:3.5mm; }
.sec-head h2 { max-width:150mm; margin:0; }
.rule { height:.3mm; background:#d8d5c8; margin:3.5mm 0; }
.grid-2 { display:grid; grid-template-columns:1fr 1fr; gap:4.5mm; }
.grid-3 { display:grid; grid-template-columns:repeat(3,1fr); gap:3.5mm; }
.grid-4 { display:grid; grid-template-columns:repeat(4,1fr); gap:3mm; }
.card { background:#fffefa; border:.3mm solid #d8d5c8; border-radius:2.4mm; padding:3.6mm; }
.card.tint { background:#eeece2; }
.callout { background:linear-gradient(120deg,#e9f6a8,#f4f9d7); border-left:1.8mm solid #c4df00; padding:3.4mm 4.2mm; border-radius:1mm; margin:2.6mm 0; }
.callout.warn { background:#fbf2dd; border-left-color:#c58a2b; }
.callout.risk { background:#f9e8e5; border-left-color:#a2453a; }
.metric-grid { display:grid; grid-template-columns:repeat(4,1fr); gap:3mm; margin:3.5mm 0; }
.metric { background:#eeece2; border:.3mm solid #d8d5c8; border-radius:2.4mm; padding:3.2mm; }
.metric .n { font-size:19pt; line-height:1; font-weight:700; }
.metric .t { font-size:5.7pt; letter-spacing:.12em; text-transform:uppercase; color:#66695e; margin-top:1.5mm; line-height:1.3; }
table { width:100%; border-collapse:collapse; }
th { font-size:5.6pt; letter-spacing:.1em; text-transform:uppercase; text-align:left; color:#66695e; border-bottom:.35mm solid #c7c4b5; padding:1.5mm 1.1mm; }
td { font-size:7pt; line-height:1.32; border-bottom:.2mm solid #d8d5c8; padding:1.4mm 1.1mm; vertical-align:top; }
tr:last-child td { border-bottom:none; }
.pill { display:inline-block; padding:.5mm 1.8mm; border-radius:9mm; font-size:5.1pt; font-weight:700; letter-spacing:.07em; text-transform:uppercase; white-space:nowrap; }
.pill.done { background:#eef6c9; color:#4f6000; border:.2mm solid #c8d88f; }
.pill.high { background:#f7dfdb; color:#8d332a; border:.2mm solid #dfb3ac; }
.pill.med { background:#f6ecd2; color:#7a5a00; border:.2mm solid #ddc48c; }
.pill.low { background:#eeece2; color:#66695e; border:.2mm solid #d8d5c8; }
.shot { margin:0 auto; background:#fff; border:.35mm solid #c7c4b5; border-radius:2.6mm; padding:1.5mm; position:relative; page-break-inside:avoid; }
.shot img { display:block; width:100%; border-radius:1.8mm; }
.shot figcaption { font-size:5.9pt; line-height:1.3; color:#66695e; padding:1.2mm .4mm 0; }
.badge { display:inline-block; font-size:5pt; font-weight:800; letter-spacing:.1em; padding:.7mm 2mm; border-radius:8mm; margin:0 0 1.2mm .2mm; }
.badge.before { background:#f7dfdb; color:#8d332a; }
.badge.after { background:#eef6c9; color:#4f6000; }
.row { display:grid; gap:3mm; align-items:start; justify-items:center; }
.row.two { grid-template-columns:1fr 1fr; justify-items:center; }
.row.three { grid-template-columns:repeat(3,1fr); }
.split { display:grid; grid-template-columns:1.05fr .95fr; gap:5mm; align-items:start; }
.kv { display:grid; grid-template-columns:31mm 1fr; gap:1.4mm 3mm; font-size:7.4pt; }
.kv .k { font-size:5.8pt; letter-spacing:.11em; text-transform:uppercase; color:#66695e; }
.kv .v { font-weight:700; }
.cover { background:radial-gradient(circle at 92% 88%,rgba(191,225,9,.2),transparent 34%),#1a1c16; color:#f6f4ed; }
.cover .inner { padding:18mm; }
.cover .logo { width:48mm; margin-bottom:28mm; }
.cover h1 { font-size:38pt; color:#fff; max-width:118mm; }
.cover h1 .lime { color:#d8f400; }
.cover .sub { font-size:14pt; line-height:1.2; color:#d7d9cc; margin-top:5mm; max-width:108mm; }
.cover .desc { font-size:8.6pt; line-height:1.5; color:#b3b6a8; max-width:104mm; margin-top:4.5mm; }
.cover .metrics { display:flex; gap:3.2mm; margin-top:9mm; width:112mm; }
.cover .metric { background:rgba(255,255,255,.06); border:.3mm solid rgba(255,255,255,.14); border-radius:2mm; padding:2.8mm; flex:1; }
.cover .metric .n { color:#d8f400; font-size:16pt; }
.cover .metric .t { color:#b7baab; }
.cover .phone { position:absolute; right:15mm; top:47mm; width:56mm; border:.5mm solid #4b4e3e; border-radius:6mm; overflow:hidden; box-shadow:0 12mm 26mm rgba(0,0,0,.5); transform:rotate(1.5deg); }
.cover .phone img { display:block; width:100%; }
.cover .meta { position:absolute; left:18mm; bottom:20mm; right:18mm; display:flex; gap:9mm; border-top:.25mm solid #3a3a3a; padding-top:3mm; font-size:6.4pt; color:#9a9e92; }
.cover .meta b { display:block; color:#f6f4ed; margin-top:1mm; }
.cover-toc { position:absolute; left:18mm; right:18mm; bottom:72mm; display:grid; grid-template-columns:repeat(3,1fr); gap:5mm; border-top:.25mm solid #3a3a3a; padding-top:3.2mm; }
.cover-toc div { font-size:6.3pt; letter-spacing:.12em; text-transform:uppercase; color:#8f9387; }
.cover-toc span { display:block; color:#d8f400; font-size:5.7pt; margin-bottom:1.3mm; }
.cover-toc b { display:block; color:#e8eadf; font-size:8pt; letter-spacing:0; text-transform:none; font-weight:600; margin-bottom:.7mm; }
.cover-toc em { font-style:normal; color:#9ca092; letter-spacing:.06em; }
"""


def cover():
    return f"""
<section class='page cover'><div class='inner'>
  <img class='logo' src='{image('assets/images/hlogo_white.png', 300)}' alt='PalTuro'>
  <div class='kicker' style='color:#d8f400'>Implementation report · 6 November 2026</div>
  <h1>Eight fixes,<br><span class='lime'>three audits</span><br>each</h1>
  <div class='sub'>What changed, what the evidence shows, and where the screens stand now.</div>
  <div class='desc'>A before/after record of every finding in the visual audit: the root cause, the code change, the three-auditor gate, and the resulting screen at 390 × 844.</div>
  <div class='metrics'>
    <div class='metric'><div class='n'>8/8</div><div class='t'>fixes shipped</div></div>
    <div class='metric'><div class='n'>177</div><div class='t'>tests passing</div></div>
    <div class='metric'><div class='n'>41</div><div class='t'>files changed</div></div>
    <div class='metric'><div class='n'>0</div><div class='t'>analyzer issues</div></div>
  </div>
  <div class='phone'><img src='{image('final2-home.png', 420)}' alt='PalTuro home'></div>
  <div class='cover-toc'>
    <div><span>01</span><b>Summary &amp; gates</b><em>pages 02–03</em></div>
    <div><span>02</span><b>Findings V-01 – V-08</b><em>pages 04–11</em></div>
    <div><span>03</span><b>Coverage &amp; limits</b><em>pages 12–14</em></div>
  </div>
  <div class='meta'>
    <div>BRANCH<b>ui-features</b></div>
    <div>BASE<b>b121126 → abe5cd5</b></div>
    <div>METHOD<b>3 audits per fix</b></div>
    <div>PREPARED FOR<b>PalTuro product team</b></div>
  </div>
</div></section>"""


def p2():
    return page(f"""
<div class='top'><span>PalTuro / implementation report</span><span><b>Executive summary</b></span></div>
<div class='sec-head'><div><div class='kicker'>Release position</div>
<h2>Every visual finding is closed, and every closure has evidence.</h2></div></div>
<p>The eight findings from the 5 November visual audit were fixed on <span class='mono'>ui-features</span>. Each fix was implemented, committed, and then reviewed by three independent auditors — functionality, quality, and regression. A fix could not proceed until all three returned PASS; failed gates were reworked and re-audited.</p>
<div class='metric-grid'>
  <div class='metric'><div class='n'>8/8</div><div class='t'>findings closed</div></div>
  <div class='metric'><div class='n'>+16</div><div class='t'>tests added (161 → 177)</div></div>
  <div class='metric'><div class='n'>30</div><div class='t'>gate rounds across 8 fixes</div></div>
  <div class='metric'><div class='n'>0</div><div class='t'>open audit blockers</div></div>
</div>
<table><thead><tr><th style='width:12mm'>Fix</th><th style='width:20mm'>Finding</th><th>Change</th><th style='width:18mm'>Commit</th><th style='width:14mm'>Status</th></tr></thead><tbody>
<tr><td class='mono'>VF-01</td><td>V-01 role cards</td><td>Content-height cards; scrollable role step for short/large text.</td><td class='mono'>9a60a2a</td><td><span class='pill done'>Pass</span></td></tr>
<tr><td class='mono'>VF-02</td><td>V-02 loading</td><td>4 s slow state, 12 s timeout, Retry, instant cache seed.</td><td class='mono'>2cf6cde</td><td><span class='pill done'>Pass</span></td></tr>
<tr><td class='mono'>VF-03</td><td>V-03 empty states</td><td>One shared <span class='mono'>AppEmptyState</span> for Chats/Requests/Activity.</td><td class='mono'>f2b1ae2</td><td><span class='pill done'>Pass</span></td></tr>
<tr><td class='mono'>VF-04</td><td>V-04 profile</td><td>Clamped name, 72 px avatar, empty-skill CTA.</td><td class='mono'>d6c68bf</td><td><span class='pill done'>Pass</span></td></tr>
<tr><td class='mono'>VF-05</td><td>V-05 chrome</td><td>48 px targets, 350 px centre, text-aware chat header.</td><td class='mono'>dc12bed</td><td><span class='pill done'>Pass</span></td></tr>
<tr><td class='mono'>VF-06</td><td>V-06 Browse</td><td>Nav-aware bottom inset; 2×2 fallback to scrollable grid.</td><td class='mono'>f347172</td><td><span class='pill done'>Pass</span></td></tr>
<tr><td class='mono'>VF-07</td><td>V-07 settings</td><td>32 px + safe-area inset; 48 px permission action.</td><td class='mono'>9629f56</td><td><span class='pill done'>Pass</span></td></tr>
<tr><td class='mono'>VF-08</td><td>V-08 copy/media</td><td>“0 Pals”, en-dash steps, top-centred media.</td><td class='mono'>5a18e7a</td><td><span class='pill done'>Pass</span></td></tr>
</tbody></table>
<div class='callout'><p class='small' style='margin:0'><b>Verdict:</b> no open visual blockers remain. The remaining risk is environmental: no iOS build or physical-device pass on this host, and a few pre-existing overflows above 200% text are documented on page 14.</p></div>
<h3 style='margin-top:4mm'>What users will notice</h3>
<div class='grid-3'>
  <div class='card'><div class='label'>First run</div><p class='small'>The role step reads as three choices, and a slow deck admits it is slow with a retry instead of showing a blank card.</p></div>
  <div class='card'><div class='label'>Everyday use</div><p class='small'>Empty lists share one rhythm, the profile survives long names, and Browse no longer ends under the nav.</p></div>
  <div class='card tint'><div class='label'>Polish</div><p class='small'>One 48 px action grid, “0 Pals”, consistent dashes, and media that keeps faces in frame.</p></div>
</div>
""", 2)


def p3():
    return page(f"""
{head('Method', 'Three auditors, one gate, no skipping ahead.', 'Process')}
<p>Each fix followed the same loop: implement, run <span class='mono'>flutter analyze</span> and the full suite, then send the change to three independent auditors. Their findings were treated as blocking. A failed gate went back to implementation and all three audits ran again.</p>
<div class='grid-3'>
  <div class='card'><div class='label'>Functionality</div><p class='small'>Does the change meet the acceptance criteria? Are interactions, semantics, and edge states intact?</p></div>
  <div class='card'><div class='label'>Quality</div><p class='small'>Tokens, structure, accessibility, text scaling, test quality, analyzer cleanliness.</p></div>
  <div class='card'><div class='label'>Regression</div><p class='small'>Full suite, adjacent screens, public APIs, short viewports, 200% text, platform chrome.</p></div>
</div>
<h3 style='margin-top:5mm'>Gate results</h3>
<table><thead><tr><th style='width:16mm'>Fix</th><th style='width:22mm'>Gate rounds</th><th>What the failed rounds caught</th><th style='width:16mm'>Result</th></tr></thead><tbody>
<tr><td class='mono'>VF-01</td><td>3</td><td>Scroll view clipped the card; 640×411 landscape then overflowed; 200% text coverage was missing.</td><td><span class='pill done'>Pass</span></td></tr>
<tr><td class='mono'>VF-02</td><td>2</td><td>Stale loads cancelled the live retry's 4 s/12 s timers; cached seed was reset by the refresh.</td><td><span class='pill done'>Pass</span></td></tr>
<tr><td class='mono'>VF-03</td><td>4</td><td>Nav clearance was dropped; SliverFillRemaining intrinsics rejected LayoutBuilder; 2×2 cells overflowed.</td><td><span class='pill done'>Pass</span></td></tr>
<tr><td class='mono'>VF-04</td><td>3</td><td>Add-skills Semantics merged into the parent; no test pinned the name clamp.</td><td><span class='pill done'>Pass</span></td></tr>
<tr><td class='mono'>VF-05</td><td>9</td><td>iOS 44 px bar clamped 48 px targets; chat header under-sized at 200%; un-migrated Explore/Pals chrome.</td><td><span class='pill done'>Pass</span></td></tr>
<tr><td class='mono'>VF-06</td><td>4</td><td>Clearance double-counted the shell nav; the skeleton still used 90 px; 2×2 cards overflowed at 200%.</td><td><span class='pill done'>Pass</span></td></tr>
<tr><td class='mono'>VF-07</td><td>3</td><td>32 px ignored the safe area; the denied-state text button consumed the tile at 200%.</td><td><span class='pill done'>Pass</span></td></tr>
<tr><td class='mono'>VF-08</td><td>2</td><td>Only 1 of 5 step labels got the en dash; video ignored the new focal alignment.</td><td><span class='pill done'>Pass</span></td></tr>
</tbody></table>
<div class='grid-2' style='margin-top:4mm'>
  <div class='card'><div class='label'>Test progression</div><p class='small'><b>161 → 177</b> tests. New coverage: role height/landscape/dark; loading slow/timeout/stale retry; shared empty state and 200% clearance; profile clamp/avatar; 48 px chrome; nav clearance; notification inset; Pals copy and en dash.</p></div>
  <div class='card tint'><div class='label'>Commands</div><p class='small mono'>flutter analyze --no-pub<br>flutter test --no-pub<br>flutter run -d web-server --dart-define-from-file=.env</p></div>
</div>
<div class='callout warn' style='margin-top:4mm'><p class='small' style='margin:0'><b>Evidence policy:</b> commits are local on <span class='mono'>ui-features</span>; nothing was pushed. Screenshots in this report were captured from a fresh build at 390 × 844 @2× after the fixes.</p></div>
""", 3)


def p4():
    return page(f"""
{head('V-01 / onboarding', 'Role cards: from three empty columns to three choices.', 'VF-01 · 9a60a2a')}
<p>Before, each card stretched to the page: <b>650 × 105 px</b>, from y≈107 to y≈757, with the icon and label pinned low. The cause was a <span class='mono'>Container</span> with <span class='mono'>alignment</span> under loose constraints; it expanded to fill the page.</p>
<div class='row two' style='margin-top:2mm'>
  {shot('ob-1.png', 'Before: 650 px tall, content near the bottom third.', 64, 'Before')}
  {shot('final-role.png', 'After: content-height cards, centred as a group.', 64, 'After')}
</div>
<div class='grid-3' style='margin-top:3mm'>
  <div class='card'><div class='label'>Change</div><p class='small'>Removed <span class='mono'>alignment</span>, floored the card at <span class='mono'>168 px</span>, and made the role step body scroll when the header or text scale leaves too little room.</p></div>
  <div class='card'><div class='label'>Accessibility</div><p class='small'>Selected state gets a 2 px dark ring (10:1 on lime); 48 px back target; 200% text scrolls instead of overflowing.</p></div>
  <div class='card tint'><div class='label'>Evidence</div><p class='small'>Card height pinned at 168; 640×411 and 390×844 @200% tests; dark-mode border test.</p></div>
</div>
<div class='callout' style='margin-top:3mm'><p class='small' style='margin:0'><b>Result:</b> the three choices are visible at once, the group is centred, and the layout survives short landscape and large text.</p></div>
<table style='margin-top:3mm'><thead><tr><th style='width:42mm'>Measure</th><th>Before</th><th>After</th></tr></thead><tbody>
<tr><td>Card height</td><td>~650 px</td><td>168 px (floor)</td></tr>
<tr><td>Card width</td><td>~105 px</td><td>~107 px</td></tr>
<tr><td>Empty space above content</td><td>~358 px</td><td>~0 px</td></tr>
<tr><td>Short landscape + 200%</td><td>overflow</td><td>scrolls, no exception</td></tr>
</tbody></table>
""", 4)


def p5():
    return page(f"""
{head('V-02 / first load', 'Home: a slow deck now says so, and offers a way out.', 'VF-02 · 2cf6cde')}
<p>Before, a cold load showed a full-card skeleton for roughly 10–12 seconds with no timeout, no progress, and no retry. The data path worked; the feedback did not. The after state below is the loaded deck; the new 4 s overlay and 12 s timeout are verified by widget tests because the test deck resolved before the 4 s threshold.</p>
<div class='row two' style='margin-top:2mm'>
  {shot('audit-home-after-outside.png', 'Before: 328×690 skeleton, no fallback.', 64, 'Before')}
  {shot('final2-home.png', 'After: deck arrives; slow/timeout states are tested.', 64, 'After')}
</div>
<div class='grid-3' style='margin-top:3mm'>
  <div class='card'><div class='label'>4 seconds</div><p class='small'>A “Still looking for matches…” card with Retry appears over the skeleton.</p></div>
  <div class='card'><div class='label'>12 seconds</div><p class='small'>The request is capped and becomes a retryable error.</p></div>
  <div class='card tint'><div class='label'>Return visits</div><p class='small'>The previous deck is seeded from <span class='mono'>MatchApi.peekDeck</span> and preserved when the refresh returns the same ids.</p></div>
</div>
<div class='callout warn' style='margin-top:3mm'><p class='small' style='margin:0'><b>Hard part:</b> a superseded retry must not cancel the live timers. Timers are now cancelled only after the generation guard, and a dedicated test completes the stale load while the retry is counting down.</p></div>
<table style='margin-top:3mm'><thead><tr><th style='width:28mm'>Window</th><th>What the user sees</th><th style='width:54mm'>State</th></tr></thead><tbody>
<tr><td>0–4 s</td><td>Full-card skeleton</td><td>loading</td></tr>
<tr><td>4–12 s</td><td>“Still looking for matches…” + Retry</td><td>slow, still loading</td></tr>
<tr><td>12 s+</td><td>“This is taking longer than expected…” + Retry</td><td>timeout error</td></tr>
<tr><td>Return visit</td><td>Previous deck immediately, refresh behind it</td><td>cache seed</td></tr>
</tbody></table>
""", 5)


def p6():
    return page(f"""
{head('V-03 / empty states', 'Chats, Requests, and Activity now share one rhythm.', 'VF-03 · f2b1ae2')}
<p>Before, the same message sat at three different heights: Chats ≈500 px, Requests ≈700 px, Activity ≈430 px with no illustration. The shared widget fixes the illustration size, text hierarchy, action slot, and bottom inset.</p>
<div class='row three' style='margin-top:1mm'>
  {shot('audit-tab-chats.png', 'Before · Chats', 42, 'Before')}
  {shot('audit-tab-requests.png', 'Before · Requests', 42, 'Before')}
  {shot('audit-activity.png', 'Before · Activity', 42, 'Before')}
</div>
<div class='row three' style='margin-top:2.5mm'>
  {shot('after-chats.png', 'After · Chats', 42, 'After')}
  {shot('after-requests.png', 'After · Requests', 42, 'After')}
  {shot('after-activity.png', 'After · Activity', 42, 'After')}
</div>
<div class='grid-2' style='margin-top:2.5mm'>
  <div class='card'><div class='label'>One widget</div><p class='small'><span class='mono'>AppEmptyState</span>: optional illustration, title, message, action, and a nav-aware bottom inset. Large text swaps the illustration to 120 px.</p></div>
  <div class='card tint'><div class='label'>Behaviour kept</div><p class='small'>Start swiping, Clear search/filters, View sent requests/Refresh, View requests, and Show all keep their exact callbacks.</p></div>
</div>
""", 6)


def p7():
    return page(f"""
{head('V-04 / profile', 'A long name no longer bends the whole header.', 'VF-04 · d6c68bf')}
<p>Before, the test name wrapped onto two lines, pushed Edit against the first line, and the skills sections rendered as empty cards with only a heading. After, the name clamps to one line, the avatar is 72 px, and empty skills invite an action.</p>
<div class='row two' style='margin-top:2mm'>
  {shot('audit-tab-profile.png', 'Before: wrapped name, Edit on line one, empty skill cards.', 64, 'Before')}
  {shot('final2-profile.png', 'After: clamped name, 72 px avatar, “0 Pals”, Add skills.', 64, 'After')}
</div>
<div class='grid-3' style='margin-top:3mm'>
  <div class='card'><div class='label'>Header</div><p class='small'>`maxLines: 1` + ellipsis; Edit stays top-right; the card height no longer depends on the name.</p></div>
  <div class='card'><div class='label'>Skills</div><p class='small'>Read-only empty cards show “No skills added yet” and a 48 px “Add skills” action that opens the editor.</p></div>
  <div class='card tint'><div class='label'>Evidence</div><p class='small'>Tests pin the clamp, avatar size, 200% header, and the empty-state callback; semantics label names learn/teach.</p></div>
</div>
<table style='margin-top:3mm'><thead><tr><th style='width:38mm'>Measure</th><th>Before</th><th>After</th></tr></thead><tbody>
<tr><td>Display name</td><td>wraps to 2 lines</td><td>1 line + ellipsis</td></tr>
<tr><td>Avatar</td><td>95 px</td><td>72 px</td></tr>
<tr><td>Edit alignment</td><td>first line of a wrapped name</td><td>top-right, name-independent</td></tr>
<tr><td>Empty skills</td><td>heading only</td><td>copy + 48 px Add skills</td></tr>
</tbody></table>
""", 7)


def p8():
    return page(f"""
{head('V-05 / chrome', 'One 48 px action grid, ending at x=350.', 'VF-05 · dc12bed')}
<p>Before, the rightmost action was 44 px on Home/Chats/Requests and 48 px on Browse/Profile, so its centre drifted between 352 and 350. After, every in-app action uses <span class='mono'>AppSpacing.iconTarget</span> and the right edge is consistently 16 px + 48 px.</p>
<div class='row two' style='margin-top:2mm'>
  {shot('audit-home-loaded.png', 'Before: 44 px actions, centre 352.', 64, 'Before')}
  {shot('final2-home.png', 'After: 48 px actions, centre 350.', 64, 'After')}
</div>
<table style='margin-top:3mm'><thead><tr><th style='width:36mm'>Surface</th><th>Rightmost centre</th><th>Target</th><th>Result</th></tr></thead><tbody>
<tr><td>Home</td><td>352 → 350</td><td>44 → 48</td><td>48×48, centre 350</td></tr>
<tr><td>Chats / Requests</td><td>352 → 350</td><td>44 → 48</td><td>48×48, centre 350</td></tr>
<tr><td>Browse / Profile / Pals</td><td>350</td><td>48</td><td>unchanged</td></tr>
<tr><td>iOS top bar</td><td>44</td><td>48</td><td>bar grows to fit the target</td></tr>
</tbody></table>
<div class='callout' style='margin-top:3mm'><p class='small' style='margin:0'><b>Also fixed:</b> the chat header now derives its height from the same 1.34 text-scale clamp AppBar uses, so large text neither clips nor leaves a dead band.</p></div>
""", 8)


def p9():
    return page(f"""
{head('V-06 / browse', 'The last category row clears the floating nav.', 'VF-06 · f347172')}
<p>Before, Browse used fixed 90/112 px bottom padding, so the last row met the nav and the loading skeleton used a different value. After, clearance is <span class='mono'>padding.bottom + 16</span>, which resolves to the nav height plus one consistent gap.</p>
<div class='row two' style='margin-top:2mm'>
  {shot('audit-tab-browse.png', 'Before: last row meets the floating nav.', 64, 'Before')}
  {shot('final5-browse-end.png', 'After: last row ends above the nav at scroll end.', 64, 'After')}
</div>
<div class='grid-3' style='margin-top:3mm'>
  <div class='card'><div class='label'>Clearance</div><p class='small'>The shell already reports the nav height in <span class='mono'>padding.bottom</span>; adding 16 px avoids both overlap and a double gap.</p></div>
  <div class='card'><div class='label'>Short screens</div><p class='small'>If a 2×2 cell would be under 172 px, the page uses the scrollable auto grid instead of squeezing the card.</p></div>
  <div class='card tint'><div class='label'>Skeleton</div><p class='small'>The loading grid uses the same clearance helper and never sits under the bar.</p></div>
</div>
<table style='margin-top:3mm'><thead><tr><th style='width:42mm'>Measure</th><th>Before</th><th>After</th></tr></thead><tbody>
<tr><td>Bottom padding</td><td>90 / 112 px</td><td>nav height + 16 px</td></tr>
<tr><td>Skeleton padding</td><td>90 px</td><td>same helper</td></tr>
<tr><td>Gap at scroll end</td><td>meets / under nav</td><td>16 px clear</td></tr>
<tr><td>Very short cell</td><td>overflow</td><td>auto grid fallback</td></tr>
</tbody></table>
""", 9)


def p10():
    return page(f"""
{head('V-07 / settings', 'Notification settings no longer end at the viewport edge.', 'VF-07 · 9629f56')}
<p>Before, the list ended at the edge with a 100 px hard-coded pad. After, the scroll end reserves 32 px plus the system safe area, and the denied-permission action is a 48 px icon instead of a text button that consumed the tile at 200%.</p>
<div class='row two' style='margin-top:2mm'>
  {shot('audit-notif-settings2.png', 'Before: content cut at the viewport edge.', 64, 'Before')}
  {shot('final6-notif-end.png', 'After: “Changes apply immediately.” with breathing room.', 64, 'After')}
</div>
<div class='grid-3' style='margin-top:3mm'>
  <div class='card'><div class='label'>Inset</div><p class='small'><span class='mono'>32 + MediaQuery.padding.bottom</span>; the page is pushed above the tab shell, so there is no double count.</p></div>
  <div class='card'><div class='label'>Permission row</div><p class='small'>Denied state uses <span class='mono'>AppChrome.iconAction</span> with a 48 px target and a tooltip; no overflow at 200%.</p></div>
  <div class='card tint'><div class='label'>Evidence</div><p class='small'>Tests pin the constant and the safe-area term (34 → 66); a probe confirmed 32 px gap at insets 0/34/48.</p></div>
</div>
<table style='margin-top:3mm'><thead><tr><th style='width:38mm'>Measure</th><th>Before</th><th>After</th></tr></thead><tbody>
<tr><td>Scroll-end inset</td><td>100 px fixed</td><td>32 px + safe area</td></tr>
<tr><td>Denied action</td><td>text button, overflows at 200%</td><td>48 px icon + tooltip</td></tr>
<tr><td>At inset 34</td><td>—</td><td>66 px total</td></tr>
</tbody></table>
""", 10)


def p11():
    return page(f"""
{head('V-08 / copy and media', 'Small words, one dash, and a better crop.', 'VF-08 · 5a18e7a')}
<p>Before, the profile read “Pal 0”, onboarding mixed hyphen and en-dash step labels, and card media was centre-cropped so portrait photos lost their focal point. After, the label is a single “0 Pals”, every step uses an en dash, and card media is top-aligned for both images and video.</p>
<div class='row two' style='margin-top:2mm'>
  {shot('audit-tab-profile.png', 'Before: “Pal 0”.', 42, 'Before')}
  {shot('final2-profile.png', 'After: “0 Pals”.', 42, 'After')}
</div>
<div class='row two' style='margin-top:2mm'>
  {shot('audit-home-loaded.png', 'Before: centre crop fills the card with “DRAFT”.', 42, 'Before')}
  {shot('after-home-media.png', 'After: top-aligned crop keeps the subject in frame.', 42, 'After')}
</div>
<div class='callout' style='margin-top:2mm'><p class='small' style='margin:0'><b>Also verified:</b> “Step 1 of 4 – Role” uses U+2013 in all five flow labels; <span class='mono'>palCountLabel</span> returns 0 Pals / 1 Pal / 2 Pals; video uses the same alignment as images.</p></div>
""", 11)


def p12():
    return page(f"""
{head('Coverage', 'What changed, by area.', 'Files')}
<p>Diff from <span class='mono'>b121126</span> to <span class='mono'>abe5cd5</span>: <b>41 files</b>, <b>+1,375 / −427</b> lines. Tests grew from 161 to 177.</p>
<table><thead><tr><th style='width:34mm'>Area</th><th>Files</th><th style='width:34mm'>What changed</th></tr></thead><tbody>
<tr><td><b>Onboarding</b></td><td class='mono'>role_card_group, onboarding_scaffold, role_screen, flow, interests/final/review</td><td>Card height, scrollBody, en-dash labels, 48 px back</td></tr>
<tr><td><b>Home / deck</b></td><td class='mono'>home_page, match_api</td><td>Slow/timeout/retry, cache seed, 48 px actions</td></tr>
<tr><td><b>Empty states</b></td><td class='mono'>app_empty_state (new), chats_page, request_page, notifications_page</td><td>One widget, nav-aware inset, illustration parity</td></tr>
<tr><td><b>Profile / skills</b></td><td class='mono'>profile_page, profile_edit, skills_card</td><td>Clamp, 72 px avatar, Add skills, 48 px actions</td></tr>
<tr><td><b>Chrome</b></td><td class='mono'>app_spacing, explore*, matches, chats_room, block_list, account*, person_card, request_detail</td><td>48 px targets, iOS 48 bar, text-aware header</td></tr>
<tr><td><b>Browse</b></td><td class='mono'>explore_page, app_skeleton</td><td>Clearance helper, 2×2 fallback, skeleton parity</td></tr>
<tr><td><b>Settings</b></td><td class='mono'>notification_preferences_page</td><td>Safe-area inset, 48 px permission action</td></tr>
<tr><td><b>Copy / media</b></td><td class='mono'>pals_count, profile_page, onboarding*, showcase_media, person_card</td><td>0 Pals, en dash, top-centre crop</td></tr>
</tbody></table>
<div class='grid-2' style='margin-top:4mm'>
  <div class='card'><div class='label'>New tests</div><p class='small mono'>home_loading_test<br>app_empty_state_test<br>profile_summary_test<br>chrome_targets_test<br>app_spacing_test</p></div>
  <div class='card tint'><div class='label'>Extended tests</div><p class='small mono'>onboarding_semantics_test<br>skills_readonly_test<br>notification_preferences_test<br>pals_count_test</p></div>
</div>
<h3 style='margin-top:4mm'>Changed files</h3>
<div class='grid-3'>
  <div class='card'><div class='label'>Onboarding</div><p class='tiny mono'>role_card_group.dart<br>onboarding_scaffold.dart<br>onboarding_role_screen.dart<br>onboarding_flow.dart<br>interests / final / review</p></div>
  <div class='card'><div class='label'>Home &amp; lists</div><p class='tiny mono'>home_page.dart<br>match_api.dart<br>app_empty_state.dart (new)<br>chats_page.dart<br>request_page.dart<br>notifications_page.dart</p></div>
  <div class='card'><div class='label'>Chrome &amp; profile</div><p class='tiny mono'>app_spacing.dart<br>explore_page.dart<br>explore_expand.dart<br>explore_category_page.dart<br>chats_room.dart<br>matches.dart<br>block_list.dart<br>account/*<br>profile_page.dart<br>profile_edit.dart<br>skills_card.dart<br>person_card.dart<br>request_detail.dart<br>showcase_media.dart</p></div>
</div>
<div class='callout' style='margin-top:3mm'><p class='small' style='margin:0'><b>API note:</b> the only new public surface is <span class='mono'>AppEmptyState</span>, the <span class='mono'>AppSpacing</span> helpers, and <span class='mono'>MatchApi.peekDeck</span>. <span class='mono'>hasCachedDeck</span> was removed after confirming it had no remaining callers.</p></div>
""", 12)


def p13():
    return page(f"""
{head('Verification', 'The evidence behind the green gates.', 'Tests')}
<div class='metric-grid'>
  <div class='metric'><div class='n'>177</div><div class='t'>tests passing</div></div>
  <div class='metric'><div class='n'>0</div><div class='t'>analyzer issues</div></div>
  <div class='metric'><div class='n'>30</div><div class='t'>audit rounds</div></div>
  <div class='metric'><div class='n'>90</div><div class='t'>auditor passes</div></div>
</div>
<h3>Behaviour pinned by tests</h3>
<table><thead><tr><th style='width:26mm'>Fix</th><th>Assertions</th></tr></thead><tbody>
<tr><td>VF-01</td><td>Card height exactly 168; 640×411 no exception; 390×844 @200% scrolls and keeps the group inside the viewport; dark-mode selected ring.</td></tr>
<tr><td>VF-02</td><td>Slow copy at 4 s; timeout at 12 s; retry restarts; a stale load cannot cancel the live timers; completion leaves the skeleton.</td></tr>
<tr><td>VF-03</td><td>Shared widget renders title/message/action; illustration present/absent; 200% action clears the nav.</td></tr>
<tr><td>VF-04</td><td>Name is one line with ellipsis; avatar 72; empty skills fire “Add skills”; 200% Edit remains hittable.</td></tr>
<tr><td>VF-05</td><td>Home actions 48×48; rightmost centre 350; iOS top bar ≥48.</td></tr>
<tr><td>VF-06</td><td>Clearance helper returns nav+16 for insets 80/94/108.</td></tr>
<tr><td>VF-07</td><td>List bottom equals 32 and 32 + safe area (34); page survives 200%.</td></tr>
<tr><td>VF-08</td><td>0 Pals / 1 Pal / 2 Pals; role step renders an en dash.</td></tr>
</tbody></table>
<div class='callout' style='margin-top:4mm'><p class='small' style='margin:0'><b>Commands:</b> <span class='mono'>flutter analyze --no-pub</span> → “No issues found”; <span class='mono'>flutter test --no-pub</span> → “177 tests, all passed”; screenshots from a fresh web-server build with <span class='mono'>--dart-define-from-file=.env</span>.</p></div>
<h3 style='margin-top:4mm'>Audit verdicts</h3>
<table><thead><tr><th style='width:16mm'>Fix</th><th>Functionality</th><th>Quality</th><th>Regression</th><th style='width:16mm'>Rounds</th></tr></thead><tbody>
<tr><td class='mono'>VF-01</td><td>Pass</td><td>Pass</td><td>Pass</td><td>3</td></tr>
<tr><td class='mono'>VF-02</td><td>Pass</td><td>Pass</td><td>Pass</td><td>2</td></tr>
<tr><td class='mono'>VF-03</td><td>Pass</td><td>Pass</td><td>Pass</td><td>4</td></tr>
<tr><td class='mono'>VF-04</td><td>Pass</td><td>Pass</td><td>Pass</td><td>3</td></tr>
<tr><td class='mono'>VF-05</td><td>Pass</td><td>Pass</td><td>Pass</td><td>9</td></tr>
<tr><td class='mono'>VF-06</td><td>Pass</td><td>Pass</td><td>Pass</td><td>4</td></tr>
<tr><td class='mono'>VF-07</td><td>Pass</td><td>Pass</td><td>Pass</td><td>3</td></tr>
<tr><td class='mono'>VF-08</td><td>Pass</td><td>Pass</td><td>Pass</td><td>2</td></tr>
</tbody></table>
""", 13)


def p14():
    return page(f"""
{head('Limits', 'What this pass does not prove.', 'Close-out')}
<div class='grid-2'>
  <div class='card'><div class='label'>Environment</div><ul class='small'><li>No iOS build or physical-device pass; platform checks used the test override.</li><li>Web build verified at 390×844; 1440 desktop was not re-captured.</li><li>Nothing pushed; commits are local on <span class='mono'>ui-features</span>.</li></ul></div>
  <div class='card tint'><div class='label'>Known residuals</div><ul class='small'><li>300% text can still overflow the bottom nav labels and the auto grid card (pre-existing).</li><li>The search/filter empty state keeps a plain title without an illustration by design.</li><li>Pals and Block list still use bespoke empty states outside VF-03 scope.</li></ul></div>
</div>
<h3 style='margin-top:5mm'>Commit trail</h3>
<table><thead><tr><th style='width:18mm'>Commit</th><th>Change</th></tr></thead><tbody>
<tr><td class='mono'>9a60a2a</td><td>Role cards size to content; role step scrolls when needed.</td></tr>
<tr><td class='mono'>2cf6cde</td><td>Deck loading has slow/timeout/retry and a cache seed.</td></tr>
<tr><td class='mono'>f2b1ae2</td><td>Shared empty state across Chats, Requests, Activity.</td></tr>
<tr><td class='mono'>d6c68bf</td><td>Profile name clamp, 72 px avatar, Add skills.</td></tr>
<tr><td class='mono'>dc12bed</td><td>48 px chrome, 350 px alignment, text-aware chat header.</td></tr>
<tr><td class='mono'>f347172</td><td>Browse clears the nav; skeleton and 2×2 fallback.</td></tr>
<tr><td class='mono'>9629f56</td><td>Notification settings safe-area inset.</td></tr>
<tr><td class='mono'>5a18e7a</td><td>0 Pals, en-dash steps, top-centred media.</td></tr>
</tbody></table>
<div class='callout' style='margin-top:5mm'><p class='small' style='margin:0'><b>Next step:</b> run the same 390/1440 pass on a real iOS build, then decide whether to push <span class='mono'>ui-features</span> and refresh the visual audit report with these screens.</p></div>
<div class='grid-3' style='margin-top:4mm'>
  <div class='card'><div class='label'>Before push</div><p class='small'>Re-run the full suite on the target CI and review the diff of the 18-file chrome commit.</p></div>
  <div class='card'><div class='label'>Device pass</div><p class='small'>Check 48 px targets, safe areas, and 200% text on a physical iPhone and a 3-button Android device.</p></div>
  <div class='card tint'><div class='label'>Report refresh</div><p class='small'>Re-capture the 11 audit surfaces and mark V-01–V-08 resolved in the visual audit PDF.</p></div>
</div>
<div class='rule'></div>
<div class='kv'><div class='k'>Report</div><div class='v'>PalTuro implementation report · 6 Nov 2026</div><div class='k'>Base → head</div><div class='v'>b121126 → abe5cd5</div><div class='k'>Status</div><div class='v'>8/8 fixes passed; local commits only</div></div>
""", 14)


html_doc = f"""<!doctype html><html><head><meta charset='utf-8'><title>PalTuro Implementation Report — 6 November 2026</title><style>{CSS}</style></head><body>
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
{p11()}
{p12()}
{p13()}
{p14()}
</body></html>"""

OUT.write_text(html_doc, encoding="utf-8")
print(f"wrote {OUT} ({OUT.stat().st_size:,} bytes)")
