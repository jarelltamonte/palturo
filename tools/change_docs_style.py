# -*- coding: utf-8 -*-
"""Visual system for the PalTuro dynamic UX change record.

The document is built as fixed A4 pages rather than a flowing article: every
page is a 210 x 297 mm section with an absolutely positioned inner frame.
That keeps pagination deliberate and prevents the half-empty pages produced by
automatic page breaks.
"""
import base64
from pathlib import Path

from change_docs_data import ROOT, TEMP

PALETTE = {
    "paper": "#f6f4ed",
    "ink": "#1b1d17",
    "muted": "#66695e",
    "olive": "#5c6b00",
    "lime": "#d8f400",
    "line": "#d8d5c8",
    "card": "#fffefa",
    "tint": "#eeece2",
}


def b64(path):
    return base64.b64encode(Path(path).read_bytes()).decode("ascii")


def font(name, file, weight, style="normal"):
    data = b64(ROOT / "assets/fonts" / file)
    return (
        f"@font-face{{font-family:'{name}';src:url(data:font/ttf;base64,{data}) "
        f"format('truetype');font-weight:{weight};font-style:{style};font-display:block}}"
    )


FONTS = "\n".join([
    font("Comfortaa", "Comfortaa/Comfortaa-Regular.ttf", 400),
    font("Comfortaa", "Comfortaa/Comfortaa-Bold.ttf", 700),
    font("Inter", "Inter/Inter_18pt-Regular.ttf", 400),
    font("Inter", "Inter/Inter_18pt-Bold.ttf", 700),
    font("Inter", "Inter/Inter_18pt-Italic.ttf", 400, "italic"),
])

LOGO_WHITE = "data:image/png;base64," + b64(ROOT / "assets/images/hlogo_white.png")
LOGO_BLACK = "data:image/png;base64," + b64(ROOT / "assets/images/hlogo_black.png")

