---
name: infographic
description: >
  Generate polished, enterprise-grade infographic diagrams as self-contained HTML files.
  Produces dark-gradient layered visuals with inline SVG icons, flow arrows, and branded
  color coding — matching the Microsoft architecture diagram aesthetic. Output is a single
  HTML file that can be screenshotted to PNG for README/documentation use.
  USE FOR: create infographic, architecture diagram, pipeline diagram, visual diagram,
  flow diagram, workflow visualization, system overview image, layered architecture picture.
  DO NOT USE FOR: interactive dashboards (use web-artifacts-builder), hand-drawn diagrams
  (use excalidraw), Mermaid code blocks, or simple text-based diagrams.
---

# Infographic Builder

Generate enterprise-grade infographic HTML files styled after Microsoft architecture diagrams: dark gradient backgrounds, layered sections, inline SVG icons, flow arrows, and branded color accents.

## Output Convention

- HTML source: `images/<name>.html` (kept for future edits)
- PNG screenshot: `images/<name>.png` (referenced in README/docs)

## Visual Style

### Background

```css
body {
  background: linear-gradient(160deg, #0a0e1a 0%, #1a1f3a 40%, #0f1a2e 70%, #0a0e1a 100%);
  min-height: 100vh;
  margin: 0;
  padding: 40px;
  font-family: "Segoe UI", -apple-system, BlinkMacSystemFont, sans-serif;
  color: #e0e0e0;
}
```

### Color Palette

| Token | Hex | Use |
|-------|-----|-----|
| `--ig-github` | `#8b5cf6` | GitHub Actions, triggers, CI/CD |
| `--ig-azure` | `#0078d4` | Azure resources, Bicep, ARM |
| `--ig-entra` | `#16a34a` | Microsoft Entra ID, authentication, consent |
| `--ig-foundry` | `#f97316` | Microsoft Foundry, AI, MCP |
| `--ig-key` | `#eab308` | Secrets, keys, credentials |
| `--ig-cosmos` | `#06b6d4` | Cosmos DB, data |
| `--ig-container` | `#ec4899` | Container Registry, Docker |
| `--ig-neutral` | `#94a3b8` | Neutral labels, muted text |
| `--ig-surface` | `rgba(255,255,255,0.06)` | Card/layer background |
| `--ig-border` | `rgba(255,255,255,0.12)` | Card borders |
| `--ig-text` | `#e0e0e0` | Primary text |
| `--ig-text-muted` | `#94a3b8` | Secondary text |

### CSS Variables Block (copy into every infographic)

```css
:root {
  --ig-github: #8b5cf6;
  --ig-azure: #0078d4;
  --ig-entra: #16a34a;
  --ig-foundry: #f97316;
  --ig-key: #eab308;
  --ig-cosmos: #06b6d4;
  --ig-container: #ec4899;
  --ig-neutral: #94a3b8;
  --ig-surface: rgba(255, 255, 255, 0.06);
  --ig-border: rgba(255, 255, 255, 0.12);
  --ig-text: #e0e0e0;
  --ig-text-muted: #94a3b8;
}
```

## Layout Patterns

### Title Header

```html
<div class="title">
  <h1>Diagram Title Here</h1>
  <p class="subtitle">Short description of what this diagram shows</p>
</div>
```

```css
.title {
  text-align: center;
  margin-bottom: 32px;
}
.title h1 {
  font-size: 28px;
  font-weight: 700;
  color: #ffffff;
  margin: 0 0 8px;
}
.title .subtitle {
  font-size: 14px;
  color: var(--ig-text-muted);
  margin: 0;
}
```

### Layer Card

Each layer is a horizontal card with: left accent border, icon, title, description, and optional pill badges.

```html
<div class="layer" style="--accent: var(--ig-azure)">
  <div class="layer-label">Layer Name</div>
  <div class="layer-content">
    <div class="layer-icon"><!-- SVG here --></div>
    <div class="layer-body">
      <h3>Component Name</h3>
      <p>Short description of what this does</p>
      <div class="pills">
        <span class="pill">Output 1</span>
        <span class="pill">Output 2</span>
        <span class="pill">Output 3</span>
      </div>
    </div>
  </div>
</div>
```

