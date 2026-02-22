<overview>
Common incident management patterns using the connect-servicenow skill. All examples use `scripts/sn.sh` commands.
</overview>

<query_patterns>

<example name="list_open_p1_incidents">
```bash
bash scripts/sn.sh query incident \
  --query "active=true^priority=1" \
  --fields "number,short_description,state,assigned_to,assignment_group,sys_created_on" \
  --display true \
  --orderby "-sys_created_on" \
  --limit 20
```
</example>

<example name="find_unassigned_active_incidents">
```bash
bash scripts/sn.sh query incident \
  --query "active=true^assigned_toISEMPTY" \
  --fields "number,short_description,priority,assignment_group,sys_created_on" \
  --display true \
  --limit 20
```
</example>

<example name="search_incidents_by_keyword">
```bash
bash scripts/sn.sh query incident \
  --query "short_descriptionLIKEserver^active=true" \
  --fields "number,short_description,state,priority" \
  --display true
```
</example>

<example name="incidents_created_last_7_days">
```bash
bash scripts/sn.sh query incident \
  --query "sys_created_on>=javascript:gs.daysAgo(7)" \
  --fields "number,short_description,state,priority,assigned_to" \
  --display true \
  --orderby "-sys_created_on"
```
</example>

<example name="incidents_assigned_to_group">
```bash
bash scripts/sn.sh query incident \
  --query "active=true^assignment_group.name=Service Desk" \
  --fields "number,short_description,state,priority,assigned_to" \
  --display true
```
</example>

</query_patterns>

<aggregate_patterns>

<example name="count_open_incidents_by_priority">
```bash
bash scripts/sn.sh aggregate incident \
  --type COUNT \
  --query "active=true" \
  --group-by "priority" \
  --display true
```
</example>

<example name="count_incidents_by_state">
```bash
bash scripts/sn.sh aggregate incident \
  --type COUNT \
  --query "sys_created_on>=javascript:gs.beginningOfThisMonth()" \
  --group-by "state" \
  --display true
```
</example>

<example name="average_reassignment_count">
```bash
bash scripts/sn.sh aggregate incident \
  --type AVG \
  --field "reassignment_count" \
  --query "state=7"
```
</example>

</aggregate_patterns>

<create_patterns>

<example name="create_new_incident">
```bash
bash scripts/sn.sh create incident '{
  "short_description": "Email server unresponsive",
  "description": "Users reporting inability to send or receive emails since 10:00 AM",
  "urgency": "1",
  "impact": "2",
  "assignment_group": "Email Support",
  "category": "Software",
  "subcategory": "Email"
}'
```
</example>

<example name="create_p1_incident">
```bash
bash scripts/sn.sh create incident '{
  "short_description": "Production database down",
  "description": "The production Oracle database is not responding to connections",
  "urgency": "1",
  "impact": "1",
  "assignment_group": "Database Team",
  "category": "Hardware",
  "subcategory": "Server"
}'
```
</example>

</create_patterns>

<update_patterns>

<example name="assign_incident">
```bash
bash scripts/sn.sh update incident <sys_id> '{
  "assigned_to": "john.smith",
  "state": "2"
}'
```
</example>

<example name="add_work_notes">
```bash
bash scripts/sn.sh update incident <sys_id> '{
  "work_notes": "Investigated the issue. Root cause is a misconfigured firewall rule."
}'
```
</example>

<example name="resolve_incident">
```bash
bash scripts/sn.sh update incident <sys_id> '{
  "state": "6",
  "close_code": "Solved (Permanently)",
  "close_notes": "Restarted the email service and applied the latest patch."
}'
```
</example>

<example name="close_incident">
```bash
bash scripts/sn.sh update incident <sys_id> '{
  "state": "7"
}'
```
</example>

</update_patterns>

<batch_patterns>

<example name="bulk_close_old_resolved_incidents">
```bash
# Step 1: Dry run — see how many match
bash scripts/sn.sh batch incident \
  --query "state=6^sys_updated_on<javascript:gs.daysAgo(90)" \
  --action update

# Step 2: Execute (after confirmation)
bash scripts/sn.sh batch incident \
  --query "state=6^sys_updated_on<javascript:gs.daysAgo(90)" \
  --action update \
  --fields '{"state":"7","close_notes":"Auto-closed: resolved over 90 days"}' \
  --confirm
```
</example>

<example name="bulk_reassign_incidents">
```bash
# Dry run
bash scripts/sn.sh batch incident \
  --query "active=true^assignment_group.name=Old Team" \
  --action update

# Execute
bash scripts/sn.sh batch incident \
  --query "active=true^assignment_group.name=Old Team" \
  --action update \
  --fields '{"assignment_group":"New Team"}' \
  --confirm
```
</example>

</batch_patterns>

<incident_states>
**Incident state values**:

| Value | Label |
|-------|-------|
| 1 | New |
| 2 | In Progress |
| 3 | On Hold |
| 6 | Resolved |
| 7 | Closed |
| 8 | Canceled |
</incident_states>
