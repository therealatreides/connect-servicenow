#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────
# ServiceNow Table API CLI — sn.sh
# connect-servicenow skill for Claude Code
#
# Based on the OpenClaw ServiceNow script by Brandon Wilson (OnlyFlows)
# Rewritten with OAuth 2.0 support and retry logic
#
# Author:  Scott Royalty
# License: MIT
# ──────────────────────────────────────────────────────────────────────
# Usage: bash sn.sh <command> [args...]
# Commands: query, get, create, update, delete, aggregate, schema, attach, batch, health
set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────────
: "${SNOW_INSTANCE_URL:?SNOW_INSTANCE_URL env var required (e.g. https://instance.service-now.com)}"
: "${SNOW_AUTH_TYPE:=basic}"

# Normalize instance URL
SNOW_INSTANCE_URL="${SNOW_INSTANCE_URL%/}"
SNOW_INSTANCE_URL="${SNOW_INSTANCE_URL/#http:\/\//https:\/\/}"
[[ "$SNOW_INSTANCE_URL" != https://* ]] && SNOW_INSTANCE_URL="https://$SNOW_INSTANCE_URL"

# Decode _B64 credential values (base64-encoded to avoid shell metacharacter issues)
[[ -n "${SNOW_PASSWORD_B64:-}" && -z "${SNOW_PASSWORD:-}" ]] && \
  SNOW_PASSWORD=$(echo "$SNOW_PASSWORD_B64" | base64 -d 2>/dev/null) && export SNOW_PASSWORD
[[ -n "${SNOW_CLIENT_SECRET_B64:-}" && -z "${SNOW_CLIENT_SECRET:-}" ]] && \
  SNOW_CLIENT_SECRET=$(echo "$SNOW_CLIENT_SECRET_B64" | base64 -d 2>/dev/null) && export SNOW_CLIENT_SECRET

# Validate auth type and required fields
case "$SNOW_AUTH_TYPE" in
  basic)
    : "${SNOW_USERNAME:?SNOW_USERNAME required for basic auth}"
    : "${SNOW_PASSWORD:?SNOW_PASSWORD required for basic auth}"
    ;;
  oauth_ropc)
    : "${SNOW_CLIENT_ID:?SNOW_CLIENT_ID required for OAuth ROPC}"
    : "${SNOW_CLIENT_SECRET:?SNOW_CLIENT_SECRET required for OAuth ROPC}"
    : "${SNOW_USERNAME:?SNOW_USERNAME required for OAuth ROPC}"
    : "${SNOW_PASSWORD:?SNOW_PASSWORD required for OAuth ROPC}"
    ;;
  oauth_client_credentials)
    : "${SNOW_CLIENT_ID:?SNOW_CLIENT_ID required for OAuth Client Credentials}"
    : "${SNOW_CLIENT_SECRET:?SNOW_CLIENT_SECRET required for OAuth Client Credentials}"
    ;;
  *)
    echo "ERROR: Unknown SNOW_AUTH_TYPE: $SNOW_AUTH_TYPE (must be basic, oauth_ropc, or oauth_client_credentials)" >&2
    exit 1
    ;;
esac

# ── Helpers ────────────────────────────────────────────────────────────
die()  { echo "ERROR: $*" >&2; exit 1; }
info() { echo "→ $*" >&2; }

# Safe jq wrapper — strips \r from output (critical for Windows/Git Bash where jq outputs \r\n)
jq_safe() { jq "$@" | tr -d '\r'; }

# ── Input Validation ──────────────────────────────────────────────────
validate_table_name() {
  [[ "$1" =~ ^[a-z0-9_]+$ ]] || die "Invalid table name: '$1' (must contain only lowercase letters, digits, and underscores)"
}

validate_sys_id() {
  [[ "$1" =~ ^[a-f0-9]{32}$ ]] || die "Invalid sys_id format: '$1' (must be 32 hex characters)"
}

validate_number() {
  [[ "$1" =~ ^[0-9]+$ ]] || die "Expected a number, got: '$1'"
}

# URI-encode a value for safe URL parameter inclusion
uri_encode() {
  jq_safe -rn --arg v "$1" '$v | @uri'
}

# ── OAuth Token Management ─────────────────────────────────────────────
_ACCESS_TOKEN=""
_REFRESH_TOKEN=""
_TOKEN_EXPIRES_AT=0
trap 'unset _ACCESS_TOKEN _REFRESH_TOKEN _TOKEN_EXPIRES_AT' EXIT

