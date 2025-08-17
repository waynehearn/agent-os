# User Guide: Token-Efficient Context Management

This guide provides practical advice for leveraging Agent OS's token optimization features in your daily workflow.

## Quick Reference

| Goal | Command | Notes |
|------|---------|-------|
| Create spec with profiling | `ENABLE_PROFILING=1 tools/run-create-spec.sh inputs.md` | View report in `.agent-os/logs/profiling/` |
| Use script-first approach | `tools/command-router.sh --script-first create-spec inputs.md` | Prioritizes token efficiency |
| Limit context size | `tools/context-gatherer.sh --max-size 512 product context.md` | Sets 512KB limit |
| Create spec from Jira | `@~/.agent-os/instructions/core/create-spec.md` with `[jira_inputs]` block | See [Jira integration](#jira-integration) |

## Understanding Token Efficiency

Token efficiency is about maximizing what you can do within LLM context limits. Agent OS achieves this through:

1. **Script operations**: Using scripts for deterministic tasks instead of tokens
2. **Smart context loading**: Only loading what's needed when it's needed
3. **Content hashing**: Tracking changes at the section level
4. **Template externalization**: Keeping reusable content in separate files

## Benefits for Users

- **Faster responses**: 40% faster operations due to reduced token processing
- **Lower costs**: 52.5% fewer tokens means lower API costs
- **More content**: Work with larger projects within the same context limits
- **Better reliability**: Less likely to hit token limits and context truncation

## How to Enable Profiling

Add `ENABLE_PROFILING=1` to any command:

```bash
# Profile create-spec operation
ENABLE_PROFILING=1 tools/run-create-spec.sh examples/sample-jira-spec-inputs.md

# Profile context gathering
ENABLE_PROFILING=1 tools/context-gatherer.sh product context.md
```

Profiling reports are saved to `.agent-os/logs/profiling/` with metrics on:

- Token usage estimation
- Operation counts (script vs. AI)
- Content composition
- Execution timing

## Optimizing Your Inputs

Follow these guidelines to make your inputs token-efficient:

1. **Be concise**: Focus on essential information
2. **Use references**: Reference existing files instead of copying content
3. **Leverage templates**: Use existing templates when available
4. **Section organization**: Use clear section headers for better context management

## Jira Integration

The token-efficient approach extends to Jira integration:

1. Create a Jira ticket with your request in the description:

```markdown
[jira_inputs]
jira_issue_key: ABC-123
use_jira_mcp: true
post_spec_to_jira: true
jira_comment_mode: summary

main_idea: >
  Brief description of feature...
[/jira_inputs]
```

2. Run create-spec with Jira reference:

```
@~/.agent-os/instructions/core/create-spec.md

[jira_inputs]
jira_issue_key: ABC-123
use_jira_mcp: true
[/jira_inputs]
```

3. The system will:
   - Efficiently fetch only needed Jira fields
   - Map fields to the specification format
   - Generate the specification with minimal token usage
   - Optionally post back to Jira with the chosen format

## Troubleshooting

| Issue | Possible Solution |
|-------|------------------|
| Operation seems slow | Try `--script-first` to prioritize script operations |
| Missing context | Check if content is in the right priority tier; may need to move from "reference" to "conditional" |
| High token usage | Run with profiling to identify which components use the most tokens |
| Duplicate content | Check for duplicate content across different context sources |

## Configuration Options

Edit `.agent-os/config.json` to adjust defaults:

```json
{
  "context": {
    "maxSizeKB": 1024,
    "cacheTTL": 3600,
    "tokenRatio": 4.0
  },
  "extensions": {
    "scanMode": "front-matter-only",
    "cacheTTL": 3600
  },
  "routing": {
    "defaultStrategy": "hybrid",
    "fallbackStrategy": "script-first"
  }
}
```

## Best Practices

1. **Start with profiling**: Get a baseline of your current token usage
2. **Identify hotspots**: Look for operations that use the most tokens
3. **Reduce context**: Review which context is truly necessary
4. **Use templates**: Create templates for repeated content
5. **Leverage caching**: Use existing caching mechanisms for frequent operations
6. **Regular maintenance**: Periodically clean up the context cache

By following these guidelines, you'll maximize the benefits of Agent OS's token-efficient hybrid approach.
