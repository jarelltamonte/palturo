# -*- coding: utf-8 -*-
"""Build the desktop-webapp implementation report (HTML, print to PDF).

Screenshots are pulled from the Playwright QA folder and normalised so the
report stays a fixed A4 page count.
"""
import base64
import io
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SHOTS = Path.home() / "AppData" / "Local" / "Temp" / "opencode" / "palturo-pw"
OUT = ROOT / "docs" / "PalTuro-Desktop-Webapp-Report-2026-11-13.html"

_cache = {}


def shot(name, width_mm, crop=None):
    """Embed a screenshot as a base64 JPEG, scaled to a printed width."""
    key = (name, width_mm, crop)
    if key in _cache:
        return _cache[key]
    path = SHOTS / name
    img = Image.open(path).convert("RGB")
    if crop:
        img = img.crop(crop)
    px = int(width_mm / 25.4 * 144)  # ~144 dpi is plenty for print
    ratio = px / img.width
    img = img.resize((px, max(1, int(img.height * ratio))), Image.LANCZOS)
    buf = io.BytesIO()
    img.save(buf, "JPEG", quality=88, optimize=True)
    data = "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode()
    _cache[key] = data
    return data


def figure(name, caption, width_mm=100, crop=None):
    return (
        "<figure class='shot' style='width:%dmm'>"
        "<img src='%s' alt='%s'>"
        "<figcaption>%s</figcaption>"
        "</figure>" % (width_mm, shot(name, width_mm, crop), caption, caption)
    )


CSS = """
@page { size: 210mm 297mm; margin: 0; }
* { box-sizing: border-box; }
body { margin:0; font-family:'Segoe UI','Inter',Arial,sans-serif; color:#171a12; background:#d8d5c9; font-size:9.2pt; line-height:1.45; }
.page { position:relative; width:210mm; height:297mm; background:#f7f5ee; overflow:hidden; page-break-after:always; }
.page:last-child { page-break-after:auto; }
.inner { position:absolute; inset:0; padding:13mm 16mm 14mm; }
.footer { position:absolute; left:16mm; right:16mm; bottom:7mm; border-top:.25mm solid #d9d6c9; padding-top:2mm; display:flex; justify-content:space-between; font-size:5.7pt; letter-spacing:.1em; text-transform:uppercase; color:#66695e; }
.footer .num { font-weight:700; color:#2d3126; }
h1,h2,h3 { font-family:'Inter','Segoe UI',sans-serif; margin:0; letter-spacing:-.03em; }
h1 { font-size:33pt; line-height:1.0; }
h2 { font-size:18.5pt; line-height:1.08; margin:0; }
h3 { font-size:9.4pt; margin:0 0 1.6mm; }
p { margin:0 0 2.3mm; }
ul { margin:0 0 2mm; padding-left:4mm; }
li { margin-bottom:1.1mm; }
.kicker { font-size:6pt; letter-spacing:.18em; text-transform:uppercase; color:#5a6900; font-weight:700; margin-bottom:1.8mm; }
.label { font-size:5.6pt; letter-spacing:.14em; text-transform:uppercase; color:#5a6900; font-weight:700; margin-bottom:1.2mm; }
.muted { color:#66695e; }
.small { font-size:7.6pt; line-height:1.42; }
.tiny { font-size:6.4pt; line-height:1.36; }
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
.card { background:#fffdf7; border:.28mm solid #d9d6c9; border-radius:2.2mm; padding:3.3mm; }
.card.tint { background:#efede4; }
.callout { background:#eaf4b8; border-left:1.6mm solid #b8d400; padding:3mm 3.8mm; border-radius:1mm; margin:2.4mm 0; }
.callout.warn { background:#faf0da; border-left-color:#c08828; }
.callout.risk { background:#f9e7e3; border-left-color:#a64336; }
.metric-grid { display:grid; grid-template-columns:repeat(4,1fr); gap:2.8mm; margin:3.2mm 0; }
.metric { background:#efede4; border:.28mm solid #d9d6c9; border-radius:2.2mm; padding:3mm; }
.metric .n { font-size:17pt; line-height:1; font-weight:700; }
.metric .t { font-size:5.6pt; letter-spacing:.11em; text-transform:uppercase; color:#66695e; margin-top:1.4mm; line-height:1.3; }
table { width:100%; border-collapse:collapse; }
th { font-size:5.5pt; letter-spacing:.1em; text-transform:uppercase; text-align:left; color:#66695e; border-bottom:.3mm solid #c6c3b4; padding:1.4mm 1.1mm; }
td { font-size:6.9pt; line-height:1.34; border-bottom:.2mm solid #d9d6c9; padding:1.4mm 1.1mm; vertical-align:top; }
tr:last-child td { border-bottom:none; }
.pill { display:inline-block; padding:.5mm 1.8mm; border-radius:9mm; font-size:5pt; font-weight:700; letter-spacing:.07em; text-transform:uppercase; white-space:nowrap; }
.pill.done { background:#edf6c2; color:#4d5e00; border:.2mm solid #c7d88c; }
.pill.med { background:#f6ecd2; color:#795900; border:.2mm solid #ddc48c; }
.pill.low { background:#efede4; color:#66695e; border:.2mm solid #d9d6c9; }
.shots { display:flex; justify-content:center; align-items:flex-start; gap:4mm; margin:1mm 0 1mm; }
.shot { margin:0; text-align:center; }
.shot img { width:100%; display:block; border:.3mm solid #cfccbe; border-radius:1.4mm; }
.shot figcaption { font-size:5.9pt; color:#66695e; margin-top:1.2mm; line-height:1.3; }
.cover { display:flex; flex-direction:column; justify-content:space-between; height:100%; }
.cover h1 em { font-style:normal; color:#5a6900; }
.cover .bottom { border-top:.3mm solid #d9d6c9; padding-top:3mm; display:flex; justify-content:space-between; align-items:flex-end; }
.code { font-family:'Cascadia Mono',Consolas,monospace; font-size:6.4pt; background:#efede4; border:.25mm solid #d9d6c9; border-radius:1.4mm; padding:2.6mm 3mm; white-space:pre-wrap; color:#3b3e34; line-height:1.4; }
"""


