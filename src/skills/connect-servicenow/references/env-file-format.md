<overview>
Environment file format for persisting ServiceNow instance credentials. Opt-in only — users must explicitly create a `.env` file to use this feature. When no `.env` is found, the skill falls back to manual credential prompting (see `authentication.md`).
</overview>

<file_locations>
**Locations** (checked in order):
1. `./.env` — Project-level (preferred)
2. `~/.claude/.servicenow.env` — Global fallback

If neither file exists, skip `.env` detection and fall back to manual credential prompt.
</file_locations>

<gitignore_requirement>
**CRITICAL: .env files MUST NEVER be committed to any repository.**

The `.env` file contains plaintext credentials. When inside a git repository, it must be listed in `.gitignore` before the skill will read it.

**Enforcement**: Before reading a `.env` file, check for a git repository and then verify gitignore coverage:

1. **Check if the working directory is inside a git repository**:
   ```bash
   git rev-parse --show-toplevel 2>/dev/null
   ```

2. **If NOT in a git repository** (command fails with non-zero exit code):
   No risk of committing credentials — skip the `.gitignore` check and proceed to read the `.env` file.
   Display: `"No git repository detected — .gitignore check not required."`

3. **If in a git repository** (command succeeds):
   Verify the `.env` file is gitignored:
   ```bash
   git check-ignore .env
   ```
   **If NOT gitignored**, refuse to read the file. Display this error and do NOT proceed:
   ```
   BLOCKED: Your .env file is NOT listed in .gitignore.

   This file contains credentials and must NEVER be committed to any repository.
   Add ".env" to your .gitignore file, then try again.
   ```
   After displaying this message, fall back to manual credential prompt. Do not offer a "continue anyway" option.

**Summary**: The `.gitignore` hard block applies only when a git repository exists. When no git repository is detected at any parent level, the `.env` file is read without the `.gitignore` check.
</gitignore_requirement>

<variable_naming_schema>
**Default instance** (unprefixed):
```
SNOW_INSTANCE_URL=https://instance.service-now.com
SNOW_AUTH_TYPE=basic
SNOW_USERNAME=admin
SNOW_PASSWORD=secret
SNOW_CLIENT_ID=abc123
SNOW_CLIENT_SECRET=xyz789
```

**Named instances** (prefixed with alias):
```
SNOW_{ALIAS}_INSTANCE_URL=https://dev.service-now.com
SNOW_{ALIAS}_AUTH_TYPE=oauth_ropc
SNOW_{ALIAS}_USERNAME=admin
SNOW_{ALIAS}_PASSWORD=secret
SNOW_{ALIAS}_CLIENT_ID=abc123
SNOW_{ALIAS}_CLIENT_SECRET=xyz789
```

**Alias rules**:
- Uppercase alphanumeric and underscores only (e.g., `DEV`, `TEST`, `PROD_US`)
- Case-insensitive for matching (stored/displayed as provided)
- Cannot be empty or use reserved word `SNOW`
</variable_naming_schema>

<required_fields_by_auth_type>
| Field | `basic` | `oauth_ropc` | `oauth_client_credentials` |
|-------|---------|-------------|---------------------------|
| `INSTANCE_URL` | Required | Required | Required |
| `AUTH_TYPE` | Required | Required | Required |
| `USERNAME` | Required | Required | — |
| `PASSWORD` | Required | Required | — |
| `CLIENT_ID` | — | Required | Required |
| `CLIENT_SECRET` | — | Required | Required |

**Notes:**
- `AUTH_TYPE` must be exactly one of: `basic`, `oauth_ropc`, `oauth_client_credentials`
- `INSTANCE_URL` must start with `https://` — apply same validation as authentication.md
- Missing required fields → instance is invalid (skip with warning)
</required_fields_by_auth_type>

<parsing_rules>
**Line format**: `KEY=VALUE` (no quotes needed, leading/trailing whitespace trimmed)

**Special characters in passwords**: Passwords containing `$`, `!`, `` ` ``, or `=` can break when the `.env` file is sourced by bash. For credentials with special characters, use base64 encoding with a `_B64` suffix:
```
# Instead of:  SNOW_PASSWORD=mZ9oP-DxxC$3   ($ expands in bash)
# Use:         SNOW_PASSWORD_B64=bVo5b1AtRHh4QyQz
```
The workflow layer decodes `_B64` values before exporting `SNOW_*` env vars to `sn.sh`. Encode with: `echo -n 'your-password' | base64`. Decode with: `echo 'encoded-value' | base64 -d`.

**Parsing behavior**:
1. Skip blank lines and lines starting with `#`
2. Split on first `=` only (values may contain `=`)
3. Trim whitespace from key and value
4. Ignore keys that don't start with `SNOW_`
5. Group keys by alias:
   - `SNOW_INSTANCE_URL` → default instance (alias: `default`)
   - `SNOW_DEV_INSTANCE_URL` → named instance (alias: `DEV`)
6. An instance exists if it has an `INSTANCE_URL` key

**Instance discovery algorithm**:
1. Collect all `SNOW_*` keys
2. Extract unique aliases (default + named)
3. For each alias, check required fields per `AUTH_TYPE`
4. Valid instances → available for selection
5. Invalid instances → skip with warning message
</parsing_rules>

<validation>
**Per-instance validation** (run for each discovered instance):

1. **AUTH_TYPE valid?** Must be `basic`, `oauth_ropc`, or `oauth_client_credentials`
   - If missing: default to `basic`
   - If unrecognized value: skip instance with warning
2. **Required fields present?** Check against required_fields_by_auth_type table
   - If missing: skip instance with warning listing missing fields
3. **INSTANCE_URL format?** Must start with `https://` and be a valid URL
   - If invalid: skip instance with warning

**Warning format**:
```
.env: Skipping instance "{alias}" — missing required fields: {field_list}
```

**Fallback behavior**:
- If ALL instances are invalid → display warning, fall back to manual credential prompt
- If SOME instances are invalid → show valid ones in menu, note skipped ones

**Example output when issues found**:
```
Loaded .env from ./.env
  WARNING: Skipping instance "PROD" — missing required fields: CLIENT_SECRET
  Found 2 valid instances: default, DEV
```
</validation>
