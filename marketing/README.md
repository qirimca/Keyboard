# QırımKey Marketing & App Store Poster Pipeline

This directory contains the reproducible App Store poster compositor, parameterized layered SVG templates, asset provenance manifest, and **Canva MCP** (`https://www.canva.dev/docs/apps/mcp/`) integration workflow.

## 1. Authentic Visual Principles

1. **Real Crimean Photography Only (`marketing/templates/assets/crimea_sunset_bg.png`)**:
   - Both Light (`01`, `03`, `04`) and Dark (`02`, `05`) App Store posters use the **authentic Crimean coastal sunset photograph** (Cape Kaya-Bash / Black Sea horizon) rather than synthetic AI-generated landscapes.
   - The photograph is framed (`1.15×` vertical scale anchored at the bottom in CoreGraphics / `y = -0.15 * height` in SVG) so the golden sunset horizon and coastal cliffs sit directly in the top header zone (`y ≈ 0.80 * h` / `20%` from the top), behind the badge, headline, subtitle, and feature pills.
   - Light posters (`01`, `03`, `04`) use a light warm translucent veil (`0.28` top / `0.06` horizon), while Dark posters (`02`, `05`) use a calm twilight/dusk veil (`0.44` top / `0.22` horizon) so the real Crimean sunset remains clearly visible and recognizable.
2. **Real Localized In-App Screenshots**:
   - Every poster embeds real XCUITest-captured iOS 27 Simulator screenshots (`docs/release/2026-10-25/assets/store_{iphone,ipad}_{shotId}_{crh,uk,en}.png`) matching the poster's language (`crh`, `uk`, `en`) and theme.
3. **Accurate Feature Copy**:
   - Poster `04_home_light` highlights **Typing Statistics, Smart Word Learning, and Cultural Quotes** (`"Statistika · Söz ögrenüv · Künlik hikmetler"` in `crh`, `"Статистика · Навчання слів · Відомі вислови"` in `uk`, `"Statistics · Word Learning · Cultural Quotes"` in `en`), matching the actual `HomeView` settings row (`"Підказки слів, навчання слів"` / `"Söz teklifleri, sözlerni ögrenüv"`).

---

## 2. Reproducible Local Rendering

Run from the repository root to render all localized PNG posters (`1320 × 2868` iPhone 6.9" and `2064 × 2752` iPad 13"), 30 layered SVG templates (`marketing/rendered/{crh,uk,en}/{iphone_6_3,ipad_13}/*.svg`), and update SHA-256 hashes in `marketing/provenance.json`:

```sh
# Render all PNG posters and parameterized SVG templates (skip 22s video re-encode)
python3 marketing/render_templates.py --posters-only

# Render only specific shots (e.g. 04_home_light and 05_home_dark)
python3 marketing/render_templates.py --posters-only --only 04_home_light,05_home_dark
```

---

## 3. Canva MCP Integration (`https://www.canva.dev/docs/apps/mcp/`)

You can connect your AI assistant (Antigravity, Claude Code, Cursor, or VS Code) directly to Canva's official remote MCP server (`https://api.canva.com/connect/v1/mcp`) to create, edit, autofill, and export designs in Canva using QırımKey's real screenshots and real Crimean photography.

### MCP Server Configuration

Add the official Canva MCP server to your MCP client configuration:

```json
{
  "mcpServers": {
    "Canva": {
      "command": "npx",
      "args": [
        "-y",
        "mcp-remote@latest",
        "https://api.canva.com/connect/v1/mcp"
      ]
    }
  }
}
```

*(For Canva Apps SDK / CLI development, you can also install `@canva/cli@latest` via `npm install -g @canva/cli@latest` and authenticate with `canva login`.)*

### Canva MCP Tool Workflow for QırımKey Posters

Once authenticated via OAuth in Canva MCP, use the following official Canva MCP tools (`https://www.canva.dev/docs/apps/mcp/tools/`):

1. **Upload Real Assets (`create-upload-url` / `upload-asset-from-url` / `get-assets`)**:
   - Upload the authentic Crimean sunset photograph: `marketing/templates/assets/crimea_sunset_bg.png`
   - Upload the localized raw screenshots: `docs/release/2026-10-25/assets/store_{iphone,ipad}_{01..05}_{crh,uk,en}.png`
2. **Import Layered SVG Templates or Generate Designs (`import-design-from-url` / `create-design` / `generate-design`)**:
   - Import any generated SVG from `marketing/rendered/{crh,uk,en}/{iphone_6_3,ipad_13}/{01..05}.svg` into Canva. Every visual element is grouped into an independent editable SVG layer:
     - `layer-photo-background` (`data-layer-alias="layer-ai-background"`): Real Crimean sunset photograph + `sunsetVeil` + `horizonGlow`
     - `layer-badge-pill`: Top capsule badge (`QIRIMKEY • ...`)
     - `layer-headline` & `layer-subtitle`: Editable display typography
     - `layer-feature-pills`: 3 feature highlight pills (`pill-1`, `pill-2`, `pill-3`)
     - `layer-device-frame`: Titanium hardware bezel, Dynamic Island / top camera, and side buttons
     - `layer-screenshot`: Clipped real in-app screenshot (`<image clip-path="url(#screenClip)" />`)
3. **Export Lossless App Store PNGs (`export-design` / `get-export-formats`)**:
   - Export at `1320 × 2868` (iPhone 6.9") and `2064 × 2752` (iPad 13") in lossless PNG format.
