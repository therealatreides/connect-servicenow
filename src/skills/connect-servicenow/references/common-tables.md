<overview>
Common ServiceNow tables for use with the connect-servicenow skill. All tables are accessible via the Table API (`/api/now/table/{table_name}`).
</overview>

<itsm_tables>
**IT Service Management (ITSM)**:

| Table | Description | Key Fields |
|-------|-------------|------------|
| `incident` | Incidents | number, short_description, state, priority, assigned_to, assignment_group, caller_id |
| `change_request` | Change Requests | number, short_description, state, type, risk, start_date, end_date, assignment_group |
| `problem` | Problems | number, short_description, state, priority, assigned_to, known_error |
| `sc_request` | Service Requests | number, requested_for, stage, approval |
| `sc_req_item` | Requested Items (RITMs) | number, short_description, state, cat_item, requested_for |
| `sc_task` | Catalog Tasks | number, short_description, state, request_item, assigned_to |
| `task` | Tasks (parent table) | number, short_description, state, assigned_to, assignment_group |
| `sla_task_sla` | Task SLAs | task, sla, stage, start_time, end_time, business_percentage |

</itsm_tables>

<cmdb_tables>
**Configuration Management Database (CMDB)**:

| Table | Description | Key Fields |
|-------|-------------|------------|
| `cmdb_ci` | Configuration Items (base) | name, sys_class_name, operational_status, environment |
| `cmdb_ci_server` | Servers | name, os, ip_address, cpu_count, ram, environment |
| `cmdb_ci_win_server` | Windows Servers | name, os, os_version, ip_address |
| `cmdb_ci_linux_server` | Linux Servers | name, os, os_version, ip_address |
| `cmdb_ci_app_server` | Application Servers | name, running_process, ip_address |
| `cmdb_ci_db_instance` | Database Instances | name, type, version, port |
| `cmdb_ci_service` | Business Services | name, operational_status, business_criticality |
| `cmdb_ci_computer` | Computers | name, os, serial_number, model_id |
| `cmdb_ci_network_gear` | Network Devices | name, ip_address, firmware_version |
| `cmdb_rel_ci` | CI Relationships | parent, child, type |

</cmdb_tables>

<user_tables>
**User and Group Management**:

| Table | Description | Key Fields |
|-------|-------------|------------|
| `sys_user` | Users | user_name, first_name, last_name, email, active, department |
| `sys_user_group` | Groups | name, description, manager, email, active |
| `sys_user_grmember` | Group Membership | user, group |
| `sys_user_role` | User Roles | user, role |
| `core_company` | Companies | name, street, city, state, country |
| `cmn_department` | Departments | name, head, company, parent |
| `cmn_location` | Locations | name, street, city, state, country |

</user_tables>

<knowledge_tables>
**Knowledge Management**:

| Table | Description | Key Fields |
|-------|-------------|------------|
| `kb_knowledge` | Knowledge Articles | number, short_description, text, workflow_state, kb_category |
| `kb_knowledge_base` | Knowledge Bases | title, description, active |
| `kb_category` | KB Categories | label, parent_id, knowledge_base |

</knowledge_tables>

<system_tables>
**System and Administration**:

| Table | Description | Key Fields |
|-------|-------------|------------|
| `sys_properties` | System Properties | name, value, description |
| `sys_dictionary` | Table/Field Definitions | name, element, internal_type, max_length, mandatory |
| `sys_choice` | Choice List Values | name, element, value, label, sequence |
| `sys_db_object` | Table Definitions | name, label, super_class |
| `sys_script` | Business Rules | name, table, when, active, script |
| `sys_script_include` | Script Includes | name, api_name, active, script |
| `sys_ui_policy` | UI Policies | short_description, table, active |
| `sys_ui_action` | UI Actions | name, table, active, script |
| `sys_update_set` | Update Sets | name, state, application, description |
| `sys_attachment` | Attachments | table_name, table_sys_id, file_name, size_bytes, content_type |
| `sys_cluster_state` | Cluster Nodes | node_id, status, system_id |
| `sys_trigger` | Scheduled Jobs | name, next_action, state, trigger_type |
| `sys_semaphore` | Semaphores/Locks | name, state, holder |

</system_tables>

<agile_tables>
**Agile Development**:

| Table | Description | Key Fields |
|-------|-------------|------------|
| `rm_story` | Stories | number, short_description, state, story_points, epic, sprint |
| `rm_epic` | Epics | number, short_description, state, product |
| `rm_scrum_task` | Scrum Tasks | number, short_description, state, story, assigned_to |
| `rm_sprint` | Sprints | name, start_date, end_date, state |
| `rm_release` | Releases | name, start_date, end_date, state |

</agile_tables>

<discovery_tip>
**Discovering tables dynamically**: Use the schema command to introspect any table:
```bash
bash scripts/sn.sh schema <table_name>
bash scripts/sn.sh schema <table_name> --fields-only
```

To find all tables extending a base table:
```bash
bash scripts/sn.sh query sys_db_object --query "super_class.name=<parent_table>" --fields "name,label"
```
</discovery_tip>