acquire_token() {
  info "Acquiring OAuth token via ${SNOW_AUTH_TYPE}..."
  local resp http_code body

  if [[ "$SNOW_AUTH_TYPE" == "oauth_ropc" ]]; then
    resp=$(curl -s -w "\n%{http_code}" -X POST "${SNOW_INSTANCE_URL}/oauth_token.do" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      --data-urlencode "grant_type=password" \
      --data-urlencode "client_id=${SNOW_CLIENT_ID}" \
      --data-urlencode "client_secret=${SNOW_CLIENT_SECRET}" \
      --data-urlencode "username=${SNOW_USERNAME}" \
      --data-urlencode "password=${SNOW_PASSWORD}")
  elif [[ "$SNOW_AUTH_TYPE" == "oauth_client_credentials" ]]; then
    resp=$(curl -s -w "\n%{http_code}" -X POST "${SNOW_INSTANCE_URL}/oauth_token.do" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      --data-urlencode "grant_type=client_credentials" \
      --data-urlencode "client_id=${SNOW_CLIENT_ID}" \
      --data-urlencode "client_secret=${SNOW_CLIENT_SECRET}")
  else
    return 0
  fi

  http_code=$(echo "$resp" | tail -1)
  body=$(echo "$resp" | sed '$d')

  if [[ "$http_code" != "200" ]]; then
    local err_desc
    err_desc=$(echo "$body" | jq_safe -r '.error_description // .error // "unknown error"' 2>/dev/null || echo "unknown error")
    die "OAuth token acquisition failed (HTTP $http_code): $err_desc"
  fi

  _ACCESS_TOKEN=$(echo "$body" | jq_safe -r '.access_token')
  _REFRESH_TOKEN=$(echo "$body" | jq_safe -r '.refresh_token // empty')
  local expires_in
  expires_in=$(echo "$body" | jq_safe -r '.expires_in // 1800')
  _TOKEN_EXPIRES_AT=$(( $(date +%s) + expires_in - 60 ))

  info "Token acquired (expires in ${expires_in}s)"
  _save_token_to_env
}

refresh_token() {
  if [[ -n "$_REFRESH_TOKEN" ]]; then
    info "Refreshing OAuth token..."
    local resp http_code body
    resp=$(curl -s -w "\n%{http_code}" -X POST "${SNOW_INSTANCE_URL}/oauth_token.do" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      --data-urlencode "grant_type=refresh_token" \
      --data-urlencode "client_id=${SNOW_CLIENT_ID}" \
      --data-urlencode "client_secret=${SNOW_CLIENT_SECRET}" \
      --data-urlencode "refresh_token=${_REFRESH_TOKEN}")

    http_code=$(echo "$resp" | tail -1)
    body=$(echo "$resp" | sed '$d')

    if [[ "$http_code" == "200" ]]; then
      _ACCESS_TOKEN=$(echo "$body" | jq_safe -r '.access_token')
      _REFRESH_TOKEN=$(echo "$body" | jq_safe -r '.refresh_token // empty')
      local expires_in
      expires_in=$(echo "$body" | jq_safe -r '.expires_in // 1800')
      _TOKEN_EXPIRES_AT=$(( $(date +%s) + expires_in - 60 ))
      info "Token refreshed"
      _save_token_to_env
      return 0
    fi
    info "Refresh failed (HTTP $http_code) — re-acquiring token..."
  fi

  # Refresh failed or no refresh token — re-acquire
  acquire_token
}

ensure_token() {
  [[ "$SNOW_AUTH_TYPE" == "basic" ]] && return 0
  local now
  now=$(date +%s)
  if [[ -z "$_ACCESS_TOKEN" || "$now" -ge "$_TOKEN_EXPIRES_AT" ]]; then
    if [[ -n "$_ACCESS_TOKEN" ]]; then
      refresh_token
    else
      acquire_token
    fi
  fi
}

# ── Token Cache (write-back to .env) ─────────────────────────────────
_save_token_to_env() {
  # Write token back to .env file if env file path and prefix are provided
  [[ "${SNOW_TOKEN_CACHE:-}" == "false" ]] && return
  [[ -z "${SNOW_ENV_FILE:-}" || -z "${SNOW_ENV_PREFIX:-}" ]] && return
  [[ ! -w "$SNOW_ENV_FILE" ]] && return

  local prefix="$SNOW_ENV_PREFIX"
  local key_token="SNOW_${prefix}_ACCESS_TOKEN"
  local key_refresh="SNOW_${prefix}_REFRESH_TOKEN"
  local key_expires="SNOW_${prefix}_TOKEN_EXPIRES_AT"

  # Remove existing token lines (if any), then append fresh values
  sed -i.bak \
    -e "/^${key_token}=/d" \
    -e "/^${key_refresh}=/d" \
    -e "/^${key_expires}=/d" \
    "$SNOW_ENV_FILE" && rm -f "${SNOW_ENV_FILE}.bak"

  {
    echo "${key_token}=${_ACCESS_TOKEN}"
    [[ -n "$_REFRESH_TOKEN" ]] && echo "${key_refresh}=${_REFRESH_TOKEN}"
    echo "${key_expires}=${_TOKEN_EXPIRES_AT}"
  } >> "$SNOW_ENV_FILE"
}

# Build auth arguments for curl into _AUTH_ARGS array
declare -a _AUTH_ARGS=()
build_auth_args() {
  _AUTH_ARGS=()
  if [[ "$SNOW_AUTH_TYPE" == "basic" ]]; then
    _AUTH_ARGS=(-u "${SNOW_USERNAME}:${SNOW_PASSWORD}")
  else
    _AUTH_ARGS=(-H "Authorization: Bearer ${_ACCESS_TOKEN}")
  fi
}

