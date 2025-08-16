---
title: Section hashing – why, when, and how
version: 1.0
lastUpdated: 2025-08-16
---

Overview
--------

Section hashing keeps your `[spec_folder]/context/manifest.json` up to date with per-section hashes, token estimates, and line ranges. The runners use this to skip unchanged sections and keep context lean and deterministic.

Why it matters
--------------

- Faster runs: skip re-reading big files when only a small part changed
- Lower token usage: load only the sections needed (P1/P2/P3 hierarchy)
- Determinism: strict section keys and ranges help the agent load the same slices every time
- CI-friendly: quick cache check to avoid unnecessary work

When to run it
--------------

- After you manually edit `spec.md` or any sub-spec under `sub-specs/`
- Before running `execute-tasks` on an existing spec (especially if you tweaked sections)
- In CI, as a pre-step for workflows that consume spec context
- After resolving merge conflicts that touched spec files

What it updates
---------------

- `files[<relPath>]` → `{ sha256, lastModified }`
- `sections[<relPath>].sections[<key>]` → `{ hash, tokens, lines }`

Notes

- Hashes are computed on UTF-8 text with LF line endings
- Token estimates are heuristic (≈ chars/4) and used for coarse budget checks
- If an old manifest uses `docs`, the script will migrate it to `files`

How to run (Windows PowerShell)
-------------------------------

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File tools/section-hash.ps1 C:\path\to\your\spec
```

Limit to specific files (optional):

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File tools/section-hash.ps1 C:\path\to\your\spec --Files spec.md, sub-specs/api-spec.md
```

How to run (POSIX shells)
-------------------------

```bash
tools/section-hash.sh /absolute/path/to/spec-folder
```

Limit to specific files (optional):

```bash
tools/section-hash.sh /absolute/path/to/spec-folder --files spec.md sub-specs/api-spec.md
```

Troubleshooting
---------------

- Missing jq (bash version): install jq or use the PowerShell version on Windows
- No sections detected: ensure your spec uses `##` headings for sections (H2)
- Duplicate section keys: duplicates are suffixed automatically (e.g., `_1`)

Schema reference
----------------

- Manifest schema: `./schemas/manifest.schema.json`
- Concept overview: `./manifest-spec.md`
