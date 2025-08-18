---
title: Manifest Specification (section-aware)
version: 1.0
lastUpdated: 2025-08-16
---

Overview
--------

This document describes the per-spec context manifest used by the flows to avoid re-reading unchanged content and to support section-level, budget-aware loading.

Goals
-----

- Skip unchanged files/sections by hash
- Load only the sections needed for the current step
- Track rough token estimates to enforce a context budget

Top-level shape
---------------

```json
{
  "files": {
    "spec.md": {"sha256": "...", "lastModified": "2025-08-16T12:00:00Z"},
    "spec-lite.md": {"sha256": "...", "lastModified": "2025-08-16T12:00:05Z"}
  },
  "sections": {
    "spec.md": {
      "sections": {
        "overview": {"hash": "abc123", "tokens": 45, "lines": "1-18"},
        "user_stories": {"hash": "def456", "tokens": 120, "lines": "19-65"}
      }
    },
    "sub-specs/api-spec.md": {
      "sections": {
        "endpoints": {"hash": "eee111", "tokens": 160, "lines": "1-80"}
      }
    }
  },
  "context_budget": {
    "total_available": 4000,
    "essential_usage": 130,
    "conditional_usage": 650,
    "remaining": 3220
  }
}
```

Field definitions
-----------------

- files
  - Map of relative file path → object with:
    - sha256: string, hex-encoded SHA-256 hash of the file with LF line endings
    - lastModified: ISO 8601 timestamp

- sections
  - Map of relative file path → object with:
    - sections: map of sectionKey → object with:
      - hash: string, hex-encoded SHA-256 of the section text
      - tokens: number, estimated token count for the section (approximate)
      - lines: string, inclusive line range within the file (e.g., "9-25")

- context_budget (optional)
  - total_available: number, default 4000
  - essential_usage: number
  - conditional_usage: number
  - remaining: number

Hashing rules
-------------

- Algorithm: SHA-256
- Input: UTF-8, LF line endings
- Section hash input: exact section text as written; include headings where applicable

Loading rules (LLM hints)
-------------------------

- Prefer lite-first artifacts before full files: `spec-lite.md`, `context/facts.md`
- Check `files[*].sha256` and `sections[*].sections[sectionKey].hash` against cached values before reading
- Read only the reported `lines` for a section when possible
- Stop loading when `context_budget.remaining` would be exceeded

Schema
------

See JSON Schema: `docs/schemas/manifest.schema.json`.

CLI usage
---------

- Generate or update section entries for a spec folder:
  - tools/section-hash.sh /absolute/path/to/spec-folder
- Limit to specific files relative to the spec folder:
  - tools/section-hash.sh /absolute/path/to/spec-folder --files spec.md sub-specs/api-spec.md
- Notes:
  - Requires jq and a POSIX shell (Linux/macOS or Windows Git Bash/WSL).
  - The script also maintains the top-level `files` hashes and will migrate older `docs` manifests to the new `files` shape.

Windows (PowerShell)
--------------------

- Run the native PowerShell version (no jq required):
  - pwsh -NoProfile -ExecutionPolicy Bypass -File tools/section-hash.ps1 c:\path\to\your\spec
  - Optionally, limit to specific files: add --Files spec.md, sub-specs/api-spec.md

Related
-------


## Troubleshooting


### Manifest Not Updating

If manifest files are not updating:

- Ensure you are running the correct hash script for your OS (Bash or PowerShell).
- Check for write permissions in the spec folder.
- Verify `jq` is installed for Bash scripts.

### Section Hashes Incorrect

If section hashes do not match expected values:

- Confirm line endings are normalized to LF.
- Check for changes in section headings or content.
- Rerun the hash script after editing files.

### Context Budget Issues

If context budget is exceeded or inaccurate:

- Review token estimates and section sizes in the manifest.
- Adjust context loading strategy to prioritize essential sections.

### General Tips

- Always update scripts after major changes.
- Review logs and script output for errors or warnings.

## Additional Resources

- [Configuration](./configuration.md)
- [Create Spec Usage](./create-spec-usage.md)
- [Troubleshooting](./troubleshooting.md)
