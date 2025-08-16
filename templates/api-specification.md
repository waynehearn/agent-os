---
description: API Specification Template
type: api_template
variables: [spec_folder_path, HTTP_METHOD, ENDPOINT_PATH, DESCRIPTION, LIST, FORMAT, POSSIBLE_ERRORS]
token_estimate: 180
conditional: requires_api_changes
---

# API Specification

This is the API specification for the spec detailed in @[spec_folder_path]/spec.md

## Endpoints

### [HTTP_METHOD] [ENDPOINT_PATH]

**Purpose:** [DESCRIPTION]
**Parameters:** [LIST]
**Response:** [FORMAT]
**Errors:** [POSSIBLE_ERRORS]

## Controllers

- **Action Names:** [ACTION_NAMES]
- **Business Logic:** [BUSINESS_LOGIC]
- **Error Handling:** [ERROR_HANDLING]

## Integration

- **Endpoint Rationale:** [ENDPOINT_RATIONALE]
- **Feature Integration:** [FEATURE_INTEGRATION]