def page(inner, num, total, right=None):
    right = right or "PalTuro / desktop webapp"
    return (
        "<div class='page'><div class='inner'>%s</div>"
        "<div class='footer'><span>%s</span>"
        "<span class='num'>%02d / %02d</span></div></div>"
        % (inner, right, num, total)
    )


def top(label, right):
    return "<div class='top'><span>%s</span><span><b>%s</b></span></div>" % (
        label,
        right,
    )


TOTAL = 11
pages = []

# ---------------------------------------------------------------- 1. cover
pages.append(
    page(
        """
<div class='cover'>
  <div>
    %s
    <div class='kicker' style='margin-top:26mm'>Implementation report / 13 November 2026</div>
    <h1>Desktop parity.<br><em>Ten bugs closed.</em><br>One chat that holds still.</h1>
    <p class='lede' style='margin-top:7mm;max-width:150mm'>
      The web app now runs as a desktop product without changing the phone
      experience. Alongside the layout work, this pass closes the notification,
      request, chat-deletion, keyboard, and scroll defects found in review, and
      turns every deleted message into a permanent ghost so a thread cannot be
      rewritten after the fact.
    </p>
    <div class='metric-grid' style='margin-top:8mm'>
      <div class='metric'><div class='n'>201</div><div class='t'>Widget and unit tests passing</div></div>
      <div class='metric'><div class='n'>0</div><div class='t'>Analyzer issues</div></div>
      <div class='metric'><div class='n'>20</div><div class='t'>Tracked files changed</div></div>
      <div class='metric'><div class='n'>2</div><div class='t'>Supabase migrations applied</div></div>
    </div>
    <div class='grid-3' style='margin-top:12mm'>
      <div class='card'>
        <div class='label'>01 / Desktop shell</div>
        <p class='small' style='margin:0'>
          Sidebar navigation, content caps, framed routes, and an exhausted
          deck that works on both wide and narrow screens.
        </p>
      </div>
      <div class='card'>
        <div class='label'>02 / Behaviour fixes</div>
        <p class='small' style='margin:0'>
          Requests badge, stale notifications, banner crash, keyboard overlap,
          message and conversation deletion.
        </p>
      </div>
      <div class='card'>
        <div class='label'>03 / Chat integrity</div>
        <p class='small' style='margin:0'>
          Deleted messages become ghosts, and the thread always lands on the
          newest message above the composer.
        </p>
      </div>
    </div>
  </div>
  <div>
    <div class='grid-3' style='margin-bottom:6mm'>
      <div class='card tint'>
        <div class='label'>Scope</div>
        <p class='tiny' style='margin:0'>
          Desktop layout for the web build, with every phone behaviour kept
          as the source of truth.
        </p>
      </div>
      <div class='card tint'>
        <div class='label'>Out of scope</div>
        <p class='tiny' style='margin:0'>
          Native builds, marketing site, and docs site. No commit, push, or
          deploy was made.
        </p>
      </div>
      <div class='card tint'>
        <div class='label'>Read this with</div>
        <p class='tiny' style='margin:0'>
          The two Supabase migrations in the repo, and the screenshots in
          this report taken from the local build.
        </p>
      </div>
    </div>
    <div class='bottom'>
    <div class='tiny muted'>
      Branch <b>palturo-webapp</b> at <b>137e382</b> plus uncommitted work.<br>
      Live checks against the local build on port 5319 and Supabase project
      <b>yjcrfgvenilptrnudvcb</b>.<br>
      Nothing was committed, pushed, or deployed for this report.
    </div>
    <div class='tiny muted' style='text-align:right'>
      PalTuro<br>Skill exchange
    </div>
    </div>
  </div>
</div>
"""
        % top("PalTuro / implementation report", "Cover"),
        1,
        TOTAL,
    )
)

