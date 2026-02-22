<overview>
Single source of truth for ServiceNow authentication in the connect-servicenow skill. Covers all supported authentication strategies, credential sources, instance selection, and connection testing.

**Related references**:
- `env-file-format.md` — .env file schema, parsing, and validation
- `oauth-patterns.md` — OAuth token acquisition, refresh, and error handling
</overview>

<auth_strategies>
**Supported authentication strategies**:

| Strategy | Auth Type Value | Required Fields | Token Behavior | Availability |
|----------|----------------|-----------------|----------------|-------------|
| Basic Auth | `basic` | instance_url, username, password | No tokens — credentials sent per request via `-u` flag | All releases |
| OAuth ROPC | `oauth_ropc` | instance_url, client_id, client_secret, username, password | access_token + refresh_token acquired at start | All releases with OAuth enabled |
| OAuth Client Credentials | `oauth_client_credentials` | instance_url, client_id, client_secret | access_token acquired at start (no refresh_token) | Washington DC+ |

**Default**: `basic` (when auth_type is not specified or user does not choose)

**Strategy selection guidance**:
- **Basic Auth**: Simplest setup, works everywhere. Credentials sent with every request.
- **OAuth ROPC**: Token-based security with user context. Requires OAuth Application in ServiceNow. Tokens can be refreshed without re-entering credentials.
- **OAuth Client Credentials**: No user password needed. Best for service accounts. Requires Washington DC or later.
</auth_strategies>

<credential_sources>
**Two sources of credentials** (checked in order):

<source name="env_file">
**1. Environment file (opt-in)**
- User creates a `.env` file with instance configurations
- See `env-file-format.md` for file locations, format, and validation
- Supports multiple named instances with different auth types
- `.env` must be gitignored in git repos (hard block). See `env-file-format.md` `<gitignore_requirement>` for full enforcement rules
</source>

<source name="manual_prompt">
**2. Manual prompt (session-only fallback)**
- Used when no `.env` file exists, or user selects "Enter manually" from instance menu
- Prompts for auth type, then auth-type-specific fields
- Credentials used for immediate API calls only — never persisted
</source>

**Priority**: .env detection runs first. If found and valid, presents instance menu. User can always choose manual entry from the menu.
</credential_sources>

<instance_selection_flow>
**Full authentication flow** (used by workflows):

```
1. CHECK FOR .ENV FILE
   ├── Found → Parse instances (see env-file-format.md)
   │   ├── Valid instances found → Display instance menu
   │   │   ├── User selects instance → Load credentials from .env
   │   │   └── User selects "Enter manually" → Go to manual prompt
   │   └── No valid instances → Warning, fall back to manual prompt
   └── Not found → Go to manual prompt

2. AUTHENTICATE
   ├── basic → Export SNOW_* env vars for sn.sh
   ├── oauth_ropc → Export SNOW_* env vars (sn.sh handles token acquisition)
   └── oauth_client_credentials → Export SNOW_* env vars (sn.sh handles token acquisition)

3. TEST CONNECTION
   └── bash scripts/sn.sh health --check version
       ├── Success → "Connected to {instance_url} via {auth_type}"
       ├── 401 → Invalid credentials, re-prompt
       ├── 403 → Insufficient permissions, inform user about roles
       ├── 404 → Invalid URL or API not available
       └── Timeout/5xx → Apply retry policy
```

**Instance menu format** (when .env has instances):
```
ServiceNow Instance Selection

Available instances from .env:

  1. default — https://mydev.service-now.com (basic)
  2. DEV — https://mydev.service-now.com (basic)
  3. TEST — https://mytest.service-now.com (oauth_ropc)
  4. PROD — https://myprod.service-now.com (oauth_client_credentials)
  5. Enter credentials manually

Select an instance (1-5):
```
</instance_selection_flow>

<manual_prompt>
**Enhanced manual prompt** (when no .env or user selects manual):

```
ServiceNow Connection Required

Authentication method:
  1. Basic Auth (username + password) — default
  2. OAuth ROPC (client credentials + username/password)
  3. OAuth Client Credentials (client credentials only, Washington DC+)

Select method (1-3, default: 1):
```

**Then prompt for auth-type-specific fields:**

**Basic Auth**:
```
Instance URL: (e.g., https://yourinstance.service-now.com)
Username:
Password:
```

**OAuth ROPC**:
```
Instance URL: (e.g., https://yourinstance.service-now.com)
Client ID:
Client Secret:
Username:
Password:
```

