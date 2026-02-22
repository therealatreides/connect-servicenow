<overview>
Common CMDB (Configuration Management Database) operations using the connect-servicenow skill.
</overview>

<query_patterns>

<example name="list_servers_by_os">
```bash
bash scripts/sn.sh query cmdb_ci_server \
  --query "osLIKELinux^operational_status=1" \
  --fields "name,os,os_version,ip_address,environment,cpu_count,ram" \
  --display true \
  --limit 50
```
</example>

<example name="find_servers_in_environment">
```bash
bash scripts/sn.sh query cmdb_ci_server \
  --query "environment=Production^operational_status=1" \
  --fields "name,os,ip_address,cpu_count,ram,classification" \
  --display true
```
</example>

<example name="list_database_instances">
```bash
bash scripts/sn.sh query cmdb_ci_db_instance \
  --query "operational_status=1" \
  --fields "name,type,version,port,ip_address,environment" \
  --display true
```
</example>

<example name="find_cis_by_name_pattern">
```bash
bash scripts/sn.sh query cmdb_ci \
  --query "nameLIKEweb-prod^operational_status=1" \
  --fields "name,sys_class_name,operational_status,environment,ip_address" \
  --display true
```
</example>

<example name="list_business_services">
```bash
bash scripts/sn.sh query cmdb_ci_service \
  --query "operational_status=1" \
  --fields "name,operational_status,business_criticality,owned_by" \
  --display true
```
</example>

<example name="find_ci_relationships">
```bash
bash scripts/sn.sh query cmdb_rel_ci \
  --query "parent=<parent_sys_id>" \
  --fields "parent,child,type" \
  --display true
```
</example>

</query_patterns>

<aggregate_patterns>

<example name="count_servers_by_os">
```bash
bash scripts/sn.sh aggregate cmdb_ci_server \
  --type COUNT \
  --query "operational_status=1" \
  --group-by "os" \
  --display true
```
</example>

<example name="count_cis_by_environment">
```bash
bash scripts/sn.sh aggregate cmdb_ci \
  --type COUNT \
  --query "operational_status=1" \
  --group-by "environment" \
  --display true
```
</example>

<example name="count_cis_by_class">
```bash
bash scripts/sn.sh aggregate cmdb_ci \
  --type COUNT \
  --query "operational_status=1" \
  --group-by "sys_class_name" \
  --display true
```
</example>

</aggregate_patterns>

<schema_patterns>

<example name="discover_cmdb_table_schema">
```bash
# Full schema
bash scripts/sn.sh schema cmdb_ci_server

# Just field names
bash scripts/sn.sh schema cmdb_ci_server --fields-only
```
</example>

<example name="find_tables_extending_cmdb_ci">
```bash
bash scripts/sn.sh query sys_db_object \
  --query "super_class.name=cmdb_ci" \
  --fields "name,label" \
  --display true \
  --limit 100
```
</example>

</schema_patterns>

<update_patterns>

<example name="update_server_attributes">
```bash
bash scripts/sn.sh update cmdb_ci_server <sys_id> '{
  "os_version": "Ubuntu 22.04.3 LTS",
  "cpu_count": "8",
  "ram": "16384"
}'
```
</example>

<example name="mark_ci_as_retired">
```bash
bash scripts/sn.sh update cmdb_ci <sys_id> '{
  "operational_status": "6",
  "install_status": "7"
}'
```
</example>

<example name="update_ci_environment">
```bash
bash scripts/sn.sh update cmdb_ci_server <sys_id> '{
  "environment": "Production"
}'
```
</example>

</update_patterns>

<batch_patterns>

<example name="bulk_update_environment">
```bash
# Dry run
bash scripts/sn.sh batch cmdb_ci_server \
  --query "nameLIKEstaging-^environment=Development" \
  --action update

# Execute
bash scripts/sn.sh batch cmdb_ci_server \
  --query "nameLIKEstaging-^environment=Development" \
  --action update \
  --fields '{"environment":"Staging"}' \
  --confirm
```
</example>

</batch_patterns>

<operational_status_values>
**CI operational status values**:

| Value | Label |
|-------|-------|
| 1 | Operational |
| 2 | Non-Operational |
| 3 | Repair in Progress |
| 4 | DR Standby |
| 5 | Ready |
| 6 | Retired |

**Install status values**:

| Value | Label |
|-------|-------|
| 1 | Installed |
| 2 | In Maintenance |
| 3 | Pending Install |
| 6 | In Stock |
| 7 | Retired |
| 8 | Stolen |
</operational_status_values>
