<overview>
Establish an authenticated connection to a ServiceNow instance. This workflow must be completed before any other workflow can execute API operations.
</overview>

<steps>

<step_detect_env>
Search for a `.env` file in this order:
1. `./.env` (current working directory)
2. `~/.claude/.servicenow.env` (global fallback)

```bash
# Check project-level
ls -la .env 2>/dev/null

# Check global fallback
ls -la ~/.claude/.servicenow.env 2>/dev/null
```

If neither exists → skip to Step 4 (manual prompt).
If found → check file permissions before proceeding:

```bash
# Verify .env is not world-readable (Unix/macOS/WSL only)
perms=$(stat -c %a .env 2>/dev/null || stat -f %Lp .env 2>/dev/null)
if [[ -n "$perms" && "$perms" != "600" && "$perms" != "400" ]]; then
  echo "WARNING: .env has permissions $perms — should be 600 (owner read/write only)"
  echo "Fix with: chmod 600 .env"
fi
```

Then proceed to Step 2.
</step_detect_env>

<step_gitignore_check>
Only applies if .env found AND inside a git repository.

```bash
# Check if in a git repository
git rev-parse --show-toplevel 2>/dev/null
```

**If NOT in a git repository**: Skip gitignore check. Display: "No git repository detected — .gitignore check not required."

**If in a git repository**:
```bash
git check-ignore .env
```

**If NOT gitignored**: Display this error and fall back to manual prompt:
```
BLOCKED: Your .env file is NOT listed in .gitignore.

This file contains credentials and must NEVER be committed to any repository.
Add ".env" to your .gitignore file, then try again.
```

**If gitignored**: Proceed to Step 3.

See `references/env-file-format.md` `<gitignore_requirement>` for full rules.
</step_gitignore_check>

<step_instance_menu>
Parse the `.env` file according to `references/env-file-format.md` `<parsing_rules>`:
1. Collect all `SNOW_*` keys
2. Extract unique aliases (default + named instances)
3. Validate each instance (check required fields per auth_type)
4. Display valid instances as a selection menu

**Menu format**:
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

**If user selects an instance**: Load its `SNOW_*` values and proceed to Step 5.
**If user selects "Enter manually"**: Proceed to Step 4.
**If all instances are invalid**: Display warnings and proceed to Step 4.
</step_instance_menu>

<step_manual_prompt>
Fallback when no valid .env instance is available.

Present auth method selection:
```
ServiceNow Connection Required

Authentication method:
  1. Basic Auth (username + password) — default
  2. OAuth ROPC (client credentials + username/password)
  3. OAuth Client Credentials (client credentials only, Washington DC+)

Select method (1-3, default: 1):
```

Then prompt for auth-type-specific fields per `references/authentication.md` `<manual_prompt>`.

**Include disclaimer**: "(Credentials are used for this session only — not cached or stored)"

Validate inputs:
- Instance URL must start with `https://`
- All required fields must be non-empty
- Remove trailing slash from URL
</step_manual_prompt>

<step_test_connection>
Export the credentials as `SNOW_*` environment variables:
```bash
export SNOW_INSTANCE_URL="https://yourinstance.service-now.com"
export SNOW_AUTH_TYPE="basic"  # or oauth_ropc or oauth_client_credentials
export SNOW_USERNAME="your_username"
export SNOW_PASSWORD="your_password"
# For OAuth:
# export SNOW_CLIENT_ID="your_client_id"
# export SNOW_CLIENT_SECRET="your_client_secret"
```

Test the connection:
```bash
bash scripts/sn.sh health --check version
```

**On success**: Display "Connected to {instance_url} via {auth_type}" and the version info.
**On failure**: Display the error and offer to retry or re-enter credentials.

See `references/authentication.md` `<connection_testing>` for response handling.
</step_test_connection>

</steps>

<success_criteria>
Connection is successful when `bash scripts/sn.sh health --check version` returns version info with exit code 0. Display: "Connected to {instance_url} via {auth_type}".
</success_criteria>

<troubleshooting>
| Error | Likely Cause | Solution |
|-------|-------------|----------|
| 401 Unauthorized | Wrong username/password or client credentials | Re-enter credentials |
| 403 Forbidden | User lacks required roles | Assign: rest_api_explorer, soap_script, web_service_admin |
| 404 Not Found | Invalid URL or OAuth not enabled | Verify URL format; for OAuth, check Application Registry |
| Connection refused | Network/VPN issue | Check VPN, firewall, proxy settings |
| OAuth "invalid_client" | Wrong client_id or client_secret | Verify in System OAuth > Application Registry |
| OAuth "unsupported_grant_type" | Grant type not enabled | Enable "Password" or "Client Credentials" grant in OAuth app |
</troubleshooting>
