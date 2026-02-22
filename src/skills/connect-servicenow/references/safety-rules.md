<overview>
Safety rules for the connect-servicenow skill. These rules are enforced both in the `sn.sh` script (hard enforcement) and in workflow guidance (procedural enforcement).
</overview>

<delete_safety>
**Delete operations require the `--confirm` flag.**

The `--confirm` flag is MANDATORY for all single-record delete operations. The `sn.sh` script enforces this: if `--confirm` is not passed, the script exits with an error message.

```bash
# This FAILS (no --confirm):
bash scripts/sn.sh delete incident abc123def456
# ERROR: Must pass --confirm to delete records. This is a safety measure.

# This SUCCEEDS:
bash scripts/sn.sh delete incident abc123def456 --confirm
```

**Workflow guidance**: Before executing a delete, always fetch and display the record first so the user can verify they are deleting the correct record:
```bash
# Step 1: Show the record
bash scripts/sn.sh get incident abc123def456 --fields "number,short_description,state" --display true

# Step 2: Confirm with user

# Step 3: Delete
bash scripts/sn.sh delete incident abc123def456 --confirm
```
</delete_safety>

<batch_safety>
**Batch operations default to DRY-RUN mode.**

All batch operations (bulk update or delete) run in dry-run mode by default. This shows how many records match the query without making any changes.

```bash
# DRY RUN (default — no changes made):
bash scripts/sn.sh batch incident --query "state=6^sys_updated_on<javascript:gs.daysAgo(90)" --action update
# Output: {"action":"update","table":"incident","matched":47,"dry_run":true,"message":"Dry run — no changes made. Use --confirm to execute."}

# EXECUTE (requires --confirm):
bash scripts/sn.sh batch incident --query "state=6^sys_updated_on<javascript:gs.daysAgo(90)" --action update --fields '{"state":"7"}' --confirm
```

**Additional safety measures**:
- `--query` is MANDATORY — the script refuses to operate on all records without a filter
- `--limit` has a safety cap at 10,000 records — attempts to set higher are automatically capped
- `--fields` is required for update actions (prevents empty updates)
- JSON payloads are validated before execution

**Workflow guidance**: Always run dry-run first, show the matched count to the user, and get explicit confirmation before adding `--confirm`.
</batch_safety>

<json_validation>
**All JSON payloads are validated before submission.**

The `sn.sh` script validates JSON inputs using `jq` before sending them to the API:
```bash
echo "$json" | jq . >/dev/null 2>&1 || die "Invalid JSON: $json"
```

This catches:
- Syntax errors (missing brackets, commas, quotes)
- Malformed strings
- Invalid escape sequences

If validation fails, the script exits immediately without making any API call.
</json_validation>

<credential_safety>
**Credential handling rules** (see also `authentication.md`):

1. **No credential persistence unless user opts in via .env**
2. **OAuth tokens held in process memory only** — never written to disk
3. **Gitignore enforcement** for .env files in git repositories
4. **No credential logging** — sn.sh never echoes passwords or tokens to stdout/stderr
</credential_safety>

<retry_safety>
**Retry policy** (implemented in sn.sh `sn_curl()`):

| Error | Retries | Delay | Rationale |
|-------|---------|-------|-----------|
| 5xx (server error) | Up to 2 | 2 seconds | Transient server issues |
| 429 (rate limit) | Up to 2 | 5 seconds | Rate limiting |
| 401 (OAuth) | Up to 2 | Immediate | Token refresh attempt |
| 401 (Basic) | 0 | — | Invalid credentials — no retry |
| 400, 403, 404 | 0 | — | Client error — no retry |
| 000 (connection failure) | Up to 2 | 2s exponential (2s, 4s) | PDI hibernation or transient network issue |

Max retries configurable via `SNOW_MAX_RETRIES` env var (default: 3 attempts).
After exhausting retries, the script exits with a descriptive error message.
</retry_safety>

<mutation_awareness>
**This skill executes real API mutations.**

Unlike some other ServiceNow skills (which mark mutations as `[MANUAL]` tasks), the connect-servicenow skill directly executes POST, PATCH, and DELETE operations when requested.

Safety is provided through:
1. **Confirmation flags** (`--confirm` for delete and batch)
2. **Dry-run defaults** (batch operations)
3. **JSON validation** (create and update)
4. **Workflow guidance** (show record before delete, dry-run before batch)
5. **User confirmation prompts** in workflows before any mutation

**When in doubt, ask the user before executing a mutation.**
</mutation_awareness>
