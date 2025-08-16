---
description: Database Schema Template
type: database_template
variables: [spec_folder_path, NEW_TABLES, NEW_COLUMNS, MODIFICATIONS, MIGRATIONS, SQL_SYNTAX, INDEXES, CONSTRAINTS, FOREIGN_KEYS, CHANGE_REASON, PERFORMANCE_CONSIDERATIONS, DATA_INTEGRITY_RULES]
token_estimate: 150
conditional: requires_db_changes
---

# Database Schema

This is the database schema implementation for the spec detailed in @[spec_folder_path]/spec.md

## Schema Changes

### New Tables

- [NEW_TABLES]

### New Columns  

- [NEW_COLUMNS]

### Modifications

- [MODIFICATIONS]

### Migrations

- [MIGRATIONS]

## Implementation Details

### SQL Syntax

```sql
[SQL_SYNTAX]
```

### Indexes and Constraints

- [INDEXES]
- [CONSTRAINTS]

### Foreign Key Relationships

- [FOREIGN_KEYS]

## Rationale

### Change Justification

- [CHANGE_REASON]

### Performance Considerations

- [PERFORMANCE_CONSIDERATIONS]

### Data Integrity Rules

- [DATA_INTEGRITY_RULES]