```css
.layer {
  background: var(--ig-surface);
  border: 1px solid var(--ig-border);
  border-left: 4px solid var(--accent);
  border-radius: 12px;
  padding: 24px;
  margin-bottom: 8px;
  position: relative;
}
.layer-label {
  position: absolute;
  top: -10px;
  left: 20px;
  background: var(--accent);
  color: #fff;
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  padding: 2px 10px;
  border-radius: 4px;
}
.layer-content {
  display: flex;
  align-items: flex-start;
  gap: 20px;
}
.layer-icon svg {
  width: 48px;
  height: 48px;
}
.layer-body h3 {
  margin: 0 0 6px;
  font-size: 18px;
  font-weight: 600;
  color: #ffffff;
}
.layer-body p {
  margin: 0 0 12px;
  font-size: 14px;
  color: var(--ig-text-muted);
}
.pills {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}
.pill {
  background: rgba(255, 255, 255, 0.08);
  border: 1px solid rgba(255, 255, 255, 0.15);
  border-radius: 6px;
  padding: 4px 12px;
  font-size: 12px;
  color: var(--ig-text);
}
```

### Parallel Branch (side-by-side cards)

```html
<div class="parallel">
  <div class="layer" style="--accent: var(--ig-foundry)">...</div>
  <div class="layer" style="--accent: var(--ig-entra)">...</div>
</div>
```

```css
.parallel {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16px;
  margin-bottom: 8px;
}
```

### Flow Arrow

```html
<div class="arrow">
  <div class="arrow-line"></div>
  <div class="arrow-label">description of flow</div>
</div>
```

```css
.arrow {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 8px 0;
}
.arrow-line {
  width: 2px;
  height: 32px;
  background: linear-gradient(to bottom, var(--ig-neutral), transparent);
  position: relative;
}
.arrow-line::after {
  content: "";
  position: absolute;
  bottom: -6px;
  left: -4px;
  border-left: 5px solid transparent;
  border-right: 5px solid transparent;
  border-top: 6px solid var(--ig-neutral);
}
.arrow-label {
  font-size: 11px;
  color: var(--ig-text-muted);
  margin-top: 4px;
  font-style: italic;
}
```

### Summary Footer Bar

```html
<div class="footer-bar">
  <div class="footer-item" style="--dot: var(--ig-entra)">
    <span class="footer-dot"></span> Clean Entra
  </div>
  <div class="footer-item" style="--dot: var(--ig-azure)">
    <span class="footer-dot"></span> Deploy Bicep
  </div>
  ...
</div>
```

```css
.footer-bar {
  display: flex;
  justify-content: center;
  gap: 32px;
  margin-top: 24px;
  padding: 16px;
  background: rgba(255, 255, 255, 0.03);
  border-radius: 8px;
  border: 1px solid var(--ig-border);
}
.footer-item {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 13px;
  color: var(--ig-text);
  font-weight: 500;
}
.footer-dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  background: var(--dot);
}
```

## Icon Library (Inline SVGs)

Use these SVG icons inline. All icons are 48×48 viewBox.

### GitHub Actions

