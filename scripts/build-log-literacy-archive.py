#!/usr/bin/env python3
from pathlib import Path
from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas
from reportlab.lib.colors import HexColor
import re

SOURCE = Path('/tmp/log-literacy.txt')
OUTPUT = Path('publications/01_NeoLabs_Log_Literacy_for_Cybersecurity_Analysts.pdf')
W, H = A4
NAVY = HexColor('#101a2b')
CYAN = HexColor('#00a6c8')
WHITE = HexColor('#ffffff')
MUTED = HexColor('#aab7ca')
INK = HexColor('#172033')
LIGHT = HexColor('#687386')


def page_chrome(c, page_no: int):
    c.setFillColor(WHITE)
    c.rect(0, 0, W, H, fill=1, stroke=0)
    c.setFillColor(NAVY)
    c.rect(0, H - 34, W, 34, fill=1, stroke=0)
    c.setFillColor(WHITE)
    c.setFont('Helvetica-Bold', 8.5)
    c.drawString(42, H - 22, 'NEOLABS  /  SOC LEVEL 1')
    c.setFillColor(CYAN)
    c.drawRightString(W - 42, H - 22, 'LOG LITERACY')
    c.setStrokeColor(CYAN)
    c.setLineWidth(0.8)
    c.line(42, 38, W - 42, 38)
    c.setFillColor(LIGHT)
    c.setFont('Helvetica', 7.2)
    c.drawString(42, 25, 'STUDENT TRAINING MATERIAL  -  AUTHORISED SYNTHETIC USE ONLY')
    c.drawRightString(W - 42, 25, f'{page_no:02d}')


def render():
    text = SOURCE.read_text(encoding='utf-8', errors='replace')
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    c = canvas.Canvas(str(OUTPUT), pagesize=A4)
    c.setTitle('Log Literacy for Cybersecurity Analysts')
    c.setAuthor('NeoLabs x Renaissance Innovation Labs')
    c.setSubject('SOC Level 1 Internship Student Training Material')

    c.setFillColor(NAVY)
    c.rect(0, 0, W, H, fill=1, stroke=0)
    c.setFillColor(WHITE)
    c.setFont('Helvetica-Bold', 30)
    c.drawString(48, H - 82, 'NEOLABS')
    c.setFillColor(CYAN)
    c.setFont('Helvetica-Bold', 10)
    c.drawString(49, H - 112, 'SOC LEVEL 1  /  FOUNDATIONAL REFERENCE')
    c.setFillColor(WHITE)
    c.setFont('Helvetica-Bold', 29)
    c.drawString(49, H - 190, 'Log Literacy for')
    c.drawString(49, H - 226, 'Cybersecurity Analysts')
    c.setFillColor(MUTED)
    c.setFont('Helvetica', 12)
    c.drawString(49, H - 263, 'A practical guide to reading, correlating and reasoning from security telemetry')
    c.setStrokeColor(CYAN)
    c.setLineWidth(3)
    c.line(49, H - 294, W - 49, H - 294)
    y = H - 340
    for key, value in [
        ('Version', 'Week 1 production release'),
        ('Publication date', 'August 2026'),
        ('Classification', 'Student Training Material'),
        ('Programme', 'NeoLabs x Renaissance Innovation Labs'),
    ]:
        c.setFillColor(CYAN)
        c.setFont('Helvetica-Bold', 8.5)
        c.drawString(49, y, key.upper())
        c.setFillColor(WHITE)
        c.setFont('Helvetica', 10.2)
        c.drawString(164, y, value)
        y -= 24
    c.setFillColor(MUTED)
    c.setFont('Helvetica', 8.5)
    c.drawString(49, 35, 'STUDENT TRAINING MATERIAL  -  AUTHORISED SYNTHETIC USE ONLY')
    c.showPage()

    page_no = 1
    for raw_page in text.split('\f'):
        lines = raw_page.replace('\r', '').split('\n')
        while lines and not lines[0].strip():
            lines.pop(0)
        while lines and not lines[-1].strip():
            lines.pop()
        if not lines:
            continue
        page_chrome(c, page_no)
        page_no += 1
        y = H - 54
        for line in lines:
            rest = line.expandtabs(4).rstrip()
            chunks = []
            if len(rest) <= 116:
                chunks = [rest]
            else:
                while len(rest) > 116:
                    cut = rest.rfind(' ', 0, 116)
                    if cut < 60:
                        cut = 116
                    chunks.append(rest[:cut])
                    rest = '  ' + rest[cut:].lstrip()
                chunks.append(rest)
            for chunk in chunks:
                if y < 50:
                    c.showPage()
                    page_chrome(c, page_no)
                    page_no += 1
                    y = H - 54
                stripped = chunk.strip()
                if re.match(r'^(MODULE\s+\d+|APPENDIX|SECTION\s+\d+|CHAPTER\s+\d+)', stripped, re.I):
                    c.setFillColor(CYAN)
                    c.setFont('Helvetica-Bold', 9.2)
                elif stripped and stripped.isupper() and len(stripped) < 95:
                    c.setFillColor(NAVY)
                    c.setFont('Helvetica-Bold', 8.3)
                else:
                    c.setFillColor(INK)
                    c.setFont('Courier', 7.1)
                c.drawString(42, y, chunk[:118])
                y -= 9.05
        c.showPage()
    c.save()


if __name__ == '__main__':
    render()
