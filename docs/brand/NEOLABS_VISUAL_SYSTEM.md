# NeoLabs SOC Toolkit Visual System

## Brand purpose

The publication system gives every student guide, technical handbook, lab and template a consistent NeoLabs identity while keeping long technical documents readable in print and on screen.

The system uses a text-based NeoLabs wordmark so the repository remains self-contained. An approved official logo may replace the wordmark later without changing the document structure.

## Wordmark

Use the following text treatment on covers and major section pages:

```text
NEOLABS
SECURITY LABS · SOC LEVEL 1
```

The primary name is uppercase, tightly spaced and visually dominant. The programme line is smaller and uses increased letter spacing.

## Colour palette

| Role | Hex | Use |
|---|---|---|
| NeoLabs Midnight | `#101A2B` | cover, major headings, footer |
| Signal Cyan | `#00A6C8` | rules, links, section markers |
| Analyst Blue | `#1F5F99` | secondary headings and callouts |
| Evidence Amber | `#D89216` | warnings and evidence notes |
| Incident Red | `#B53838` | critical warnings only |
| Slate | `#4B5563` | supporting text |
| Paper | `#F7F9FC` | page and callout background |
| White | `#FFFFFF` | cover text and contrast |

Colour must never be the only way meaning is communicated. Every warning, success or severity indicator must also include text.

## Typography

The automated publication workflow uses freely available system fonts:

- headings: `DejaVu Sans`, `Arial`, sans-serif;
- body: `DejaVu Serif`, `Georgia`, serif;
- code: `DejaVu Sans Mono`, `Consolas`, monospace.

Do not commit font files to the repository.

## Page structure

### Cover

- NeoLabs wordmark;
- publication title;
- track and level;
- version and publication date;
- statement: “Authorised synthetic training use only.”

### Running header

- NeoLabs SOC Level 1;
- current module or publication title.

### Running footer

- classification: Student Training Material;
- page number;
- repository-generated publication notice.

### Headings

- H1 starts a major module and uses a strong midnight rule;
- H2 uses Analyst Blue;
- H3 remains dark and compact;
- heading levels must not be skipped.

## Callouts

Use these labels consistently:

- **Analyst note** — supporting interpretation or workflow advice;
- **Evidence requirement** — what must be recorded;
- **Safety boundary** — prohibited access, data or actions;
- **Escalation point** — when the analyst must stop and hand off;
- **Troubleshooting check** — a test that narrows a technical failure;
- **Lab task** — an assessed action using synthetic evidence.

## Tables and code

Tables use a dark header and alternating light rows. Long tables may break across pages, but headings must repeat.

Code blocks use a light background, border and monospaced font. Commands must be directly executable or clearly marked as examples with placeholders.

## Screenshots

Screenshots must:

- show the relevant interface area at readable size;
- include a figure title and explanation;
- redact credentials, private URLs and personal information;
- identify the Wazuh version where layout matters;
- avoid decorative device frames that reduce readability.

## Accessibility

- body text should render at approximately 10.5–11.5 pt in PDF;
- line spacing should remain at least 1.35;
- links must be distinguishable without relying only on colour;
- heading hierarchy must remain semantic in HTML;
- images require descriptive alt text in the source Markdown;
- tables should not be used purely for visual layout.

## Publication naming

Generated publications use stable names:

```text
NeoLabs_SOC_L1_Analyst_Handbook.pdf
NeoLabs_SOC_L1_Wazuh_Guide.pdf
NeoLabs_SOC_L1_Investigation_Templates.pdf
NeoLabs_SOC_L1_Lab_Pack.pdf
```

## Approval

A publication is ready only when technical validation, safety review, editorial review, link checking and PDF rendering succeed. Generated PDFs are workflow artifacts and should be released only from a reviewed commit or tagged version.
