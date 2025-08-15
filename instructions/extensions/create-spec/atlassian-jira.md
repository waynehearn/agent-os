---
description: Atlassian Jira integration for Spec Agent Kibo
targets: ["create-spec"]
version: 1.0
encoding: UTF-8
vendor: atlassian
requires: ["mcp:atlassian"]
---

<!-- markdownlint-disable MD033 MD032 MD007 MD022 MD023 MD041 -->

# Atlassian Jira Extension (create-spec)

<!-- Jira-driven initiation and optional post-sync extension. This file is only applied when present. -->

<variables>
  <jira_issue_key>[JIRA_ISSUE_KEY_OR_EMPTY]</jira_issue_key>
  <use_jira_mcp>false</use_jira_mcp>
  <post_spec_to_jira>true</post_spec_to_jira>
  <jira_comment_mode>summary</jira_comment_mode> <!-- values: full | diff | summary -->
</variables>

<step number="1.1" subagent="context-fetcher" name="jira_initiation">

## Step 1.1 (Extension): Jira initiation (optional)

If a Jira issue key is supplied and Atlassian MCP is available, derive initial inputs from Jira to seed spec creation.

<gate>
  RUN ONLY IF: jira_mcp_available == true AND [use_jira_mcp] == true AND [jira_issue_key] matches /(?i)^(jira:)?[A-Z][A-Z0-9]+-\d+$/
</gate>

<actions>
  1. STRIP optional prefix `jira:` from [jira_issue_key]
  2. FETCH via Atlassian MCP: key, summary, description, status, assignee, labels, components, fixVersions; custom fields (acceptance criteria, story points) when present; last 5 comments; linked issues
  3. DISPLAY a compact preview and ASK confirmation (yes/no)
  4. IF yes:
     - MAP to core inputs:
       - main_idea := summary (1–2 sentences)
       - initial_user_stories := acceptance criteria if present, else derive 1–3 from description
       - in_scope := derive 1–5 concrete items from description/labels/components
       - out_of_scope := optional exclusions when explicit
       - expected_deliverables := 1–3 browser‑testable outcomes
       - tech_constraints := components/labels implying constraints
     - FILL any missing required fields per core Step 1 schema by prompting the user
  5. PROCEED to context gathering
</actions>

</step>

<step number="6.2" subagent="context-fetcher" name="jira_comment_with_spec">

## Step 6.2 (Extension): Post spec.md to Jira (optional)

Synchronize `spec.md` back to Jira for visibility.

<condition>
  EXECUTE ONLY IF: [post_spec_to_jira] == true AND [jira_issue_key] is a non-empty valid key AND jira_mcp_available == true
  MODE: When [jira_comment_mode] == "summary", post a concise summary of changes; when "diff", post a unified diff; when "full", post full content (size-limited)
  SAFETY: Exclude secrets and local absolute paths
</condition>

<inputs>
  - jira_issue_key: [jira_issue_key]
  - spec_path: @[spec_folder_path]/spec.md
</inputs>

<actions>
  1. READ @[spec_folder_path]/spec.md
  2. COMPUTE sha256 of file content as [spec_sha]
  3. CHECK recent Jira comments for prior sync footer: "Synced by Spec Agent Kibo • key: [spec_key] • sha256: <hash>"
     - IF a matching [spec_sha] exists: SKIP posting
     - ELSE capture previous synced content if available for diff/summary
  4. POST according to [jira_comment_mode]: summary | diff | full (with excerpt fallback when size limits apply)
  5. APPEND footer: "Synced by Spec Agent Kibo • key: [CURRENT_DATE]-[SPEC_NAME] • sha256: [spec_sha]"
</actions>

<notes>
  - This extension does not alter local files; it only posts to Jira.
  - Re-run this step to re-sync after edits; it dedupes by hash.
</notes>

</step>