# Acquire initial token for OAuth auth types (check cache first)
if [[ "$SNOW_AUTH_TYPE" != "basic" ]]; then
  if [[ "${SNOW_TOKEN_CACHE:-}" != "false" \
     && -n "${SNOW_ACCESS_TOKEN:-}" \
     && -n "${SNOW_TOKEN_EXPIRES_AT:-}" \
     && "$(date +%s)" -lt "${SNOW_TOKEN_EXPIRES_AT}" ]]; then
    _ACCESS_TOKEN="$SNOW_ACCESS_TOKEN"
    _REFRESH_TOKEN="${SNOW_REFRESH_TOKEN:-}"
    _TOKEN_EXPIRES_AT="$SNOW_TOKEN_EXPIRES_AT"
    info "Using cached token (expires in $(( _TOKEN_EXPIRES_AT - $(date +%s) ))s)"
  else
    acquire_token
  fi
fi

# ── Core API Function ──────────────────────────────────────────────────
sn_curl() {
  local method="$1" url="$2"
  shift 2

  ensure_token

  local attempt max_attempts="${SNOW_MAX_RETRIES:-3}" delay=2
  for (( attempt=1; attempt<=max_attempts; attempt++ )); do
    local resp http_code body

    # Build auth args fresh each attempt (token may have been refreshed)
    build_auth_args

    resp=$(curl -s -w "\n%{http_code}" -X "$method" "$url" \
      "${_AUTH_ARGS[@]}" \
      -H "Accept: application/json" \
      -H "Content-Type: application/json" \
      "$@") || true

    http_code=$(echo "$resp" | tail -1)
    body=$(echo "$resp" | sed '$d')

    case "$http_code" in
      2[0-9][0-9])
        echo "$body"
        return 0
        ;;
      401)
        if [[ "$SNOW_AUTH_TYPE" != "basic" && "$attempt" -lt "$max_attempts" ]]; then
          info "Token rejected (401) — refreshing..."
          refresh_token
          continue
        fi
        die "Authentication failed (HTTP 401). Check credentials."
        ;;
      429)
        if (( attempt < max_attempts )); then
          info "Rate limited (429) — waiting 5 seconds..."
          sleep 5
          continue
        fi
        die "Rate limited (HTTP 429). Try again later."
        ;;
      5[0-9][0-9])
        if (( attempt < max_attempts )); then
          info "Server error ($http_code) — retrying in ${delay}s (attempt $attempt/$max_attempts)..."
          sleep "$delay"
          continue
        fi
        die "Server error (HTTP $http_code) after $max_attempts attempts."
        ;;
      000)
        if (( attempt < max_attempts )); then
          info "Connection failed — retrying in ${delay}s (attempt $attempt/$max_attempts)..."
          sleep "$delay"
          delay=$((delay * 2))
          continue
        fi
        die "Connection failed (HTTP 000) after $max_attempts attempts. Check network and instance availability."
        ;;
      400) die "Bad request (HTTP 400): $(echo "$body" | jq_safe -r '.error.message // .error // "check query syntax"' 2>/dev/null || echo "check request parameters")" ;;
      403) die "Access denied (HTTP 403). Check user roles: rest_api_explorer, soap_script, web_service_admin" ;;
      404) die "Not found (HTTP 404). Check URL, table name, or sys_id." ;;
      *)   die "Unexpected HTTP $http_code. Check request parameters and instance availability." ;;
    esac
  done
}

# Like sn_curl but returns HTTP status code (for delete operations)
sn_curl_status() {
  local method="$1" url="$2"
  shift 2

  ensure_token

  build_auth_args

  curl -s -o /dev/null -w "%{http_code}" -X "$method" "$url" \
    "${_AUTH_ARGS[@]}" \
    -H "Accept: application/json" \
    "$@"
}

# Auth-aware file curl (for attachments — no Content-Type: application/json)
sn_curl_file() {
  local method="$1" url="$2"
  shift 2

  ensure_token

  build_auth_args

  curl -sf -X "$method" "$url" \
    "${_AUTH_ARGS[@]}" \
    "$@"
}

# Non-fatal curl wrapper for batch operations
# Returns 0 for 2xx, 1 for errors. Sets _SN_HTTP_CODE with the response status.
# Precondition: caller MUST call ensure_token immediately before invoking this function.
# This wrapper does not retry on 429/5xx — rate limiting causes per-record failure.
_SN_HTTP_CODE=""
sn_curl_try() {
  local method="$1" url="$2"
  shift 2

  build_auth_args

  local resp
  resp=$(curl -s -w "\n%{http_code}" -X "$method" "$url" \
    "${_AUTH_ARGS[@]}" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    "$@") || true

  _SN_HTTP_CODE=$(echo "$resp" | tail -1 | tr -d '\r')
  local body
  body=$(echo "$resp" | sed '$d')

  if [[ "$_SN_HTTP_CODE" =~ ^2[0-9][0-9]$ ]]; then
    echo "$body"
    return 0
  fi
  return 1
}