# ---------------------------------------------------------------- 2. summary
pages.append(
    page(
        top("PalTuro / implementation report", "Summary")
        + """
<div class='fix-head'><div class='fix-no'>SUMMARY</div><div>
  <h2>Two product asks, ten defects, and one rule for deleted text.</h2>
</div></div>
<p class='lede'>
  The desktop shell is additive: every screen still renders exactly as before
  below 900 px. The fixes below were each reproduced first, then pinned with a
  test or a live check so the same failure cannot return quietly.
</p>
<table>
  <tr><th style='width:22mm'>Area</th><th style='width:58mm'>What was wrong</th><th>What changed</th></tr>
  <tr><td><b>Desktop layout</b></td><td>Web opened as a stretched phone: floating bottom bar, single narrow column, no navigation context.</td><td>Sidebar shell at 900 px and up, per-screen content caps, framed pushed pages. Phone layout untouched.</td></tr>
  <tr><td><b>For You deck</b></td><td>When every card was seen the screen went blank with no explanation.</td><td>Animated exhausted pile with a plain note and four ways forward, remembered across sessions.</td></tr>
  <tr><td><b>Explore</b></td><td>Explore listed skills, not people, so it could not fill the deck.</td><td>Endless random person deck built from the same card as For You.</td></tr>
  <tr><td><b>Browse</b></td><td>Empty categories were shown, so tapping one led to a dead end.</td><td>Only branches with people for the active role are listed, each with a live count.</td></tr>
  <tr><td><b>Requests badge</b></td><td>Badge counted every unread activity, including feedback and handled requests.</td><td>Badge counts unread incoming connection requests only.</td></tr>
  <tr><td><b>Banner crash</b></td><td>Match banner used a tooltip button above the Navigator, where no Overlay exists.</td><td>Tooltip replaced with a semantics label; regression test asserts no Overlay ancestor is required.</td></tr>
  <tr><td><b>Stale notifications</b></td><td>Withdrawn requests and read-state changes on another device never reached this client.</td><td>Realtime now handles insert, update, and delete; banners are enriched with names and skills.</td></tr>
  <tr><td><b>Login keyboard</b></td><td>Primary actions sat in a bottom bar the keyboard covered.</td><td>Actions moved into the scrollable form; login resizes to avoid the inset on mobile.</td></tr>
  <tr><td><b>Deletion</b></td><td>No way to remove a message or clear a conversation.</td><td>Sender-only message delete, participant-only conversation clear, Pal connection kept.</td></tr>
  <tr><td><b>Deleted context</b></td><td>Deleting a message removed the row, so a sender could erase what a reply answered.</td><td>Rows become tombstones: body set to "Message Deleted", <span class='mono'>deleted_at</span> recorded.</td></tr>
  <tr><td><b>Chat scroll</b></td><td>New messages stopped one line short of the bottom.</td><td>Second post-frame jump after the lazy list refines its extent.</td></tr>
</table>
<div class='callout'>
  <b>Rule applied to deleted text.</b> A deleted message keeps its place in the
  thread. Both people see a gray, italic "Message Deleted" bubble that cannot be
  tapped, long-pressed, or copied, and the database keeps the row with its
  timestamp.
</div>
<h3 style='margin-top:6mm'>How each item was handled</h3>
<div class='grid-4'>
  <div class='card tint'>
    <div class='label'>1 / Reproduce</div>
    <p class='tiny' style='margin:0'>
      Two accounts on the local build. Every defect was seen before it was
      touched, so the cause was observed rather than guessed.
    </p>
  </div>
  <div class='card tint'>
    <div class='label'>2 / Fix at the cause</div>
    <p class='tiny' style='margin:0'>
      Badge data source, Overlay-free banner, RPC tombstone, second scroll
      frame. No timing hacks where a structural fix existed.
    </p>
  </div>
  <div class='card tint'>
    <div class='label'>3 / Pin it</div>
    <p class='tiny' style='margin:0'>
      Widget tests for the keyboard, banner, deck, and request rollback.
      Live runs for deletion, ghosts, and scroll.
    </p>
  </div>
  <div class='card tint'>
    <div class='label'>4 / Prove it</div>
    <p class='tiny' style='margin:0'>
      Analyzer clean, 201 tests green, disposable QA data removed, test
      account returned to its original state.
    </p>
  </div>
</div>
<div class='rule' style='margin-top:6mm'></div>
<div class='grid-3'>
  <div>
    <div class='label'>Release state</div>
    <p class='small' style='margin:0'>
      Uncommitted on <b>palturo-webapp</b> at <b>137e382</b>. Nothing pushed,
      nothing deployed.
    </p>
  </div>
  <div>
    <div class='label'>Data state</div>
    <p class='small' style='margin:0'>
      Test account back to 3 Pals and 2 pending requests. No QA rows left in
      profiles, skills, connections, messages, or notifications.
    </p>
  </div>
  <div>
    <div class='label'>Preview</div>
    <p class='small' style='margin:0'>
      Local build on port 5319, served from the branch with the working tree
      as described in this report.
    </p>
  </div>
</div>
""",
        2,
        TOTAL,
    )
)

