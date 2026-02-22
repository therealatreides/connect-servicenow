<overview>
OAuth 2.0 authentication patterns for ServiceNow REST API access. Supports two grant types: Resource Owner Password Credentials (ROPC) and Client Credentials. Both acquire access tokens from the ServiceNow OAuth token endpoint.

**Prerequisite**: An OAuth Application must be configured in ServiceNow (System OAuth > Application Registry). See `<servicenow_oauth_setup_reference>` for details.
</overview>

<token_endpoint>
**URL**: `POST https://{instance}/oauth_token.do`

**Content-Type**: `application/x-www-form-urlencoded`

This endpoint handles token acquisition, refresh, and revocation for all OAuth grant types.
</token_endpoint>

<critical_encoding_requirement>
**CRITICAL: Always use `--data-urlencode` (NOT `-d`) for all OAuth token requests.**

Client secrets and passwords frequently contain special characters (`! @ # $ % ^ & * ( ) ; < > ? { } | +`) that break URL form encoding when passed with curl's `-d` flag. The `-d` flag sends values as-is without encoding, causing ServiceNow to reject the request with `"error":"server_error"`.

Using `--data-urlencode` ensures all parameter values are properly URL-encoded before transmission, regardless of special characters in credentials.
</critical_encoding_requirement>

<grant_types>

<ropc>
**Resource Owner Password Credentials (ROPC)**

Requires: client_id, client_secret, username, password
Returns: access_token + refresh_token

```bash
curl -s -X POST "https://{instance}/oauth_token.do" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "grant_type=password" \
  --data-urlencode "client_id={client_id}" \
  --data-urlencode "client_secret={client_secret}" \
  --data-urlencode "username={username}" \
  --data-urlencode "password={password}"
```

**Successful response**:
```json
{
  "access_token": "eyJhbGci...",
  "refresh_token": "xRkPTswu...",
  "scope": "useraccount",
  "token_type": "Bearer",
  "expires_in": 1800
}
```

**Notes**:
- `expires_in` is in seconds (default: 1800 = 30 minutes)
- `refresh_token` can be used to obtain new access tokens without re-entering credentials
- Token carries the user's permissions and roles
</ropc>

<client_credentials>
**Client Credentials Grant**

Requires: client_id, client_secret (no user password)
Returns: access_token only (no refresh_token)
Availability: ServiceNow Washington DC and later releases

```bash
curl -s -X POST "https://{instance}/oauth_token.do" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "grant_type=client_credentials" \
  --data-urlencode "client_id={client_id}" \
  --data-urlencode "client_secret={client_secret}"
```

**Successful response**:
```json
{
  "access_token": "eyJhbGci...",
  "scope": "useraccount",
  "token_type": "Bearer",
  "expires_in": 1800
}
```

**Notes**:
- No refresh_token is provided — re-request when token expires
- Permissions are determined by the OAuth application's configured scope and user
- Not available on releases prior to Washington DC (returns 400 or 404)
</client_credentials>

</grant_types>

<token_usage>
**Using the access token in API calls**:

Replace Basic Auth `-u` flag with Bearer Authorization header:

```bash
curl -s -H "Authorization: Bearer {access_token}" \
  -H "Accept: application/json" \
  "https://{instance}/api/now/table/incident?sysparm_query=active=true&sysparm_limit=5"
```

**Header format**:
```
Authorization: Bearer {access_token}
```

All API endpoints that accept Basic Auth also accept Bearer tokens. No other changes to the API call are required.
</token_usage>

<token_lifecycle>
**Expiry tracking**:
- Record `expires_in` from token response and the time of acquisition
- Before each API call, check if token expires within 60 seconds
- If within 60-second buffer → refresh before making the API call

**Refresh flow — ROPC** (has refresh_token):
```bash
curl -s -X POST "https://{instance}/oauth_token.do" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  --data-urlencode "grant_type=refresh_token" \
  --data-urlencode "client_id={client_id}" \
  --data-urlencode "client_secret={client_secret}" \
  --data-urlencode "refresh_token={refresh_token}"
```

