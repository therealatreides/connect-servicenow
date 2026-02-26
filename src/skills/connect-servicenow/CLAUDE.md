<overview>
Canonical ServiceNow REST API connection skill for Claude Code. Provides an executable bash CLI (`scripts/sn.sh`) with 10 commands for full CRUD, aggregation, schema introspection, attachment management, batch operations, and instance health monitoring. Unlike other ServiceNow skills (which are pure markdown guidance), this skill makes real API calls.
</overview>

<invocation>
The skill activates when the user needs to connect to or interact with a ServiceNow instance via REST API. Route through SKILL.md which classifies the request and loads the appropriate workflow.
</invocation>

<architecture>
```
User Request
    │
    ▼
SKILL.md — Classify request via <routing>
    │
    ├── Connection request → workflows/connect-instance.md
    ├── Query/Read request → workflows/query-and-read.md
    ├── Create/Update request → workflows/create-and-update.md
    ├── Delete/Batch request → workflows/delete-and-batch.md
    ├── Attachment request → workflows/attachments.md
    └── Health request → workflows/health-check.md
         │
         ▼
    Workflow sets SNOW_* env vars → calls scripts/sn.sh
         │
         ▼
    sn.sh handles auth (Basic/-u or OAuth/Bearer), retry logic, and API call
```
</architecture>

<authentication_architecture>

Three auth strategies supported (all handled by sn.sh):

1. **Basic Auth** — `-u username:password` on every request
2. **OAuth ROPC** — Token acquired at script start, refreshed on expiry
3. **OAuth Client Credentials** — Token acquired at script start, re-acquired on expiry

Credentials sourced from `.env` file (opt-in) or manual prompt (session-only). The `.env` format uses `SNOW_*` prefixes and supports multiple named instances. See `references/authentication.md`.

</authentication_architecture>

<directory_structure>

```
├── CLAUDE.md                    # This file — meta-guidance
├── SKILL.md                     # Entry point: principles, routing, tool reference
├── .env-example                 # Credential template (SNOW_* format)
├── scripts/
│   └── sn.sh                   # Executable CLI — all 10 commands
├── references/
│   ├── tool-reference.md       # Complete syntax for all 10 sn.sh commands
│   ├── authentication.md       # Primary auth reference (3 strategies)
│   ├── oauth-patterns.md       # Token acquisition, refresh, error handling
│   ├── env-file-format.md      # .env schema, parsing, validation
│   ├── encoded-query-syntax.md # Query operator reference
│   ├── common-tables.md        # ITSM/CMDB/System table reference
│   └── safety-rules.md         # Delete, batch, mutation safety
├── workflows/
│   ├── connect-instance.md     # Auth flow: .env → menu → test
│   ├── query-and-read.md       # query, get, schema, aggregate
│   ├── create-and-update.md    # create, update (with confirmation)
│   ├── delete-and-batch.md     # delete, batch (with safety emphasis)
│   ├── attachments.md          # attach list/upload/download
│   └── health-check.md         # Monitor instance health
└── patterns/
    ├── incident-management.md  # ITSM incident patterns
    ├── change-management.md    # Change request patterns
    └── cmdb-operations.md      # CMDB CI patterns
```

</directory_structure>

<safety_rules>
See SKILL.md `<safety>` for principles and `references/safety-rules.md` for complete rules.

Key enforcement points: delete requires `--confirm`, batch defaults to dry-run, JSON validated before submission, `.env` must be gitignored, show command before executing mutations.
</safety_rules>

<security_hardening>

Defenses built into `sn.sh`:

1. **HTTPS enforcement** — `http://` URLs are automatically upgraded to `https://`. Bare hostnames get `https://` prepended. Credentials are never sent over plaintext HTTP.
2. **Input validation** — Table names: `^[a-z0-9_]+$`. Sys_ids: `^[a-f0-9]{32}$`. Numbers: `^[0-9]+$`. All query parameters URI-encoded via `jq @uri`.
3. **API-returned data validation** — Parent table names from schema walk responses are validated against the same regex before use in URLs.
4. **Error message sanitization** — Invalid JSON payloads are not echoed in error messages to prevent leaking sensitive field values (e.g., passwords being set on user records).
5. **Token lifecycle** — OAuth tokens are cached in `.env` for cross-invocation reuse when `SNOW_ENV_FILE` and `SNOW_ENV_PREFIX` are provided (disable with `SNOW_TOKEN_CACHE=false`). When caching is disabled or env file is not provided, tokens are process-scoped and cleared on EXIT. `ensure_token` is called inside the batch processing loop to prevent mid-batch token expiry.
6. **Download path validation** — Attachment downloads verify the output directory exists before making the API call.
7. **No shell injection** — `set -euo pipefail` enforced. No `eval`, `exec`, or backtick expansion with user input. All inputs treated as data, never code.

