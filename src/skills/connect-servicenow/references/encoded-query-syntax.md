<overview>
ServiceNow encoded query syntax reference. Encoded queries are the filter language used in `sysparm_query` parameters across the Table API and Stats API. The `sn.sh` script accepts these via the `--query` option.
</overview>

<operators>

<logical_operators>
**Logical operators** (combine conditions):

| Operator | Syntax | Example |
|----------|--------|---------|
| AND | `^` | `active=true^priority=1` |
| OR | `^OR` | `active=true^ORpriority=1` |
| NEW QUERY | `^NQ` | `active=true^NQstate=6` (union of two queries) |

**Evaluation order**: AND (`^`) binds tighter than OR (`^OR`). Use `^NQ` for complex union queries.
</logical_operators>

<comparison_operators>
**Comparison operators**:

| Operator | Syntax | Example | Description |
|----------|--------|---------|-------------|
| Equals | `=` | `state=1` | Exact match |
| Not equals | `!=` | `state!=7` | Not equal |
| Greater than | `>` | `priority>2` | Greater than |
| Greater or equal | `>=` | `sys_created_on>=javascript:gs.daysAgo(30)` | Greater or equal |
| Less than | `<` | `priority<3` | Less than |
| Less or equal | `<=` | `sys_updated_on<=javascript:gs.endOfLastMonth()` | Less or equal |

</comparison_operators>

<string_operators>
**String operators**:

| Operator | Syntax | Example | Description |
|----------|--------|---------|-------------|
| Contains | `LIKE` | `short_descriptionLIKEserver` | Case-insensitive contains |
| Does not contain | `NOT LIKE` | `short_descriptionNOT LIKEtest` | Does not contain |
| Starts with | `STARTSWITH` | `numberSTARTSWITHINC` | Starts with string |
| Ends with | `ENDSWITH` | `numberENDSWITH001` | Ends with string |

</string_operators>

<set_operators>
**Set operators**:

| Operator | Syntax | Example | Description |
|----------|--------|---------|-------------|
| In list | `IN` | `stateIN1,2,3` | Value in comma-separated list |
| Not in list | `NOT IN` | `stateNOT IN6,7` | Value not in list |
| Is empty | `ISEMPTY` | `assigned_toISEMPTY` | Field is null/empty |
| Is not empty | `ISNOTEMPTY` | `assigned_toISNOTEMPTY` | Field has a value |

</set_operators>

<reference_operators>
**Reference field operators** (dot-walking):

| Pattern | Example | Description |
|---------|---------|-------------|
| `field.subfield=value` | `caller_id.name=John Smith` | Walk through reference to compare |
| `field.subfield.subfield=value` | `assignment_group.manager.name=Jane` | Multi-level dot-walk |

Dot-walking works on any reference field and can traverse multiple levels.
</reference_operators>

<date_operators>
**Date/time operators** (use JavaScript functions):

| Pattern | Example | Description |
|---------|---------|-------------|
| Relative date | `sys_created_on>=javascript:gs.daysAgo(7)` | Created in last 7 days |
| Relative date | `sys_updated_on<javascript:gs.daysAgo(90)` | Updated more than 90 days ago |
| Minutes ago | `sys_created_on>=javascript:gs.minutesAgo(30)` | Created in last 30 minutes |
| Begin of day | `sys_created_on>=javascript:gs.beginningOfToday()` | Created today |
| Begin of month | `sys_created_on>=javascript:gs.beginningOfThisMonth()` | Created this month |
| Begin of year | `sys_created_on>=javascript:gs.beginningOfThisYear()` | Created this year |
| Absolute date | `sys_created_on>=2025-01-01` | Created after a specific date (static — replace as needed) |

</date_operators>

</operators>

<examples>
**Common query patterns**:

```bash
# Active P1 incidents
"active=true^priority=1"

# Open incidents assigned to a specific group
"active=true^assignment_group.name=Service Desk"

# Incidents created in the last 7 days
"sys_created_on>=javascript:gs.daysAgo(7)"

# Unassigned active incidents
"active=true^assigned_toISEMPTY"

# High-priority incidents containing "server" in short description
"priority<=2^short_descriptionLIKEserver"

# Incidents in specific states (New, In Progress, On Hold)
"stateIN1,2,3"

# Changes scheduled for the future
"start_date>javascript:gs.nowDateTime()^type=normal"

# CMDB servers running Linux
"osLIKELinux^operational_status=1"

# Knowledge articles in a specific category
"kb_category.label=Networking^workflow_state=published"
```
</examples>

<url_encoding_note>
**URL encoding**: The `sn.sh` script automatically URL-encodes query strings using `jq`:
```bash
jq -rn --arg v "$query" '$v | @uri'
```

You do NOT need to manually encode queries — pass them as plain text to the `--query` option. Special characters like `^`, `=`, `>`, `<` are encoded automatically.
</url_encoding_note>
