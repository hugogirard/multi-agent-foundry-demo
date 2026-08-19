# Copilot Instructions for multi-agent-foundry-demo

## Diagram / Image Generation

When asked to create a diagram, infographic, or visual for documentation:

1. **Create an HTML file** in `images/` using the dark infographic style established in `images/infra-pipeline.html`. Match the CSS variables (`--ig-*`), layer cards, pill badges, SVG icons, arrow connectors, and footer legend.
2. **Open the HTML in the browser** (`file:///` URI) and use Playwright to screenshot the `.container` element to a PNG in the same `images/` folder.
3. **Reference the PNG** from markdown docs (`![alt](../images/name.png)`).
4. Keep the `.html` source alongside the `.png` so diagrams can be edited and re-exported later.
5. Do **not** use Excalidraw (`.excalidraw` files don't render on GitHub) or inline Mermaid (doesn't match the project's visual style).