</security_hardening>

<windows_compatibility>

**Windows / Git Bash notes** (applies when running `sn.sh` via Git Bash on Windows):

1. **CRLF in jq output**: On Windows, `jq` outputs `\r\n` line endings. The `jq_safe()` wrapper in `sn.sh` strips `\r` from all `jq -r` output to prevent corrupted URLs, Bearer tokens, and sys_ids. If adding new `jq -r` calls, always use `jq_safe` instead.

2. **Line endings for bash files**: All `.sh`, `.bash`, `.bats`, and `.env` files must use LF line endings. The root `.gitattributes` enforces this project-wide. If adding new file types that bash will consume, add them to `.gitattributes`.

3. **Debugging hidden characters**: If you suspect CRLF corruption, use:
   ```bash
   echo "$variable" | od -c          # shows \r, \n, \t
   echo "$variable" | cat -A         # shows $ at line end, ^M for \r
   ```

4. **Base64 values with trailing `=`**: When parsing `.env` values that contain `=` (like base64), never use `IFS='='` to split. Use parameter expansion instead: `name="${line%%=*}"` and `value="${line#*=}"`.

</windows_compatibility>

<common_workflows>

<git_workflow>
- Follow GitHub Flow (feature branches from main)
- Use Conventional Commits format:
  - `feat:` new feature
  - `fix:` bug fix
  - `docs:` documentation
  - `refactor:` code refactoring
  - `test:` adding tests
  - `chore:` maintenance
</git_workflow>

<testing>
- Framework: **BATS** (Bash Automated Testing System) — setup via `bash tests/setup.sh`
- Run unit tests (no network): `bash tests/run_tests.sh --unit`
- Run integration tests (requires PDI credentials in `tests/.env.test`): `bash tests/run_tests.sh --integration`
- Run all: `bash tests/run_tests.sh --all`
- Always run unit tests before committing
</testing>

</common_workflows>

<verification>
Before completing any task:
1. Run unit tests: `bash tests/run_tests.sh --unit` — all 210 tests must pass
2. If `sn.sh` was modified, verify the changed command works against a live instance (or spot-check with mocked tests)
3. Ensure `.env` files are not staged: `git diff --cached --name-only | grep -v example | grep -q '\.env' && echo "WARNING: .env staged"`
</verification>

<authoring_rules>

Rules to follow when editing this skill's files:

1. **Keep `<intent_routing>` in sync with `<keyword_fallback>`** — Every category in the keyword fallback table must have a corresponding pattern in `<intent_routing>`. Intent routing is the primary path; if a category only exists in fallback, it will always take the weaker route.

2. **No XML comments inside JSON code blocks** — Never use `<!-- -->` inside fenced code blocks that contain JSON. These are syntactically invalid JSON and will break `jq` validation if copied verbatim. Place guidance notes outside the code fence or in a surrounding XML tag instead.

3. **Separate developer-only content structurally** — Wrap any content intended for skill developers (not runtime execution) in a `<developer_reference>` tag with an explicit "DO NOT execute during runtime" instruction. Bold-text disclaimers alone are insufficient — Claude may overlook them mid-file.

4. **Multi-workflow instructions must be unambiguous** — When describing sequential operations, specify whether to load all files upfront or one at a time. Default: complete each workflow before loading the next.

5. **Avoid duplicating reference content in SKILL.md** — SKILL.md is the routing/overview layer. If detailed content exists in a reference file, point to it rather than restating it. When summarizing, note which source is authoritative.

</authoring_rules>

<related_skills>

Other ServiceNow skills that may invoke or complement this skill:

- **servicenow-developer** — Platform development guidance (client/server scripts, UI)
- **servicenow-rest-api** — REST API documentation and patterns (112+ APIs)
- **servicenow-troubleshooter** — Script conflict analysis and Workspace UI troubleshooting
- **servicenow-story-intake** — Agile story fetching and implementation planning
- **servicenow-uibuilder** — UI Builder declarative actions
- **servicenow-som** — Sales and Order Management
- **servicenow-knowledge** — Knowledge Base article creation

</related_skills>
