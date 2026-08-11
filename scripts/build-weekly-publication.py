#!/usr/bin/env python3
"""Render a NeoLabs-branded weekly Markdown learning pack to PDF.

This publisher intentionally supports the small Markdown subset used by internship
learning packs: headings, paragraphs, bullet/numbered lists, fenced code, simple
pipe tables and horizontal rules. It uses standard PDF fonts so CI is deterministic.
"""
from __future__ import annotations

import argparse
import html
import re
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (
    BaseDocTemplate,
    Frame,
    KeepTogether,
    ListFlowable,
    ListItem,
    PageBreak,
    PageTemplate,
    Paragraph,
    Spacer,
    Table,
    TableStyle,
)

MIDNIGHT = colors.HexColor('#101A2B')
CYAN = colors.HexColor('#00A6C8')
BLUE = colors.HexColor('#1F5F99')
AMBER = colors.HexColor('#D89216')
RED = colors.HexColor('#B53838')
SLATE = colors.HexColor('#4B5563')
PAPER = colors.HexColor('#F7F9FC')
WHITE = colors.white

HEAD = 'Helvetica-Bold'
BODY = 'Times-Roman'
BODY_BOLD = 'Times-Bold'
MONO = 'Courier'


def inline(text: str) -> str:
    """Escape source text and restore a tiny trusted inline-Markdown subset."""
    value = html.escape(text, quote=False)
    value = re.sub(r'`([^`]+)`', r'<font name="Courier">\1</font>', value)
    value = re.sub(r'\*\*([^*]+)\*\*', r'<b>\1</b>', value)
    return value


def slug_meta(lines: list[str], label: str) -> str | None:
    prefix = f'**{label}:**'
    for line in lines[:20]:
        if line.startswith(prefix):
            return line[len(prefix):].strip()
    return None


class NeoDoc(BaseDocTemplate):
    def __init__(self, filename: str, track: str, week: str, **kwargs):
        super().__init__(filename, **kwargs)
        self.track = track
        self.week = week
        frame = Frame(17 * mm, 20 * mm, A4[0] - 34 * mm, A4[1] - 40 * mm, id='body')
        self.addPageTemplates([PageTemplate(id='main', frames=frame, onPage=self.draw_page)])

    def draw_page(self, canvas, doc):
        if doc.page == 1:
            canvas.saveState()
            canvas.setFillColor(MIDNIGHT)
            canvas.rect(0, 0, A4[0], A4[1], fill=1, stroke=0)
            canvas.restoreState()
            return
        canvas.saveState()
        canvas.setFont(HEAD, 7.5)
        canvas.setFillColor(SLATE)
        canvas.drawString(17 * mm, A4[1] - 11 * mm, f'NEOLABS  |  {self.track}')
        canvas.setStrokeColor(CYAN)
        canvas.setLineWidth(0.7)
        canvas.line(17 * mm, A4[1] - 14 * mm, A4[0] - 17 * mm, A4[1] - 14 * mm)
        canvas.setFont(BODY, 7)
        canvas.drawString(17 * mm, 10 * mm, 'STUDENT TRAINING MATERIAL  |  AUTHORISED SYNTHETIC USE ONLY')
        canvas.drawRightString(A4[0] - 17 * mm, 10 * mm, f'{doc.page} / {self.week}')
        canvas.restoreState()


