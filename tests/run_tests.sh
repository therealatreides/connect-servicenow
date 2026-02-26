#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────
# ServiceNow Connector — Test Runner
# Runs unit and/or integration tests using bats-core.
#
# Usage:
#   bash tests/run_tests.sh [OPTIONS]
#
# Options:
#   --unit          Run unit tests only (no network required)
#   --integration   Run integration tests only (requires .env.test)
#   --all           Run all tests (default)
#   --file <path>   Run a specific test file
#   --profile <name> Run integration tests with a specific credential profile
#                    (default = auto-detect all profiles in .env.test)
#   --cleanup       Clean up orphaned test records from PDI
#   --verbose       Show individual test output
#   --help          Show this help
# ──────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BATS="${SCRIPT_DIR}/bats/bats-core/bin/bats"
SN_SCRIPT="${PROJECT_ROOT}/src/skills/connect-servicenow/scripts/sn.sh"

# ── Usage ────────────────────────────────────────────────────────────

usage() {
  cat << 'EOF'
ServiceNow Connector — Test Runner

Usage: bash tests/run_tests.sh [OPTIONS]

Options:
  --unit          Run unit tests only (no network required)
  --integration   Run integration tests only (requires .env.test)
  --all           Run all tests (default)
  --file <path>   Run a specific test file
  --profile <name> Run integration tests with a specific credential profile
                   Use "default" for SNOW_* vars, or a prefix like "pdi" for SNOW_PDI_*
                   Omit to auto-detect and run all profiles
  --cleanup       Clean up orphaned test records from PDI
  --verbose       Show individual test output
  --help          Show this help

Multi-Profile Support:
  Your .env.test can contain multiple credential sets using prefixes:
    SNOW_INSTANCE_URL=...       # default profile (basic auth)
    SNOW_AUTH_TYPE=basic
    SNOW_USERNAME=admin
    SNOW_PASSWORD=secret

    SNOW_PDI_INSTANCE_URL=...   # "pdi" profile (OAuth)
    SNOW_PDI_AUTH_TYPE=oauth_client_credentials
    SNOW_PDI_CLIENT_ID=...
    SNOW_PDI_CLIENT_SECRET=...

  Running --all or --integration auto-detects profiles and runs tests for each.

Setup:
  1. bash tests/setup.sh              # Download bats-core
  2. cp tests/.env.test.example tests/.env.test
  3. Edit tests/.env.test with your PDI credentials
  4. bash tests/run_tests.sh --unit    # Run unit tests (no network)
  5. bash tests/run_tests.sh --all     # Run all tests
EOF
}

# ── Argument Parsing ─────────────────────────────────────────────────

MODE="all"
BATS_ARGS=("--print-output-on-failure")
SPECIFIC_FILE=""
PROFILE_ARG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --unit)         MODE="unit"; shift ;;
    --integration)  MODE="integration"; shift ;;
    --all)          MODE="all"; shift ;;
    --file)         MODE="file"; SPECIFIC_FILE="$2"; shift 2 ;;
    --profile)      PROFILE_ARG="$2"; shift 2 ;;
    --cleanup)      MODE="cleanup"; shift ;;
    --verbose)      BATS_ARGS+=("--verbose-run"); shift ;;
    --help)         usage; exit 0 ;;
    *)              echo "Unknown option: $1"; echo ""; usage; exit 1 ;;
  esac
done

# ── Prerequisite Checks ─────────────────────────────────────────────

echo "=== ServiceNow Connector Test Suite ==="
echo ""

# Check bats
if [[ ! -f "$BATS" ]]; then
  echo "ERROR: bats-core not found."
  echo "Run: bash tests/setup.sh"
  exit 1
fi

# Check jq
if ! command -v jq &>/dev/null; then
  echo "ERROR: jq is required but not found in PATH."
  echo "Install: winget install jqlang.jq  (or scoop install jq)"
  exit 1
fi

# Check curl
if ! command -v curl &>/dev/null; then
  echo "ERROR: curl is required but not found in PATH."
  exit 1
fi

echo "  bats:  $("$BATS" --version)"
echo "  jq:    $(jq --version)"
echo "  curl:  $(curl --version | head -1)"
echo ""

# ── Profile Detection ────────────────────────────────────────────────

