#!/usr/bin/env bash
# Shared test helper — loaded by every .bats file via:
#   load '../helpers/test_helper'   (from unit/ or integration/)

# ── Path resolution ──────────────────────────────────────────────────
PROJECT_ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
SCRIPT_PATH="${PROJECT_ROOT}/src/skills/connect-servicenow/scripts/sn.sh"
FIXTURES_DIR="${PROJECT_ROOT}/tests/fixtures"
HELPERS_DIR="${PROJECT_ROOT}/tests/helpers"

# ── Load bats libraries ─────────────────────────────────────────────
load "${PROJECT_ROOT}/tests/bats/bats-support/load"
load "${PROJECT_ROOT}/tests/bats/bats-assert/load"

# ── Fake environment for unit tests ─────────────────────────────────
# Sets minimal valid env vars for basic auth pointing at a fake URL.
# This allows the script to pass env validation without hitting any network.
setup_fake_env() {
  export SNOW_INSTANCE_URL="https://fake-instance.service-now.com"
  export SNOW_AUTH_TYPE="basic"
  export SNOW_USERNAME="testuser"
  export SNOW_PASSWORD="testpass"
}

# Clean up all SNOW_* env vars
teardown_env() {
  unset SNOW_INSTANCE_URL SNOW_AUTH_TYPE SNOW_USERNAME SNOW_PASSWORD \
        SNOW_CLIENT_ID SNOW_CLIENT_SECRET 2>/dev/null || true
}

# ── Convenience runner ───────────────────────────────────────────────
# Run sn.sh and capture stdout, stderr, and exit code via bats `run`.
# Usage: run_sn <args...>
run_sn() {
  run bash "$SCRIPT_PATH" "$@"
}

# A valid 32-char hex sys_id for use in tests
VALID_SYS_ID="6816f79cc0a8016401c5a33be04be441"

# ── JSON output helpers ──────────────────────────────────────────────
# Extract JSON from mixed bats output (removes → info and ERROR lines).
# bats captures both stdout and stderr in $output, so info() and die()
# messages appear mixed with JSON output. This strips them.
# Usage: json_output | jq -e '.key'
json_output() {
  echo "$output" | grep -v '^→ ' | grep -v '^ERROR:'
}
