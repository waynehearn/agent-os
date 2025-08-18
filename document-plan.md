# Documentation Review & Restructuring Plan

**2025-08-17 Orphan Sweep, Navigation Audit, and TOC Update:**

- Audited for orphaned docs and missing links; schemas/README.md was not linked from the TOC.
- Updated docs/Index.md TOC to cover all top-level docs and link schemas/README.md.
- Confirmed README.md only links QuickStart Guide.md and docs/Index.md as entry points.
- Verified all docs (except .obsidian) are reachable from the top-level navigation.
- Marked orphan sweep, inventory, and navigation audit as complete.

## Task List (Progress)

- [x] Inventory all documentation files and subfolders
- [x] Map documentation hierarchy and navigation
- [x] Audit for orphaned docs and missing links
- [x] Update TOC in docs/Index.md to cover all docs
- [x] Link schemas/README.md from Index.md
- [x] Ensure README.md only links QuickStart and Index
- [x] Confirm all docs are reachable from entry point
- [ ] Review future subfolders for navigation coverage

## Summary

All documentation files have been inventoried, organized, and are now navigable from the entry point. The orphan sweep and navigation audit are complete. Future subfolders/docs should be linked via parent README.md in the TOC. Document-plan.md tracks completed work and next steps.

---

## 1. Audit and Inventory

- List all documentation files in the repo (docs/, root, and other doc folders)
- Identify core entry points: README.md, Getting Started, QuickStart Guide, architecture, usage, and feature docs
- Map current structure: note existing hierarchy, cross-links, and orphaned/outdated docs

## 1. Audit and Inventory [x]

- List all documentation files in the repo (docs/, root, and other doc folders) **[done]**
- Identify core entry points: README.md, Getting Started, QuickStart Guide, architecture, usage, and feature docs **[done]**
- Map current structure: note existing hierarchy, cross-links, and orphaned/outdated docs **[done]**

## 2. Define Documentation Hierarchy

- Top-level (README.md):
  - Project overview
  - Quick links: Getting Started, Features, Architecture, Usage, Troubleshooting, Contributing
  - Table of Contents (TOC) linking all parent docs

- Core Sections:
  - Getting Started (installation, setup, first run)
  - Features & Functions (overview, with links to detailed docs)
  - Architecture (system design, context flow, extension model)
  - Usage Guides (how to run, test, optimize, extend)
  - Advanced Topics (context optimization, extension development, CI, etc.)
  - Troubleshooting & FAQ
  - Changelog & Roadmap
  - Contributing

## 3. Review and Update Content

- For each doc:
  - Compare content to current implementation (scripts, features, CLI, config, etc.)
  - Update outdated instructions, flags, or references
  - Ensure all features/functions are documented (including new/advanced ones)
  - Add missing topics (e.g., context optimizer, extension scanner, cache manager)
  - Remove or merge redundant docs

## 4. Standardize Structure and Tone

- Template for each doc:
  - Title and brief summary
  - Prerequisites (if any)
  - Step-by-step instructions or explanations
  - Examples and code snippets
  - Back link to parent/TOC
  - Consistent tone: concise, direct, user-focused

## 5. Implement Navigation

- TOC page: Central index linking all parent docs and major features
- Back links: At the end of each doc, link to parent/TOC
- Cross-links: Where relevant, link related docs/features

## 6. Final Review

- Check for completeness: All features, flags, and workflows covered
- Logical flow: Entry points surface core features, advanced topics are discoverable
- Accuracy: All instructions match current implementation
- Consistency: Structure, tone, and navigation are uniform

---

### Next Steps

1. Inventory all docs and map the current structure
2. Draft the new hierarchy and TOC
3. Review and update each doc for accuracy and completeness
4. Apply the standard template and add navigation links
5. Final review and polish

---

## Completed Work Log

**2025-08-17  Audit and Inventory:**

- All documentation files and their locations have been mapped across root, docs/, subfolders, examples, test, commands, instructions, and supporting folders. This provides a foundation for hierarchy planning, TOC creation, and content review.

---

## LLM Guidance Prompt

If you are an LLM or agent picking up this documentation review task:

- There is a `markdownlint.json` file in this project. Please follow its rules for formatting and style.
- After editing docs, run the following bash command to auto-fix markdown linting issues:

```bash
npx markdownlint-cli '**/*.md' --fix
```

- Ensure all documentation is accurate, complete, and organized as described above.
- Use the standard template and maintain consistent tone and navigation.
- Add or update the Table of Contents and back links as needed.