def styles():
    base = getSampleStyleSheet()
    return {
        'cover_brand': ParagraphStyle('cover_brand', parent=base['Normal'], fontName=HEAD, fontSize=25, leading=28, textColor=WHITE, spaceAfter=4),
        'cover_line': ParagraphStyle('cover_line', parent=base['Normal'], fontName=HEAD, fontSize=9, leading=11, textColor=CYAN, spaceAfter=28),
        'cover_title': ParagraphStyle('cover_title', parent=base['Title'], fontName=HEAD, fontSize=28, leading=31, textColor=WHITE, spaceAfter=12),
        'cover_sub': ParagraphStyle('cover_sub', parent=base['Normal'], fontName=HEAD, fontSize=12.5, leading=18, textColor=colors.HexColor('#D6E5EE'), spaceAfter=18),
        'cover_meta': ParagraphStyle('cover_meta', parent=base['Normal'], fontName=HEAD, fontSize=8.5, leading=13, textColor=WHITE),
        'h1': ParagraphStyle('h1', parent=base['Heading1'], fontName=HEAD, fontSize=20, leading=23, textColor=MIDNIGHT, spaceBefore=5, spaceAfter=8),
        'h2': ParagraphStyle('h2', parent=base['Heading2'], fontName=HEAD, fontSize=14, leading=17, textColor=BLUE, spaceBefore=9, spaceAfter=5),
        'h3': ParagraphStyle('h3', parent=base['Heading3'], fontName=HEAD, fontSize=11.5, leading=14, textColor=MIDNIGHT, spaceBefore=7, spaceAfter=4),
        'body': ParagraphStyle('body', parent=base['BodyText'], fontName=BODY, fontSize=10.4, leading=14.4, textColor=MIDNIGHT, spaceAfter=7),
        'small': ParagraphStyle('small', parent=base['BodyText'], fontName=BODY, fontSize=8.5, leading=11.5, textColor=SLATE, spaceAfter=5),
        'code': ParagraphStyle('code', parent=base['Code'], fontName=MONO, fontSize=8.1, leading=11, textColor=MIDNIGHT, backColor=colors.HexColor('#EDF2F7'), borderColor=CYAN, borderWidth=0.8, borderPadding=7, leftIndent=4, rightIndent=4, spaceBefore=5, spaceAfter=8),
        'quote': ParagraphStyle('quote', parent=base['BodyText'], fontName=BODY, fontSize=9.7, leading=13.4, textColor=MIDNIGHT, backColor=PAPER, borderColor=AMBER, borderWidth=0.8, borderPadding=8, leftIndent=5, rightIndent=5, spaceBefore=6, spaceAfter=8),
    }


def cover(st, title: str, track: str, programme: str, week: str, classification: str):
    return [
        Spacer(1, 34 * mm),
        Paragraph('NEOLABS', st['cover_brand']),
        Paragraph(f'SECURITY LABS | {html.escape(track)}', st['cover_line']),
        Spacer(1, 17 * mm),
        Paragraph(html.escape(title), st['cover_title']),
        Paragraph('Weekly Learning Pack | Learn + Connect + Operate', st['cover_sub']),
        Spacer(1, 74 * mm),
        Table([['']], colWidths=[155 * mm], rowHeights=[1.2 * mm], style=TableStyle([('BACKGROUND', (0, 0), (-1, -1), CYAN)])),
        Spacer(1, 6 * mm),
        Paragraph(
            f'Programme: {html.escape(programme)}<br/>'
            f'{html.escape(week)}<br/>'
            'Version: 1.0<br/>'
            'Classification: ' + html.escape(classification) + '<br/>'
            'Authorised synthetic training use only.',
            st['cover_meta'],
        ),
        PageBreak(),
    ]


def table_flow(rows: list[list[str]], st):
    if not rows:
        return []
    width = 165 * mm
    cols = max(len(row) for row in rows)
    col_widths = [width / cols] * cols
    data = []
    for r, row in enumerate(rows):
        style = st['small'] if r else ParagraphStyle('th', parent=st['small'], fontName=HEAD, textColor=WHITE)
        data.append([Paragraph(inline(cell.strip()), style) for cell in row])
    tbl = Table(data, colWidths=col_widths, repeatRows=1)
    tbl.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), MIDNIGHT),
        ('TEXTCOLOR', (0, 0), (-1, 0), WHITE),
        ('GRID', (0, 0), (-1, -1), 0.35, colors.HexColor('#CBD5E1')),
        ('BACKGROUND', (0, 1), (-1, -1), WHITE),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [WHITE, PAPER]),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('LEFTPADDING', (0, 0), (-1, -1), 5),
        ('RIGHTPADDING', (0, 0), (-1, -1), 5),
        ('TOPPADDING', (0, 0), (-1, -1), 4),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
    ]))
    return [tbl, Spacer(1, 5)]


