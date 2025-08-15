---
title: Project Tech Stack (Demo – HTML/JS)
version: 1.0
lastUpdated: 2025-08-14
---

This is a minimal frontend stack for the quickstart demo.

- Frontend: HTML5 + CSS3 + Vanilla JavaScript (ES2020+)
- Build: None required (open `site/index.html` directly)
- Testing: Optional (light DOM/unit tests if desired)
- Accessibility: Basic a11y (alt text, contrast, focus styles)
- Performance: Keep assets small; inline SVG when practical

Conventions

- JS organization: a small module in `site/app.js` with clear function names
- DOM hooks: use `data-` attributes or ids (`#kibo-agent-badge-container`)
- CSS: namespaced class names with `kibo-` prefix (e.g., `.kibo-badge`)
- No bundler: keep everything framework-free and portable
