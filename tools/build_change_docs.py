# -*- coding: utf-8 -*-
"""Build the PalTuro dynamic UX record as fixed A4 pages.

Run:  python tools/build_change_docs.py
Out:  docs/PalTuro-Dynamic-UX-Changes.html
"""
from pathlib import Path

from change_docs_style import CSS, FONTS
import change_docs_pages_a as a
import change_docs_pages_b as b

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs" / "PalTuro-Dynamic-UX-Changes.html"

# The page order is the document. Nothing reflows, so every number is stable.
ORDER = [
    "cover", "contents", "exec", "scope", "arch",
    "A0", "A1", "A2A6", "A3", "A4", "A5A7",
    "B0", "B1", "B2", "B3",
    "C0", "C1C2", "C3",
    "D",
    "migrations", "behaviour", "platform", "tests",
    "commits1", "commits2", "files1", "files2",
    "limitations", "operations", "audit",
    "gallery1", "gallery2", "gallery3", "gallery4", "gallery5",
    "acceptance", "back",
]
TOTAL = len(ORDER)
NUM = {key: i + 1 for i, key in enumerate(ORDER)}

TOC = {
    "exec": NUM["exec"],
    "scope": NUM["scope"],
    "arch": NUM["arch"],
    "A0": NUM["A0"], "A1": NUM["A1"], "A2A6": NUM["A2A6"], "A3": NUM["A3"],
    "A4": NUM["A4"], "A5A7": NUM["A5A7"],
    "B0": NUM["B0"], "B1": NUM["B1"], "B2": NUM["B2"], "B3": NUM["B3"],
    "C0": NUM["C0"], "C1C2": NUM["C1C2"], "C3": NUM["C3"],
    "D": NUM["D"],
    "migrations": NUM["migrations"], "behaviour": NUM["behaviour"],
    "platform": NUM["platform"], "tests": NUM["tests"],
    "commits": NUM["commits1"], "files": NUM["files1"],
    "limitations": NUM["limitations"], "operations": NUM["operations"],
    "audit": NUM["audit"], "gallery": NUM["gallery1"],
    "acceptance": NUM["acceptance"],
}


def render():
    pages = []
    for key in ORDER:
        n = NUM[key]
        if key == "cover":
            pages.append(a.cover(n, TOTAL))
        elif key == "contents":
            pages.append(a.contents(n, TOTAL, TOC))
        elif key == "exec":
            pages.append(a.executive(n, TOTAL))
        elif key == "scope":
            pages.append(a.scope(n, TOTAL))
        elif key == "arch":
            pages.append(a.architecture(n, TOTAL))
        elif key == "A0":
            pages.append(a.a0(n, TOTAL))
        elif key == "A1":
            pages.append(a.a1(n, TOTAL))
        elif key == "A2A6":
            pages.append(a.a2_a6(n, TOTAL))
        elif key == "A3":
            pages.append(a.a3(n, TOTAL))
        elif key == "A4":
            pages.append(a.a4(n, TOTAL))
        elif key == "A5A7":
            pages.append(a.a5_a7(n, TOTAL))
        elif key == "B0":
            pages.append(a.b0(n, TOTAL))
        elif key == "B1":
            pages.append(a.b1(n, TOTAL))
        elif key == "B2":
            pages.append(a.b2(n, TOTAL))
        elif key == "B3":
            pages.append(a.b3(n, TOTAL))
        elif key == "C0":
            pages.append(a.c0(n, TOTAL))
        elif key == "C1C2":
            pages.append(a.c1_c2(n, TOTAL))
        elif key == "C3":
            pages.append(a.c3(n, TOTAL))
        elif key == "D":
            pages.append(a.d_track(n, TOTAL))
        elif key == "migrations":
            pages.append(b.migrations_page(n, TOTAL))
        elif key == "behaviour":
            pages.append(b.behaviour_page(n, TOTAL))
        elif key == "platform":
            pages.append(b.platform_page(n, TOTAL))
        elif key == "tests":
            pages.append(b.tests_page(n, TOTAL))
        elif key == "commits1":
            pages.append(b.commits_page(n, TOTAL, 1))
        elif key == "commits2":
            pages.append(b.commits_page(n, TOTAL, 2))
        elif key == "files1":
            pages.append(b.files_page(n, TOTAL, 1))
        elif key == "files2":
            pages.append(b.files_page(n, TOTAL, 2))
        elif key == "limitations":
            pages.append(b.limitations_page(n, TOTAL))
        elif key == "operations":
            pages.append(b.operations_page(n, TOTAL))
        elif key == "audit":
            pages.append(b.audit_page(n, TOTAL))
        elif key == "gallery1":
            pages.append(b.gallery_1(n, TOTAL))
        elif key == "gallery2":
            pages.append(b.gallery_2(n, TOTAL))
        elif key == "gallery3":
            pages.append(b.gallery_3(n, TOTAL))
        elif key == "gallery4":
            pages.append(b.gallery_4(n, TOTAL))
        elif key == "gallery5":
            pages.append(b.gallery_5(n, TOTAL))
        elif key == "acceptance":
            pages.append(b.acceptance(n, TOTAL))
        elif key == "back":
            pages.append(b.back(n, TOTAL))
        else:
            raise KeyError(key)

    doc = (
        '<!doctype html><html><head><meta charset="utf-8">'
        "<title>PalTuro — Dynamic UX, QOL &amp; Social Presence — 5 November 2026</title>"
        f"<style>{FONTS}\n{CSS}</style></head><body>{''.join(pages)}</body></html>"
    )
    OUT.parent.mkdir(exist_ok=True)
    OUT.write_text(doc, encoding="utf-8")
    print(f"wrote {OUT} ({OUT.stat().st_size:,} bytes, {TOTAL} pages)")


if __name__ == "__main__":
    render()