# ── query ──────────────────────────────────────────────────────────────
cmd_query() {
  local table="" query="" fields="" limit="20" offset="" orderby="" display=""
  table="${1:?Usage: sn.sh query <table> [options]}"
  validate_table_name "$table"
  shift

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --query)   query="$2";   shift 2 ;;
      --fields)  fields="$2";  shift 2 ;;
      --limit)   limit="$2"; validate_number "$limit"; shift 2 ;;
      --offset)  offset="$2"; shift 2 ;;
      --orderby) orderby="$2"; shift 2 ;;
      --display) display="$2"; shift 2 ;;
      *) die "Unknown option: $1" ;;
    esac
  done

  [[ -n "$offset" ]] && validate_number "$offset"

  local url="${SNOW_INSTANCE_URL}/api/now/table/${table}?sysparm_limit=${limit}"
  [[ -n "$query" ]]   && url+="&sysparm_query=$(uri_encode "$query")"
  [[ -n "$fields" ]]  && url+="&sysparm_fields=$(uri_encode "$fields")"
  [[ -n "$offset" ]]  && url+="&sysparm_offset=${offset}"
  [[ -n "$orderby" ]] && url+="&sysparm_orderby=$(uri_encode "$orderby")"
  [[ -n "$display" ]] && url+="&sysparm_display_value=$(uri_encode "$display")"

  info "GET $table (limit=$limit)"
  local resp
  resp=$(sn_curl GET "$url") || die "API request failed"

  local count
  count=$(echo "$resp" | jq '.result | length')
  echo "$resp" | jq '{record_count: (.result | length), results: .result}'
  info "Returned $count record(s)"
}

# ── get ────────────────────────────────────────────────────────────────
cmd_get() {
  local table="${1:?Usage: sn.sh get <table> <sys_id> [options]}"
  local sys_id="${2:?Usage: sn.sh get <table> <sys_id> [options]}"
  validate_table_name "$table"
  validate_sys_id "$sys_id"
  shift 2

  local fields="" display=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --fields)  fields="$2";  shift 2 ;;
      --display) display="$2"; shift 2 ;;
      *) die "Unknown option: $1" ;;
    esac
  done

  local url="${SNOW_INSTANCE_URL}/api/now/table/${table}/${sys_id}"
  local sep="?"
  [[ -n "$fields" ]]  && url+="${sep}sysparm_fields=$(uri_encode "$fields")" && sep="&"
  [[ -n "$display" ]] && url+="${sep}sysparm_display_value=$(uri_encode "$display")"

  info "GET $table/$sys_id"
  sn_curl GET "$url" | jq '.result'
}

# ── create ─────────────────────────────────────────────────────────────
cmd_create() {
  local table="${1:?Usage: sn.sh create <table> '<json>'}"
  local json="${2:?Usage: sn.sh create <table> '<json>'}"
  validate_table_name "$table"
  shift 2

  # Validate JSON
  echo "$json" | jq . >/dev/null 2>&1 || die "Invalid JSON payload — check syntax"

  local url="${SNOW_INSTANCE_URL}/api/now/table/${table}"
  info "POST $table"
  local resp
  resp=$(sn_curl POST "$url" -d "$json") || die "Create failed"
  echo "$resp" | jq '{sys_id: .result.sys_id, number: .result.number, result: .result}'
  info "Created record: $(echo "$resp" | jq_safe -r '.result.sys_id')"
}

# ── update ─────────────────────────────────────────────────────────────
cmd_update() {
  local table="${1:?Usage: sn.sh update <table> <sys_id> '<json>'}"
  local sys_id="${2:?Usage: sn.sh update <table> <sys_id> '<json>'}"
  local json="${3:?Usage: sn.sh update <table> <sys_id> '<json>'}"
  validate_table_name "$table"
  validate_sys_id "$sys_id"
  shift 3

  echo "$json" | jq . >/dev/null 2>&1 || die "Invalid JSON payload — check syntax"

  local url="${SNOW_INSTANCE_URL}/api/now/table/${table}/${sys_id}"
  info "PATCH $table/$sys_id"
  local resp
  resp=$(sn_curl PATCH "$url" -d "$json") || die "Update failed"
  echo "$resp" | jq '.result'
  info "Updated record: $sys_id"
}

# ── delete ─────────────────────────────────────────────────────────────
cmd_delete() {
  local table="${1:?Usage: sn.sh delete <table> <sys_id> --confirm}"
  local sys_id="${2:?Usage: sn.sh delete <table> <sys_id> --confirm}"
  validate_table_name "$table"
  validate_sys_id "$sys_id"
  shift 2

  local confirmed=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --confirm) confirmed=true; shift ;;
      *) die "Unknown option: $1" ;;
    esac
  done

  [[ "$confirmed" != "true" ]] && die "Must pass --confirm to delete records. This is a safety measure."

  local url="${SNOW_INSTANCE_URL}/api/now/table/${table}/${sys_id}"
  info "DELETE $table/$sys_id"
  local http_code
  http_code=$(sn_curl_status DELETE "$url")

  if [[ "$http_code" == "204" || "$http_code" == "200" ]]; then
    jq -n --arg sid "$sys_id" --arg tbl "$table" '{status:"deleted",sys_id:$sid,table:$tbl}'
    info "Deleted $table/$sys_id"
  elif [[ "$http_code" == "404" ]]; then
    die "Record not found: $table/$sys_id"
  else
    die "Delete failed with HTTP $http_code"
  fi
}

