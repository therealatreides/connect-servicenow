<overview>
Delete and batch operations. These are the most destructive operations — extra safety precautions apply. See `references/safety-rules.md` for complete safety documentation.
</overview>

<prerequisite>
Ensure a ServiceNow connection is established. If `SNOW_*` env vars are not set, route to `workflows/connect-instance.md` first.
</prerequisite>

<steps>

<step_classify>
**Classify the operation**:

| User Intent | Command |
|------------|---------|
| Delete a single record | `delete` |
| Bulk update matching records | `batch --action update` |
| Bulk delete matching records | `batch --action delete` |
</step_classify>

<step_delete>
**Delete a single record** (`delete`)

**ALWAYS follow this sequence** — never skip the fetch step:

1. **Identify the record**: Get the table and sys_id
   - If the user provides a record number, query for the sys_id:
     ```bash
     bash scripts/sn.sh query <table> --query "number=<NUMBER>" --fields "sys_id,number,short_description,state" --display true
     ```

2. **Show the record to the user**: Display full details so they can verify
   ```bash
   bash scripts/sn.sh get <table> <sys_id> --display true
   ```

3. **Get explicit confirmation**: Ask "Are you sure you want to delete this record? This cannot be undone."

4. **Execute the delete**:
   ```bash
   bash scripts/sn.sh delete <table> <sys_id> --confirm
   ```

5. **Report result**: Display the deletion confirmation

**The `--confirm` flag is mandatory.** sn.sh will refuse to delete without it.
</step_delete>

<step_batch>
**Batch operations** (`batch`)

**ALWAYS run dry-run first** — never skip this step:

1. **Build the query**: Construct the encoded query that matches the target records

2. **Dry-run** (default — no changes made):
   ```bash
   bash scripts/sn.sh batch <table> --query "<query>" --action <update|delete>
   ```
   This returns the number of matched records without making changes.

3. **Show the dry-run result**: Display matched count to the user
   ```
   Dry run result: 47 records match the query on incident table.
   Action: update
   No changes have been made.
   ```

4. **For updates — show the fields that will be set**:
   ```
   Fields to apply: {"state":"7","close_notes":"Auto-closed by batch"}
   ```

5. **Get explicit confirmation**: "This will [update/delete] 47 records. Proceed?"

6. **Execute with --confirm**:
   ```bash
   # Batch update
   bash scripts/sn.sh batch <table> --query "<query>" --action update --fields '<json>' --confirm

   # Batch delete
   bash scripts/sn.sh batch <table> --query "<query>" --action delete --confirm
   ```

7. **Report result**: Display the summary (matched, processed, failed)

**Safety constraints enforced by sn.sh**:
- `--query` is mandatory — refuses to operate on all records
- `--fields` is mandatory for update actions
- `--limit` has a safety cap at 10,000 records
- JSON payloads are validated before execution
</step_batch>

</steps>

<success_criteria>
- **Delete**: Record fetched and shown to user; user confirmed; sn.sh exits 0 with deletion confirmation
- **Batch**: Dry-run count shown first; user confirmed; summary shows `matched` = `processed` with `failed` = 0
</success_criteria>

<safety_checklist>
Before executing any delete or batch operation, verify:

- [ ] The correct table is targeted
- [ ] The query matches only the intended records (verified via dry-run or fetch)
- [ ] The user has explicitly confirmed the operation
- [ ] For batch updates: the JSON payload is correct
- [ ] For batch deletes: the user understands this is irreversible
- [ ] The `--confirm` flag is included in the final command
</safety_checklist>