CSS = r"""
*{box-sizing:border-box}
html,body{margin:0;padding:0;background:#d6d3c8;color:#1b1d17;font-family:Inter,Arial,sans-serif;-webkit-print-color-adjust:exact;print-color-adjust:exact}
body{font-size:9pt;line-height:1.42}
@page{size:210mm 297mm;margin:0}
.page{position:relative;width:210mm;height:297mm;background:#f6f4ed;overflow:hidden;page-break-after:always;break-after:page}
.page:last-child{page-break-after:auto;break-after:auto}
.inner{position:absolute;inset:0;padding:14mm 15mm 17mm}
.dark{background:#1a1c16;color:#f6f4ed}
.dark .muted{color:#a9ac9d}
.dark .line{border-color:#3a3d31}

/* running head + foot */
.top{display:flex;justify-content:space-between;align-items:flex-end;border-bottom:.35mm solid #d8d5c8;padding-bottom:2mm;margin-bottom:5mm;font-size:6.1pt;letter-spacing:.17em;text-transform:uppercase;color:#66695e}
.top .r{color:#5c6b00;font-weight:700}
.dark .top{border-color:#3a3d31;color:#a9ac9d}
.footer{position:absolute;left:15mm;right:15mm;bottom:7mm;border-top:.25mm solid #d8d5c8;padding-top:2mm;display:flex;justify-content:space-between;font-size:5.9pt;letter-spacing:.08em;text-transform:uppercase;color:#66695e}
.footer .num{font-weight:700;letter-spacing:.12em;color:#31342b}
.dark .footer{border-color:#3a3d31;color:#a9ac9d}
.dark .footer .num{color:#d8f400}

/* type */
h1,h2,h3,h4{font-family:Comfortaa,Inter,sans-serif;font-weight:700;margin:0;letter-spacing:-.025em}
h1{font-size:34pt;line-height:1.02}
h2{font-size:17.5pt;line-height:1.08;margin:0 0 3mm}
h3{font-size:10.2pt;line-height:1.18;margin:0 0 1.8mm}
h4{font-size:8.8pt;line-height:1.2;margin:0 0 1mm}
p{margin:0 0 2.6mm}
.lead{font-size:9.6pt;line-height:1.5;color:#31342b}
.muted{color:#66695e}
.small{font-size:7.8pt;line-height:1.4}
.tiny{font-size:6.5pt;line-height:1.35}
.mono{font-family:'Cascadia Mono',Consolas,monospace;font-size:7pt;color:#5c6b00}
.kicker{font-size:6.2pt;letter-spacing:.18em;text-transform:uppercase;color:#5c6b00;font-weight:700;margin-bottom:2.4mm}
.label{font-size:5.9pt;letter-spacing:.15em;text-transform:uppercase;font-weight:700;color:#5c6b00;margin-bottom:1.6mm}
.dark .kicker,.dark .label{color:#d8f400}
.dark .muted{color:#a9ac9d}
.quote{font-family:Comfortaa;line-height:1.24}
.nowrap{white-space:nowrap}

/* section opener */
.sec-head{display:flex;justify-content:space-between;align-items:flex-end;gap:8mm;margin-bottom:4mm}
.sec-head h2{max-width:142mm;margin-bottom:0}
.sec-head .side{max-width:52mm;text-align:right;font-size:7.2pt;line-height:1.42;color:#66695e;margin:0}
.rule{height:.3mm;background:#d8d5c8;margin:4mm 0}
.dark .rule{background:#3a3d31}

/* cards and grids */
.grid-2{display:grid;grid-template-columns:1fr 1fr;gap:5mm}
.grid-3{display:grid;grid-template-columns:repeat(3,1fr);gap:3.5mm}
.grid-4{display:grid;grid-template-columns:repeat(4,1fr);gap:3mm}
.split{display:grid;grid-template-columns:1.08fr .92fr;gap:6mm;align-items:start}
.split-wide{display:grid;grid-template-columns:1.3fr .7fr;gap:6mm;align-items:start}
.card{background:#fffefa;border:.3mm solid #d8d5c8;border-radius:2.6mm;padding:4.2mm}
.card.tint{background:#eeece2}
.card h3{font-size:9.6pt}
.card p:last-child,.card ul:last-child{margin-bottom:0}
.card .big-no{font-family:Comfortaa;font-size:19pt;line-height:1;color:#5c6b00;margin-bottom:1.5mm}
.grid-2 > .card,.grid-3 > .card,.grid-4 > .card{height:100%}
ul{margin:0 0 2.2mm;padding-left:4mm}
li{margin-bottom:1.3mm}
ul.tight li{margin-bottom:.9mm}
.checks{list-style:none;padding:0;margin:0}
.checks li{position:relative;padding-left:4.6mm;margin-bottom:1.3mm;font-size:7.6pt;line-height:1.38}
.checks li:before{content:"✓";position:absolute;left:0;top:-.2mm;color:#5c6b00;font-weight:700}
.checks.neg li:before{content:"×";color:#a2453a}

/* metrics */
.metric-grid{display:grid;grid-template-columns:repeat(4,1fr);gap:3mm;margin:4mm 0}
.metric{background:#eeece2;border:.3mm solid #d8d5c8;border-radius:2.6mm;padding:3.4mm}
.metric .n{font-family:Comfortaa;font-size:21pt;line-height:1;letter-spacing:-.04em;color:#22251b}
.metric .n em{font-style:normal;font-size:10pt;color:#5c6b00}
.metric .t{font-size:5.9pt;letter-spacing:.12em;text-transform:uppercase;color:#66695e;margin-top:1.6mm;line-height:1.3}
.dark .metric{background:rgba(255,255,255,.05);border-color:rgba(255,255,255,.13)}
.dark .metric .n{color:#f6f4ed}.dark .metric .n em{color:#d8f400}
.dark .metric .t{color:#b7baab}

/* pills */
.ok,.blocked,.deferred,.neutral{display:inline-block;padding:.7mm 2mm;border-radius:9mm;font-size:5.4pt;letter-spacing:.08em;font-weight:700;text-transform:uppercase;white-space:nowrap}
.ok{background:#eef6c9;color:#4f6000;border:.2mm solid #c8d88f}
.blocked{background:#f7dfdb;color:#8d332a;border:.2mm solid #dfb3ac}
.deferred{background:#f6ecd2;color:#7a5a00;border:.2mm solid #ddc48c}
.neutral{background:#eeece2;color:#66695e;border:.2mm solid #d8d5c8}
.ok:before{content:"●";font-size:4pt;margin-right:1mm;vertical-align:.3mm}

/* tables */
table{width:100%;border-collapse:collapse}
th{font-size:5.8pt;letter-spacing:.1em;text-transform:uppercase;text-align:left;color:#66695e;border-bottom:.35mm solid #c7c4b5;padding:1.8mm 1.4mm;vertical-align:bottom}
td{font-size:7.2pt;line-height:1.36;border-bottom:.2mm solid #d8d5c8;padding:1.7mm 1.4mm;vertical-align:top}
tr:last-child td{border-bottom:none}
td.case{font-weight:700;white-space:nowrap}
td.mono,th.mono{font-family:'Cascadia Mono',Consolas,monospace;font-size:6.6pt;color:#5c6b00}
table.compact td{padding:1.25mm 1.2mm;font-size:6.8pt;line-height:1.3}
table.compact th{padding:1.4mm 1.2mm}
table.ledger td{font-size:6.55pt;padding:1.05mm 1mm;line-height:1.26}
table.ledger th{font-size:5.4pt;padding:1.2mm 1mm}
table.files td{font-family:'Cascadia Mono',Consolas,monospace;font-size:5.9pt;padding:.72mm 1mm;line-height:1.18}
table.files th{font-size:5.4pt;padding:1mm 1mm}
table.files td.area{font-family:Inter,Arial,sans-serif;font-size:6.3pt;color:#66695e}
tr.section td{background:#eeece2;font-weight:700;font-size:6.1pt;letter-spacing:.12em;text-transform:uppercase;color:#5c6b00}

/* callouts */
.callout{background:linear-gradient(120deg,#e9f6a8,#f4f9d7);border-left:1.8mm solid #c4df00;padding:4mm 5mm;border-radius:1mm;margin:4mm 0}
.callout p:last-child{margin-bottom:0}
.callout.warn{background:#fbf2dd;border-left-color:#c58a2b}
.callout.risk{background:#f9e8e5;border-left-color:#a2453a}
.callout.dark{background:#25291c;border-left-color:#d8f400;color:#f6f4ed}
.callout.dark .muted{color:#a9ac9d}

/* key/value */
.kv{display:grid;grid-template-columns:31mm 1fr;gap:1.6mm 3mm;font-size:7.6pt}
.kv .k{font-size:5.9pt;letter-spacing:.11em;text-transform:uppercase;color:#66695e;padding-top:.3mm}
.kv .v{font-weight:700;color:#31342b}

/* cover + back */
.cover{background:radial-gradient(circle at 92% 88%,rgba(216,244,0,.22),transparent 34%),radial-gradient(circle at 70% 0%,rgba(216,244,0,.07),transparent 36%),#1a1c16;color:#f6f4ed}
.cover .inner{position:absolute;inset:0;padding:18mm}
.cover .logo{width:48mm;margin-bottom:27mm}
.cover .title{font-family:Comfortaa;font-size:33pt;line-height:1.04;letter-spacing:-.045em;width:110mm}
.cover .title .lime{color:#d8f400}
.cover .sub{font-family:Comfortaa;font-size:12.4pt;line-height:1.16;color:#d7d9cc;margin-top:4mm;width:104mm}
.cover .desc{font-size:8.3pt;color:#b3b6a8;width:100mm;margin-top:4mm;line-height:1.48}
.cover .metrics{display:flex;gap:3mm;margin-top:7mm;width:110mm}
.cover .metric{background:rgba(255,255,255,.055);border:.3mm solid rgba(255,255,255,.13);border-radius:2mm;padding:2.6mm;flex:1}
.cover .metric .n{font-size:15.5pt;color:#d8f400;font-family:Comfortaa;line-height:1}
.cover .metric .t{font-size:5.1pt;color:#b7baab;margin-top:1.2mm;line-height:1.28;letter-spacing:.06em;text-transform:uppercase}
.cover .meta{display:flex;gap:5.5mm;margin-top:7mm;font-size:6.1pt;color:#aeb1a2;width:112mm}
.cover .meta b{display:block;color:#f6f4ed;font-size:6.4pt;margin-top:.8mm;font-weight:700}
.cover .meta span{font-size:5.2pt;letter-spacing:.1em;text-transform:uppercase}
.cover .phone{position:absolute;right:14mm;top:44mm;width:60mm;border:.5mm solid #4b4e3e;border-radius:6mm;overflow:hidden;box-shadow:0 12mm 26mm rgba(0,0,0,.5);transform:rotate(1.6deg);background:#000}
.cover .phone img{display:block;width:100%}
.cover .ring{position:absolute;border:.35mm solid rgba(216,244,0,.3);border-radius:50%}
.cover .ring.one{width:120mm;height:120mm;right:-46mm;bottom:-42mm}
.cover .ring.two{width:82mm;height:82mm;right:-16mm;bottom:-14mm;border-color:rgba(216,244,0,.58)}
.cover .ring.three{width:43mm;height:43mm;right:16mm;bottom:15mm;border-color:rgba(216,244,0,.9)}
.cover .tracks{position:absolute;left:18mm;right:18mm;bottom:19mm;display:grid;grid-template-columns:repeat(4,1fr);gap:4mm;border-top:.25mm solid rgba(255,255,255,.16);padding-top:3mm}.cover .tracks div{font-size:5.5pt;letter-spacing:.12em;text-transform:uppercase;color:#8f9488}
.cover .tracks b{display:block;color:#f6f4ed;font-size:7.4pt;letter-spacing:0;text-transform:none;margin-bottom:.8mm;font-weight:700}
.cover .quote-line{position:absolute;left:18mm;bottom:45mm;width:106mm;font-family:Comfortaa;font-size:14pt;line-height:1.22;color:#d7d9cc}
.cover .quote-line .lime{color:#d8f400}

/* contents */
.toc{display:grid;grid-template-columns:1fr 1fr;gap:0 10mm}
.toc-row{display:flex;justify-content:space-between;gap:4mm;border-bottom:.2mm dotted #d8d5c8;padding:1.55mm 0;font-size:7.9pt}
.toc-row .t{display:flex;gap:2mm}
.toc-row .no{color:#5c6b00;font-weight:700;width:6mm;flex:0 0 6mm}
.toc-row .p{color:#66695e;font-size:6.9pt;white-space:nowrap}
.toc-group{font-size:6pt;letter-spacing:.14em;text-transform:uppercase;color:#66695e;margin:3mm 0 1mm;font-weight:700}

/* screenshots */
.shots{display:grid;gap:3mm;align-items:start}
.shots.two{grid-template-columns:repeat(2,1fr)}
.shots.three{grid-template-columns:repeat(3,1fr)}
.phone-wrap{margin:0;min-width:0}
.phone-wrap .phone{background:#fff;border:.35mm solid #c7c4b5;border-radius:4mm;overflow:hidden;box-shadow:0 2mm 5mm rgba(27,29,23,.1)}
.phone-wrap img{display:block;width:100%}
.cap{font-size:6.2pt;line-height:1.32;color:#66695e;margin-top:1.4mm}
.cap b{display:block;color:#31342b;font-size:6.5pt;margin-bottom:.4mm}
.wide{border:.35mm solid #c7c4b5;border-radius:3mm;overflow:hidden;box-shadow:0 2mm 5mm rgba(27,29,23,.08)}
.wide img{display:block;width:100%}
.gallery{display:grid;grid-template-columns:repeat(3,46mm);gap:3.6mm 5mm;justify-content:center;align-items:start;margin-top:1mm}
.gallery .phone-wrap .phone{border-radius:3.4mm}
.gallery .cap{font-size:5.9pt;line-height:1.28;margin-top:1.1mm}
.gallery .cap b{font-size:6.1pt}
.gallery .note-card{background:#eeece2;border:.3mm solid #d8d5c8;border-radius:3mm;padding:3.6mm;height:100%;display:flex;flex-direction:column}
.gallery .note-card h4{font-family:Comfortaa;font-size:8.4pt;margin-bottom:1.6mm}
.gallery .note-card p{font-size:6.4pt;line-height:1.4;margin:0}
.gallery .note-card table{margin-top:1mm}
.gallery .note-card th{font-size:5pt;padding:.8mm 0;border-bottom:.2mm solid #c7c4b5}
.gallery .note-card td{font-size:5.9pt;padding:.68mm 0;border-bottom:.15mm solid #ddd9ca;line-height:1.28}
.gallery .note-card td:first-child{color:#5c6b00;font-weight:700;white-space:nowrap;padding-right:2mm}
.gallery .note-card ul{padding-left:3.4mm;margin:0}
.gallery .note-card li{font-size:6.3pt;line-height:1.35;margin-bottom:.8mm}
.gallery-wide{display:grid;grid-template-columns:repeat(4,41mm);gap:4mm;justify-content:center;align-items:start}
.gallery-wide .cap{font-size:5.8pt}
.gallery-wide .phone-wrap .phone{border-radius:3mm}

/* architecture */
.arch{background:#fffefa;border:.3mm solid #d8d5c8;border-radius:3mm;padding:5mm;margin:3mm 0}
.arch-row{display:grid;grid-template-columns:repeat(5,1fr);gap:2mm;align-items:stretch}
.arch-node{background:#eeece2;border:.3mm solid #d8d5c8;border-radius:2mm;padding:3mm 2.4mm;min-height:19mm}
.arch-node .n{font-size:6pt;letter-spacing:.1em;text-transform:uppercase;color:#66695e;margin-bottom:1.2mm}
.arch-node b{font-family:Comfortaa;font-size:7.6pt;line-height:1.2;display:block}
.arch-node span{font-size:6.1pt;line-height:1.3;color:#66695e;display:block;margin-top:1mm}
.arch-arrow{display:flex;align-items:center;justify-content:center;color:#5c6b00;font-size:12pt;font-weight:700}
.arch-split{display:grid;grid-template-columns:repeat(4,1fr);gap:2mm;margin-top:3mm}
.arch-split div{background:#f4f8da;border:.25mm solid #d7e3a2;border-radius:2mm;padding:2.4mm;font-size:6.7pt;line-height:1.35}
.arch-split b{display:block;font-size:7pt;margin-bottom:.6mm}

/* misc */
.steps{display:grid;grid-template-columns:repeat(3,1fr);gap:3mm}
.step{background:#fffefa;border:.3mm solid #d8d5c8;border-radius:2mm;padding:3.6mm}
.step .no{font-family:Comfortaa;font-size:16pt;color:#5c6b00;line-height:1}
.step h3{font-size:8.8pt;margin:1.6mm 0 1.2mm}
.step p{font-size:6.9pt;line-height:1.35;margin:0;color:#66695e}
.big{font-family:Comfortaa;font-size:44pt;line-height:.95;letter-spacing:-.05em;color:#5c6b00;margin:2mm 0 1mm}
.big-sub{font-family:Comfortaa;font-size:14pt;line-height:1.15;margin-bottom:5mm}
.timeline{display:grid;grid-template-columns:repeat(5,1fr);gap:2mm;margin-top:3mm}
.timeline .t{background:#fffefa;border:.25mm solid #d8d5c8;border-radius:2mm;padding:2.6mm;font-size:6.5pt;line-height:1.32}
.timeline .t b{display:block;font-family:Comfortaa;font-size:7.2pt;margin-bottom:.8mm}
.timeline .t .no{font-size:5.5pt;letter-spacing:.12em;color:#5c6b00;font-weight:700}
.sign{display:grid;grid-template-columns:1fr 1fr;gap:9mm;margin-top:8mm}
.sign .line{border-bottom:.3mm solid #31342b;height:10mm}
.sign .who{font-size:5.9pt;letter-spacing:.1em;text-transform:uppercase;color:#66695e;margin-top:1.4mm}
"""