# ── aggregate ──────────────────────────────────────────────────────────
cmd_aggregate() {
  local table="${1:?Usage: sn.sh aggregate <table> --type <TYPE> [options]}"
  validate_table_name "$table"
  shift

  local agg_type="" query="" field="" group_by="" display=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --type)     agg_type="$2"; shift 2 ;;
      --query)    query="$2";    shift 2 ;;
      --field)    field="$2";    shift 2 ;;
      --group-by) group_by="$2"; shift 2 ;;
      --display)  display="$2";  shift 2 ;;
      *) die "Unknown option: $1" ;;
    esac
  done

  [[ -z "$agg_type" ]] && die "Usage: sn.sh aggregate <table> --type <COUNT|AVG|MIN|MAX|SUM> [options]"
  agg_type=$(echo "$agg_type" | tr '[:lower:]' '[:upper:]')

  # Validate: AVG/MIN/MAX/SUM need --field
  if [[ "$agg_type" != "COUNT" && -z "$field" ]]; then
    die "$agg_type requires --field <fieldname>"
  fi

  local url="${SNOW_INSTANCE_URL}/api/now/stats/${table}"
  local sep="?"

  if [[ "$agg_type" == "COUNT" ]]; then
    url+="${sep}sysparm_count=true"
  else
    url+="${sep}sysparm_${agg_type,,}_fields=$(uri_encode "$field")"
  fi
  sep="&"

  [[ -n "$query" ]]    && url+="${sep}sysparm_query=$(uri_encode "$query")"
  [[ -n "$group_by" ]] && url+="${sep}sysparm_group_by=$(uri_encode "$group_by")"
  [[ -n "$display" ]]  && url+="${sep}sysparm_display_value=$(uri_encode "$display")"

  info "STATS $agg_type on $table"
  local resp
  resp=$(sn_curl GET "$url") || die "Aggregate request failed"
  echo "$resp" | jq '.result'
}

# ── schema ─────────────────────────────────────────────────────────────
cmd_schema() {
  local table="${1:?Usage: sn.sh schema <table> [--fields-only] [--include-inherited]}"
  validate_table_name "$table"
  shift
  local fields_only=false include_inherited=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --fields-only) fields_only=true; shift ;;
      --include-inherited) include_inherited=true; shift ;;
      *) die "Unknown option: $1" ;;
    esac
  done

  local tables_to_query=("$table")

  # Optionally walk parent tables to include inherited fields
  if [[ "$include_inherited" == "true" ]]; then
    info "SCHEMA $table (including inherited fields)"
    local current="$table"
    while [[ -n "$current" ]]; do
      local parent_url="${SNOW_INSTANCE_URL}/api/now/table/sys_db_object?sysparm_query=name=${current}&sysparm_fields=super_class&sysparm_limit=1&sysparm_display_value=true"
      local parent_resp
      parent_resp=$(sn_curl GET "$parent_url" 2>/dev/null) || break
      local parent
      parent=$(echo "$parent_resp" | jq_safe -r '.result[0].super_class // empty')
      if [[ -z "$parent" || "$parent" == "null" ]]; then
        break
      fi
      # Validate API-returned parent table name before using in URL
      if [[ ! "$parent" =~ ^[a-z0-9_]+$ ]]; then
        info "WARNING: Skipping unexpected parent table name: $parent"
        break
      fi
      tables_to_query+=("$parent")
      current="$parent"
    done
    info "Querying fields from: ${tables_to_query[*]}"
  else
    info "SCHEMA $table (via sys_dictionary)"
  fi

  # Query sys_dictionary for each table and merge results
  local all_results="[]"
  for tbl in "${tables_to_query[@]}"; do
    local url="${SNOW_INSTANCE_URL}/api/now/table/sys_dictionary?sysparm_query=name=${tbl}^internal_type!=collection&sysparm_fields=element,column_label,internal_type,max_length,mandatory,reference&sysparm_limit=500&sysparm_display_value=true"
    local resp
    resp=$(sn_curl GET "$url") || die "Schema request failed for table: $tbl"
    all_results=$(echo "$all_results" | jq --argjson new "$(echo "$resp" | jq '.result')" '. + $new')
  done

  if [[ "$fields_only" == "true" ]]; then
    echo "$all_results" | jq '[.[] | select(.element != "") | .element] | unique | sort'
  else
    echo "$all_results" | jq '[.[] | select(.element != "") | {
      field: .element,
      label: .column_label,
      type: .internal_type,
      max_length: .max_length,
      mandatory: .mandatory,
      reference: (if .reference != "" then .reference else null end)
    }] | unique_by(.field) | sort_by(.field)'
  fi
}

