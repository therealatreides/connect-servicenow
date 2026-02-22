<overview>
Read operations: query records, get single records, inspect table schemas, and run aggregate queries. All operations are read-only (GET requests only).
</overview>

<prerequisite>
Ensure a ServiceNow connection is established. If `SNOW_*` env vars are not set, route to `workflows/connect-instance.md` first.
</prerequisite>

<steps>

<step_classify>
**Classify the read request**:

| User Intent | Command | Example |
|------------|---------|---------|
| Search/list records | `query` | "Show me open P1 incidents" |
| Get specific record | `get` | "Get details for INC0012345" |
| Inspect table fields | `schema` | "What fields does the incident table have?" |
| Count or statistics | `aggregate` | "How many open incidents by priority?" |
| Field list only | `schema --fields-only` | "List all fields on change_request" |
</step_classify>

<step_query>
**Query records** (`query`)

1. Identify the target table (see `references/common-tables.md` if uncertain)
2. Build the encoded query from the user's natural language request (see `references/encoded-query-syntax.md`)
3. Select relevant fields with `--fields` to reduce response size
4. Set appropriate `--limit` (default 20)
5. Use `--display true` for user-facing output

```bash
bash scripts/sn.sh query <table> \
  --query "<encoded_query>" \
  --fields "<field1,field2,...>" \
  --limit <n> \
  --display true
```

**Natural language mapping examples**:
- "open P1 incidents" → `--query "active=true^priority=1"`
- "incidents assigned to Service Desk" → `--query "assignment_group.name=Service Desk"`
- "changes created this week" → `--query "sys_created_on>=javascript:gs.beginningOfThisWeek()"`
- "unassigned active tasks" → `--query "active=true^assigned_toISEMPTY"`

**Pagination**: If the user needs more records than returned:
```bash
# Page 2 (records 21-40)
bash scripts/sn.sh query incident --query "active=true" --limit 20 --offset 20
```
</step_query>

<step_get>
**Get single record** (`get`)

When the user references a specific record number (e.g., INC0012345):

1. First, query to find the sys_id:
```bash
bash scripts/sn.sh query incident --query "number=INC0012345" --fields "sys_id,number,short_description"
```

2. Then get full details:
```bash
bash scripts/sn.sh get incident <sys_id> --display true
```

Or combine with `--fields` for specific information:
```bash
bash scripts/sn.sh get incident <sys_id> --fields "number,short_description,state,assigned_to,description" --display true
```
</step_get>

<step_schema>
**Inspect table schema** (`schema`)

Use when the user asks about table structure, available fields, or field types:

```bash
# Full schema with types, lengths, mandatory flags
bash scripts/sn.sh schema incident

# Just field names
bash scripts/sn.sh schema incident --fields-only
```

Schema is useful before create/update operations to verify field names and types.
</step_schema>

<step_aggregate>
**Aggregate queries** (`aggregate`)

For counting, averaging, or statistical questions:

```bash
# Count open incidents by priority
bash scripts/sn.sh aggregate incident --type COUNT --query "active=true" --group-by "priority" --display true

# Average reassignment count for active incidents
bash scripts/sn.sh aggregate incident --type AVG --field "reassignment_count" --query "active=true"

# Maximum story points
bash scripts/sn.sh aggregate rm_story --type MAX --field "story_points"

# Sum of business duration for closed incidents
bash scripts/sn.sh aggregate incident --type SUM --field "business_duration" --query "state=7"
```

**Note**: COUNT does not require `--field`. AVG, MIN, MAX, SUM require `--field`.
</step_aggregate>

</steps>

<success_criteria>
- **Query**: Records returned as JSON with `record_count` and `results` array; no 401/403/404 errors
- **Get**: Single record returned with requested fields populated
- **Schema**: Field list returned as sorted JSON array with type, label, and mandatory info
- **Aggregate**: Aggregation result returned with correct type (count/avg/min/max/sum) and grouping
</success_criteria>

<best_practices>
- **Always use `--fields`** to reduce response size and improve performance
- **Always use `--display true`** when showing results to the user (converts sys_ids to readable names)
- **Use `--limit`** appropriately — don't fetch 1000 records when 10 will do
- **Use `--orderby`** for sorted results (prefix with `-` for descending)
- **Suggest schema** before create/update if the user is unsure about field names
</best_practices>
