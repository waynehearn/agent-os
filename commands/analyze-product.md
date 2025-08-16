# Analyze Product

Analyze your product's codebase and install Spec Agent Kibo

Refer to the instructions located in @~/.agent-os/instructions/core/analyze-product.md

Discovery-first behavior
------------------------

When invoked, the flow first runs a Bash-only discovery to reuse any existing context (Claude Code, repo docs, or prior product files) before asking questions or generating files:

- Internally: `bash tools/discover-product-context.sh --write-if-missing`
- Side effects: writes `.agent-os/product/context/context.json` only if missing; otherwise read-only
- If discovery is insufficient, the flow can create a minimal `.agent-os/product/` skeleton, but only if you explicitly allow it (see inputs below)

Prerequisites
-------------

- Bash (macOS/Linux, Windows Git Bash/WSL)
- `jq` on PATH; see `docs/installation.md` for Windows Git Bash no-admin steps

Optional inputs (provide inline when invoking):

Optional inputs (provide inline when invoking):

- context_notes: any high-level context the agent should consider during analysis

```text
@~/.agent-os/instructions/core/analyze-product.md

[analyze_inputs]
context_notes: >
  [Optional: key notes to guide analysis]
auto_init_product: false
[/analyze_inputs]
```

- `auto_init_product` (optional): if set to `true`, allows the flow to run discovery with `--init-product` to create minimal `.agent-os/product/` docs when discovery alone is insufficient. If `false` or omitted, the flow will ask you for missing context instead of creating files.

Manual discovery (optional)
---------------------------

You can run discovery yourself before invoking the command:

```bash
bash tools/discover-product-context.sh --write-if-missing
# or target another repo path
bash tools/discover-product-context.sh /absolute/path/to/project --write-if-missing
```

To bootstrap minimal product docs when needed (opt-in):

```bash
bash tools/discover-product-context.sh /absolute/path/to/project --init-product --write
```

See also: `docs/context-discovery.md` for details on sources and output format.