**OAuth Client Credentials**:
```
Instance URL: (e.g., https://yourinstance.service-now.com)
Client ID:
Client Secret:
```

**Include disclaimer**: "(Credentials are used for this session only — not cached or stored)"

**Validation rules**:
- Instance URL: Must start with `https://`, accepted formats: *.service-now.com, *.servicenowservices.com, custom domain. Remove trailing slash.
- Username: Non-empty, case-sensitive (ServiceNow user_name, not email)
- Password: Non-empty
- Client ID: Non-empty
- Client Secret: Non-empty
</manual_prompt>

<connection_testing>
**Test method**: `bash scripts/sn.sh health --check version`

This queries `/api/now/table/sys_properties` (filtering for `glide.war`, `glide.build.date`, and `glide.build.tag`) to verify connectivity and authentication. On success, it returns the instance build version.

**Alternative test** (direct curl):

Basic Auth:
```bash
curl -s -u "{username}:{password}" \
  -H "Accept: application/json" \
  "{instance_url}/api/now/table/sys_user?sysparm_limit=1"
```

OAuth (Bearer token):
```bash
curl -s -H "Authorization: Bearer {access_token}" \
  -H "Accept: application/json" \
  "{instance_url}/api/now/table/sys_user?sysparm_limit=1"
```

**Response handling**:
- **200 OK**: Connection successful. Display: "Connected to {instance_url} via {auth_type}"
- **401 Unauthorized**:
  - Basic Auth: Invalid credentials — re-prompt user
  - OAuth: Token acquisition failed — check client credentials and grant type
- **403 Forbidden**: Valid credentials but insufficient permissions — inform user about required roles (rest_api_explorer, soap_script, web_service_admin)
- **404 Not Found**: Invalid instance URL — verify URL format
- **Timeout/5xx**: Apply retry policy from SKILL.md

**Required ServiceNow roles for API access**:
- `rest_api_explorer`
- `soap_script` (for some operations)
- `web_service_admin` (for administrative operations)
</connection_testing>

<validation_rules>
**Instance URL validation**:
- Must start with `https://`
- Accepted formats:
  - `https://instance.service-now.com`
  - `https://instance.servicenowservices.com`
  - Custom domain: `https://servicenow.company.com`
- Remove trailing slash if present
- Must be valid URL format

**Auth type validation**:
- Must be one of: `basic`, `oauth_ropc`, `oauth_client_credentials`
- Default to `basic` if not specified

**Field validation** (all non-empty strings):
- Username, Password, Client ID, Client Secret — no client-side format validation (server validates)
</validation_rules>

<security_notes>
**Credential handling rules**:

1. **No credential persistence unless user opts in via .env**: Credentials entered manually are used for immediate API calls only and are not stored anywhere
2. **.env is user-managed**: The skill reads .env files but never creates or modifies them. Users are responsible for securing their .env files.
3. **Gitignore enforcement**: The `.env` file must never be committed to any repository. When inside a git repository, the skill refuses to read `.env` unless it is listed in `.gitignore` — this is a hard block with no override. **Exception**: If the working directory is not inside any git repository (verified via `git rev-parse --show-toplevel`), the `.gitignore` requirement is waived since there is no risk of committing credentials
4. **Tokens never persisted**: OAuth access_tokens and refresh_tokens are held in script process memory only — never written to disk, .env files, logs, or any persistent storage
5. **Session-scoped**: All credentials and tokens are valid only for the current sn.sh invocation
6. **No token caching**: Each sn.sh invocation acquires fresh tokens

**Rationale**: Relaxing "never persist" to "opt-in via .env" balances security with developer ergonomics. Users who work with the same instances repeatedly can opt in to credential storage, while the default behavior remains session-only prompting.
</security_notes>

<developer_reference>
DO NOT execute this section during runtime. This content is for skill developers extending this skill only.

<workflow_integration_guide>

```xml
<step_authentication>
**Authenticate to ServiceNow**

Follow the authentication flow from `references/authentication.md`:
1. Check for .env file and parse instances
2. Display instance menu or fall back to manual prompt
3. Export SNOW_* env vars for the selected instance
4. Test connection with `bash scripts/sn.sh health --check version`

**Security**: See `authentication.md` `<security_notes>` for credential handling rules.
**OAuth details**: See `references/oauth-patterns.md` for token acquisition and refresh patterns.
</step_authentication>
```
</workflow_integration_guide>
</developer_reference>
