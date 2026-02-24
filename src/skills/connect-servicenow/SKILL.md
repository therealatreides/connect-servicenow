---
name: connect-servicenow
description: Connects Claude Code to any ServiceNow instance via REST API, executing CRUD, aggregation, schema, attachment, batch, and health operations through an authenticated CLI. Use when you need to query, create, update, or delete ServiceNow records programmatically.
---

<objective>
Provide reliable, authenticated access to any ServiceNow instance via REST API. Execute CRUD operations, aggregations, schema discovery, attachment management, batch operations, and health checks through the `scripts/sn.sh` CLI. This is the canonical connection layer — other ServiceNow skills may reference this skill for API operations.
</objective>

<quick_start>
1. Set up credentials in `.env` (see `.env-example` in this skill's directory) or provide them when prompted (for OAuth setup, see `references/authentication.md`):
   ```
   SNOW_INSTANCE_URL=https://yourinstance.service-now.com
   SNOW_AUTH_TYPE=basic
   SNOW_USERNAME=admin
   SNOW_PASSWORD=yourpassword
   ```
2. Test connection:
   ```bash
   bash scripts/sn.sh health --check version
   ```
3. Run any command:
   ```bash
   bash scripts/sn.sh query incident --query "active=true^priority=1" --fields "number,short_description" --limit 5
   ```
</quick_start>

<safety>
<rule name="delete">Requires `--confirm` flag (enforced by sn.sh)</rule>
<rule name="batch">Defaults to dry-run mode; requires `--confirm` to execute</rule>
<rule name="batch-query">`--query` is mandatory — refuses to operate on all records</rule>
<rule name="batch-limit">Capped at 10,000 records for safety</rule>
<rule name="json-validation">All create/update payloads validated before submission</rule>
<rule name="mutation-confirmation">Before any mutation, show the user the exact command and data. Get confirmation before executing.</rule>

See `references/safety-rules.md` `<delete_safety>`, `<batch_safety>`, `<mutation_awareness>` for complete documentation.
</safety>

<retry_policy>
Transient failures (5xx, 429, OAuth 401) and connection failures (HTTP 000) are retried up to 2 times with appropriate delays. HTTP 000 uses exponential backoff (2s, 4s) to handle PDI hibernation wake-up. Client errors (400, 403, 404) and Basic Auth 401s are not retried. Max retries configurable via `SNOW_MAX_RETRIES` env var (default: 3 attempts). After exhausting retries, the script exits with a descriptive error message.

Full retry behavior and table: `references/safety-rules.md` `<retry_safety>`.
</retry_policy>

<security_checklist>
1. `.env` files containing credentials MUST be listed in `.gitignore`
2. NEVER log or echo `SNOW_PASSWORD`, `SNOW_CLIENT_SECRET`, or OAuth tokens
3. Instance URLs MUST use HTTPS — reject HTTP URLs
4. OAuth tokens cached in `.env` for session reuse (same file as credentials). Disable with `SNOW_TOKEN_CACHE=false`
5. Manually entered credentials are session-scoped — not persisted unless user opts in via `.env`
6. TLS certificate verification is enforced via curl's default certificate bundle — never use `--insecure` or `-k`

Full credential rules: `references/safety-rules.md` `<credential_safety>`.
</security_checklist>

<tools>
Invoke as: `bash scripts/sn.sh <subcommand> [args]`

| Command | Syntax |
|---------|--------|
| `query` | `query <table> --query "..." --fields "..." --limit N` |
| `get` | `get <table> <sys_id> [--fields "..."] [--display true]` |
| `create` | `create <table> '{"field":"value"}'` |
| `update` | `update <table> <sys_id> '{"field":"value"}'` |
| `delete` | `delete <table> <sys_id> --confirm` |
| `aggregate` | `aggregate <table> --type COUNT\|AVG\|MIN\|MAX\|SUM [--field field] [--group-by field] [--query "..."]` |
| `schema` | `schema <table> [--fields-only] [--include-inherited]` |
| `batch` | `batch <table> --query "..." --action <update|delete> [--fields '{"k":"v"}'] [--confirm]` |
| `health` | `health --check version|nodes|jobs|semaphores|stats|all` |
| `attach list` | `attach list <table> <sys_id>` |
| `attach download` | `attach download <attachment_sys_id> <output_path>` |
| `attach upload` | `attach upload <table> <sys_id> <file_path> [content_type]` |

Full syntax and examples: `references/tool-reference.md`
</tools>

<intake>
Present this ServiceNow operations menu to the user:

1. Connect to an instance — Set up credentials and test connection
2. Query or read records — Search, get, inspect schema, aggregate stats
3. Create or update records — Add or modify data
4. Delete or bulk operations — Delete records or run bulk update/delete
5. Manage attachments — List, upload, or download files
6. Check instance health — Version, nodes, jobs, semaphores, stats
7. Get help — Understand how this skill works

Or describe what you need and Claude will determine the appropriate workflow.
If the request is ambiguous, ask one clarifying question before routing.
If the request spans multiple categories, handle operations in the order stated — complete each workflow before loading the next. Do not load multiple workflow files simultaneously.
</intake>

<routing>
<intent_routing description="primary — use this first">
- Table name + question about data → `workflows/query-and-read.md`
- Table name + JSON payload → `workflows/create-and-update.md`
- "Delete" + table/record → `workflows/delete-and-batch.md`
- "Bulk" or "batch" + table → `workflows/delete-and-batch.md`
- "How many" + table → `workflows/query-and-read.md` (aggregate)
- "Schema" or "fields" + table → `workflows/query-and-read.md` (schema)
- Incident-specific request → also load `patterns/incident-management.md` as an overlay (execute alongside the matched workflow)
- Change-specific request → also load `patterns/change-management.md` as an overlay (execute alongside the matched workflow)
- CMDB/CI-specific request → also load `patterns/cmdb-operations.md` as an overlay (execute alongside the matched workflow)
- "Health" or "version" or "status" or "nodes" or "jobs" + instance → `workflows/health-check.md`
- "Attach" or "attachment" or "upload" or "download" + record → `workflows/attachments.md`
- Any request requiring ServiceNow data → ensure connected first via `workflows/connect-instance.md`
</intent_routing>

<keyword_fallback description="use only when no intent pattern matches">

| Category | Workflow |
|----------|----------|
| Connection / auth | `workflows/connect-instance.md` |
| Query / read / schema / aggregate | `workflows/query-and-read.md` |
| Create / update | `workflows/create-and-update.md` |
| Delete / batch | `workflows/delete-and-batch.md` |
| Attachments | `workflows/attachments.md` |
| Health / status | `workflows/health-check.md` |
| Help | Provide a summary from this file's `<objective>`, `<tools>`, and `<intake>` tags. Do not load a workflow file. |
</keyword_fallback>

After reading the workflow, follow it exactly.
</routing>

<navigation>
Consult these indexes to locate detailed documentation. Load files on-demand based on routing decisions — do not preload all files.

<reference_files>
All in `references/`:

| File | Purpose |
|------|---------|
| tool-reference.md | Complete syntax and examples for all 10 sn.sh commands |
| authentication.md | Primary auth reference (all strategies, .env, OAuth) |
| oauth-patterns.md | OAuth token acquisition, refresh, and error handling |
| env-file-format.md | .env file schema, parsing, and validation |
| encoded-query-syntax.md | ServiceNow encoded query operators and examples |
| common-tables.md | Common table names for ITSM, CMDB, Knowledge, System |
| safety-rules.md | Delete, batch, JSON validation, and mutation safety rules |
</reference_files>

<workflow_files>
All in `workflows/`:

| Workflow | Purpose |
|----------|---------|
| connect-instance.md | Establish ServiceNow connection (auth, test) |
| query-and-read.md | Query, get, schema, aggregate operations |
| create-and-update.md | Create and update records |
| delete-and-batch.md | Delete and batch operations (with safety emphasis) |
| attachments.md | List, upload, download attachments |
| health-check.md | Monitor instance health |
</workflow_files>

<pattern_files>
All in `patterns/`:

| Pattern | Purpose |
|---------|---------|
| incident-management.md | Query, aggregate, create, update, batch patterns for incidents |
| change-management.md | Query, create, update patterns for change requests |
| cmdb-operations.md | Query, schema, update, batch patterns for CMDB CIs |
</pattern_files>

</navigation>

<rules>
1. ALWAYS authenticate before API calls. If no connection is established, route to `workflows/connect-instance.md` first.
2. ALWAYS show the exact `sn.sh` command and JSON payload to the user before executing any mutation (create, update, delete, or batch).
3. ALWAYS run batch in dry-run first. NEVER pass `--confirm` without showing the matched count to the user.
4. NEVER execute a delete without first fetching and displaying the target record to the user.
5. Use `--display true` for user-facing output. Reference fields show sys_ids by default; use `--display true` for human-readable values.
6. Use `--fields` for efficiency. Specify needed fields with `--fields` to reduce response size.
7. ALWAYS stop after clarifying questions. When asking a question, END the response immediately. Do not continue with conditional guidance.
8. Production-ready examples. Multi-step scripts and batch operations must include error handling and be complete enough to use as-is. Single-command examples are exempt.
9. After sn.sh exits with a retry-exhausted error, display the error message verbatim and ask the user whether to re-attempt or re-enter credentials.
</rules>

<success_criteria>
- **Connection**: `bash scripts/sn.sh health --check version` returns version info without error
- **Query**: Records returned as JSON with `record_count` and `results`; no 401/403/404 errors
- **Mutation**: User confirmed command before execution; sn.sh exits 0; sys_id of created/updated record displayed
- **Batch**: Dry-run count shown first; user confirmed; summary shows `matched` = `processed` with `failed` = 0
- **Delete**: Record fetched and shown to user; user confirmed; sn.sh exits 0 with deletion confirmation
- **Schema**: Field list returned as sorted JSON array with type, label, and mandatory info
- **Health**: JSON output with requested checks (version/nodes/jobs/semaphores/stats) populated
</success_criteria>
