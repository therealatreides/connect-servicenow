<overview>
Common change request management patterns using the connect-servicenow skill.
</overview>

<query_patterns>

<example name="list_scheduled_changes">
```bash
bash scripts/sn.sh query change_request \
  --query "start_date>javascript:gs.nowDateTime()^active=true" \
  --fields "number,short_description,type,risk,start_date,end_date,assignment_group" \
  --display true \
  --orderby "start_date"
```
</example>

<example name="find_open_emergency_changes">
```bash
bash scripts/sn.sh query change_request \
  --query "active=true^type=emergency" \
  --fields "number,short_description,state,risk,assigned_to,start_date" \
  --display true
```
</example>

<example name="changes_in_specific_window">
```bash
bash scripts/sn.sh query change_request \
  --query "start_date>=javascript:gs.beginningOfLastMonth()^end_date<=javascript:gs.endOfLastMonth()" \
  --fields "number,short_description,type,state,start_date,end_date" \
  --display true \
  --orderby "start_date"
```
</example>

<example name="changes_pending_approval">
```bash
bash scripts/sn.sh query change_request \
  --query "approval=requested^active=true" \
  --fields "number,short_description,type,risk,requested_by" \
  --display true
```
</example>

</query_patterns>

<aggregate_patterns>

<example name="count_changes_by_type">
```bash
bash scripts/sn.sh aggregate change_request \
  --type COUNT \
  --query "sys_created_on>=javascript:gs.beginningOfThisMonth()" \
  --group-by "type" \
  --display true
```
</example>

<example name="count_changes_by_risk">
```bash
bash scripts/sn.sh aggregate change_request \
  --type COUNT \
  --query "active=true" \
  --group-by "risk" \
  --display true
```
</example>

</aggregate_patterns>

<create_patterns>

<example name="create_normal_change">
```bash
bash scripts/sn.sh create change_request '{
  "short_description": "Upgrade web server to latest version",
  "description": "Upgrade Apache web servers from 2.4.52 to 2.4.58 to address security vulnerabilities",
  "type": "normal",
  "risk": "moderate",
  "impact": "3",
  "assignment_group": "Web Infrastructure",
  "start_date": "YYYY-MM-DD 02:00:00",
  "end_date": "YYYY-MM-DD 04:00:00",
  "justification": "CVE-YYYY-XXXX patching required by security policy",
  "implementation_plan": "1. Take server out of load balancer\n2. Stop Apache\n3. Apply upgrade\n4. Verify configuration\n5. Start Apache\n6. Return to load balancer",
  "backout_plan": "1. Stop Apache\n2. Restore from pre-upgrade snapshot\n3. Start Apache\n4. Return to load balancer",
  "test_plan": "1. Verify service responds on port 443\n2. Run automated test suite\n3. Verify no errors in access log"
}'
```

**Replace placeholders**: `YYYY-MM-DD` dates and `CVE-YYYY-XXXX` must be replaced with actual values before execution.
</example>

<example name="create_emergency_change">
```bash
bash scripts/sn.sh create change_request '{
  "short_description": "Emergency patch for critical security vulnerability",
  "description": "Applying emergency patch for actively exploited vulnerability",
  "type": "emergency",
  "risk": "high",
  "impact": "1",
  "assignment_group": "Security Operations",
  "justification": "Active exploitation detected in the wild"
}'
```
</example>

</create_patterns>

<update_patterns>

<example name="move_change_to_implementation">
```bash
bash scripts/sn.sh update change_request <sys_id> '{
  "state": "-1"
}'
```
</example>

<example name="complete_change_successful">
```bash
bash scripts/sn.sh update change_request <sys_id> '{
  "state": "3",
  "close_code": "successful",
  "close_notes": "All changes applied successfully. Verified in production."
}'
```
</example>

<example name="complete_change_unsuccessful">
```bash
bash scripts/sn.sh update change_request <sys_id> '{
  "state": "3",
  "close_code": "unsuccessful",
  "close_notes": "Backout plan executed due to test failures after upgrade."
}'
```
</example>

</update_patterns>

<change_states>
**Change request state values**:

| Value | Label |
|-------|-------|
| -5 | New |
| -4 | Assess |
| -3 | Authorize |
| -2 | Scheduled |
| -1 | Implement |
| 0 | Review |
| 3 | Closed |
| 4 | Canceled |

**Change types**: normal, standard, emergency
**Risk levels**: high, moderate, low
</change_states>
