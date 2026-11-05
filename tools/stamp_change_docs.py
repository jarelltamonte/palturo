"""Merge the cover and content PDFs and stamp the shared header/footer."""
import pymupdf

cover = pymupdf.open('docs/_cover.pdf')
content = pymupdf.open('docs/_content.pdf')
out = pymupdf.open()
out.insert_pdf(cover)
out.insert_pdf(content)

total = out.page_count
W, H = out[0].rect.width, out[0].rect.height
left, right = 45.35, W - 45.35
head_color = (0.435, 0.478, 0.29)
foot_color = (0.54, 0.565, 0.51)
line_color = (0.85, 0.86, 0.80)
bg = (0.961, 0.957, 0.937)
left_foot = 'PALTURO · DYNAMIC UX, QOL & SOCIAL PRESENCE'

for i, page in enumerate(out):
    if i > 0:
        page.draw_rect(page.rect, color=None, fill=bg, overlay=False)

    line = (0.23, 0.23, 0.23) if i == 0 else line_color
    page.draw_line((left, H - 36), (right, H - 36), color=line, width=0.45)
    right_foot = f'05 NOV 2026 · ui-features @ 08de0e8 · {i + 1:02d} / {total:02d}'
    fc = (0.58, 0.58, 0.58) if i == 0 else foot_color
    page.insert_text((left, H - 26), left_foot, fontname='helv', fontsize=6.0, color=fc)
    tw = pymupdf.get_text_length(right_foot, fontname='helv', fontsize=6.0)
    page.insert_text((right - tw, H - 26), right_foot, fontname='helv', fontsize=6.0, color=fc)

    if i > 0:
        page.insert_text((left, 32), 'PALTURO / DYNAMIC UX COMPLETION',
                         fontname='helv', fontsize=6.0, color=head_color)
        tr = 'CHANGE DOCUMENTATION'
        tw = pymupdf.get_text_length(tr, fontname='helv', fontsize=6.0)
        page.insert_text((right - tw, 32), tr, fontname='helv', fontsize=6.0, color=head_color)

out.set_metadata({
    'title': 'PalTuro - Dynamic UX, QOL & Social Presence',
    'author': 'PalTuro product team',
    'subject': 'Complete change documentation',
    'creator': 'PalTuro engineering',
})
out.save('docs/PalTuro-Dynamic-UX-Changes.pdf', garbage=3, deflate=True)
print('pages', total)