```html
<svg viewBox="0 0 48 48" fill="none" xmlns="http://www.w3.org/2000/svg">
  <circle cx="24" cy="24" r="20" fill="#1a1a2e" stroke="var(--ig-github)" stroke-width="2"/>
  <path d="M24 12C17.4 12 12 17.4 12 24c0 5.3 3.4 9.8 8.2 11.4.6.1.8-.3.8-.6v-2c-3.3.7-4-1.6-4-1.6-.5-1.4-1.3-1.8-1.3-1.8-1.1-.7.1-.7.1-.7 1.2.1 1.8 1.2 1.8 1.2 1.1 1.8 2.8 1.3 3.5 1 .1-.8.4-1.3.7-1.6-2.7-.3-5.5-1.3-5.5-5.9 0-1.3.5-2.4 1.2-3.2-.1-.3-.5-1.5.1-3.2 0 0 1-.3 3.3 1.2 1-.3 2-.4 3-.4s2 .1 3 .4c2.3-1.5 3.3-1.2 3.3-1.2.6 1.7.3 2.9.1 3.2.8.8 1.2 1.9 1.2 3.2 0 4.6-2.8 5.6-5.5 5.9.4.4.8 1.1.8 2.2v3.3c0 .3.2.7.8.6C32.6 33.8 36 29.3 36 24c0-6.6-5.4-12-12-12z" fill="var(--ig-github)"/>
</svg>
```

### Azure / Bicep

```html
<svg viewBox="0 0 48 48" fill="none" xmlns="http://www.w3.org/2000/svg">
  <circle cx="24" cy="24" r="20" fill="#1a1a2e" stroke="var(--ig-azure)" stroke-width="2"/>
  <path d="M18.5 14L14 34h4.2l1.5-6.8h5.6L28 34h4.2L27.5 14h-9zm5 4.2l2 8h-4l2-8z" fill="var(--ig-azure)"/>
  <path d="M30 18l4 8-4 8" stroke="var(--ig-azure)" stroke-width="1.5" fill="none" stroke-linecap="round"/>
</svg>
```

### Microsoft Entra ID

```html
<svg viewBox="0 0 48 48" fill="none" xmlns="http://www.w3.org/2000/svg">
  <circle cx="24" cy="24" r="20" fill="#1a1a2e" stroke="var(--ig-entra)" stroke-width="2"/>
  <path d="M24 14l-8 4v8c0 5.3 3.4 10.2 8 12 4.6-1.8 8-6.7 8-12v-8l-8-4z" fill="none" stroke="var(--ig-entra)" stroke-width="2"/>
  <path d="M24 20a3 3 0 110 6 3 3 0 010-6zm0 7c-3 0-5 1.5-5 3v1h10v-1c0-1.5-2-3-5-3z" fill="var(--ig-entra)"/>
</svg>
```

### Microsoft Foundry / MCP

```html
<svg viewBox="0 0 48 48" fill="none" xmlns="http://www.w3.org/2000/svg">
  <circle cx="24" cy="24" r="20" fill="#1a1a2e" stroke="var(--ig-foundry)" stroke-width="2"/>
  <path d="M16 20h16v2H16zm0 4h12v2H16zm0 4h14v2H16z" fill="var(--ig-foundry)" opacity="0.6"/>
  <path d="M20 14l-4 6h8l-4 6" stroke="var(--ig-foundry)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
  <path d="M28 22l4 6h-8l4 6" stroke="var(--ig-foundry)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
```

### Key / Secrets

```html
<svg viewBox="0 0 48 48" fill="none" xmlns="http://www.w3.org/2000/svg">
  <circle cx="24" cy="24" r="20" fill="#1a1a2e" stroke="var(--ig-key)" stroke-width="2"/>
  <circle cx="20" cy="24" r="5" fill="none" stroke="var(--ig-key)" stroke-width="2"/>
  <path d="M25 24h10m-3-3v6m-4-6v6" stroke="var(--ig-key)" stroke-width="2" stroke-linecap="round"/>
</svg>
```

### Cosmos DB

```html
<svg viewBox="0 0 48 48" fill="none" xmlns="http://www.w3.org/2000/svg">
  <circle cx="24" cy="24" r="20" fill="#1a1a2e" stroke="var(--ig-cosmos)" stroke-width="2"/>
  <ellipse cx="24" cy="24" rx="10" ry="4" fill="none" stroke="var(--ig-cosmos)" stroke-width="1.5"/>
  <ellipse cx="24" cy="24" rx="4" ry="10" fill="none" stroke="var(--ig-cosmos)" stroke-width="1.5" transform="rotate(60 24 24)"/>
  <ellipse cx="24" cy="24" rx="4" ry="10" fill="none" stroke="var(--ig-cosmos)" stroke-width="1.5" transform="rotate(-60 24 24)"/>
  <circle cx="24" cy="24" r="2.5" fill="var(--ig-cosmos)"/>
</svg>
```