Response contains new `access_token` and `refresh_token`. Replace both in memory.

**Refresh flow — Client Credentials** (no refresh_token):
Re-execute the original client_credentials grant request to obtain a new access_token.

**In-session flow**:
```
Before API call:
  1. Check token expiry (acquired_at + expires_in - 60s buffer)
  2. If expired or within buffer:
     a. ROPC: Use refresh_token grant
     b. Client Credentials: Re-request with client_credentials grant
  3. If refresh succeeds: Update in-memory token, proceed with API call
  4. If refresh fails: Report error and exit
```
</token_lifecycle>

<error_handling>
**Token acquisition errors**:

| HTTP Status | Meaning | Action |
|------------|---------|--------|
| 200 | Success | Parse access_token, store in memory |
| 400 | Bad Request | Invalid grant_type, missing parameters, or invalid credentials. Display error description from response body. |
| 401 | Unauthorized | Invalid client_id or client_secret. Re-prompt for OAuth credentials. |
| 403 | Forbidden | OAuth client or scope not authorized. Inform user to check OAuth Application Registry. |
| 404 | Not Found | OAuth endpoint not available (instance may not support OAuth or pre-Washington DC for client_credentials). Offer Basic Auth fallback. |
| 429 | Too Many Requests | Rate limited. Wait 5 seconds, retry up to 2 times. |
| 5xx | Server Error | ServiceNow issue. Apply retry policy (up to 2 retries with 2-second delay). |

**Error response format**:
```json
{
  "error": "invalid_grant",
  "error_description": "Invalid username or password"
}
```

Common `error` values:
- `invalid_grant` — Wrong username/password (ROPC) or expired refresh_token
- `invalid_client` — Wrong client_id or client_secret
- `invalid_scope` — Requested scope not available
- `unsupported_grant_type` — Grant type not enabled on instance

**401 during API call** (token rejected):
1. Attempt token refresh (ROPC: refresh_token grant; Client Creds: re-request)
2. If refresh succeeds: Retry the original API call with new token
3. If refresh fails: Report error and exit
</error_handling>

<servicenow_oauth_setup_reference>
**Informational — all changes are manual in ServiceNow**

Users who need to configure OAuth in their ServiceNow instance:

1. **Navigate**: System OAuth > Application Registry
2. **Create OAuth Application**:
   - Click "New"
   - For ROPC: Select "Create an OAuth API endpoint for external clients"
   - For Client Credentials: Select "Create an OAuth API endpoint for external clients" (Washington DC+)
3. **Configure**:
   - Name: Descriptive name (e.g., "Claude Code Integration")
   - Client ID: Auto-generated (copy for .env)
   - Client Secret: Auto-generated (copy for .env)
   - Redirect URL: Not needed for ROPC/Client Credentials
   - Token Lifespan: Default 1800 seconds (30 minutes)
   - Refresh Token Lifespan: Default 8640000 seconds (100 days)
4. **Grant Types**: Ensure "Password" and/or "Client Credentials" are enabled
5. **Active**: Set to true

**Required roles for OAuth setup**: `admin` or `oauth_admin`

**Note**: This section is for user reference only. The skill never creates or modifies OAuth applications — all ServiceNow configuration is manual.
</servicenow_oauth_setup_reference>

<token_security>
**Token handling rules**:

1. **In-memory only**: Access tokens and refresh tokens are held in the sn.sh process only — never written to disk, .env files, logs, or any persistent storage
2. **Process-scoped**: Tokens are valid only for the current sn.sh execution
3. **No token caching**: Each sn.sh invocation acquires fresh tokens
4. **Refresh tokens**: Used within the process to avoid token expiry during long operations (batch), but discarded when the process ends
5. **Client secrets in .env**: Acceptable because .env is user-managed and gitignored — same security model as passwords in .env

**Rationale**: Tokens are short-lived process artifacts. Persisting them provides no benefit (they expire) and creates risk (token leakage). Client credentials in .env are acceptable because the user has explicitly opted in to credential persistence.
</token_security>
