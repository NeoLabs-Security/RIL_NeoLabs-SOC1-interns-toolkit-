#!/usr/bin/env python3
from __future__ import annotations

import argparse
import datetime as dt
import html
import os
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

import markdown
from weasyprint import HTML

ROOT = Path(__file__).resolve().parents[1]
CSS_PATH = ROOT / "docs" / "brand" / "print.css"


@dataclass(frozen=True)
class Publication:
    filename: str
    title: str
    subtitle: str
    sources: tuple[str, ...]


PUBLICATIONS = (
    Publication(
        filename="NeoLabs_SOC_L1_Analyst_Handbook.pdf",
        title="SOC Level 1 Analyst Handbook",
        subtitle="Security operations foundations, investigation workflows and capstone reporting",
        sources=(
            "docs/secops-foundations/01-security-operations-foundations.md",
            "docs/secops-foundations/02-alert-triage-evidence-and-escalation.md",
            "docs/secops-foundations/03-siem-pipelines-and-log-quality.md",
            "docs/secops-foundations/04-incident-response-and-playbook-development.md",
            "docs/secops-foundations/05-windows-and-sysmon-investigation.md",
            "docs/secops-foundations/06-linux-web-and-cloud-log-investigation.md",
            "docs/secops-foundations/07-wazuh-alert-investigation-and-tuning.md",
            "docs/secops-foundations/08-case-management-reporting-and-capstone.md",
        ),
    ),
    Publication(
        filename="NeoLabs_SOC_L1_Wazuh_Guide.pdf",
        title="Wazuh Deployment and Investigation Guide",
        subtitle="Architecture, dashboard workflow, workstation setup, recovery and troubleshooting",
        sources=(
            "docs/wazuh-handbook/01-wazuh-architecture-and-neolabs-deployment.md",
            "docs/dashboard-tutorials/01-orientation-and-alert-investigation.md",
            "docs/setup/WORKSTATION_COMPATIBILITY.md",
            "docs/setup/BACKUP_AND_RECOVERY.md",
            "troubleshooting/WAZUH_SETUP_AND_TROUBLESHOOTING_GUIDE.md",
            "wazuh-stack/README.md",
        ),
    ),
    Publication(
        filename="NeoLabs_SOC_L1_Investigation_Templates.pdf",
        title="SOC Investigation Templates",
        subtitle="Evidence register, query journal and incident-report forms",
        sources=(
            "templates/evidence-log-template.md",
            "templates/query-journal-template.md",
            "templates/incident-report-template.md",
        ),
    ),
    Publication(
        filename="NeoLabs_SOC_L1_Lab_Pack.pdf",
        title="SOC Level 1 Guided Lab Pack",
        subtitle="Synthetic defensive investigations and analyst command references",
        sources=(
            "labs/01-authentication-triage/README.md",
            "references/query-command-reference/README.md",
        ),
    ),
)

COMPLETE_TOOLKIT_SOURCES = tuple(
    dict.fromkeys(source for publication in PUBLICATIONS for source in publication.sources)
)


def slugify(value: str) -> str:
    value = re.sub(r"<[^>]+>", "", value)
    value = re.sub(r"[^a-zA-Z0-9]+", "-", value).strip("-").lower()
    return value or "section"


def first_heading(markdown_text: str, fallback: str) -> str:
    for line in markdown_text.splitlines():
        match = re.match(r"^#\s+(.+?)\s*$", line)
        if match:
            return match.group(1)
    return fallback


def render_markdown(path: Path, anchor: str) -> tuple[str, str]:
    text = path.read_text(encoding="utf-8")
    title = first_heading(text, path.stem.replace("-", " ").title())
    body = markdown.markdown(
        text,
        extensions=["fenced_code", "tables", "toc", "sane_lists"],
        extension_configs={"toc": {"permalink": False}},
        output_format="html5",
    )
    return title, (
        f'<section class="module" id="{html.escape(anchor)}">'
        f'<p class="section-source">Source: {html.escape(path.relative_to(ROOT).as_posix())}</p>'
        f"{body}</section>"
    )