### Container Registry

```html
<svg viewBox="0 0 48 48" fill="none" xmlns="http://www.w3.org/2000/svg">
  <circle cx="24" cy="24" r="20" fill="#1a1a2e" stroke="var(--ig-container)" stroke-width="2"/>
  <rect x="14" y="20" width="20" height="12" rx="2" fill="none" stroke="var(--ig-container)" stroke-width="2"/>
  <path d="M14 24h20M20 20v12M26 20v12" stroke="var(--ig-container)" stroke-width="1.5"/>
  <rect x="20" y="16" width="8" height="4" rx="1" fill="none" stroke="var(--ig-container)" stroke-width="1.5"/>
</svg>
```

### App Service / Web App

```html
<svg viewBox="0 0 48 48" fill="none" xmlns="http://www.w3.org/2000/svg">
  <circle cx="24" cy="24" r="20" fill="#1a1a2e" stroke="var(--ig-azure)" stroke-width="2"/>
  <rect x="14" y="16" width="20" height="16" rx="2" fill="none" stroke="var(--ig-azure)" stroke-width="2"/>
  <path d="M14 20h20" stroke="var(--ig-azure)" stroke-width="1.5"/>
  <circle cx="17" cy="18" r="1" fill="var(--ig-azure)"/>
  <circle cx="20" cy="18" r="1" fill="var(--ig-azure)"/>
  <path d="M18 24l3 4-3 4M26 24l-3 4 3 4" stroke="var(--ig-azure)" stroke-width="1.5" stroke-linecap="round"/>
</svg>
```

## Rendering to PNG

After creating the HTML file, render to PNG:

**Option A — Browser screenshot (recommended)**
1. Open the HTML file in a browser (Edge/Chrome)
2. Set viewport to 1200px width
3. Take a full-page screenshot (DevTools → Ctrl+Shift+P → "Capture full size screenshot")
4. Save as `images/<name>.png`

**Option B — Playwright (automated)**
```powershell
npx playwright screenshot --viewport-size="1200,900" images/<name>.html images/<name>.png
```

**Option C — PowerShell with Edge**
```powershell
$html = Resolve-Path "images/<name>.html"
& "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" --headless --screenshot="images/<name>.png" --window-size=1200,900 "file:///$($html.Path -replace '\\','/')"
```

## Full Example Template

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <title>Diagram Title</title>
  <style>
    :root {
      --ig-github: #8b5cf6;
      --ig-azure: #0078d4;
      --ig-entra: #16a34a;
      --ig-foundry: #f97316;
      --ig-key: #eab308;
      --ig-cosmos: #06b6d4;
      --ig-container: #ec4899;
      --ig-neutral: #94a3b8;
      --ig-surface: rgba(255, 255, 255, 0.06);
      --ig-border: rgba(255, 255, 255, 0.12);
      --ig-text: #e0e0e0;
      --ig-text-muted: #94a3b8;
    }
    * { box-sizing: border-box; }
    body {
      background: linear-gradient(160deg, #0a0e1a 0%, #1a1f3a 40%, #0f1a2e 70%, #0a0e1a 100%);
      min-height: 100vh;
      margin: 0;
      padding: 40px 60px;
      font-family: "Segoe UI", -apple-system, BlinkMacSystemFont, sans-serif;
      color: var(--ig-text);
    }
    .container { max-width: 1000px; margin: 0 auto; }
    /* ... paste layer, arrow, footer styles from above ... */
  </style>
</head>
<body>
  <div class="container">
    <div class="title">
      <h1>Diagram Title</h1>
      <p class="subtitle">Description</p>
    </div>
    <!-- layers, arrows, parallel sections, footer -->
  </div>
</body>
</html>
```
