from pathlib import Path

p = Path('tools/build_visual_audit.py')
s = p.read_text(encoding='utf-8')


def insert(fn, nxt, marker, code):
    global s
    a = s.index(f"def {fn}():")
    b = s.index(f"def {nxt}():", a)
    chunk = s[a:b]
    idx = chunk.rindex(marker)
    chunk = chunk[:idx] + code + "\n" + chunk[idx:]
    s = s[:a] + chunk + s[b:]


insert("p2", "p3", '""", 2)', """<h3 style='margin-top:5mm'>Severity definitions</h3>
<div class='grid-4'>
  <div class='card'><div class='label'>High</div><p class='small'>Blocks comprehension or first-run trust. Fix before release.</p></div>
  <div class='card'><div class='label'>Medium</div><p class='small'>Visible inconsistency on a common path. Fix in the next pass.</p></div>
  <div class='card'><div class='label'>Low</div><p class='small'>Copy or composition polish. Batch with adjacent work.</p></div>
  <div class='card tint'><div class='label'>Info</div><p class='small'>Working surface recorded as evidence, not a defect.</p></div>
</div>""")

insert("p4", "p5", '""", 4)', """<h3 style='margin-top:4mm'>Observed load timeline</h3>
<div class='grid-4'>
  <div class='card'><div class='label'>0-2 s</div><p class='small'>Full-card skeleton, no progress label beyond "Loading recommendations".</p></div>
  <div class='card'><div class='label'>2-4 s</div><p class='small'>No change; the screen still reads as broken or empty.</p></div>
  <div class='card'><div class='label'>4-10 s</div><p class='small'>No retry or fallback. The skeleton remains the only feedback.</p></div>
  <div class='card tint'><div class='label'>~12 s</div><p class='small'>Deck appears with 14 people. The data was available after two match calls.</p></div>
</div>""")

insert("p5", "p6", '""", 5)', """<h3 style='margin-top:4mm'>Measured empty states</h3>
<table><thead><tr><th style='width:28mm'>Surface</th><th style='width:28mm'>Visual center</th><th style='width:34mm'>Illustration</th><th>Action</th></tr></thead><tbody>
<tr><td><b>Chats</b></td><td>y = 500</td><td>Ghost</td><td>Start swiping</td></tr>
<tr><td><b>Requests</b></td><td>y = 700</td><td>Ghost</td><td>Refresh</td></tr>
<tr><td><b>Activity</b></td><td>y = 430</td><td>None</td><td>View requests</td></tr>
<tr><td><b>Pals / filters</b></td><td>varies</td><td>varies</td><td>varies</td></tr>
</tbody></table>""")

insert("p6", "p7", '""", 6)', """<h3 style='margin-top:4mm'>Name stress matrix</h3>
<table><thead><tr><th style='width:20mm'>Length</th><th>Observed</th><th style='width:34mm'>Expected</th></tr></thead><tbody>
<tr><td>12 chars</td><td>Single line; fits.</td><td>Single line.</td></tr>
<tr><td>20 chars</td><td>Still single line.</td><td>Single line or ellipsis.</td></tr>
<tr><td>25 chars</td><td>Wraps into two lines; card grows.</td><td>Ellipsis or fixed two-line box.</td></tr>
<tr><td>40 chars</td><td>Would wrap further; Edit remains on line one.</td><td>Clamp; Edit anchored top-right.</td></tr>
</tbody></table>""")

insert("p7", "p8", '""", 7)', """<h3 style='margin-top:3mm'>Action spacing</h3>
<table><thead><tr><th style='width:30mm'>Bar</th><th>First action</th><th>Second</th><th>Gap</th></tr></thead><tbody>
<tr><td><b>Home</b></td><td>264</td><td>308 / 352</td><td>44</td></tr>
<tr><td><b>Chats</b></td><td>304</td><td>352</td><td>48</td></tr>
<tr><td><b>Requests</b></td><td>306</td><td>352</td><td>46</td></tr>
<tr><td><b>Browse / Profile</b></td><td>350</td><td>-</td><td>-</td></tr>
</tbody></table>""")

insert("p8", "p9", '""", 8)', """<h3 style='margin-top:4mm'>Shared bottom-inset spec</h3>
<table><thead><tr><th style='width:34mm'>Element</th><th>Current</th><th style='width:40mm'>Target</th></tr></thead><tbody>
<tr><td>Browse list bottom</td><td>No nav-aware inset</td><td>Nav height + 16</td></tr>
<tr><td>Settings / Notifications</td><td>16 px</td><td>32 px</td></tr>
<tr><td>Section rhythm</td><td>20 / 24 mixed</td><td>24</td></tr>
<tr><td>Activity / Chats empty</td><td>Different centers</td><td>Shared EmptyState</td></tr>
</tbody></table>""")

insert("p9", "p10", '""", 9)', """<h3 style='margin-top:4mm'>Screenshot index</h3>
<div class='grid-2'>
  <div class='card'><p class='small'><b>Onboarding:</b> role step at 390. <b>Home:</b> skeleton and loaded deck. <b>Browse:</b> category grid. <b>Chats / Requests / Activity:</b> empty states.</p></div>
  <div class='card tint'><p class='small'><b>Profile / Account:</b> header and security rows. <b>Settings / Notifications / Chat privacy:</b> settings hierarchy. <b>Auth:</b> desktop dark and mobile light.</p></div>
</div>""")

a = s.index("def p10():")
b = s.index("html_doc =", a)
chunk = s[a:b]
idx = chunk.rindex('""", 10)')
code = """<div class='grid-2' style='margin-top:5mm'>
  <div class='card'><div class='label'>Prepared by</div><p class='small'>PalTuro engineering · Playwright visual pass</p></div>
  <div class='card tint'><div class='label'>Next step</div><p class='small'>Fix V-01 and V-02 first, then batch V-03 to V-06 into the next UI pass.</p></div>
</div>"""
chunk = chunk[:idx] + code + "\n" + chunk[idx:]
s = s[:a] + chunk + s[b:]

p.write_text(s, encoding='utf-8')
print('report filled')
