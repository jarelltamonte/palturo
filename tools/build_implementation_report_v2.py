# -*- coding: utf-8 -*-
"""Build a fresh implementation report with normalized, centred screenshots."""
import base64
import html
import io
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
TMP = Path.home() / "AppData" / "Local" / "Temp" / "opencode"
OUT = ROOT / "docs" / "PalTuro-Implementation-Report-2026-11-06-v2.html"
TOTAL = 15
DEVICE_W = 780  # 390 CSS px at 2x; all report shots are normalised to this

_cache = {}


def image(name, width=500):
    key = (name, width)
    if key in _cache:
        return _cache[key]
    path = TMP / name
    if not path.exists():
        path = ROOT / name
    img = Image.open(path).convert("RGB")
    # Some audit captures were wider than the device (a white strip on the
    # right). Crop to the device width so the app content is centred.
    if img.width > DEVICE_W:
        img = img.crop((0, 0, DEVICE_W, img.height))
    elif img.width < DEVICE_W:
        canvas = Image.new("RGB", (DEVICE_W, img.height), "white")
        canvas.paste(img, ((DEVICE_W - img.width) // 2, 0))
        img = canvas
    ratio = width / img.width
    img = img.resize((width, int(img.height * ratio)), Image.LANCZOS)
    buf = io.BytesIO()
    img.save(buf, "JPEG", quality=85, optimize=True)
    data = "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode()
    _cache[key] = data
    return data


def logo(name, width=520, background=(18, 22, 15)):
    key = ("logo", name, width)
    if key in _cache:
        return _cache[key]
    path = ROOT / name
    img = Image.open(path).convert("RGBA")
    bg = Image.new("RGBA", img.size, background + (255,))
    bg.alpha_composite(img)
    img = bg.convert("RGB")
    ratio = width / img.width
    img = img.resize((width, int(img.height * ratio)), Image.LANCZOS)
    buf = io.BytesIO()
    img.save(buf, "PNG", optimize=True)
    data = "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()
    _cache[key] = data
    return data


def esc(v):
    return html.escape(str(v))


def shot(name, label, caption, tag):
    return (
        f"<figure class='shot'><div class='tag {tag.lower()}'>{esc(label)}</div>"
        f"<img src='{image(name)}' alt=''>"
        f"<figcaption>{esc(caption)}</figcaption></figure>"
    )


def page(content, n, cls=""):
    return (
        f"<section class='page {cls}'><div class='inner'>{content}</div>"
        f"<div class='footer'><span>PalTuro · implementation report · 6 November 2026</span>"
        f"<span class='num'>{n:02d} / {TOTAL:02d}</span></div></section>"
    )


def head(idx, title, side):
    return (
        f"<div class='top'><span>PalTuro / implementation report</span>"
        f"<span><b>{esc(side)}</b></span></div>"
        f"<div class='fix-head'><div class='fix-no'>{idx}</div><div>"
        f"<h2>{title}</h2></div></div>"
    )


CSS = """
@page { size: 210mm 297mm; margin: 0; }
* { box-sizing: border-box; }
body { margin:0; font-family:'Segoe UI','Inter',Arial,sans-serif; color:#171a12; background:#d8d5c9; font-size:9.2pt; line-height:1.45; }
.page { position:relative; width:210mm; height:297mm; background:#f7f5ee; overflow:hidden; page-break-after:always; }
.page:last-child { page-break-after:auto; }
.inner { position:absolute; inset:0; padding:14mm 16mm 16mm; }
.footer { position:absolute; left:16mm; right:16mm; bottom:7mm; border-top:.25mm solid #d9d6c9; padding-top:2mm; display:flex; justify-content:space-between; font-size:5.7pt; letter-spacing:.1em; text-transform:uppercase; color:#66695e; }
.footer .num { font-weight:700; color:#2d3126; }
h1,h2,h3 { font-family:'Inter','Segoe UI',sans-serif; margin:0; letter-spacing:-.03em; }
h1 { font-size:34pt; line-height:1.0; }
h2 { font-size:19pt; line-height:1.08; margin:0; }
h3 { font-size:9.6pt; margin:0 0 1.6mm; }
p { margin:0 0 2.4mm; }
ul { margin:0 0 2mm; padding-left:4mm; }
li { margin-bottom:1.1mm; }
.kicker { font-size:6pt; letter-spacing:.18em; text-transform:uppercase; color:#5a6900; font-weight:700; margin-bottom:1.8mm; }
.label { font-size:5.6pt; letter-spacing:.14em; text-transform:uppercase; color:#5a6900; font-weight:700; margin-bottom:1.2mm; }
.muted { color:#66695e; }
.small { font-size:7.5pt; line-height:1.4; }
.tiny { font-size:6.3pt; line-height:1.35; }
.mono { font-family:'Cascadia Mono',Consolas,monospace; font-size:6.6pt; color:#5a6900; }
.top { display:flex; justify-content:space-between; border-bottom:.3mm solid #d9d6c9; padding-bottom:2mm; margin-bottom:4mm; font-size:5.8pt; letter-spacing:.16em; text-transform:uppercase; color:#66695e; }
.top b { color:#5a6900; }
.fix-head { display:flex; gap:4mm; align-items:flex-start; margin-bottom:3mm; }
.fix-no { font-size:6.2pt; letter-spacing:.08em; color:#fff; background:#1d2a14; border-radius:1.4mm; padding:1.3mm 2mm; margin-top:1mm; white-space:nowrap; }
.lede { font-size:8.9pt; line-height:1.5; color:#3b3e34; margin:0 0 3mm; }
.lede b { color:#171a12; }
.rule { height:.3mm; background:#d9d6c9; margin:3mm 0; }
.grid-2 { display:grid; grid-template-columns:1fr 1fr; gap:4mm; }
.grid-3 { display:grid; grid-template-columns:repeat(3,1fr); gap:3.4mm; }
.grid-4 { display:grid; grid-template-columns:repeat(4,1fr); gap:2.8mm; }
.card { background:#fffdf7; border:.28mm solid #d9d6c9; border-radius:2.2mm; padding:3.4mm; }
.card.tint { background:#efede4; }
.callout { background:#eaf4b8; border-left:1.6mm solid #b8d400; padding:3.1mm 4mm; border-radius:1mm; margin:2.4mm 0; }
.callout.warn { background:#faf0da; border-left-color:#c08828; }
.callout.risk { background:#f9e7e3; border-left-color:#a64336; }
.metric-grid { display:grid; grid-template-columns:repeat(4,1fr); gap:2.8mm; margin:3.2mm 0; }
.metric { background:#efede4; border:.28mm solid #d9d6c9; border-radius:2.2mm; padding:3mm; }
.metric .n { font-size:18pt; line-height:1; font-weight:700; }
.metric .t { font-size:5.6pt; letter-spacing:.11em; text-transform:uppercase; color:#66695e; margin-top:1.4mm; line-height:1.3; }
table { width:100%; border-collapse:collapse; }
th { font-size:5.5pt; letter-spacing:.1em; text-transform:uppercase; text-align:left; color:#66695e; border-bottom:.3mm solid #c6c3b4; padding:1.4mm 1.1mm; }
td { font-size:6.9pt; line-height:1.32; border-bottom:.2mm solid #d9d6c9; padding:1.35mm 1.1mm; vertical-align:top; }
tr:last-child td { border-bottom:none; }
.pill { display:inline-block; padding:.5mm 1.8mm; border-radius:9mm; font-size:5pt; font-weight:700; letter-spacing:.07em; text-transform:uppercase; white-space:nowrap; }
.pill.done { background:#edf6c2; color:#4d5e00; border:.2mm solid #c7d88c; }
.pill.high { background:#f7dfdb; color:#8b3229; border:.2mm solid #dfb3ac; }
.pill.med { background:#f6ecd2; color:#795900; border:.2mm solid #ddc48c; }
.pill.low { background:#efede4; color:#66695e; border:.2mm solid #d9d6c9; }
.shots { display:flex; justify-content:center; align-items:flex-start; gap:5mm; margin:1.5mm 0 2mm; }
.shots.two .shot { width:55mm; }
.shots.three .shot { width:38mm; }
.shots.four .shot { width:34mm; }
.shots.small .shot { width:44mm; }
.shot { margin:0; text-align:center; }
.shot img { display:block; width:100%; border:.3mm solid #c9c6b7; border-radius:2mm; background:#fff; }
.shot figcaption { font-size:5.7pt; line-height:1.3; color:#66695e; padding-top:1.1mm; }
.tag { display:inline-block; font-size:4.9pt; font-weight:800; letter-spacing:.12em; padding:.55mm 2mm; border-radius:8mm; margin-bottom:1mm; }
.tag.before { background:#f6dcd7; color:#8b3229; }
.tag.after { background:#eaf4b8; color:#4d5e00; }
.stat-strip { display:flex; gap:4mm; border-top:.3mm solid #d9d6c9; padding-top:2.5mm; margin-top:1mm; }
.stat { flex:1; }
.stat .k { font-size:5.4pt; letter-spacing:.11em; text-transform:uppercase; color:#66695e; }
.stat .v { font-size:8.2pt; font-weight:700; margin-top:.6mm; }
.cover { background:radial-gradient(circle at 88% 12%,rgba(200,234,0,.14),transparent 36%),#12160f; color:#f7f5ee; }
.cover .inner { padding:18mm; }
.cover .logo { width:46mm; margin-bottom:26mm; }
.cover .eyebrow { color:#d3f000; font-size:6.6pt; letter-spacing:.22em; text-transform:uppercase; font-weight:700; }
.cover h1 { font-size:47pt; line-height:.95; margin-top:5mm; max-width:128mm; color:#fff; }
.cover h1 em { font-style:normal; color:#d3f000; }
.cover .sub { font-size:13pt; line-height:1.25; color:#d6d9cc; margin-top:6mm; max-width:112mm; }
.cover .desc { font-size:8.4pt; line-height:1.5; color:#aeb2a2; max-width:105mm; margin-top:4mm; }
.cover .metrics { display:flex; gap:3mm; margin-top:10mm; width:128mm; }
.cover .metric { background:rgba(255,255,255,.055); border:.3mm solid rgba(255,255,255,.13); border-radius:2mm; padding:2.8mm; flex:1; }
.cover .metric .n { color:#d3f000; font-size:16pt; }
.cover .metric .t { color:#b5b8aa; }
.cover .contents { position:absolute; left:18mm; right:18mm; bottom:70mm; border-top:.25mm solid #343a2e; padding-top:3mm; display:grid; grid-template-columns:repeat(3,1fr); gap:6mm; }
.cover .contents .k { color:#d3f000; font-size:5.7pt; letter-spacing:.14em; }
.cover .contents b { display:block; color:#eef0e4; font-size:8pt; margin-top:1.2mm; letter-spacing:0; }
.cover .contents em { display:block; font-style:normal; color:#8f9485; font-size:6pt; margin-top:.7mm; letter-spacing:.08em; }
.cover .meta { position:absolute; left:18mm; right:18mm; bottom:20mm; border-top:.25mm solid #343a2e; padding-top:3mm; display:flex; gap:9mm; font-size:6.2pt; color:#929687; }
.cover .meta b { display:block; color:#f7f5ee; margin-top:1mm; }
"""


def cover():
    return f"""
<section class='page cover'><div class='inner'>
  <img class='logo' src='{logo('assets/images/hlogo_white.png', 420)}' alt='PalTuro'>
  <div class='eyebrow'>Implementation report · 6 November 2026</div>
  <h1>Nine fixes.<br><em>One centered</em><br>record.</h1>
  <div class='sub'>Every finding closed, with normalised before/after screens and three audits behind each gate.</div>
  <div class='desc'>This edition rebuilds the report from scratch: all captures are cropped to the device frame and centred in their rows, so the interface is never pushed to one side.</div>
  <div class='metrics'>
    <div class='metric'><div class='n'>9/9</div><div class='t'>fixes shipped</div></div>
    <div class='metric'><div class='n'>182</div><div class='t'>tests passing</div></div>
    <div class='metric'><div class='n'>44</div><div class='t'>files changed</div></div>
    <div class='metric'><div class='n'>0</div><div class='t'>analyzer issues</div></div>
  </div>
  <div class='contents'>
    <div><div class='k'>01</div><b>Summary &amp; method</b><em>pages 02–03</em></div>
    <div><div class='k'>02</div><b>Findings V-01 – V-08</b><em>pages 04–11</em></div>
    <div><div class='k'>03</div><b>Deck hotfix &amp; close-out</b><em>pages 12–15</em></div>
  </div>
  <div class='meta'>
    <div>BRANCH<b>ui-features</b></div>
    <div>BASE → HEAD<b>b121126 → 408c1b9</b></div>
    <div>METHOD<b>3 audits per fix</b></div>
    <div>PREPARED FOR<b>PalTuro product team</b></div>
  </div>
</div></section>"""


def p2():
    return page(f"""
<div class='top'><span>PalTuro / implementation report</span><span><b>Executive summary</b></span></div>
<div class='fix-head'><div class='fix-no'>SUMMARY</div><div><h2>Everything the audit found is closed, and the deck no longer sticks.</h2></div></div>
<p class='lede'>Eight visual findings were fixed first, each behind a three-auditor gate. A later swipe defect — cards left outside the viewport and a request spinner that could hang — was fixed as a ninth change, with its own tests. The report is regenerated from a clean template; every capture is cropped to 390 × 844 and centred.</p>
<div class='metric-grid'>
  <div class='metric'><div class='n'>9/9</div><div class='t'>fixes closed</div></div>
  <div class='metric'><div class='n'>182</div><div class='t'>tests (from 161)</div></div>
  <div class='metric'><div class='n'>30</div><div class='t'>gate rounds</div></div>
  <div class='metric'><div class='n'>0</div><div class='t'>open blockers</div></div>
</div>
<table><thead><tr><th style='width:12mm'>Fix</th><th style='width:18mm'>Finding</th><th>Outcome</th><th style='width:18mm'>Commit</th><th style='width:13mm'>State</th></tr></thead><tbody>
<tr><td class='mono'>VF-01</td><td>V-01</td><td>Role cards size to content and stay reachable on short screens.</td><td class='mono'>9a60a2a</td><td><span class='pill done'>Pass</span></td></tr>
<tr><td class='mono'>VF-02</td><td>V-02</td><td>Slow load admits it and offers Retry; cache paints first.</td><td class='mono'>2cf6cde</td><td><span class='pill done'>Pass</span></td></tr>
<tr><td class='mono'>VF-03</td><td>V-03</td><td>One empty-state component across Chats, Requests, Activity.</td><td class='mono'>f2b1ae2</td><td><span class='pill done'>Pass</span></td></tr>
<tr><td class='mono'>VF-04</td><td>V-04</td><td>Name clamps, avatar 72, empty skills get an action.</td><td class='mono'>d6c68bf</td><td><span class='pill done'>Pass</span></td></tr>
<tr><td class='mono'>VF-05</td><td>V-05</td><td>One 48 px action grid; rightmost centre at 350.</td><td class='mono'>dc12bed</td><td><span class='pill done'>Pass</span></td></tr>
<tr><td class='mono'>VF-06</td><td>V-06</td><td>Browse clears the floating nav, including the skeleton.</td><td class='mono'>f347172</td><td><span class='pill done'>Pass</span></td></tr>
<tr><td class='mono'>VF-07</td><td>V-07</td><td>Settings end with a safe-area inset and a 48 px action.</td><td class='mono'>9629f56</td><td><span class='pill done'>Pass</span></td></tr>
<tr><td class='mono'>VF-08</td><td>V-08</td><td>“0 Pals”, en-dash steps, top-centred media.</td><td class='mono'>5a18e7a</td><td><span class='pill done'>Pass</span></td></tr>
<tr><td class='mono'>VF-09</td><td>Deck</td><td>Long swipes commit; hanging sends time out; red skip surface.</td><td class='mono'>408c1b9</td><td><span class='pill done'>Pass</span></td></tr>
</tbody></table>
<div class='callout' style='margin-top:3mm'><p class='small' style='margin:0'><b>Report integrity:</b> the previous PDF embedded several captures that were wider than the phone frame (880–920 px instead of 780), which left a white strip on the right and made the UI look shifted left. This edition crops every capture to the 780 px device width before scaling.</p></div>
<div class='grid-3' style='margin-top:3mm'>
  <div class='card'><div class='label'>First run</div><p class='small'>Readable role choices; honest loading with a way out.</p></div>
  <div class='card'><div class='label'>Daily use</div><p class='small'>One empty rhythm, a stable profile header, Browse that ends cleanly.</p></div>
  <div class='card tint'><div class='label'>Deck</div><p class='small'>Release past the threshold always commits; no dead spinner.</p></div>
</div>
""", 2)


def p3():
    return page(f"""
{head('METHOD', 'Three independent audits before a fix could move on.', 'Process')}
<p class='lede'>Each change went through the same gate: analyzer and full suite locally, then functionality, quality, and regression reviews. A failure returned the fix to implementation and all three audits ran again. The deck hotfix added a fourth check: repeated gesture runs on the web build.</p>
<div class='grid-3'>
  <div class='card'><div class='label'>Functionality</div><p class='small'>Acceptance criteria, interactions, edge states, semantics.</p></div>
  <div class='card'><div class='label'>Quality</div><p class='small'>Tokens, structure, accessibility, test quality, analyzer.</p></div>
  <div class='card'><div class='label'>Regression</div><p class='small'>Full suite, adjacent screens, short viewports, 200% text, platform chrome.</p></div>
</div>
<h3 style='margin-top:4mm'>Gate results</h3>
<table><thead><tr><th style='width:15mm'>Fix</th><th style='width:18mm'>Rounds</th><th>What a failed round caught</th><th style='width:13mm'>Result</th></tr></thead><tbody>
<tr><td class='mono'>VF-01</td><td>3</td><td>Scroll clipped the card; landscape overflowed; 200% text wasn't covered.</td><td><span class='pill done'>Pass</span></td></tr>
<tr><td class='mono'>VF-02</td><td>2</td><td>Stale load cancelled the retry timers; cache seed was reset.</td><td><span class='pill done'>Pass</span></td></tr>
<tr><td class='mono'>VF-03</td><td>4</td><td>Nav inset lost; sliver intrinsics; 2×2 cells overflowed.</td><td><span class='pill done'>Pass</span></td></tr>
<tr><td class='mono'>VF-04</td><td>3</td><td>Add-skills semantics merged into the parent; clamp untested.</td><td><span class='pill done'>Pass</span></td></tr>
<tr><td class='mono'>VF-05</td><td>9</td><td>iOS bar clamped targets; chat header clipped at 200%.</td><td><span class='pill done'>Pass</span></td></tr>
<tr><td class='mono'>VF-06</td><td>4</td><td>Clearance double-counted the nav; skeleton kept 90 px.</td><td><span class='pill done'>Pass</span></td></tr>
<tr><td class='mono'>VF-07</td><td>3</td><td>Safe area ignored; denied action overflowed at 200%.</td><td><span class='pill done'>Pass</span></td></tr>
<tr><td class='mono'>VF-08</td><td>2</td><td>Four of five step labels missed the en dash; video alignment ignored.</td><td><span class='pill done'>Pass</span></td></tr>
<tr><td class='mono'>VF-09</td><td>4</td><td>Long-drag guard blocked dismissal; request had no cap.</td><td><span class='pill done'>Pass</span></td></tr>
</tbody></table>
<div class='grid-2' style='margin-top:4mm'>
  <div class='card'><div class='label'>Test progression</div><p class='small'><b>161 → 182</b>. New coverage for card height, loading states, empty states, profile clamp, chrome targets, nav clearance, settings inset, Pals copy, and the deck's long-swipe / timeout paths.</p></div>
  <div class='card tint'><div class='label'>Commands</div><p class='small mono'>flutter analyze --no-pub<br>flutter test --no-pub<br>flutter build web --release</p></div>
</div>
<div class='callout warn' style='margin-top:3mm'><p class='small' style='margin:0'><b>Evidence policy:</b> commits are local on <span class='mono'>ui-features</span>. Screens were captured at 390 × 844 @2× from the release web build; every image is normalised to 780 px before layout.</p></div>
""", 3)


def p4():
    return page(f"""
{head('VF-01 / 09', 'Role cards: from three empty columns to three choices.', 'V-01 · 9a60a2a')}
<p class='lede'>The three cards stretched to the page: <b>650 × 105 px</b>, content pinned low. A <span class='mono'>Container</span> with <span class='mono'>alignment</span> under loose constraints expanded to fill the page.</p>
<div class='shots two'>
  {shot('ob-1.png', 'Before', 'Three tall columns, content near the bottom', 'before')}
  {shot('final-role.png', 'After', 'Content-height cards, centred as a group', 'after')}
</div>
<div class='grid-3'>
  <div class='card'><div class='label'>Change</div><p class='small'>Remove alignment, floor the card at 168 px, and let the role body scroll when the header or text scale leaves too little room.</p></div>
  <div class='card'><div class='label'>Accessibility</div><p class='small'>2 px selected ring (10:1), 48 px back target, 200% text scrolls instead of overflowing.</p></div>
  <div class='card tint'><div class='label'>Evidence</div><p class='small'>168 px pinned; 640×411 and 390×844 @200%; dark-mode border.</p></div>
</div>
<table style='margin-top:3mm'><thead><tr><th style='width:44mm'>Measure</th><th>Before</th><th>After</th></tr></thead><tbody>
<tr><td>Card height</td><td>~650 px</td><td>168 px floor</td></tr>
<tr><td>Empty space above content</td><td>~358 px</td><td>~0 px</td></tr>
<tr><td>Short landscape + 200%</td><td>overflow</td><td>scrolls, no exception</td></tr>
</tbody></table>
""", 4)


def p5():
    return page(f"""
{head('VF-02 / 09', 'A slow deck now says so, and offers a way out.', 'V-02 · 2cf6cde')}
<p class='lede'>A cold load showed a 328 × 690 skeleton for 10–12 seconds with no timeout, progress, or retry. The after capture is the loaded deck; the 4 s and 12 s states are covered by widget tests because the test deck resolves before the 4 s threshold.</p>
<div class='shots two'>
  {shot('audit-home-after-outside.png', 'Before', 'Full-card skeleton, no fallback', 'before')}
  {shot('final2-home.png', 'After', 'Deck arrives; slow/timeout states tested', 'after')}
</div>
<div class='grid-3'>
  <div class='card'><div class='label'>4 seconds</div><p class='small'>“Still looking for matches…” with Retry over the skeleton.</p></div>
  <div class='card'><div class='label'>12 seconds</div><p class='small'>The request is capped and becomes a retryable error.</p></div>
  <div class='card tint'><div class='label'>Return visits</div><p class='small'>The previous deck is seeded via <span class='mono'>peekDeck</span> and preserved when ids match.</p></div>
</div>
<table style='margin-top:3mm'><thead><tr><th style='width:26mm'>Window</th><th>User sees</th><th style='width:48mm'>State</th></tr></thead><tbody>
<tr><td>0–4 s</td><td>Full-card skeleton</td><td>loading</td></tr>
<tr><td>4–12 s</td><td>Still looking… + Retry</td><td>slow, loading</td></tr>
<tr><td>12 s+</td><td>Taking longer… + Retry</td><td>timeout error</td></tr>
</tbody></table>
""", 5)


def p6():
    return page(f"""
{head('VF-03 / 09', 'Chats, Requests, and Activity share one rhythm.', 'V-03 · f2b1ae2')}
<p class='lede'>Before, the same message sat at ≈500 px, ≈700 px, and ≈430 px; Activity had no illustration. One <span class='mono'>AppEmptyState</span> now owns the illustration, type hierarchy, action slot, and nav-aware inset.</p>
<div class='shots three'>
  {shot('audit-tab-chats.png', 'Before', 'Chats', 'before')}
  {shot('audit-tab-requests.png', 'Before', 'Requests', 'before')}
  {shot('audit-activity.png', 'Before', 'Activity', 'before')}
</div>
<div class='shots three'>
  {shot('after-chats.png', 'After', 'Chats', 'after')}
  {shot('after-requests.png', 'After', 'Requests', 'after')}
  {shot('after-activity.png', 'After', 'Activity', 'after')}
</div>
<div class='grid-2'>
  <div class='card'><div class='label'>One component</div><p class='small'>Optional illustration, title, message, action, bottom inset; the illustration drops to 120 px at large text.</p></div>
  <div class='card tint'><div class='label'>Behaviour kept</div><p class='small'>Start swiping, clear filters, view sent, refresh, view requests, show all — callbacks unchanged.</p></div>
</div>
""", 6)


def p7():
    return page(f"""
{head('VF-04 / 09', 'A long name no longer bends the header.', 'V-04 · d6c68bf')}
<p class='lede'>The name wrapped to two lines, Edit sat against line one, and empty skills rendered as bare headings. The header now clamps; the avatar is 72 px; empty sections invite an action.</p>
<div class='shots two'>
  {shot('audit-tab-profile.png', 'Before', 'Wrapped name, empty skill cards', 'before')}
  {shot('final2-profile.png', 'After', 'Clamped name, 0 Pals, Add skills', 'after')}
</div>
<div class='grid-3'>
  <div class='card'><div class='label'>Header</div><p class='small'>One line with ellipsis; Edit is top-right and independent of wrapping.</p></div>
  <div class='card'><div class='label'>Skills</div><p class='small'>“No skills added yet” plus a 48 px action that opens the editor.</p></div>
  <div class='card tint'><div class='label'>Evidence</div><p class='small'>Clamp, avatar, 200% header, and the empty-state callback are tested.</p></div>
</div>
<table style='margin-top:3mm'><thead><tr><th style='width:40mm'>Measure</th><th>Before</th><th>After</th></tr></thead><tbody>
<tr><td>Display name</td><td>2 lines</td><td>1 line + ellipsis</td></tr>
<tr><td>Avatar</td><td>95 px</td><td>72 px</td></tr>
<tr><td>Empty skills</td><td>heading only</td><td>copy + Add skills</td></tr>
</tbody></table>
""", 7)


def p8():
    return page(f"""
{head('VF-05 / 09', 'One 48 px grid, ending at x=350.', 'V-05 · dc12bed')}
<p class='lede'>The rightmost action was 44 px on Home/Chats/Requests and 48 px on Browse/Profile, so its centre drifted between 352 and 350. Every in-app action now uses <span class='mono'>iconTarget</span> and the same trailing inset.</p>
<div class='shots two'>
  {shot('audit-home-loaded.png', 'Before', '44 px actions, centre 352', 'before')}
  {shot('final2-home.png', 'After', '48 px actions, centre 350', 'after')}
</div>
<table style='margin-top:2mm'><thead><tr><th style='width:38mm'>Surface</th><th>Centre</th><th>Target</th><th>Result</th></tr></thead><tbody>
<tr><td>Home</td><td>352 → 350</td><td>44 → 48</td><td>aligned</td></tr>
<tr><td>Chats / Requests</td><td>352 → 350</td><td>44 → 48</td><td>aligned</td></tr>
<tr><td>Browse / Profile / Pals</td><td>350</td><td>48</td><td>unchanged</td></tr>
<tr><td>iOS top bar</td><td>44</td><td>48</td><td>bar grows to fit</td></tr>
</tbody></table>
<div class='callout' style='margin-top:2mm'><p class='small' style='margin:0'><b>Also:</b> the chat header derives its height from the same 1.34 text-scale clamp AppBar uses.</p></div>
""", 8)


def p9():
    return page(f"""
{head('VF-06 / 09', 'The last Browse row clears the floating nav.', 'V-06 · f347172')}
<p class='lede'>Fixed 90/112 px padding let the last row meet the nav, and the skeleton used a different value. Clearance is now <span class='mono'>padding.bottom + 16</span>; short cells fall back to the scrollable auto grid.</p>
<div class='shots two'>
  {shot('audit-tab-browse.png', 'Before', 'Last row meets the nav', 'before')}
  {shot('final5-browse-end.png', 'After', 'Last row clears the nav', 'after')}
</div>
<div class='grid-3'>
  <div class='card'><div class='label'>Clearance</div><p class='small'>The shell reports the nav height; add 16 px only — no overlap, no double gap.</p></div>
  <div class='card'><div class='label'>Short screens</div><p class='small'>Below 172 px, a 2×2 cell switches to the scrollable auto grid.</p></div>
  <div class='card tint'><div class='label'>Skeleton</div><p class='small'>Uses the same helper, so loading and loaded rows agree.</p></div>
</div>
<table style='margin-top:3mm'><thead><tr><th style='width:42mm'>Measure</th><th>Before</th><th>After</th></tr></thead><tbody>
<tr><td>Bottom padding</td><td>90 / 112 px</td><td>nav + 16 px</td></tr>
<tr><td>Scroll-end gap</td><td>meets nav</td><td>16 px clear</td></tr>
<tr><td>Skeleton</td><td>90 px</td><td>same helper</td></tr>
</tbody></table>
""", 9)


def p10():
    return page(f"""
{head('VF-07 / 09', 'Notification settings end with breathing room.', 'V-07 · 9629f56')}
<p class='lede'>The list ended at the viewport edge with a hard-coded 100 px pad. It now reserves 32 px plus the system safe area; the denied-permission action is a 48 px icon instead of a text button that consumed the tile at 200%.</p>
<div class='shots two'>
  {shot('audit-notif-settings2.png', 'Before', 'Content cut at the edge', 'before')}
  {shot('final6-notif-end.png', 'After', 'Changes apply immediately, with room', 'after')}
</div>
<div class='grid-3'>
  <div class='card'><div class='label'>Inset</div><p class='small'><span class='mono'>32 + padding.bottom</span>; pushed above the tab shell, so no double count.</p></div>
  <div class='card'><div class='label'>Permission row</div><p class='small'>Icon action, 48 px target, tooltip; no overflow at 200%.</p></div>
  <div class='card tint'><div class='label'>Evidence</div><p class='small'>Constant and safe-area term pinned; probes at insets 0/34/48.</p></div>
</div>
<table style='margin-top:3mm'><thead><tr><th style='width:40mm'>Measure</th><th>Before</th><th>After</th></tr></thead><tbody>
<tr><td>Scroll-end inset</td><td>100 px fixed</td><td>32 px + safe area</td></tr>
<tr><td>At inset 34</td><td>—</td><td>66 px total</td></tr>
</tbody></table>
""", 10)


def p11():
    return page(f"""
{head('VF-08 / 09', 'Small words, one dash, a better crop.', 'V-08 · 5a18e7a')}
<p class='lede'>The profile read “Pal 0”, onboarding mixed hyphen and en-dash labels, and card media centre-cropped portraits. The label is now a single “0 Pals”, every step uses U+2013, and media is top-aligned for images and video.</p>
<div class='shots two small'>
  {shot('audit-tab-profile.png', 'Before', '“Pal 0”', 'before')}
  {shot('final2-profile.png', 'After', '“0 Pals”', 'after')}
</div>
<div class='shots two small'>
  {shot('audit-home-loaded.png', 'Before', 'Centre crop fills the card', 'before')}
  {shot('after-home-media.png', 'After', 'Top-aligned subject', 'after')}
</div>
<div class='callout'><p class='small' style='margin:0'><b>Also verified:</b> “Step 1 of 4 – Role” uses U+2013 in all five flow labels; <span class='mono'>palCountLabel</span> returns 0 Pals / 1 Pal / 2 Pals; video shares the image alignment.</p></div>
""", 11)


def p12():
    return page(f"""
{head('VF-09 / 09', 'The deck commits on release — and no longer strands a card.', 'Deck hotfix · 408c1b9')}
<p class='lede'>Releasing a card after dragging it past the viewport edge left it outside the screen: <span class='mono'>dismiss()</span> refused when the offset passed 1.1× width and nothing reset the deck. A hanging send also left “Sending request…” forever.</p>
<div class='shots three'>
  {shot('stuck-15.png', 'Before', 'Card stranded; spinner never clears', 'before')}
  {shot('timeout-14.png', 'After', '12 s cap restores the card + error', 'after')}
  {shot('left-surface2.png', 'After', 'Filled red skip surface, white X', 'after')}
</div>
<div class='grid-3'>
  <div class='card'><div class='label'>Release</div><p class='small'>Past 35% or a flick &gt;800 px/s commits; below threshold settles back. A card already past the edge finishes immediately.</p></div>
  <div class='card'><div class='label'>Request</div><p class='small'>Sends are capped at 12 s, then the card returns with an error instead of an endless busy state.</p></div>
  <div class='card tint'><div class='label'>Visual</div><p class='small'>Skip is now a filled red card with white X and label, mirroring the filled green check.</p></div>
</div>
<div class='stat-strip'>
  <div class='stat'><div class='k'>Recursive runs</div><div class='v'>20 + 15, zero failures</div></div>
  <div class='stat'><div class='k'>Gesture checks</div><div class='v'>Long drag, 5 consecutive, hang</div></div>
  <div class='stat'><div class='k'>Tests</div><div class='v'>+5 deck / timeout</div></div>
</div>
<table style='margin-top:3mm'><thead><tr><th style='width:52mm'>Gesture</th><th>Expected</th><th style='width:16mm'>Result</th></tr></thead><tbody>
<tr><td>Long drag, 2× card width</td><td>Commit once, no off-screen card</td><td>Pass</td></tr>
<tr><td>Release at 60% width</td><td>Commit with exit animation</td><td>Pass</td></tr>
<tr><td>Release at 20% width</td><td>Settle back to origin</td><td>Pass</td></tr>
<tr><td>Five consecutive long swipes</td><td>Five advances</td><td>Pass</td></tr>
<tr><td>Request hangs</td><td>Card restored after 12 s + error</td><td>Pass</td></tr>
</tbody></table>
""", 12)


def p13():
    return page(f"""
{head('COVERAGE', 'What changed, by area.', 'Files')}
<p class='lede'>Diff from <span class='mono'>b121126</span> to <span class='mono'>408c1b9</span>: <b>44 files</b>, <b>+1,612 / −449</b> lines. Tests grew from 161 to 182.</p>
<table><thead><tr><th style='width:32mm'>Area</th><th>Files</th><th style='width:32mm'>What changed</th></tr></thead><tbody>
<tr><td><b>Onboarding</b></td><td class='mono'>role_card_group, onboarding_scaffold, role_screen, flow, interests/final/review</td><td>Card height, scrollBody, en-dash labels, 48 px back</td></tr>
<tr><td><b>Home / deck</b></td><td class='mono'>home_page, match_api, swipe_deck</td><td>Loading states, cache seed, long-swipe commit, request cap</td></tr>
<tr><td><b>Empty states</b></td><td class='mono'>app_empty_state (new), chats_page, request_page, notifications_page</td><td>One widget, nav-aware inset, illustration parity</td></tr>
<tr><td><b>Profile / skills</b></td><td class='mono'>profile_page, profile_edit, skills_card</td><td>Clamp, 72 px avatar, Add skills, 48 px actions</td></tr>
<tr><td><b>Chrome</b></td><td class='mono'>app_spacing, explore*, matches, chats_room, block_list, account*, person_card, request_detail</td><td>48 px targets, iOS 48 bar, text-aware header</td></tr>
<tr><td><b>Browse / settings</b></td><td class='mono'>explore_page, app_skeleton, notification_preferences_page</td><td>Clearance helper, 2×2 fallback, safe-area inset</td></tr>
<tr><td><b>Copy / media</b></td><td class='mono'>pals_count, onboarding*, showcase_media, person_card</td><td>0 Pals, en dash, top-centre crop</td></tr>
</tbody></table>
<h3 style='margin-top:4mm'>Test files</h3>
<div class='grid-3'>
  <div class='card'><div class='label'>New</div><p class='small mono'>home_loading_test<br>home_swipe_test<br>app_empty_state_test<br>profile_summary_test<br>chrome_targets_test<br>app_spacing_test</p></div>
  <div class='card'><div class='label'>Extended</div><p class='small mono'>onboarding_semantics_test<br>skills_readonly_test<br>notification_preferences_test<br>pals_count_test<br>swipe_deck_test</p></div>
  <div class='card tint'><div class='label'>API note</div><p class='small'>New: <span class='mono'>AppEmptyState</span>, spacing helpers, <span class='mono'>peekDeck</span>, deck send hook. <span class='mono'>hasCachedDeck</span> removed after checking callers.</p></div>
</div>
<div class='callout' style='margin-top:3mm'><p class='small' style='margin:0'><b>Screenshot hygiene:</b> 3 captures were 880–920 px wide with a pure-white strip on the right. They are cropped to 780 px in this edition, which removes the visual left shift.</p></div>
""", 13)


def p14():
    return page(f"""
{head('VERIFICATION', 'The evidence behind the green gates.', 'Tests')}
<div class='metric-grid'>
  <div class='metric'><div class='n'>182</div><div class='t'>tests passing</div></div>
  <div class='metric'><div class='n'>0</div><div class='t'>analyzer issues</div></div>
  <div class='metric'><div class='n'>30</div><div class='t'>audit rounds</div></div>
  <div class='metric'><div class='n'>90</div><div class='t'>auditor passes</div></div>
</div>
<h3>Behaviour pinned</h3>
<table><thead><tr><th style='width:24mm'>Fix</th><th>Assertions</th></tr></thead><tbody>
<tr><td>VF-01</td><td>168 px card; 640×411; 390×844 @200%; dark selected ring.</td></tr>
<tr><td>VF-02</td><td>4 s copy; 12 s timeout; retry re-arms; stale load cannot cancel it.</td></tr>
<tr><td>VF-03</td><td>Shared widget; illustration presence; 200% nav clearance.</td></tr>
<tr><td>VF-04</td><td>One-line name; avatar 72; empty CTA; 200% Edit hittable.</td></tr>
<tr><td>VF-05</td><td>48×48 actions; rightmost 350; iOS bar ≥48.</td></tr>
<tr><td>VF-06</td><td>Clearance nav+16 for insets 80/94/108.</td></tr>
<tr><td>VF-07</td><td>32 and 32+safe-area; 200% page.</td></tr>
<tr><td>VF-08</td><td>0 Pals / 1 Pal / 2 Pals; en-dash role label.</td></tr>
<tr><td>VF-09</td><td>Long drag commits; below-threshold returns; 5 swipes; red surface; send timeout.</td></tr>
</tbody></table>
<div class='callout' style='margin-top:4mm'><p class='small' style='margin:0'><b>Commands:</b> analyze clean; 182 tests pass; release web build with <span class='mono'>--dart-define-from-file=.env</span>. Deck checked with 20 + 15 repeated runs and live mouse/touch drags.</p></div>
<h3 style='margin-top:4mm'>Audit verdicts</h3>
<table><thead><tr><th style='width:15mm'>Fix</th><th>Functionality</th><th>Quality</th><th>Regression</th><th style='width:13mm'>Rounds</th></tr></thead><tbody>
<tr><td class='mono'>VF-01</td><td>Pass</td><td>Pass</td><td>Pass</td><td>3</td></tr>
<tr><td class='mono'>VF-02</td><td>Pass</td><td>Pass</td><td>Pass</td><td>2</td></tr>
<tr><td class='mono'>VF-03</td><td>Pass</td><td>Pass</td><td>Pass</td><td>4</td></tr>
<tr><td class='mono'>VF-04</td><td>Pass</td><td>Pass</td><td>Pass</td><td>3</td></tr>
<tr><td class='mono'>VF-05</td><td>Pass</td><td>Pass</td><td>Pass</td><td>9</td></tr>
<tr><td class='mono'>VF-06</td><td>Pass</td><td>Pass</td><td>Pass</td><td>4</td></tr>
<tr><td class='mono'>VF-07</td><td>Pass</td><td>Pass</td><td>Pass</td><td>3</td></tr>
<tr><td class='mono'>VF-08</td><td>Pass</td><td>Pass</td><td>Pass</td><td>2</td></tr>
</tbody></table>
""", 14)


def p15():
    return page(f"""
{head('CLOSE-OUT', 'What this pass does not prove.', 'Limits')}
<div class='grid-2'>
  <div class='card'><div class='label'>Environment</div><ul class='small'><li>No iOS build or physical-device pass; platform checks used the test override.</li><li>Web verified at 390×844; 1440 was not re-captured.</li><li>Nothing pushed; commits remain local on <span class='mono'>ui-features</span>.</li></ul></div>
  <div class='card tint'><div class='label'>Known residuals</div><ul class='small'><li>300% text can still overflow the nav labels and auto grid card.</li><li>Pals and Block list keep bespoke empty states outside VF-03.</li><li>The visual report covers 390 width only.</li></ul></div>
</div>
<h3 style='margin-top:5mm'>Commit trail</h3>
<table><thead><tr><th style='width:17mm'>Commit</th><th>Change</th></tr></thead><tbody>
<tr><td class='mono'>9a60a2a</td><td>Role cards size to content; role step scrolls when needed.</td></tr>
<tr><td class='mono'>2cf6cde</td><td>Deck loading has slow/timeout/retry and a cache seed.</td></tr>
<tr><td class='mono'>f2b1ae2</td><td>Shared empty state across Chats, Requests, Activity.</td></tr>
<tr><td class='mono'>d6c68bf</td><td>Profile name clamp, 72 px avatar, Add skills.</td></tr>
<tr><td class='mono'>dc12bed</td><td>48 px chrome, 350 alignment, text-aware chat header.</td></tr>
<tr><td class='mono'>f347172</td><td>Browse clears the nav; skeleton and 2×2 fallback.</td></tr>
<tr><td class='mono'>9629f56</td><td>Notification settings safe-area inset.</td></tr>
<tr><td class='mono'>5a18e7a</td><td>0 Pals, en-dash steps, top-centred media.</td></tr>
<tr><td class='mono'>408c1b9</td><td>Long swipes commit; sends time out; red skip surface.</td></tr>
</tbody></table>
<div class='callout' style='margin-top:5mm'><p class='small' style='margin:0'><b>Next:</b> run this pass on a real iPhone and a 3-button Android device, then decide whether to push <span class='mono'>ui-features</span> and refresh the visual-audit PDF.</p></div>
<div class='grid-3' style='margin-top:4mm'>
  <div class='card'><div class='label'>Before push</div><p class='small'>Re-run the suite on CI and review the 18-file chrome commit.</p></div>
  <div class='card'><div class='label'>Device pass</div><p class='small'>Check 48 px targets, safe areas, and 200% text on hardware.</p></div>
  <div class='card tint'><div class='label'>Report refresh</div><p class='small'>Re-capture the audit surfaces and mark V-01–V-08 resolved.</p></div>
</div>
<div class='rule'></div>
<div class='kv' style='display:grid;grid-template-columns:30mm 1fr;gap:1.4mm 3mm;font-size:7.3pt'>
  <div class='label' style='margin:0'>Report</div><div><b>PalTuro implementation report · 6 Nov 2026</b></div>
  <div class='label' style='margin:0'>Base → head</div><div><b>b121126 → 408c1b9</b></div>
  <div class='label' style='margin:0'>Status</div><div><b>9/9 fixes passed; local commits only</b></div>
</div>
""", 15)


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
{p15()}
</body></html>"""

OUT.write_text(html_doc, encoding="utf-8")
print(f"wrote {OUT} ({OUT.stat().st_size:,} bytes)")
