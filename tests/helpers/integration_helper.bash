#!/usr/bin/env bash
# Integration test helper — loads real PDI credentials and provides
# cleanup tracking for self-cleaning tests.
#
# Usage in .bats files:
#   setup() {
#     load '../helpers/test_helper'
#     load '../helpers/integration_helper'
#     load_test_env
#   }
#   teardown() {
#     cleanup_test_records
#   }

# ── Credential loading ───────────────────────────────────────────────

# Multi-profile support: Set SNOW_PROFILE env var before running tests.
#   SNOW_PROFILE=""      (default) — uses SNOW_* variables directly (basic auth)
#   SNOW_PROFILE="pdi"   — maps SNOW_PDI_* variables to SNOW_*
#   SNOW_PROFILE="foo"   — maps SNOW_FOO_* variables to SNOW_*
#
# This allows .env.test to hold multiple credential sets with different prefixes.

load_test_env() {
  local env_file="${PROJECT_ROOT}/tests/.env.test"
  if [[ ! -f "$env_file" ]]; then
    skip "No tests/.env.test file found — integration tests require PDI credentials"
  fi

  # Parse the env file line-by-line (never use 'source' — special chars in secrets break it)
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    local name="${line%%=*}"
    local value="${line#*=}"
    name=$(echo "$name" | xargs)
    [[ "$name" == SNOW_* ]] && export "$name=$value"
  done < "$env_file"

  # If a profile is active, map prefixed vars to SNOW_* vars
  if [[ -n "${SNOW_PROFILE:-}" ]]; then
    local prefix="SNOW_${SNOW_PROFILE^^}_"  # e.g. SNOW_PDI_
    local mapped=0

    # Map each prefixed variable to its SNOW_ equivalent
    # Note: uses parameter expansion (not IFS='=') to preserve trailing '=' in base64 values
    while IFS= read -r line; do
      local name="${line%%=*}"
      local value="${line#*=}"
      if [[ "$name" == ${prefix}* ]]; then
        local snow_name="SNOW_${name#${prefix}}"
        export "$snow_name=$value"
        mapped=$((mapped + 1))
      fi
    done < <(env | grep "^${prefix}")

    if [[ "$mapped" -eq 0 ]]; then
      skip "Profile '${SNOW_PROFILE}' — no ${prefix}* variables found in .env.test"
    fi
  fi

  # Decode base64-encoded credentials (avoids shell escaping issues with special chars)
  # Convention: SNOW_PASSWORD_B64 → SNOW_PASSWORD, SNOW_CLIENT_SECRET_B64 → SNOW_CLIENT_SECRET
  if [[ -n "${SNOW_PASSWORD_B64:-}" ]]; then
    export SNOW_PASSWORD
    SNOW_PASSWORD=$(echo "$SNOW_PASSWORD_B64" | base64 -d)
  fi
  if [[ -n "${SNOW_CLIENT_SECRET_B64:-}" ]]; then
    export SNOW_CLIENT_SECRET
    SNOW_CLIENT_SECRET=$(echo "$SNOW_CLIENT_SECRET_B64" | base64 -d)
  fi

  # Validate minimum required vars are set
  if [[ -z "${SNOW_INSTANCE_URL:-}" ]]; then
    skip "SNOW_INSTANCE_URL not set in tests/.env.test"
  fi
}

# ── Cleanup tracking ─────────────────────────────────────────────────

# Array of "table:sys_id" entries to delete in teardown
CLEANUP_RECORDS=()

# Register a record for cleanup in teardown.
# Usage: register_cleanup <table> <sys_id>
register_cleanup() {
  CLEANUP_RECORDS+=("$1:$2")
}

# Delete all registered records. Called in teardown().
# Silently ignores failures (record may already be deleted by the test).
cleanup_test_records() {
  for entry in "${CLEANUP_RECORDS[@]:-}"; do
    [[ -z "$entry" ]] && continue
    local table="${entry%%:*}"
    local sys_id="${entry##*:}"
    bash "$SCRIPT_PATH" delete "$table" "$sys_id" --confirm 2>/dev/null || true
  done
  CLEANUP_RECORDS=()
}

# ── Test record helpers ──────────────────────────────────────────────

# Unique marker prefix for test records (includes PID for parallel safety)
TEST_RECORD_MARKER="BATS_TEST_RECORD_$$"

# Create a test incident and return its sys_id.
# Automatically registered for cleanup.
# Usage: sys_id=$(create_test_incident "optional extra description")
create_test_incident() {
  local extra="${1:-}"
  local desc="${TEST_RECORD_MARKER} ${extra} -- auto-created, safe to delete"
  local json
  json=$(jq -n --arg d "$desc" '{"short_description":$d,"urgency":"3","impact":"3"}')

  local result
  result=$(bash "$SCRIPT_PATH" create incident "$json" 2>/dev/null)
  local sys_id
  sys_id=$(echo "$result" | jq -r '.sys_id')

  if [[ -z "$sys_id" || "$sys_id" == "null" ]]; then
    echo "FAILED_TO_CREATE"
    return 1
  fi

  register_cleanup "incident" "$sys_id"
  echo "$sys_id"
}

# Verify a record exists by fetching it. Returns 0 if found, 1 if not.
# Usage: record_exists incident <sys_id>
record_exists() {
  local table="$1" sys_id="$2"
  bash "$SCRIPT_PATH" get "$table" "$sys_id" >/dev/null 2>&1
}