# Detect available credential profiles from .env.test
# Returns a space-separated list like "default pdi"
detect_profiles() {
  local env_file="${SCRIPT_DIR}/.env.test"
  [[ ! -f "$env_file" ]] && return

  local profiles=()
  local has_default=false

  # Check for default SNOW_INSTANCE_URL (not prefixed)
  if grep -qE '^SNOW_INSTANCE_URL=' "$env_file"; then
    has_default=true
    profiles+=("default")
  fi

  # Find prefixed profiles: SNOW_<PREFIX>_INSTANCE_URL
  while IFS= read -r line; do
    # Extract the prefix between SNOW_ and _INSTANCE_URL
    local prefix
    prefix=$(echo "$line" | sed -n 's/^SNOW_\([A-Z0-9_]*\)_INSTANCE_URL=.*/\1/p')
    if [[ -n "$prefix" ]]; then
      profiles+=("$(echo "$prefix" | tr '[:upper:]' '[:lower:]')")
    fi
  done < <(grep -E '^SNOW_[A-Z0-9]+_INSTANCE_URL=' "$env_file" 2>/dev/null || true)

  echo "${profiles[*]}"
}

# Get human-readable description for a profile
profile_description() {
  local profile="$1"
  local env_file="${SCRIPT_DIR}/.env.test"

  if [[ "$profile" == "default" ]]; then
    local auth_type url
    auth_type=$(grep -E '^SNOW_AUTH_TYPE=' "$env_file" | tail -1 | cut -d'=' -f2-)
    url=$(grep -E '^SNOW_INSTANCE_URL=' "$env_file" | tail -1 | cut -d'=' -f2-)
    echo "${auth_type:-basic} @ ${url:-unknown}"
  else
    local prefix="SNOW_${profile^^}_"
    local auth_type url
    auth_type=$(grep -E "^${prefix}AUTH_TYPE=" "$env_file" | tail -1 | cut -d'=' -f2-)
    url=$(grep -E "^${prefix}INSTANCE_URL=" "$env_file" | tail -1 | cut -d'=' -f2-)
    echo "${auth_type:-unknown} @ ${url:-unknown}"
  fi
}

# ── Test Runners ─────────────────────────────────────────────────────

UNIT_EXIT=0
INTEGRATION_EXIT=0

run_unit() {
  echo "--- Unit Tests (no network required) ---"
  echo ""
  "$BATS" "${BATS_ARGS[@]}" "${SCRIPT_DIR}/unit/" || UNIT_EXIT=$?
  echo ""
  return $UNIT_EXIT
}

run_integration_for_profile() {
  local profile="$1"
  local profile_exit=0

  # Set the profile env var for integration_helper.bash
  if [[ "$profile" == "default" ]]; then
    export SNOW_PROFILE=""
  else
    export SNOW_PROFILE="$profile"
  fi

  local desc
  desc=$(profile_description "$profile")
  echo "  ┌─────────────────────────────────────────────────────"
  echo "  │ Profile: $profile ($desc)"
  echo "  └─────────────────────────────────────────────────────"
  echo ""

  # Connection test as a gate
  echo "  [gate] Checking connectivity for profile '$profile'..."
  if ! "$BATS" "${BATS_ARGS[@]}" "${SCRIPT_DIR}/integration/test_connection.bats"; then
    echo ""
    echo "  FAIL: Connection test failed for profile '$profile'. Skipping remaining tests."
    echo ""
    return 1
  fi
  echo ""

  # Read-only tests
  echo "  [read] Running read-only tests..."
  "$BATS" "${BATS_ARGS[@]}" \
    "${SCRIPT_DIR}/integration/test_query.bats" \
    "${SCRIPT_DIR}/integration/test_get.bats" \
    "${SCRIPT_DIR}/integration/test_schema.bats" \
    "${SCRIPT_DIR}/integration/test_aggregate.bats" \
    "${SCRIPT_DIR}/integration/test_health.bats" || profile_exit=$?
  echo ""

  # Mutation tests
  echo "  [write] Running mutation tests..."
  "$BATS" "${BATS_ARGS[@]}" \
    "${SCRIPT_DIR}/integration/test_create.bats" \
    "${SCRIPT_DIR}/integration/test_update.bats" \
    "${SCRIPT_DIR}/integration/test_delete.bats" \
    "${SCRIPT_DIR}/integration/test_crud_lifecycle.bats" || profile_exit=$?
  echo ""

  # Attachment and batch tests
  echo "  [bulk] Running attachment and batch tests..."
  "$BATS" "${BATS_ARGS[@]}" \
    "${SCRIPT_DIR}/integration/test_attach.bats" \
    "${SCRIPT_DIR}/integration/test_batch.bats" || profile_exit=$?
  echo ""

  # Clean up profile var
  unset SNOW_PROFILE

  return $profile_exit
}