def parse_body(lines: list[str], st):
    out = []
    paragraph: list[str] = []
    bullets: list[str] = []
    numbers: list[str] = []
    code: list[str] = []
    table: list[list[str]] = []
    in_code = False

    def flush_paragraph():
        nonlocal paragraph
        if paragraph:
            out.append(Paragraph(inline(' '.join(x.strip() for x in paragraph)), st['body']))
            paragraph = []

    def flush_lists():
        nonlocal bullets, numbers
        if bullets:
            out.append(ListFlowable([ListItem(Paragraph(inline(x), st['body'])) for x in bullets], bulletType='bullet', leftIndent=18))
            out.append(Spacer(1, 5))
            bullets = []
        if numbers:
            out.append(ListFlowable([ListItem(Paragraph(inline(x), st['body'])) for x in numbers], bulletType='1', leftIndent=22))
            out.append(Spacer(1, 5))
            numbers = []

    def flush_table():
        nonlocal table
        if table:
            # Drop Markdown alignment separator row.
            clean = [row for row in table if not all(re.fullmatch(r':?-{3,}:?', cell.strip()) for cell in row)]
            out.extend(table_flow(clean, st))
            table = []

    for raw in lines:
        line = raw.rstrip('\n')
        if line.startswith('```'):
            flush_paragraph(); flush_lists(); flush_table()
            if in_code:
                out.append(Paragraph('<br/>'.join(html.escape(x) for x in code), st['code']))
                code = []
                in_code = False
            else:
                in_code = True
            continue
        if in_code:
            code.append(line)
            continue
        if not line.strip():
            flush_paragraph(); flush_lists(); flush_table(); continue
        if line.strip() == '---':
            flush_paragraph(); flush_lists(); flush_table(); out.append(Spacer(1, 5)); continue
        if line.startswith('|') and line.endswith('|'):
            flush_paragraph(); flush_lists()
            table.append([cell.strip() for cell in line.strip('|').split('|')])
            continue
        flush_table()
        if line.startswith('### '):
            flush_paragraph(); flush_lists(); out.append(Paragraph(inline(line[4:]), st['h3'])); continue
        if line.startswith('## '):
            flush_paragraph(); flush_lists(); out.append(Paragraph(inline(line[3:]), st['h2'])); continue
        if line.startswith('# '):
            flush_paragraph(); flush_lists(); out.append(Paragraph(inline(line[2:]), st['h1'])); continue
        if line.startswith('> '):
            flush_paragraph(); flush_lists(); out.append(Paragraph(inline(line[2:]), st['quote'])); continue
        if re.match(r'^[-*]\s+', line):
            flush_paragraph(); numbers = []
            bullets.append(re.sub(r'^[-*]\s+', '', line)); continue
        if re.match(r'^\d+\.\s+', line):
            flush_paragraph(); bullets = []
            numbers.append(re.sub(r'^\d+\.\s+', '', line)); continue
        # Skip metadata already shown on cover.
        if re.match(r'^\*\*(Track|Programme|Classification):\*\*', line):
            continue
        paragraph.append(line)

    flush_paragraph(); flush_lists(); flush_table()
    if in_code and code:
        out.append(Paragraph('<br/>'.join(html.escape(x) for x in code), st['code']))
    return out


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--track', required=True)
    parser.add_argument('--week', default='Week 02')
    args = parser.parse_args()

    lines = args.source.read_text(encoding='utf-8').splitlines()
    title = next((line[2:].strip() for line in lines if line.startswith('# ')), args.week)
    programme = slug_meta(lines, 'Programme') or 'NeoLabs x Renaissance Innovation Labs Cybersecurity Internship'
    classification = slug_meta(lines, 'Classification') or 'Student Training Material'

    st = styles()
    story = cover(st, title, args.track, programme, args.week, classification)
    # Do not repeat the first H1 or metadata from the source in body.
    body_start = 1 if lines and lines[0].startswith('# ') else 0
    story.extend(parse_body(lines[body_start:], st))

    args.output.parent.mkdir(parents=True, exist_ok=True)
    doc = NeoDoc(
        str(args.output),
        args.track,
        args.week,
        pagesize=A4,
        leftMargin=17 * mm,
        rightMargin=17 * mm,
        topMargin=20 * mm,
        bottomMargin=20 * mm,
        title=title,
        author='NeoLabs x Renaissance Innovation Labs',
        subject=f'{args.track} internship learning pack',
    )
    doc.build(story)
    print(f'Built {args.output} ({args.output.stat().st_size} bytes)')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