# ── attach ─────────────────────────────────────────────────────────────
cmd_attach() {
  local subcmd="${1:?Usage: sn.sh attach <list|download|upload> ...}"
  shift

  case "$subcmd" in
    list)
      local table="${1:?Usage: sn.sh attach list <table> <sys_id>}"
      local sys_id="${2:?Usage: sn.sh attach list <table> <sys_id>}"
      validate_table_name "$table"
      validate_sys_id "$sys_id"
      local url="${SNOW_INSTANCE_URL}/api/now/attachment?sysparm_query=$(uri_encode "table_name=${table}^table_sys_id=${sys_id}")"
      info "LIST attachments on $table/$sys_id"
      sn_curl GET "$url" | jq '[.result[] | {sys_id: .sys_id, file_name: .file_name, size_bytes: .size_bytes, content_type: .content_type, download_link: .download_link}]'
      ;;
    download)
      local att_id="${1:?Usage: sn.sh attach download <attachment_sys_id> <output_path>}"
      local output="${2:?Usage: sn.sh attach download <attachment_sys_id> <output_path>}"
      validate_sys_id "$att_id"
      # Validate output directory exists
      local output_dir
      output_dir=$(dirname "$output")
      [[ -d "$output_dir" ]] || die "Output directory does not exist: $output_dir"
      local url="${SNOW_INSTANCE_URL}/api/now/attachment/${att_id}/file"
      info "DOWNLOAD attachment $att_id → $output"
      sn_curl_file GET "$url" -o "$output" || die "Download failed"
      jq -n --arg p "$output" '{status:"downloaded",path:$p}'
      ;;
    upload)
      local table="${1:?Usage: sn.sh attach upload <table> <sys_id> <file_path> [content_type]}"
      local sys_id="${2:?Usage: sn.sh attach upload <table> <sys_id> <file_path> [content_type]}"
      local filepath="${3:?Usage: sn.sh attach upload <table> <sys_id> <file_path> [content_type]}"
      validate_table_name "$table"
      validate_sys_id "$sys_id"
      local ctype="${4:-application/octet-stream}"
      local filename
      filename=$(basename "$filepath")
      local url="${SNOW_INSTANCE_URL}/api/now/attachment/file?table_name=${table}&table_sys_id=${sys_id}&file_name=$(uri_encode "$filename")"
      info "UPLOAD $filename to $table/$sys_id"
      sn_curl_file POST "$url" \
        -H "Accept: application/json" \
        -H "Content-Type: ${ctype}" \
        --data-binary "@${filepath}" | jq '.result | {sys_id, file_name, size_bytes, table_name, table_sys_id}'
      ;;
    *) die "Unknown attach subcommand: $subcmd (use list, download, upload)" ;;
  esac
}

# ── batch ──────────────────────────────────────────────────────────────
cmd_batch() {
  local table="${1:?Usage: sn.sh batch <table> --query \"<query>\" --action <update|delete> [--fields '{...}'] [--dry-run] [--limit 200] [--confirm]}"
  validate_table_name "$table"
  shift

  local query="" action="" fields="" dry_run=true limit=200 confirmed=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --query)   query="$2";   shift 2 ;;
      --action)  action="$2";  shift 2 ;;
      --fields)  fields="$2";  shift 2 ;;
      --dry-run) dry_run=true; shift ;;
      --limit)   limit="$2"; validate_number "$limit"; shift 2 ;;
      --confirm) confirmed=true; dry_run=false; shift ;;
      *) die "Unknown option: $1" ;;
    esac
  done

  [[ -z "$action" ]] && die "Missing --action <update|delete>"
  [[ "$action" != "update" && "$action" != "delete" ]] && die "--action must be 'update' or 'delete'"
  [[ -z "$query" ]] && die "Missing --query (required for batch operations — refusing to operate on all records)"
  [[ "$action" == "update" && -z "$fields" ]] && die "--fields required for update action"

  # Validate fields JSON if provided
  if [[ -n "$fields" ]]; then
    echo "$fields" | jq . >/dev/null 2>&1 || die "Invalid JSON in --fields — check syntax"
  fi

  # Safety cap on limit
  if (( limit > 10000 )); then
    info "WARNING: Capping limit from $limit to 10000 for safety"
    limit=10000
  fi

  # Step 1: Query matching records (sys_id only for efficiency)
  local url="${SNOW_INSTANCE_URL}/api/now/table/${table}?sysparm_fields=sys_id&sysparm_limit=${limit}"
  url+="&sysparm_query=$(uri_encode "$query")"

  info "Querying $table for matching records..."
  local resp
  resp=$(sn_curl GET "$url") || die "Failed to query matching records"

  local matched
  matched=$(echo "$resp" | jq '.result | length')
  info "Found $matched record(s) matching query on $table"

  # Step 2: Dry-run check
  if [[ "$dry_run" == "true" ]]; then
    jq -n --arg act "$action" --arg tbl "$table" --argjson m "$matched" \
      '{action:$act,table:$tbl,matched:$m,dry_run:true,message:"Dry run — no changes made. Use --confirm to execute."}'
    return 0
  fi

  # Step 3: Safety confirmation
  if [[ "$confirmed" != "true" ]]; then
    die "Must pass --confirm to execute batch $action. Found $matched records. This is a safety measure."
  fi

  if [[ "$matched" -eq 0 ]]; then
    jq -n --arg act "$action" --arg tbl "$table" \
      '{action:$act,table:$tbl,matched:0,processed:0,failed:0}'
    return 0
  fi

  # Step 4: Extract sys_ids and iterate
  local sys_ids
  sys_ids=$(echo "$resp" | jq_safe -r '.result[].sys_id')

  local processed=0 failed=0 total="$matched"

  ensure_token

  while IFS= read -r sys_id; do
    [[ -z "$sys_id" ]] && continue
    ensure_token

    if [[ "$action" == "update" ]]; then
      if sn_curl_try PATCH "${SNOW_INSTANCE_URL}/api/now/table/${table}/${sys_id}" -d "$fields" >/dev/null; then
        processed=$((processed + 1))
      else
        failed=$((failed + 1))
        info "FAILED to update $sys_id (HTTP $_SN_HTTP_CODE)"
      fi
    elif [[ "$action" == "delete" ]]; then
      if sn_curl_try DELETE "${SNOW_INSTANCE_URL}/api/now/table/${table}/${sys_id}" >/dev/null; then
        processed=$((processed + 1))
      else
        failed=$((failed + 1))
        info "FAILED to delete $sys_id (HTTP $_SN_HTTP_CODE)"
      fi
    fi

    # Progress every 10 records or at the end
    if (( (processed + failed) % 10 == 0 )) || (( processed + failed == total )); then
      info "${action^}d $((processed + failed)) of $total records ($failed failed)"
    fi
  done <<< "$sys_ids"

  jq -n --arg act "$action" --arg tbl "$table" --argjson m "$matched" --argjson p "$processed" --argjson f "$failed" \
    '{action:$act,table:$tbl,matched:$m,processed:$p,failed:$f}'
  info "Batch $action complete: $processed succeeded, $failed failed out of $matched"
}

