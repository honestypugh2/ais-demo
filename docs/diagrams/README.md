# Architecture diagrams

Editable **draw.io** sources for the architecture docs. Each `.drawio` here is the
source of truth; the rendered **SVG** used in the docs lives in
[`../images/`](../images/).

| Diagram | Source (editable) | Rendered (in docs) |
| --- | --- | --- |
| End-to-end demo flow | [architecture-overview.drawio](architecture-overview.drawio) | [../images/architecture-overview.svg](../images/architecture-overview.svg) |
| Two governed surfaces / AI gateway | [apim-ai-gateway.drawio](apim-ai-gateway.drawio) | [../images/apim-ai-gateway.svg](../images/apim-ai-gateway.svg) |
| Path to production (APIM landing zone) | [apim-landing-zone.drawio](apim-landing-zone.drawio) | [../images/apim-landing-zone.svg](../images/apim-landing-zone.svg) |

## Editing & exporting

1. Open the `.drawio` file in VS Code with the **Draw.io Integration** extension
   (`hediet.vscode-drawio`), or at [app.diagrams.net](https://app.diagrams.net).
2. Edit, then export a render that the docs reference:
   - **Export as → SVG…** → save to `../images/<name>.svg` (used by the Markdown).
   - **Export as → PNG…** (2x) → `../images/<name>.png` if you prefer raster (e.g. for slides).
3. Keep the file name in sync with the table above so the doc links keep working.

> Tip: when exporting SVG, tick **"Include a copy of my diagram"** to make the SVG
> itself re-editable in draw.io — handy if you only want to keep one file per diagram.

## Palette (house style)

| Layer | Fill |
| --- | --- |
| Azure service (primary) | `#0078D4` / `#0F6CBD` |
| Integration (Logic Apps / Service Bus) | `#8661C5` |
| AI (Document Intelligence / Azure OpenAI) | `#107C10` / `#EAF7EA` |
| Eventing (Event Grid) | `#D83B01` / `#FEF0E7` |
| Identity (Entra) | `#5C2D91` |
| Observability / neutral | `#5E5E5E` / `#F3F2F1` |

The landing-zone diagram follows the numbered-band convention (1 Channels → 2
Edge/Identity → 3 APIM Landing Zone → 4 App Tier → 5 Data/Integration → 6
Observability), aligned with the
[Azure APIM landing zone reference](https://learn.microsoft.com/azure/architecture/example-scenario/integration/app-gateway-internal-api-management-function#architecture).