# ---------------------------------------------------------------- 3. shell
pages.append(
    page(
        top("PalTuro / desktop shell", "Layout")
        + """
<div class='fix-head'><div class='fix-no'>D-01</div><div>
  <h2>A sidebar appears at 900 px, and the phone layout stops being stretched.</h2>
</div></div>
<p class='lede'>
  Above 900 px the bottom bar is replaced by a fixed 248 px sidebar with the
  logo, the four destinations, live badges, and a short product note. The
  content column is capped per screen instead of filling the window.
</p>
<div class='shots'>
  %s
  %s
</div>
<div class='shots'>
  %s
  %s
</div>
<p class='small muted' style='margin-top:1mm'>
  Caps: For You 760 px, Browse 1120 px, Chats, Requests, and Profile 820 px.
  Pushed pages are framed at 820 px, authentication and onboarding at 560 px.
  Badges in the sidebar come from the same services as the phone tab bar.
</p>
<div class='grid-3' style='margin-top:4mm'>
  <div class='card tint'>
    <div class='label'>Sidebar</div>
    <p class='tiny' style='margin:0'>
      Fixed 248 px column with the wordmark, the four destinations, live
      badges, and a short note that the product is mobile-first.
    </p>
  </div>
  <div class='card tint'>
    <div class='label'>Frames</div>
    <p class='tiny' style='margin:0'>
      Pushed pages render inside an 820 px frame with a back affordance, so a
      chat or a profile never stretches to the window edge.
    </p>
  </div>
  <div class='card tint'>
    <div class='label'>Badges</div>
    <p class='tiny' style='margin:0'>
      Chats and Requests counts come from the same services as the phone tab
      bar, so the two layouts cannot disagree.
    </p>
  </div>
</div>
"""
        % (
            figure("s1440-home.png", "For You at 1440, 760 px column", 88),
            figure("browse-polished.png", "Browse at 1440, 1120 px grid", 88),
            figure("d1440-chats.png", "Chats at 1440, 820 px column", 88),
            figure("d1440-requests.png", "Requests at 1440, 820 px column", 88),
        ),
        3,
        TOTAL,
        right="PalTuro / desktop webapp",
    )
)

# ---------------------------------------------------------------- 4. breakpoints
pages.append(
    page(
        top("PalTuro / desktop shell", "Breakpoints")
        + """
<div class='fix-head'><div class='fix-no'>D-02</div><div>
  <h2>Three layouts, one code path, no second app to maintain.</h2>
</div></div>
<p class='lede'>
  The shell decides once from the window width. Below 900 px nothing new is
  rendered, so every phone behaviour, gesture, and route transition is the one
  that already shipped.
</p>
<table>
  <tr><th style='width:26mm'>Width</th><th style='width:40mm'>Navigation</th><th>Content</th></tr>
  <tr><td><b>900 px and up</b></td><td>Left sidebar, no bottom bar</td><td>Per-screen caps from 760 to 1120 px, pushed pages framed at 820</td></tr>
  <tr><td><b>601 to 899 px</b></td><td>Bottom bar</td><td>Single 600 px column, centered</td></tr>
  <tr><td><b>600 px and below</b></td><td>Bottom bar</td><td>Full width phone layout, unchanged</td></tr>
</table>
<div class='shots' style='margin-top:5mm'>
  %s
  %s
  %s
  %s
</div>
<div class='callout warn' style='margin-top:3mm'>
  <b>Guard against regression.</b> The responsive shell returns the child
  untouched when the window is under 900 px, and the desktop frame does the
  same. There is no desktop-only widget tree that a phone could accidentally
  receive.
</div>
<h3 style='margin-top:5mm'>Kept exactly as shipped on mobile</h3>
<div class='grid-4'>
  <div class='card tint'>
    <div class='label'>Navigation</div>
    <p class='tiny' style='margin:0'>Same five tabs, same order, same floating bar.</p>
  </div>
  <div class='card tint'>
    <div class='label'>Gestures</div>
    <p class='tiny' style='margin:0'>Swipe deck, long press, pull to refresh, and back gestures.</p>
  </div>
  <div class='card tint'>
    <div class='label'>Routes</div>
    <p class='tiny' style='margin:0'>Same push transitions, sheets, and dialogs.</p>
  </div>
  <div class='card tint'>
    <div class='label'>Density</div>
    <p class='tiny' style='margin:0'>Same padding, type scale, and hit targets.</p>
  </div>
</div>
"""
        % (
            figure("s900-home.png", "900 px: sidebar appears", 38),
            figure("tablet-home.png", "800 px: 600 px column", 38),
            figure("m390-home.png", "390 px: phone layout", 38),
            figure("exhausted-mobile.png", "390 px: exhausted state", 38),
        ),
        4,
        TOTAL,
    )
)