# ── health ─────────────────────────────────────────────────────────────
cmd_health() {
  local check="all"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --check) check="$2"; shift 2 ;;
      *) die "Unknown option: $1" ;;
    esac
  done

  local valid_checks="all version nodes jobs semaphores stats"
  if [[ ! " $valid_checks " =~ " $check " ]]; then
    die "Invalid check: $check (valid: $valid_checks)"
  fi

  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Start building JSON output
  local output
  output=$(jq -n --arg inst "$SNOW_INSTANCE_URL" --arg ts "$timestamp" \
    '{instance: $inst, timestamp: $ts}')

  # ── version check ──
  if [[ "$check" == "all" || "$check" == "version" ]]; then
    info "Checking instance version..."
    local ver_output='{}'

    # Get glide.war (build version)
    local ver_url="${SNOW_INSTANCE_URL}/api/now/table/sys_properties?sysparm_query=name=glide.war&sysparm_fields=value&sysparm_limit=1"
    local ver_resp
    if ver_resp=$(sn_curl GET "$ver_url" 2>/dev/null); then
      local build_val
      build_val=$(echo "$ver_resp" | jq_safe -r '.result[0].value // "unknown"')
      ver_output=$(echo "$ver_output" | jq --arg b "$build_val" '. + {build: $b}')
    else
      ver_output=$(echo "$ver_output" | jq '. + {build: "unavailable"}')
    fi

    # Get build date
    local date_url="${SNOW_INSTANCE_URL}/api/now/table/sys_properties?sysparm_query=name=glide.build.date&sysparm_fields=value&sysparm_limit=1"
    if ver_resp=$(sn_curl GET "$date_url" 2>/dev/null); then
      local build_date
      build_date=$(echo "$ver_resp" | jq_safe -r '.result[0].value // "unknown"')
      ver_output=$(echo "$ver_output" | jq --arg d "$build_date" '. + {build_date: $d}')
    fi

    # Get build tag
    local tag_url="${SNOW_INSTANCE_URL}/api/now/table/sys_properties?sysparm_query=name=glide.build.tag&sysparm_fields=value&sysparm_limit=1"
    if ver_resp=$(sn_curl GET "$tag_url" 2>/dev/null); then
      local build_tag
      build_tag=$(echo "$ver_resp" | jq_safe -r '.result[0].value // "unknown"')
      ver_output=$(echo "$ver_output" | jq --arg t "$build_tag" '. + {build_tag: $t}')
    fi

    output=$(echo "$output" | jq --argjson v "$ver_output" '. + {version: $v}')
    info "Version check complete"
  fi

  # ── nodes check ──
  if [[ "$check" == "all" || "$check" == "nodes" ]]; then
    info "Checking cluster nodes..."
    local nodes_url="${SNOW_INSTANCE_URL}/api/now/table/sys_cluster_state?sysparm_fields=node_id,status,system_id,most_recent_message&sysparm_limit=50"
    local nodes_resp
    if nodes_resp=$(sn_curl GET "$nodes_url" 2>/dev/null); then
      local nodes_arr
      nodes_arr=$(echo "$nodes_resp" | jq '[.result[] | {
        node_id: .node_id,
        status: .status,
        system_id: .system_id,
        most_recent_message: .most_recent_message
      }]')
      output=$(echo "$output" | jq --argjson n "$nodes_arr" '. + {nodes: $n}')
    else
      output=$(echo "$output" | jq '. + {nodes: {"error": "Unable to query sys_cluster_state — check ACLs"}}')
    fi
    info "Nodes check complete"
  fi

  # ── jobs check ──
  if [[ "$check" == "all" || "$check" == "jobs" ]]; then
    info "Checking scheduled jobs..."
    local jobs_query="state=0^next_action<javascript:gs.minutesAgo(30)"
    local jobs_url="${SNOW_INSTANCE_URL}/api/now/table/sys_trigger?sysparm_fields=name,next_action,state,trigger_type&sysparm_limit=20"
    jobs_url+="&sysparm_query=$(uri_encode "$jobs_query")"
    local jobs_resp
    if jobs_resp=$(sn_curl GET "$jobs_url" 2>/dev/null); then
      local stuck_count overdue_list
      stuck_count=$(echo "$jobs_resp" | jq '.result | length')
      overdue_list=$(echo "$jobs_resp" | jq '[.result[] | {
        name: .name,
        next_action: .next_action,
        state: .state,
        trigger_type: .trigger_type
      }]')
      output=$(echo "$output" | jq --argjson sc "$stuck_count" --argjson ol "$overdue_list" \
        '. + {jobs: {stuck: $sc, overdue: $ol}}')
    else
      output=$(echo "$output" | jq '. + {jobs: {"error": "Unable to query sys_trigger — check ACLs"}}')
    fi
    info "Jobs check complete"
  fi

  # ── semaphores check ──
  if [[ "$check" == "all" || "$check" == "semaphores" ]]; then
    info "Checking semaphores..."
    local sem_url="${SNOW_INSTANCE_URL}/api/now/table/sys_semaphore?sysparm_query=state=active&sysparm_fields=name,state,holder&sysparm_limit=20"
    local sem_resp
    if sem_resp=$(sn_curl GET "$sem_url" 2>/dev/null); then
      local sem_count sem_list
      sem_count=$(echo "$sem_resp" | jq '.result | length')
      sem_list=$(echo "$sem_resp" | jq '[.result[] | {
        name: .name,
        state: .state,
        holder: .holder
      }]')
      output=$(echo "$output" | jq --argjson ac "$sem_count" --argjson sl "$sem_list" \
        '. + {semaphores: {active: $ac, list: $sl}}')
    else
      output=$(echo "$output" | jq '. + {semaphores: {"error": "Unable to query sys_semaphore — check ACLs"}}')
    fi
    info "Semaphores check complete"
  fi

  # ── stats check ──
  if [[ "$check" == "all" || "$check" == "stats" ]]; then
    info "Gathering instance stats..."
    local stats_output='{}'

    # Active incidents (state != 7 = Closed)
    local inc_url="${SNOW_INSTANCE_URL}/api/now/stats/incident?sysparm_count=true&sysparm_query=$(uri_encode 'state!=7')"
    local inc_resp
    if inc_resp=$(sn_curl GET "$inc_url" 2>/dev/null); then
      local inc_count
      inc_count=$(echo "$inc_resp" | jq_safe -r '.result.stats.count // "0"')
      stats_output=$(echo "$stats_output" | jq --arg c "$inc_count" '. + {incidents_active: ($c | tonumber)}')
    fi

    # Open P1 incidents
    local p1_url="${SNOW_INSTANCE_URL}/api/now/stats/incident?sysparm_count=true&sysparm_query=$(uri_encode 'active=true^priority=1')"
    local p1_resp
    if p1_resp=$(sn_curl GET "$p1_url" 2>/dev/null); then
      local p1_count
      p1_count=$(echo "$p1_resp" | jq_safe -r '.result.stats.count // "0"')
      stats_output=$(echo "$stats_output" | jq --arg c "$p1_count" '. + {p1_open: ($c | tonumber)}')
    fi

    # Active changes
    local chg_url="${SNOW_INSTANCE_URL}/api/now/stats/change_request?sysparm_count=true&sysparm_query=$(uri_encode 'active=true')"
    local chg_resp
    if chg_resp=$(sn_curl GET "$chg_url" 2>/dev/null); then
      local chg_count
      chg_count=$(echo "$chg_resp" | jq_safe -r '.result.stats.count // "0"')
      stats_output=$(echo "$stats_output" | jq --arg c "$chg_count" '. + {changes_active: ($c | tonumber)}')
    fi

    # Open problems
    local prb_url="${SNOW_INSTANCE_URL}/api/now/stats/problem?sysparm_count=true&sysparm_query=$(uri_encode 'active=true')"
    local prb_resp
    if prb_resp=$(sn_curl GET "$prb_url" 2>/dev/null); then
      local prb_count
      prb_count=$(echo "$prb_resp" | jq_safe -r '.result.stats.count // "0"')
      stats_output=$(echo "$stats_output" | jq --arg c "$prb_count" '. + {problems_open: ($c | tonumber)}')
    fi

    output=$(echo "$output" | jq --argjson s "$stats_output" '. + {stats: $s}')
    info "Stats check complete"
  fi

  echo "$output" | jq .
}

# ── Main dispatcher ────────────────────────────────────────────────────
cmd="${1:?Usage: sn.sh <query|get|create|update|delete|aggregate|schema|attach|batch|health> ...}"
shift

case "$cmd" in
  query)     cmd_query "$@" ;;
  get)       cmd_get "$@" ;;
  create)    cmd_create "$@" ;;
  update)    cmd_update "$@" ;;
  delete)    cmd_delete "$@" ;;
  aggregate) cmd_aggregate "$@" ;;
  schema)    cmd_schema "$@" ;;
  attach)    cmd_attach "$@" ;;
  batch)     cmd_batch "$@" ;;
  health)    cmd_health "$@" ;;
  *)         die "Unknown command: $cmd" ;;
esac