run_integration() {
  if [[ ! -f "${SCRIPT_DIR}/.env.test" ]]; then
    echo "--- Integration Tests ---"
    echo "SKIP: tests/.env.test not found."
    echo "Copy tests/.env.test.example to tests/.env.test and fill in PDI credentials."
    echo ""
    return 0
  fi

  # Determine which profiles to run
  local profiles_to_run=()
  if [[ -n "$PROFILE_ARG" ]]; then
    profiles_to_run=("$PROFILE_ARG")
  else
    read -ra profiles_to_run <<< "$(detect_profiles)"
  fi

  if [[ ${#profiles_to_run[@]} -eq 0 ]]; then
    echo "--- Integration Tests ---"
    echo "SKIP: No credential profiles detected in tests/.env.test"
    echo ""
    return 0
  fi

  echo "--- Integration Tests (live PDI) ---"
  echo ""
  echo "  Detected profiles: ${profiles_to_run[*]}"
  echo ""

  local any_failed=0
  for profile in "${profiles_to_run[@]}"; do
    if ! run_integration_for_profile "$profile"; then
      any_failed=1
    fi
    echo "  ─────────────────────────────────────────────────────"
    echo ""
  done

  if [[ "$any_failed" -ne 0 ]]; then
    INTEGRATION_EXIT=1
  fi

  return $INTEGRATION_EXIT
}

run_cleanup() {
  if [[ ! -f "${SCRIPT_DIR}/.env.test" ]]; then
    echo "ERROR: Cleanup requires tests/.env.test"
    exit 1
  fi

  # Parse env file line-by-line (never use 'source' — special chars in secrets break it)
  while IFS= read -r _line || [[ -n "$_line" ]]; do
    [[ -z "$_line" || "$_line" =~ ^[[:space:]]*# ]] && continue
    _name="${_line%%=*}"; _value="${_line#*=}"; _name=$(echo "$_name" | xargs)
    [[ "$_name" == SNOW_* ]] && export "$_name=$_value"
  done < "${SCRIPT_DIR}/.env.test"
  unset _line _name _value

  echo "Searching for orphaned BATS_TEST_RECORD entries on incident table..."
  local result
  result=$(bash "$SN_SCRIPT" query incident \
    --query "short_descriptionLIKEBATS_TEST_RECORD" \
    --fields "sys_id,short_description" \
    --limit 100 2>/dev/null) || {
    echo "ERROR: Query failed. Check your .env.test credentials."
    exit 1
  }

  local count
  count=$(echo "$result" | jq '.record_count')
  echo "Found $count orphaned test record(s)."

  if [[ "$count" -gt 0 ]]; then
    echo "$result" | jq -r '.results[].sys_id' | while IFS= read -r sid; do
      echo "  Deleting $sid..."
      bash "$SN_SCRIPT" delete incident "$sid" --confirm 2>/dev/null || echo "    (failed to delete $sid)"
    done
    echo "Cleanup complete."
  else
    echo "No orphaned records found."
  fi
}

# ── Execute ──────────────────────────────────────────────────────────

case "$MODE" in
  unit)
    run_unit
    ;;
  integration)
    run_integration
    ;;
  all)
    run_unit || true
    run_integration || true
    ;;
  file)
    if [[ ! -f "$SPECIFIC_FILE" ]]; then
      echo "ERROR: File not found: $SPECIFIC_FILE"
      exit 1
    fi
    "$BATS" "${BATS_ARGS[@]}" "$SPECIFIC_FILE"
    ;;
  cleanup)
    run_cleanup
    ;;
esac

# ── Summary ──────────────────────────────────────────────────────────

echo "=== Done ==="

if [[ "$UNIT_EXIT" -ne 0 || "$INTEGRATION_EXIT" -ne 0 ]]; then
  exit 1
fi
