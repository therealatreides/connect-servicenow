#!/usr/bin/env bats
# Tests for native .env file reading and --instance flag (sn.sh startup logic)

setup() {
  load '../helpers/test_helper'
  load '../helpers/mock_curl'
  # Clean env before each test
  teardown_env
  unset SNOW_ENV_FILE SNOW_ENV_PREFIX SNOW_TOKEN_CACHE 2>/dev/null || true
  ENV_FIXTURES="${FIXTURES_DIR}/env_files"
}

teardown() {
  teardown_env
  teardown_mock_curl 2>/dev/null || true
  unset SNOW_ENV_FILE SNOW_ENV_PREFIX SNOW_TOKEN_CACHE 2>/dev/null || true
}

# ── --instance flag selects named instance ─────────────────────────

@test "env-loading: --instance flag selects named instance from .env" {
  setup_mock_curl
  mock_curl_response '{"result":[]}' 200
  run bash "$SCRIPT_PATH" --env-file="${ENV_FIXTURES}/multi_instance.env" --instance=DEV query incident --limit 1
  assert_success
  teardown_mock_curl
}

@test "env-loading: --instance=DEV maps SNOW_DEV_* to SNOW_*" {
  # Source env loading functions by running sn.sh and checking it picks the right URL
  setup_mock_curl
  mock_curl_response '{"result":[]}' 200
  run bash "$SCRIPT_PATH" --env-file="${ENV_FIXTURES}/multi_instance.env" --instance=DEV query incident --limit 1
  assert_success
  local call_args
  call_args=$(mock_curl_call_args 1)
  assert [ "$(echo "$call_args" | grep -c 'dev-test.service-now.com')" -gt 0 ]
  teardown_mock_curl
}

@test "env-loading: --instance=TEST selects TEST instance" {
  setup_mock_curl
  mock_curl_response '{"result":[]}' 200
  run bash "$SCRIPT_PATH" --env-file="${ENV_FIXTURES}/multi_instance.env" --instance=TEST query incident --limit 1
  assert_success
  local call_args
  call_args=$(mock_curl_call_args 1)
  assert [ "$(echo "$call_args" | grep -c 'test-test.service-now.com')" -gt 0 ]
  teardown_mock_curl
}

# ── Auto-detect single instance ──────────────────────────────────

@test "env-loading: auto-detect single instance when no --instance given" {
  setup_mock_curl
  mock_curl_response '{"result":[]}' 200
  run bash "$SCRIPT_PATH" --env-file="${ENV_FIXTURES}/single_instance.env" query incident --limit 1
  assert_success
  local call_args
  call_args=$(mock_curl_call_args 1)
  assert [ "$(echo "$call_args" | grep -c 'single-test.service-now.com')" -gt 0 ]
  teardown_mock_curl
}

# ── Error on multiple instances without --instance ────────────────

@test "env-loading: error on multiple instances without --instance flag" {
  run bash "$SCRIPT_PATH" --env-file="${ENV_FIXTURES}/multi_instance.env" query incident --limit 1
  assert_failure
  assert_output --partial "Multiple instances found"
  assert_output --partial "--instance="
}

# ── Pre-exported vars take precedence ────────────────────────────

@test "env-loading: pre-exported vars take precedence over .env" {
  setup_mock_curl
  mock_curl_response '{"result":[]}' 200
  export SNOW_INSTANCE_URL="https://pre-exported.service-now.com"
  export SNOW_AUTH_TYPE="basic"
  export SNOW_USERNAME="preuser"
  export SNOW_PASSWORD="prepass"
  run bash "$SCRIPT_PATH" --env-file="${ENV_FIXTURES}/single_instance.env" query incident --limit 1
  assert_success
  local call_args
  call_args=$(mock_curl_call_args 1)
  # Should use pre-exported URL, not the one from .env
  assert [ "$(echo "$call_args" | grep -c 'pre-exported.service-now.com')" -gt 0 ]
  teardown_mock_curl
}

# ── Nonexistent .env file ────────────────────────────────────────

@test "env-loading: error when --env-file points to nonexistent file" {
  run bash "$SCRIPT_PATH" --env-file="/tmp/nonexistent_12345.env" query incident --limit 1
  assert_failure
  assert_output --partial ".env file not found"
}

# ── Invalid instance alias ───────────────────────────────────────

@test "env-loading: error when --instance alias not found in .env" {
  run bash "$SCRIPT_PATH" --env-file="${ENV_FIXTURES}/multi_instance.env" --instance=PROD query incident --limit 1
  assert_failure
  assert_output --partial "Instance 'PROD' not found"
}

# ── Special characters in secrets ────────────────────────────────

@test "env-loading: special characters in client secret loaded without shell expansion" {
  # This test verifies the .env is parsed safely — the secret contains )};<!*+(
  # sn.sh will fail at OAuth token acquisition (no real server), but it should NOT
  # fail during .env parsing with a shell syntax error
  run bash "$SCRIPT_PATH" --env-file="${ENV_FIXTURES}/special_chars.env" --instance=DEV health --check version
  # Should fail with connection error (no server), NOT a shell parsing error
  assert_failure
  refute_output --partial "syntax error"
  refute_output --partial "unexpected token"
}

# ── Token caching vars auto-set ──────────────────────────────────

@test "env-loading: SNOW_ENV_FILE and SNOW_ENV_PREFIX set when reading .env" {
  # We test indirectly: the token cache write-back requires SNOW_ENV_FILE.
  # If it's set correctly, the script proceeds past env validation.
  setup_mock_curl
  mock_curl_response '{"result":[]}' 200
  run bash "$SCRIPT_PATH" --env-file="${ENV_FIXTURES}/single_instance.env" query incident --limit 1
  assert_success
  teardown_mock_curl
}

# ── Global flags stripped from command args ───────────────────────

@test "env-loading: --instance and --env-file flags are not passed to command" {
  setup_mock_curl
  mock_curl_response '{"result":[]}' 200
  # If flags leak through, sn.sh would try to use them as table name or options
  run bash "$SCRIPT_PATH" --env-file="${ENV_FIXTURES}/single_instance.env" query incident --limit 1
  assert_success
  teardown_mock_curl
}
