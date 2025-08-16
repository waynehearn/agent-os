## Using this repo with GitHub Copilot Chat

These prompts were written for Claude Code with subagents. GitHub Copilot Chat doesn’t spawn multiple autonomous subagents or run arbitrary tools by itself, but you can get most of the value by asking Copilot to follow the agent playbooks in this repo and by running VS Code tasks/scripts yourself.


### What works in Copilot Chat

- Reading and following playbooks in this repo when you reference file paths explicitly (use @workspace in Chat).
- Producing specs, task plans, and diffs/patches based on our templates and schemas.
- Guiding you through terminal/VS Code tasks you run manually.


### What doesn’t (without building an extension)

- Autonomous subagent orchestration, parallel agents, or tool execution.
- Direct Jira/HTTP calls or shell execution initiated by Copilot itself.
- Persisted “roles” beyond the current chat unless you restate them.

If you need true agents/tools, consider building a VS Code extension that exposes a Copilot extension (advanced), or keep using Claude/Cursor for multi-agent automation.

---

## Quick-start prompts (copy/paste into Copilot Chat)

Tip: Prefix with `@workspace` so Copilot can read files you reference.


### 1) Context Fetcher

"Act as the Context Fetcher per `claude-code/agents/context-fetcher.md`. Read `docs/context-discovery.md` and `examples/golden/context/manifest.json`. Output a concise product/context summary and list unknowns/gaps per the playbook. Keep responses under 200 lines."


### 2) Planner

"Follow `commands/plan-product.md` using `examples/quickstart/initial-request.md` as the input. Produce a high-level plan and risks. Use `docs/create-spec-tasks.md` for structure."


### 3) Spec Creator

"Follow `commands/create-spec.md` and `docs/create-spec-steps.md`. Conform to `docs/schemas/spec-input.schema.json` and `docs/schemas/product-context.schema.json`. Use `templates/enhanced-manifest.json` if relevant. Return a diff-ready spec."


### 4) Task Executor (proposal mode)

"Using `commands/execute-tasks.md` and `instructions/core/execute-tasks.md`, propose an ordered set of edits and shell steps. For file edits, return patch-style suggestions. For shell steps, list commands but don’t run them."


### 5) File Creator

"Behave as the File Creator per `claude-code/agents/file-creator.md`. Create or update files to implement the proposed tasks. Return minimal, focused diffs."


### 6) Git Workflow

"Follow `claude-code/agents/git-workflow.md`. Propose exact git commands (branch, commit messages). Do not execute—only propose."


### 7) Test Runner (manual run)

"Follow `claude-code/agents/test-runner.md`. Then ask me to run the VS Code task ‘hash golden example sections (pwsh)’ and paste back the output for analysis."

---

## Running the helper tasks yourself

- Hash golden example sections (Windows/PowerShell): VS Code → Tasks: Run Task → "hash golden example sections (pwsh)"
- Verify jq: VS Code → Tasks: Run Task → "verify jq"

If you prefer the shell equivalents, see `tools/section-hash.ps1` and `tools/verify-jq.sh`.

---

## Tips for better results

- Always cite file paths so Copilot grounds its answers in the repo (e.g., `docs/index.md`, `docs/manifest-spec.md`).
- Keep each chat focused on one role (Context Fetcher, Planner, Spec Creator, etc.).
- Ask for patch-style outputs when creating/editing files to keep diffs tight.
- Use the golden example in `examples/golden/` as a reference oracle.

---

## Jira integration

The Jira extension flow in `instructions/extensions/create-spec/atlassian-jira.md` describes a subagent pattern. Copilot Chat won’t call Jira directly unless you build a Copilot-enabled VS Code extension that exposes those actions. As a workaround, have Copilot draft the payloads/steps and run them with your Jira CLI/automation outside of Chat.
