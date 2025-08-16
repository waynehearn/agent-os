![Spec Agent K banner](assets/specl-agent-kibo-banner.png)

Your system for deterministic spec-driven agentic development.

What is Spec Agent K?
------------------

Spec Agent K is a system for spec‑driven agentic development. It gives AI coding agents structured workflows aligned to your standards, stack, and codebase context so they ship quality code on the first try—not the fifth.

---

## Works with

- Claude Code, Cursor, or other AI coding tools(sort of)
- New products or established codebases
- Big features or small fixes
- Any language or framework

---
## Reviews

> _“Spec Agent K has matured from a strong spec‑first framework into a fast, investigation‑capable system with real, measurable context‑cost reductions. Investigation mode, section‑aware manifests, and lite‑first artifacts make day‑to‑day work both cheaper and more reliable.  Overall Rating: 8.5/10.”_ — GitHub Copilot

> _“Spec Agent K is a sophisticated LLM‑driven framework that transforms minimal prompting into structured specifications and implementation plans. It excels at greenfield and structured enhancements, while investigation‑heavy work and emergencies benefit from complementary approaches. Overall Rating: 7.5/10.”_ — Claude Code

---
## Get Started

- [QuickStart](QuickStart%20Guide.md)
- [Index](./docs/Index.md)

---

## What’s inside

- Commands: commands/
- Core instruction flows:
  - Plan Product: instructions/core/plan-product.md
  - Create Spec: instructions/core/create-spec.md
  - Execute Tasks: instructions/core/execute-tasks.md
  - Execute Task: instructions/core/execute-task.md
  - Analyze Product: instructions/core/analyze-product.md
  - Claude Code agents (examples):
  - File Creator: claude-code/agents/file-creator.md
  - Context Fetcher: claude-code/agents/context-fetcher.md
  - Git Workflow: claude-code/agents/git-workflow.md

---

## Performance & context optimization

- Externalized templates reduce core file size and improve reuse (see `templates/` and Architecture guide)
- Hierarchical, budget-aware context loading with section-level manifests
- Extension registry caching with front-matter-only reads and 1-hour
- Lite-first reads (`spec-lite.md`, `context/facts.md`)
- Section-level manifests for targeted reloads
- Extension registry caching using front-matter-only reads

---

## Support & updates

- Troubleshooting: [docs/troubleshooting.md](docs/troubleshooting.md)
- Changelog: [CHANGELOG.md](CHANGELOG.md)
- Project license: [LICENSE](LICENSE)

Created by Brian Casel at Builder Methods — more resources at [buildermethods.com](https://buildermethods.com)
Modified by ChatGPT5/ClaudeCode with some prompting from [Wayne.Hearn@kiboecommerce.com](mailto:Wayne.Hearn@kiboecommerce.com)
