# -*- coding: utf-8 -*-
"""Shared render helpers for the change record pages."""
import base64
import html
from pathlib import Path

from change_docs_data import TEMP


def esc(value):
    return html.escape(str(value))


def src(name):
    path = Path(name)
    if not path.is_absolute():
        path = TEMP / path
    data = base64.b64encode(path.read_bytes()).decode("ascii")
    return "data:image/png;base64," + data


def phone(name, title, caption):
    return (
        f'<figure class="phone-wrap"><div class="phone"><img src="{src(name)}" alt="">'
        f'</div><figcaption class="cap"><b>{esc(title)}</b>{esc(caption)}</figcaption></figure>'
    )


def top(right, left="PalTuro / dynamic UX change record"):
    return f'<div class="top"><span>{esc(left)}</span><span class="r">{esc(right)}</span></div>'


def page(content, n, total, cls="", right="", left="PalTuro / dynamic UX change record"):
    header = top(right, left) if right else ""
    return (
        f'<section class="page {cls}"><div class="inner">{header}{content}</div>'
        f'<div class="footer"><span>PalTuro · dynamic UX, QOL &amp; social presence · 5 Nov 2026</span>'
        f'<span class="num">{n:02d} / {total:02d}</span></div></section>'
    )


def sec_head(kicker, title, side):
    return (
        f'<div class="sec-head"><div><div class="kicker">{kicker}</div>'
        f'<h2>{title}</h2></div><p class="side">{side}</p></div>'
    )


def metric(n, label, suffix=""):
    em = f"<em>{suffix}</em>" if suffix else ""
    return f'<div class="metric"><div class="n">{n}{em}</div><div class="t">{label}</div></div>'
