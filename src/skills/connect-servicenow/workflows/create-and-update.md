<overview>
Create and update records on ServiceNow tables. These are mutation operations (POST/PATCH) — always confirm with the user before executing.
</overview>

<prerequisite>
Ensure a ServiceNow connection is established. If `SNOW_*` env vars are not set, route to `workflows/connect-instance.md` first.
</prerequisite>

<steps>

<step_classify>
**Identify the operation**:

| User Intent | Command |
|------------|---------|
| Create a new record | `create` |
| Update an existing record | `update` |
</step_classify>

<step_create>
**Create a record** (`create`)

1. **Identify the table**: Determine the target table from the user's request
2. **Check schema** (recommended): If unsure about field names or required fields:
   ```bash
   bash scripts/sn.sh schema <table>
   ```
3. **Build JSON payload**: Construct the field values as JSON
4. **Show the command to the user**: Display the exact command and JSON before executing
5. **Get user confirmation**: Wait for explicit approval
6. **Execute**:
   ```bash
   bash scripts/sn.sh create <table> '<json>'
   ```
7. **Show result**: Display the sys_id and number of the created record

**Example flow**:
```
I'll create an incident with these details:

Table: incident
Fields:
  - short_description: "Email server unresponsive"
  - urgency: "1"
  - impact: "2"
  - assignment_group: "Email Support"
  - description: "The email server has been unresponsive since 10:00 AM"

Command:
bash scripts/sn.sh create incident '{"short_description":"Email server unresponsive","urgency":"1","impact":"2","assignment_group":"Email Support","description":"The email server has been unresponsive since 10:00 AM"}'

Shall I proceed?
```
</step_create>

<step_update>
**Update a record** (`update`)

1. **Identify the record**: Get the table and sys_id
   - If the user provides a record number (e.g., INC0012345), query for the sys_id first:
     ```bash
     bash scripts/sn.sh query incident --query "number=INC0012345" --fields "sys_id,number,short_description,state"
     ```
2. **Show current state**: Display the record's current values for the fields being changed
3. **Build JSON payload**: Only include the fields being updated (PATCH semantics)
4. **Show the command to the user**: Display the exact command before executing
5. **Get user confirmation**: Wait for explicit approval
6. **Execute**:
   ```bash
   bash scripts/sn.sh update <table> <sys_id> '<json>'
   ```
7. **Show result**: Display the updated record

**Example flow**:
```
Current record INC0012345:
  - state: "New"
  - assigned_to: ""
  - priority: "3"

I'll update with these changes:
  - state: "2" (In Progress)
  - assigned_to: "john.smith"

Command:
bash scripts/sn.sh update incident abc123def456 '{"state":"2","assigned_to":"john.smith"}'

Shall I proceed?
```
</step_update>

</steps>

<success_criteria>
- **Create**: User confirmed command before execution; sn.sh exits 0; sys_id and number of created record displayed
- **Update**: User confirmed command before execution; sn.sh exits 0; updated field values confirmed in response
</success_criteria>

<safety_reminders>
- **Always show the command before executing** — let the user verify the payload
- **JSON must be valid** — sn.sh validates JSON before submission; invalid JSON causes an abort
- **Only include changed fields** in update payloads — PATCH semantics update only specified fields
- **Use schema to verify field names** — incorrect field names are silently ignored by ServiceNow
- **Reference fields** accept either sys_id or display value depending on the field configuration
</safety_reminders>