# ---------------------------------------------------------------- 5. deck
pages.append(
    page(
        top("PalTuro / For You", "Exhausted state")
        + """
<div class='fix-head'><div class='fix-no'>D-03</div><div>
  <h2>Seen every card? The deck says so, and hands over four exits.</h2>
</div></div>
<p class='lede'>
  Previously the last swipe left a blank canvas. The new state keeps a small
  pile of cards on screen, puts a note on the top card, and offers Explore,
  View Again, Browse, and Update Profile.
</p>
<div class='shots'>
  %s
  %s
</div>
<div class='grid-2' style='margin-top:2mm'>
  <div class='card'>
    <div class='label'>Why it happened</div>
    <p class='small' style='margin:0'>
      The deck had no terminal state. Once every candidate was skipped or
      requested, the list was empty and the page had nothing to draw.
    </p>
  </div>
  <div class='card'>
    <div class='label'>How it is fixed</div>
    <p class='small' style='margin:0'>
      Seen cards are stored per account in
      <span class='mono'>deck_seen_v1_&lt;userId&gt;</span>, so the exhausted
      state survives a reload and a new login. View Again clears that local set.
    </p>
  </div>
</div>
<div class='grid-2' style='margin-top:3mm;align-items:center'>
  <div>%s</div>
  <div class='callout' style='margin:0'>
    <b>Explore is a person deck, not a skill list.</b> It reuses the For You card
    and deals random people without end, so there is always a way to keep looking
    after the curated deck runs out.
  </div>
</div>
"""
        % (
            figure(
                "exhausted.png",
                "Every card seen: the pile stays, with a note on top",
                88,
                (330, 0, 1110, 780),
            ),
            figure(
                "exhausted-relogin.png",
                "The same state after signing out and back in",
                88,
                (330, 0, 1110, 780),
            ),
            figure(
                "explore-after-skips.png",
                "Explore deals another person, not a skill row",
                66,
                (330, 0, 1110, 900),
            ),
        ),
        5,
        TOTAL,
    )
)

# ---------------------------------------------------------------- 6. browse
pages.append(
    page(
        top("PalTuro / Browse", "Dead ends")
        + """
<div class='fix-head'><div class='fix-no'>D-04</div><div>
  <h2>Browse hides what it cannot fill, and counts what it can.</h2>
</div></div>
<p class='lede'>
  Browse used to list every branch in the taxonomy, including branches with no
  mentors or no learners for the role you picked. Tapping one opened an empty
  category. Now the grid only lists branches with people, and each card states
  the count.
</p>
<div class='shots'>
  %s
  %s
</div>
<div class='grid-2'>
  <div class='card tint'>
    <div class='label'>Cause</div>
    <p class='small' style='margin:0'>
      The taxonomy is static. It was rendered without checking whether any
      profile matched the selected role, so the page promised supply it did
      not have.
    </p>
  </div>
  <div class='card tint'>
    <div class='label'>Fix</div>
    <p class='small' style='margin:0'>
      Counts are derived from the loaded people for the active role, empty
      branches are dropped, and the category page filters empty child skills
      while showing an avatar preview at the top.
    </p>
  </div>
</div>
<div class='shots' style='margin-top:4mm'>
  %s
</div>
"""
        % (
            figure("browse-polished.png", "Browse at 1440: only branches with people, counts on each card", 100),
            figure("browse-mobile.png", "Browse at 390: same rule, phone layout", 42),
            figure(
                "category-polished.png",
                "Category page: avatar preview, empty child skills hidden",
                100,
                (300, 0, 1140, 620),
            ),
        ),
        6,
        TOTAL,
    )
)

