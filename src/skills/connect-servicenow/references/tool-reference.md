<overview>
Complete command reference for all 10 `scripts/sn.sh` commands. Each tool documents usage syntax, options, and examples.
</overview>

<tool name="query">
**Query any table**

```bash
bash scripts/sn.sh query <table> [options]
```

Options:
- `--query "<encoded_query>"` — ServiceNow encoded query (e.g. `active=true^priority=1`)
- `--fields "<field1,field2>"` — Comma-separated fields to return
- `--limit <n>` — Max records (default 20)
- `--offset <n>` — Pagination offset
- `--orderby "<field>"` — Sort field (prefix with `-` for descending)
- `--display <true|false|all>` — Display values mode

Examples:
```bash
# List open P1 incidents
bash scripts/sn.sh query incident --query "active=true^priority=1" --fields "number,short_description,state,assigned_to" --limit 10

# All users in IT department
bash scripts/sn.sh query sys_user --query "department=IT" --fields "user_name,email,name"

# Recent change requests
bash scripts/sn.sh query change_request --query "sys_created_on>=javascript:gs.beginningOfThisYear()" --orderby "-sys_created_on" --limit 5
```
</tool>

<tool name="get">
**Get a single record by sys_id**

```bash
bash scripts/sn.sh get <table> <sys_id> [options]
```

Options:
- `--fields "<field1,field2>"` — Fields to return
- `--display <true|false|all>` — Display values mode

Example:
```bash
bash scripts/sn.sh get incident abc123def456 --fields "number,short_description,state,assigned_to" --display true
```
</tool>

<tool name="create">
**Create a record**

```bash
bash scripts/sn.sh create <table> '<json_fields>'
```

Example:
```bash
bash scripts/sn.sh create incident '{"short_description":"Server down","urgency":"1","impact":"1","assignment_group":"Service Desk"}'
```
</tool>

<tool name="update">
**Update a record**

```bash
bash scripts/sn.sh update <table> <sys_id> '<json_fields>'
```

Example:
```bash
bash scripts/sn.sh update incident abc123def456 '{"state":"6","close_code":"Solved (Permanently)","close_notes":"Restarted service"}'
```
</tool>

<tool name="delete">
**Delete a record**

```bash
bash scripts/sn.sh delete <table> <sys_id> --confirm
```

The `--confirm` flag is **required** to prevent accidental deletions.
</tool>

<tool name="aggregate">
**Aggregate queries**

```bash
bash scripts/sn.sh aggregate <table> --type <TYPE> [options]
```

Types: `COUNT`, `AVG`, `MIN`, `MAX`, `SUM`

Options:
- `--type <TYPE>` — Aggregation type (required)
- `--query "<encoded_query>"` — Filter records
- `--field "<field>"` — Field to aggregate on (required for AVG/MIN/MAX/SUM)
- `--group-by "<field>"` — Group results by field
- `--display <true|false|all>` — Display values mode

Examples:
```bash
# Count open incidents by priority
bash scripts/sn.sh aggregate incident --type COUNT --query "active=true" --group-by "priority"

# Average reassignment count
bash scripts/sn.sh aggregate incident --type AVG --field "reassignment_count" --query "active=true"
```
</tool>

<tool name="schema">
**Get table schema**

```bash
bash scripts/sn.sh schema <table> [--fields-only] [--include-inherited]
```

Returns field names, types, max lengths, mandatory flags, reference targets, and choice values.

Options:
- `--fields-only` — Return a compact sorted list of field names only
- `--include-inherited` — Include fields inherited from parent tables (e.g., `task` fields on `incident`). Without this flag, only fields defined directly on the target table are returned.

Examples:
```bash
# Table-specific fields only (default)
bash scripts/sn.sh schema incident

# Include fields inherited from task and other parent tables
bash scripts/sn.sh schema incident --include-inherited

# Compact field list with inherited fields
bash scripts/sn.sh schema incident --fields-only --include-inherited
```
</tool>

<tool name="batch">
**Bulk update or delete records**

```bash
bash scripts/sn.sh batch <table> --query "<encoded_query>" --action <update|delete> [--fields '{"field":"value"}'] [--limit 200] [--confirm]
```

Runs in **dry-run mode by default**. Pass `--confirm` to execute.

Options:
- `--query "<encoded_query>"` — Filter records (required)
- `--action <update|delete>` — Operation (required)
- `--fields '<json>'` — Fields to set (required for update)
- `--limit <n>` — Max records (default 200, cap 10000)
- `--confirm` — Execute the operation

Examples:
```bash
# Dry run: see how many records match
bash scripts/sn.sh batch incident --query "state=6^sys_updated_on<javascript:gs.daysAgo(90)" --action update

# Execute bulk close
bash scripts/sn.sh batch incident --query "state=6^sys_updated_on<javascript:gs.daysAgo(90)" --action update --fields '{"state":"7","close_notes":"Auto-closed"}' --confirm
```
</tool>

<tool name="health">
**Instance health check**

```bash
bash scripts/sn.sh health [--check <all|version|nodes|jobs|semaphores|stats>]
```

Checks: version, cluster nodes, stuck jobs, semaphores, instance stats (incidents/changes/problems).

Examples:
```bash
bash scripts/sn.sh health                  # Full health check
bash scripts/sn.sh health --check version  # Just version
bash scripts/sn.sh health --check stats    # Quick dashboard
```
</tool>

<tool name="attach">
**Manage attachments**

```bash
# List attachments on a record
bash scripts/sn.sh attach list <table> <sys_id>

# Download an attachment
bash scripts/sn.sh attach download <attachment_sys_id> <output_path>

# Upload an attachment
bash scripts/sn.sh attach upload <table> <sys_id> <file_path> [content_type]
```
</tool>
