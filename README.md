# ServiceNow Connector for Claude Code

**By [Scott Royalty](https://onlyflows.tech) / [OnlyFlows](https://onlyflows.tech)**

> Connect Claude Code to any ServiceNow instance — full CRUD, analytics, schema introspection, attachment management, batch operations, and health monitoring via REST API.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![GitHub](https://img.shields.io/badge/GitHub-therealatreides-black?logo=github)](https://github.com/therealatreides/Claude-Code-ServiceNow-Connector)

---

## What It Does

The ServiceNow Connector is a **Claude Code skill** that gives your AI agent native access to **any ServiceNow instance** through a bash CLI (`scripts/sn.sh`). Unlike documentation-only skills, this one makes real API calls — querying tables, creating records, running aggregations, managing attachments, and more.

Ask questions in natural language and Claude translates them into precise ServiceNow REST API calls. Whether you're triaging incidents at 2 AM, auditing CMDB accuracy, or building change request dashboards, this skill turns Claude into a ServiceNow power user.

**Supports three authentication strategies:** Basic Auth, OAuth ROPC, and OAuth Client Credentials.

---

## Features

| Command | Description |
|---------|-------------|
| **query** | Query any table with encoded queries, field selection, pagination, and sorting |
| **get** | Retrieve a single record by sys_id with display value support |
| **create** | Create records on any table with JSON field payloads |
| **update** | Update records via PATCH with partial field updates |
| **delete** | Delete records with mandatory `--confirm` safety flag |
| **aggregate** | Run COUNT, AVG, MIN, MAX, SUM with group-by support |
| **schema** | Introspect table schemas — field types, lengths, references, mandatory flags |
| **attach** | List, upload, and download file attachments on any record |
| **batch** | Bulk update or delete records with dry-run safety, query filters, and progress tracking |
| **health** | Instance health dashboard — version, cluster nodes, stuck jobs, semaphores, and quick stats |

---

## Prerequisites

- **Claude Code** — [Anthropic's CLI for Claude](https://docs.anthropic.com/en/docs/claude-code)
- **bash**, **curl**, and **jq** must be available on your system
- A ServiceNow instance with REST API access enabled
- A ServiceNow user account with appropriate table permissions
- If using OAuth tokens, proper inbound client id/secrets

---

## Installation

Clone the repository into your Claude Code skills directory:

```bash
git clone https://github.com/therealatreides/Claude-Code-ServiceNow-Connector.git \
  ~/.claude/skills/connect-servicenow
```

Or add it as a skill path in your Claude Code configuration.

---

## Configuration

### Quick Start

1. Copy the environment template and fill in your credentials:

   ```bash
   cp ~/.claude/skills/connect-servicenow/src/skills/connect-servicenow/.env-example .env
   ```

2. Edit `.env` with your ServiceNow credentials (see auth types below).

3. Test the connection:

   ```bash
   bash scripts/sn.sh health --check version
   ```

> **Important:** Never commit `.env` files. Ensure `.env` is in your `.gitignore`.

### Basic Auth

```env
SNOW_INSTANCE_URL=https://your-instance.service-now.com
SNOW_AUTH_TYPE=basic
SNOW_USERNAME=admin
SNOW_PASSWORD=your-password
```

### OAuth ROPC (Resource Owner Password Credentials)

```env
SNOW_INSTANCE_URL=https://your-instance.service-now.com
SNOW_AUTH_TYPE=oauth_ropc
SNOW_USERNAME=admin
SNOW_PASSWORD=your-password
SNOW_CLIENT_ID=your-client-id
SNOW_CLIENT_SECRET=your-client-secret
```

### OAuth Client Credentials (Recommended)

```env
SNOW_INSTANCE_URL=https://your-instance.service-now.com
SNOW_AUTH_TYPE=oauth_client_credentials
SNOW_CLIENT_ID=your-client-id
SNOW_CLIENT_SECRET=your-client-secret
```

### Named Instances

Connect to multiple instances by prefixing variables with an alias:

```env
SNOW_DEV_INSTANCE_URL=https://dev-instance.service-now.com
SNOW_DEV_AUTH_TYPE=basic
SNOW_DEV_USERNAME=admin
SNOW_DEV_PASSWORD=your-password

SNOW_PROD_INSTANCE_URL=https://prod-instance.service-now.com
SNOW_PROD_AUTH_TYPE=oauth_client_credentials
SNOW_PROD_CLIENT_ID=your-client-id
SNOW_PROD_CLIENT_SECRET=your-client-secret
```

> **Tip:** Use a dedicated integration user with least-privilege ACLs rather than an admin account.

---

## Usage Examples

Once configured, just ask Claude in natural language:

### Incident Management

> **"How many open P1 incidents do we have?"**
> Runs an aggregate COUNT on `incident` where `active=true^priority=1`

> **"Create an incident for the VPN outage affecting the Chicago office"**
> Creates a record on `incident` with the description and impact details

> **"Who submitted the most incidents this month?"**
> Queries `incident` with date filters and groups by caller

### Change Management

> **"Show me all changes scheduled for this week"**
> Queries `change_request` with date range filters on `start_date`

### CMDB & Schema Discovery

> **"What's the schema of the cmdb_ci_server table?"**
> Returns all fields, types, references, and mandatory flags

> **"List all Linux servers in the production environment"**
> Queries `cmdb_ci_server` with OS and environment filters

### Knowledge Management

> **"Find knowledge articles about password resets"**
> Searches `kb_knowledge` with description LIKE filters

### Bulk Operations

> **"Close all resolved incidents older than 90 days"**
> Runs `batch` on `incident` with state/date filters and update action (dry-run first)

> **"How many abandoned test records do we have?"**
> Dry-run batch delete to count matching records without changes

### Instance Health

> **"Is the instance healthy?"**
> Runs `health` with all checks — version, nodes, stuck jobs, semaphores, and stats

> **"Any stuck scheduled jobs?"**
> Runs `health --check jobs` to find overdue sys_trigger records

### Direct CLI Usage

```bash
# Query open P1 incidents
bash scripts/sn.sh query incident --query "active=true^priority=1" --fields "number,short_description,assigned_to" --limit 10

# Get a single record with display values
bash scripts/sn.sh get incident <sys_id> --display true

# Create a record
bash scripts/sn.sh create incident '{"short_description":"VPN outage","priority":"1","impact":"1"}'

# Aggregate count by priority
bash scripts/sn.sh aggregate incident --type COUNT --group-by priority --query "active=true"

# Check instance health
bash scripts/sn.sh health --check all
```

---

## Supported Tables

The skill works with **any** ServiceNow table, but here are the most common:

| Table | Description |
|-------|-------------|
| `incident` | Incident records |
| `change_request` | Change requests |
| `problem` | Problem records |
| `sc_req_item` | Requested Items (RITMs) |
| `sc_request` | Service requests |
| `sys_user` | User records |
| `sys_user_group` | Group records |
| `cmdb_ci` | Configuration Items (base) |
| `cmdb_ci_server` | Server CIs |
| `cmdb_ci_app_server` | Application Server CIs |
| `kb_knowledge` | Knowledge articles |
| `task` | Parent task table |
| `sys_choice` | Choice list values |
| `sla_condition` | SLA definitions |
| `change_task` | Change tasks |
| `incident_task` | Incident tasks |

---

## Encoded Query Cheat Sheet

ServiceNow uses encoded query syntax for filtering. Here's a quick reference:

| Operator | Syntax | Example |
|----------|--------|---------|
| Equals | `field=value` | `priority=1` |
| Not equals | `field!=value` | `state!=7` |
| Contains | `fieldLIKEvalue` | `short_descriptionLIKEserver` |
| Starts with | `fieldSTARTSWITHvalue` | `numberSTARTSWITHINC` |
| Greater than | `field>value` | `sys_created_on>2026-01-01` |
| Greater or equal | `field>=value` | `priority>=2` |
| Less than | `field<value` | `reassignment_count<3` |
| Is empty | `fieldISEMPTY` | `assigned_toISEMPTY` |
| Is not empty | `fieldISNOTEMPTY` | `resolution_codeISNOTEMPTY` |
| In list | `fieldINvalue1,value2` | `stateIN1,2,3` |
| AND | `^` | `active=true^priority=1` |
| OR | `^OR` | `priority=1^ORpriority=2` |
| Dot-walking | `ref.field=value` | `caller_id.department=IT` |
| Order by | `^ORDERBYfield` | `^ORDERBYsys_created_on` |
| Order descending | `^ORDERBYDESCfield` | `^ORDERBYDESCpriority` |

---

## Security & Safety

### Credential Safety

- **Zero hardcoded credentials** — all authentication via environment variables or `.env` file
- **No instance URLs stored** — `SNOW_INSTANCE_URL` is read from env at runtime
- **`.env` gitignore enforcement** — the skill verifies `.env` is gitignored before proceeding

### Operation Safety

- **Delete safety** — the `--confirm` flag is mandatory for all delete operations
- **Batch dry-run** — batch operations default to dry-run mode; requires `--confirm` to execute
- **Batch query required** — `--query` is mandatory for batch operations; refuses to operate on all records
- **Batch limit** — capped at 10,000 records per operation
- **JSON validation** — all create/update payloads are validated before submission
- **Mutation confirmation** — exact command and data shown to user before executing any create, update, or delete

### Retry Logic

- **Timeout/5xx errors** — retry up to 2 times with 2-second delay
- **Rate limiting (429)** — wait 5 seconds, retry up to 2 times
- **OAuth 401** — refresh token and retry up to 2 times
- **Basic Auth 401** — no retry (invalid credentials)
- **403/404/400** — no retry (client error)

---

## Project Structure

```
servicenow-connector/
├── README.md
├── README-Example.md
├── assets/                             # Support/donation images
└── src/
    └── skills/
        └── connect-servicenow/
            ├── SKILL.md                # Entry point — routing, tools, rules
            ├── CLAUDE.md               # Architecture and meta-guidance
            ├── .env-example            # Credential template
            ├── scripts/
            │   └── sn.sh              # Executable CLI — all 10 commands
            ├── references/
            │   ├── tool-reference.md   # Complete command syntax and examples
            │   ├── authentication.md   # Auth strategies (Basic, OAuth ROPC, OAuth CC)
            │   ├── oauth-patterns.md   # Token acquisition and refresh
            │   ├── env-file-format.md  # .env schema and validation
            │   ├── encoded-query-syntax.md  # Query operator reference
            │   ├── common-tables.md    # ITSM/CMDB/System table reference
            │   └── safety-rules.md     # Delete, batch, and mutation safety
            ├── workflows/
            │   ├── connect-instance.md # Auth flow and connection setup
            │   ├── query-and-read.md   # Query, get, schema, aggregate
            │   ├── create-and-update.md # Create and update records
            │   ├── delete-and-batch.md # Delete and batch operations
            │   ├── attachments.md      # List, upload, download files
            │   └── health-check.md     # Instance health monitoring
            └── patterns/
                ├── incident-management.md  # ITSM incident patterns
                ├── change-management.md    # Change request patterns
                └── cmdb-operations.md      # CMDB CI patterns
```

---

## Built By

**Scott Royalty** — ServiceNow Developer & AI Automation

- [OnlyFlows](https://onlyflows.tech) — ServiceNow tools, skills & AI automation

### Acknowledgments

The core CLI script (`sn.sh`) was adapted from **Brandon Wilson's** OpenClaw ServiceNow skill. Brandon is a ServiceNow Certified Technical Architect (CTA) and the original author of the ServiceNow REST API integration pattern that this project builds upon from his sn.sh script and previous work I had done in other skills.

---

## Support

If you find this project useful, consider supporting its development:

<table>
  <tr>
    <td align="center">
      <strong>CashApp</strong><br/>
      <img src="assets/cashapp_qr.png" alt="CashApp QR Code" width="200"/>
    </td>
    <td align="center">
      <strong>PayPal</strong><br/>
      <img src="assets/paypal_qr.png" alt="PayPal QR Code" width="200"/>
    </td>
  </tr>
</table>

---

## License

MIT License — see [LICENSE](LICENSE) for details.

Copyright &copy; 2026 Scott Royalty / OnlyFlows

---

## Contributing

Contributions welcome! Open an issue or PR at [github.com/therealatreides/Claude-Code-ServiceNow-Connector](https://github.com/therealatreides/Claude-Code-ServiceNow-Connector).

Ideas for contribution:

- Additional ServiceNow API support (CMDB API, Import Sets, Scripted REST)
- Additional OAuth flows or SSO integrations
- ServiceNow Flow Designer integration
- Additional domain patterns (Service Catalog, HR, ITOM)
- Test suite and CI/CD pipeline