# ---------------------------------------------------------------- 7. notifications
pages.append(
    page(
        top("PalTuro / notifications", "Badge and banners")
        + """
<div class='fix-head'><div class='fix-no'>B-01</div><div>
  <h2>The Requests badge now counts requests, and banners survive their own host.</h2>
</div></div>
<p class='lede'>
  Two separate faults sat behind the notification complaints: the badge was
  fed by the whole unread feed, and the match banner crashed because its close
  button needed an Overlay that does not exist above the Navigator.
</p>
<div class='shots'>
  %s
  %s
</div>
<div class='grid-2' style='margin-top:1mm'>
  <div class='card'>
    <div class='label'>Badge and read state</div>
    <ul class='small' style='margin:0'>
      <li>Requests badge uses unread incoming connection requests only.</li>
      <li>Accepting or declining marks that request notification read.</li>
      <li>Tapping a banner marks its notification read.</li>
      <li>Realtime handles insert, delete, and update, so a withdrawn request and a read on another device both land here.</li>
    </ul>
  </div>
  <div class='card'>
    <div class='label'>Banner crash</div>
    <p class='small' style='margin:0 0 1.5mm'>
      <span class='mono'>IconButton(tooltip:)</span> builds a Tooltip, which
      looks up an Overlay. The banner host sits above the Navigator, so that
      lookup threw. Replaced with a <span class='mono'>Semantics(label:)</span>
      wrapper, which needs no Overlay.
    </p>
    <p class='small' style='margin:0'>
      Pinned by <span class='mono'>banner does not require an Overlay ancestor</span>.
    </p>
  </div>
</div>
<p class='small muted' style='margin-top:2mm'>
  Banners also respect notification preferences, are enriched with the person
  and skill behind a realtime row, and are removed when the notification is
  withdrawn server-side.
</p>
<h3 style='margin-top:4mm'>One table for the four notification kinds</h3>
<table>
  <tr><th style='width:36mm'>Kind</th><th style='width:26mm'>Counts in badge</th><th style='width:38mm'>Banner</th><th>Realtime source</th></tr>
  <tr><td>Connection request</td><td>Yes, unread only</td><td>Shown unless Requests is open</td><td>Insert on <span class='mono'>notifications</span></td></tr>
  <tr><td>Request accepted or declined</td><td>No</td><td>Shown, enriched with the chat</td><td>Insert on <span class='mono'>notifications</span></td></tr>
  <tr><td>Feedback ready</td><td>No</td><td>Shown, respects preferences</td><td>Insert on <span class='mono'>notifications</span></td></tr>
  <tr><td>Withdrawn request</td><td>Drops immediately</td><td>Existing banner removed</td><td>Delete on <span class='mono'>notifications</span></td></tr>
</table>
"""
        % (
            figure("requests-badge-fixed.png", "Requests badge reflects unread requests only", 118),
            figure("e2e-2-test-banner.png", "Match banner rendered above the Navigator, no Overlay", 118),
        ),
        7,
        TOTAL,
    )
)

# ---------------------------------------------------------------- 8. login
pages.append(
    page(
        top("PalTuro / authentication", "Keyboard")
        + """
<div class='fix-head'><div class='fix-no'>B-02</div><div>
  <h2>The primary button no longer hides behind the keyboard.</h2>
</div></div>
<p class='lede'>
  On a phone the Log In and Sign Up buttons lived in a bottom bar. When the
  keyboard opened, that bar was covered and the form could not be submitted
  without dismissing it first.
</p>
<div class='shots'>
  %s
  %s
</div>
<div class='grid-2' style='margin-top:1mm'>
  <div class='card'>
    <div class='label'>Cause</div>
    <p class='small' style='margin:0'>
      The actions were outside the scrollable body, so the inset that the
      keyboard adds moved the body but not the bar.
    </p>
  </div>
  <div class='card'>
    <div class='label'>Fix</div>
    <p class='small' style='margin:0'>
      Log In, Forgot Password, Create new account, and Sign Up now sit inside
      the form and scroll with it. Login uses
      <span class='mono'>resizeToAvoidBottomInset</span> on mobile and keeps the
      web scroll workaround.
    </p>
  </div>
</div>
<div class='callout' style='margin-top:2.5mm'>
  <b>Regression tests at 390 x 844 with a 300 px keyboard.</b> Login asserts that
  Log In, Forgot Password, and Create new account all end above the keyboard;
  register asserts the same for Sign Up. Both fail on overflow or layout
  exceptions.
</div>
"""
        % (
            figure("login4-page.png", "Login at 390: actions inside the scrollable form", 44),
            figure("login-filled.png", "Register flow: Sign Up follows the form", 44),
        ),
        8,
        TOTAL,
    )
)

