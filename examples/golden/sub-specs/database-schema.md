# Database Schema

## User Table

- Columns: id (PK), name (TEXT), created_at (TIMESTAMP)
- Indexes: idx_user_name

## Audit Table

- Columns: id (PK), action (TEXT), at (TIMESTAMP)