def validate_sources(sources: Iterable[str]) -> list[Path]:
    paths: list[Path] = []
    missing: list[str] = []
    for source in sources:
        path = ROOT / source
        if not path.is_file():
            missing.append(source)
        else:
            paths.append(path)
    if missing:
        raise SystemExit("Missing publication sources:\n" + "\n".join(missing))
    return paths


def cover(title: str, subtitle: str, publication_date: str, version: str) -> str:
    return f"""
    <section class="cover">
      <div>
        <p class="brand-wordmark">NEOLABS</p>
        <p class="brand-line">SECURITY LABS · SOC LEVEL 1</p>
        <h1>{html.escape(title)}</h1>
        <p class="subtitle">{html.escape(subtitle)}</p>
      </div>
      <div class="meta">
        <p><strong>Version:</strong> {html.escape(version)}</p>
        <p><strong>Publication date:</strong> {html.escape(publication_date)}</p>
        <p><strong>Classification:</strong> Student Training Material</p>
        <p>Authorised synthetic training use only.</p>
      </div>
    </section>
    """


def render_publication(
    publication: Publication,
    output_dir: Path,
    publication_date: str,
    version: str,
) -> None:
    paths = validate_sources(publication.sources)
    sections: list[str] = []
    toc_items: list[str] = []
    used_anchors: set[str] = set()

    for index, path in enumerate(paths, start=1):
        text = path.read_text(encoding="utf-8")
        title = first_heading(text, path.stem)
        anchor = slugify(f"{index}-{title}")
        while anchor in used_anchors:
            anchor += "-section"
        used_anchors.add(anchor)
        rendered_title, section = render_markdown(path, anchor)
        toc_items.append(
            f'<li><a href="#{html.escape(anchor)}">{index}. {html.escape(rendered_title)}</a></li>'
        )
        sections.append(section)

    css = CSS_PATH.read_text(encoding="utf-8")
    document = f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>{html.escape(publication.title)}</title>
  <style>{css}</style>
</head>
<body>
  {cover(publication.title, publication.subtitle, publication_date, version)}
  <section class="toc">
    <h1>Contents</h1>
    <ul>{''.join(toc_items)}</ul>
  </section>
  {''.join(sections)}
</body>
</html>
"""

    output_dir.mkdir(parents=True, exist_ok=True)
    html_path = output_dir / publication.filename.replace(".pdf", ".html")
    pdf_path = output_dir / publication.filename
    html_path.write_text(document, encoding="utf-8")
    HTML(string=document, base_url=str(ROOT)).write_pdf(pdf_path)

    if pdf_path.stat().st_size < 10_000:
        raise SystemExit(f"Generated PDF is unexpectedly small: {pdf_path}")
    print(f"generated {pdf_path.relative_to(ROOT)}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Build NeoLabs SOC Level 1 branded publications.")
    parser.add_argument("--output-dir", default="dist/publications")
    parser.add_argument("--version", default=os.environ.get("PUBLICATION_VERSION", "1.0-draft"))
    parser.add_argument(
        "--date",
        default=os.environ.get("PUBLICATION_DATE", dt.datetime.now(dt.timezone.utc).date().isoformat()),
    )
    args = parser.parse_args()

    output_dir = (ROOT / args.output_dir).resolve()
    if ROOT not in output_dir.parents and output_dir != ROOT:
        raise SystemExit("Output directory must be inside the repository working tree.")
    if not CSS_PATH.is_file():
        raise SystemExit(f"Missing print stylesheet: {CSS_PATH}")

    for publication in PUBLICATIONS:
        render_publication(publication, output_dir, args.date, args.version)

    complete = Publication(
        filename="NeoLabs_SOC_L1_Complete_Toolkit.pdf",
        title="SOC Level 1 Complete Toolkit",
        subtitle="Analyst handbook, Wazuh guide, templates, references and guided lab",
        sources=COMPLETE_TOOLKIT_SOURCES,
    )
    render_publication(complete, output_dir, args.date, args.version)


if __name__ == "__main__":
    main()