# ---------------------------------------------------------------- 9. deletion
pages.append(
    page(
        top("PalTuro / chat deletion", "Message and conversation")
        + """
<div class='fix-head'><div class='fix-no'>B-03</div><div>
  <h2>Long press a message to delete it. Long press a chat to clear it.</h2>
</div></div>
<p class='lede'>
  Message deletion is sender-only. Conversation deletion is available to either
  participant, clears the messages, and deliberately keeps the Pal connection,
  so the relationship is not lost with the history.
</p>
<div class='shots'>
  %s
</div>
<div class='shots'>
  %s
</div>
<div class='grid-2' style='margin-top:1mm'>
  <div class='card'>
    <div class='label'>Backend</div>
    <p class='small' style='margin:0'>
      <span class='mono'>delete_message(uuid)</span> checks the caller is the
      sender. <span class='mono'>delete_conversation(uuid)</span> checks the
      caller is a participant, deletes the messages, and leaves the connection
      row in place.
    </p>
  </div>
  <div class='card'>
    <div class='label'>Defect found in live testing</div>
    <p class='small' style='margin:0'>
      The first conversation delete failed because it reset the
      <span class='mono'>NOT NULL</span> read timestamps to null. It now sets
      them to <span class='mono'>now()</span>, and the live run clears the
      thread while the connection stays <span class='mono'>accepted</span>.
    </p>
  </div>
</div>
<h3 style='margin-top:5mm'>Rules the UI enforces</h3>
<table>
  <tr><th style='width:40mm'>Action</th><th style='width:42mm'>Who can do it</th><th>What survives</th></tr>
  <tr><td>Delete message</td><td>The sender only</td><td>The row, its timestamp, and a "Message Deleted" bubble for both people</td></tr>
  <tr><td>Delete conversation</td><td>Either participant</td><td>The connection, its status, and both profiles. Messages are removed</td></tr>
  <tr><td>Peer view</td><td>Not applicable</td><td>The ghost appears without a refresh, over Realtime UPDATE</td></tr>
</table>
"""
        % (
            figure(
                "rep2-2-delete-confirm.png",
                "Message delete: sender-only, confirmed, then replaced by a ghost",
                150,
                (0, 180, 1440, 760),
            ),
            figure(
                "rep2-5-conversation-confirm.png",
                "Conversation delete: messages go, the Pal connection stays",
                150,
                (0, 180, 1440, 760),
            ),
        ),
        9,
        TOTAL,
    )
)

# ---------------------------------------------------------------- 10. ghosts + scroll
pages.append(
    page(
        top("PalTuro / chat integrity", "Tombstones")
        + """
<div class='fix-head'><div class='fix-no'>B-04</div><div>
  <h2>Deleted text keeps its place, so no one can edit the past.</h2>
</div></div>
<p class='lede'>
  Removing the row let a sender erase a statement and leave the other person's
  reply hanging, which is exactly how a thread gets taken out of context. A
  deleted message is now a tombstone: the body is replaced with
  <b>Message Deleted</b> and <span class='mono'>deleted_at</span> is set. The
  bubble is gray and italic, and cannot be tapped, long-pressed, or copied.
</p>
<div class='shots'>
  %s
  %s
</div>
<div class='grid-2' style='margin-top:1mm'>
  <div class='card'>
    <div class='label'>Server</div>
    <p class='small' style='margin:0'>
      <span class='mono'>20261113000300_message_tombstones.sql</span> adds
      <span class='mono'>deleted_at</span>, rewrites
      <span class='mono'>delete_message</span> as an update, and returns
      <span class='mono'>deleted_at</span> from
      <span class='mono'>get_conversation</span>. Both clients read the same row.
    </p>
  </div>
  <div class='card'>
    <div class='label'>Client</div>
    <p class='small' style='margin:0'>
      The room treats a row as deleted when
      <span class='mono'>deleted_at</span> is set or the body is the ghost text.
      The local delete updates the row in place instead of removing it, and
      Realtime UPDATE paints the peer's tombstone without a refresh.
    </p>
  </div>
</div>
<div class='fix-head' style='margin-top:5mm'><div class='fix-no'>B-05</div><div>
  <h3 style='margin:0'>And the view lands on the newest message, not one line above it.</h3>
</div></div>
<p class='small' style='margin:0'>
  A lazy list reports an estimated <span class='mono'>maxScrollExtent</span> on
  the frame a new bubble is inserted, then refines it once that bubble is laid
  out. The single jump used the estimate, which is why the last line sat just
  below the composer. A second post-frame jump lands on the true bottom. Live
  check: a sent message now sits fully above the composer with the thread
  scrolled to it.
</p>
<div class='shots' style='margin-top:2mm'>
  %s
</div>
"""
        % (
            figure(
                "rep2-3-tombstone.png",
                "Your own deleted message becomes a ghost in place",
                88,
                (300, 60, 1140, 470),
            ),
            figure(
                "tomb3-6-peer-ghost.png",
                "The peer's tombstone arrives live over Realtime",
                88,
                (300, 60, 1140, 830),
            ),
            figure(
                "tomb2-2-sent.png",
                "Sent message lands fully above the composer",
                118,
                (300, 700, 1140, 900),
            ),
        ),
        10,
        TOTAL,
    )
)

