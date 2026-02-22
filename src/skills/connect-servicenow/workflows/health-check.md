<overview>
Monitor ServiceNow instance health. Checks version, cluster nodes, scheduled jobs, semaphores, and quick ITSM statistics.
</overview>

<prerequisite>
Ensure a ServiceNow connection is established. If `SNOW_*` env vars are not set AND the user is not already in a connection flow, route to `workflows/connect-instance.md` first.
</prerequisite>

<steps>

<step_classify>
**Classify the health check request**:

| User Intent | Check Type | Command |
|------------|------------|---------|
| Full health check | all (default) | `health` |
| Instance version/build | version | `health --check version` |
| Cluster node status | nodes | `health --check nodes` |
| Stuck scheduled jobs | jobs | `health --check jobs` |
| Active semaphores/locks | semaphores | `health --check semaphores` |
| Quick ITSM dashboard | stats | `health --check stats` |
</step_classify>

<step_execute>
**Run the health check**:

```bash
# Full health check (all dimensions)
bash scripts/sn.sh health

# Specific check
bash scripts/sn.sh health --check <version|nodes|jobs|semaphores|stats>
```
</step_execute>

<step_interpret>
**Interpret the results**:

<check name="version">
- Shows instance build version, build date, and build tag
- Useful for confirming which ServiceNow release is running (e.g., Washington DC, Xanadu, Zurich)
</check>

<check name="nodes">
- Lists cluster nodes with their status (online/offline)
- **Action if node offline**: May indicate maintenance or an issue — check with ServiceNow admin
</check>

<check name="jobs">
- Shows stuck/overdue scheduled jobs (state=ready but next_action > 30 minutes past)
- **stuck: 0** — healthy, no stuck jobs
- **stuck > 0** — investigate the listed jobs; they may need manual restart
- Common stuck jobs: discovery, CMDB health, mid-server sync
</check>

<check name="semaphores">
- Shows active semaphores (potential locks)
- **active: 0-2** — normal
- **active > 5** — investigate; may indicate locking issues or runaway processes
</check>

<check name="stats">
- Quick dashboard: active incidents, open P1s, active changes, open problems
- Useful for a quick pulse check on the instance
</check>

</step_interpret>

</steps>

<success_criteria>
- Health check command exits 0 with JSON output containing the requested check dimensions (version/nodes/jobs/semaphores/stats)
</success_criteria>

<follow_up>
After reviewing health results, common follow-up actions:

- **Stuck jobs found**: Query sys_trigger for details:
  ```bash
  bash scripts/sn.sh query sys_trigger --query "state=0^next_action<javascript:gs.minutesAgo(30)" --fields "name,next_action,state" --display true
  ```

- **High P1 count**: Drill into P1 incidents:
  ```bash
  bash scripts/sn.sh query incident --query "active=true^priority=1" --fields "number,short_description,assigned_to,sys_created_on" --display true
  ```

- **Offline nodes**: Check cluster state details:
  ```bash
  bash scripts/sn.sh query sys_cluster_state --query "status!=online" --display true
  ```
</follow_up>