# ---------------------------------------------------------------- 11. verification
pages.append(
    page(
        top("PalTuro / verification", "Evidence")
        + """
<div class='fix-head'><div class='fix-no'>VERIFY</div><div>
  <h2>What was run, what it proved, and what it did not.</h2>
</div></div>
<div class='metric-grid' style='margin-top:0'>
  <div class='metric'><div class='n'>201</div><div class='t'>Tests passing</div></div>
  <div class='metric'><div class='n'>0</div><div class='t'>Analyzer issues</div></div>
  <div class='metric'><div class='n'>2</div><div class='t'>Live accounts</div></div>
  <div class='metric'><div class='n'>4</div><div class='t'>Ghost rows verified</div></div>
</div>
<h3>Automated</h3>
<table>
  <tr><th style='width:70mm'>Suite</th><th>Result</th></tr>
  <tr><td><span class='mono'>flutter analyze --no-pub</span></td><td>No issues found</td></tr>
  <tr><td><span class='mono'>flutter test</span></td><td>201 passed, 0 failed</td></tr>
  <tr><td>New: <span class='mono'>login_keyboard_test.dart</span></td><td>Login and register actions end above a 300 px keyboard at 390 x 844</td></tr>
  <tr><td>New: <span class='mono'>app_banner_test.dart</span></td><td>Banner renders without an Overlay ancestor</td></tr>
  <tr><td>New: <span class='mono'>explore_deck_page_test.dart</span>, <span class='mono'>exhausted_deck_view_test.dart</span>, <span class='mono'>seen_deck_service_test.dart</span></td><td>Deck, exhausted state, and seen-card persistence</td></tr>
  <tr><td>New: <span class='mono'>request_card_test.dart</span></td><td>Accept failure rolls the card back</td></tr>
</table>
<h3 style='margin-top:4mm'>Live, two accounts</h3>
<table>
  <tr><th style='width:46mm'>Check</th><th>Observed</th></tr>
  <tr><td>Badge after handling</td><td>Unread request badge drops when the request is accepted or declined</td></tr>
  <tr><td>Banner above Navigator</td><td>Match banner renders, no crash, tapping opens the chat</td></tr>
  <tr><td>Message delete</td><td>Sender deletes, both sides show a ghost, row remains with <span class='mono'>deleted_at</span></td></tr>
  <tr><td>Peer delete</td><td>Ghost appears live without a refresh</td></tr>
  <tr><td>Conversation delete</td><td>Messages drop to 0, chat leaves the list, connection stays <span class='mono'>accepted</span></td></tr>
  <tr><td>Scroll</td><td>Newest sent and received message fully above the composer</td></tr>
  <tr><td>Cleanup</td><td>Disposable QA user removed, test account back to 3 Pals and 2 pending requests</td></tr>
</table>
<h3 style='margin-top:4mm'>Limits</h3>
<ul class='small'>
  <li>The report covers the web build on Chrome at 1440, 900, 800, and 390 px. It does not claim native iOS or Android verification in this pass.</li>
  <li>Tombstones are proven on the message RPC and the chat room. Exports, notifications, and search that quote message text were not re-audited here.</li>
  <li>The scroll fix is verified visually and by behaviour, not by a widget test with a lazy list of variable-height bubbles.</li>
  <li>Nothing was committed, pushed, or deployed. The live site and docs site were not rebuilt for this report.</li>
</ul>
<h3 style='margin-top:4mm'>Files touched</h3>
<p class='tiny muted' style='margin:0'>
  lib/widgets/responsive_shell.dart, desktop_route_frame.dart,
  exhausted_deck_view.dart, app_banner.dart; lib/screen/navigation_bar.dart,
  home_page.dart, explore_page.dart, explore_deck_page.dart,
  explore_category_page.dart, request_page.dart, chats_page.dart,
  chats_room.dart, card/request_card.dart; lib/authentication/login.dart,
  register.dart; lib/services/notification_service.dart,
  notification_presenter.dart, local_notification_service.dart, match_api.dart,
  seen_deck_service.dart; lib/screen/explore_taxonomy.dart;
  supabase/migrations/20261113000200_chat_delete.sql and
  20261113000300_message_tombstones.sql.
</p>
""",
        11,
        TOTAL,
    )
)

html = (
    "<!DOCTYPE html><html lang='en'><head><meta charset='utf-8'>"
    "<title>PalTuro desktop webapp report</title><style>%s</style></head><body>%s</body></html>"
    % (CSS, "".join(pages))
)

OUT.write_text(html, encoding="utf-8")
print("wrote", OUT, len(html))
