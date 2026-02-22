#!/usr/bin/env bats
# Tests for environment variable validation and configuration (sn.sh lines 17-44)

setup() {
  load '../helpers/test_helper'
  # Deliberately do NOT set up env — each test controls its own env
}

teardown() {
  teardown_env
}

# ── SNOW_INSTANCE_URL ────────────────────────────────────────────────

@test "env: missing SNOW_INSTANCE_URL exits with error" {
  unset SNOW_INSTANCE_URL
  export SNOW_AUTH_TYPE="basic"
  export SNOW_USERNAME="user"
  export SNOW_PASSWORD="pass"
  run bash "$SCRIPT_PATH" query incident
  assert_failure
  assert_output --partial "SNOW_INSTANCE_URL"
}

@test "env: SNOW_INSTANCE_URL trailing slash is normalized" {
  load '../helpers/mock_curl'
  setup_mock_curl
  mock_curl_response '{"result":[]}' 200
  export SNOW_INSTANCE_URL="https://myinstance.service-now.com/"
  export SNOW_AUTH_TYPE="basic"
  export SNOW_USERNAME="user"
  export SNOW_PASSWORD="pass"
  run bash "$SCRIPT_PATH" query incident --limit 1
  assert_success
  local call_args
  call_args=$(mock_curl_call_args 1)
  # URL should not have double slash before /api
  refute [ "$(echo "$call_args" | grep -c '\.com//api')" -gt 0 ]
  teardown_mock_curl
}

@test "env: SNOW_INSTANCE_URL without https:// gets it prepended" {
  load '../helpers/mock_curl'
  setup_mock_curl
  mock_curl_response '{"result":[]}' 200
  export SNOW_INSTANCE_URL="myinstance.service-now.com"
  export SNOW_AUTH_TYPE="basic"
  export SNOW_USERNAME="user"
  export SNOW_PASSWORD="pass"
  run bash "$SCRIPT_PATH" query incident --limit 1
  assert_success
  local call_args
  call_args=$(mock_curl_call_args 1)
  assert [ "$(echo "$call_args" | grep -c 'https://myinstance')" -gt 0 ]
  teardown_mock_curl
}

# ── SNOW_AUTH_TYPE ───────────────────────────────────────────────────

@test "env: SNOW_AUTH_TYPE defaults to basic when unset" {
  load '../helpers/mock_curl'
  setup_mock_curl
  mock_curl_response '{"result":[]}' 200
  export SNOW_INSTANCE_URL="https://fake.service-now.com"
  unset SNOW_AUTH_TYPE
  export SNOW_USERNAME="user"
  export SNOW_PASSWORD="pass"
  run bash "$SCRIPT_PATH" query incident --limit 1
  assert_success
  teardown_mock_curl
}

@test "env: unknown SNOW_AUTH_TYPE exits with error" {
  export SNOW_INSTANCE_URL="https://fake.service-now.com"
  export SNOW_AUTH_TYPE="kerberos"
  export SNOW_USERNAME="user"
  export SNOW_PASSWORD="pass"
  run bash "$SCRIPT_PATH" query incident
  assert_failure
  assert_output --partial "Unknown SNOW_AUTH_TYPE: kerberos"
}

# ── Basic auth required fields ───────────────────────────────────────

@test "env: basic auth requires SNOW_USERNAME" {
  export SNOW_INSTANCE_URL="https://fake.service-now.com"
  export SNOW_AUTH_TYPE="basic"
  unset SNOW_USERNAME
  export SNOW_PASSWORD="pass"
  run bash "$SCRIPT_PATH" query incident
  assert_failure
  assert_output --partial "SNOW_USERNAME"
}

@test "env: basic auth requires SNOW_PASSWORD" {
  export SNOW_INSTANCE_URL="https://fake.service-now.com"
  export SNOW_AUTH_TYPE="basic"
  export SNOW_USERNAME="user"
  unset SNOW_PASSWORD
  run bash "$SCRIPT_PATH" query incident
  assert_failure
  assert_output --partial "SNOW_PASSWORD"
}

# ── OAuth ROPC required fields ───────────────────────────────────────

@test "env: oauth_ropc requires SNOW_CLIENT_ID" {
  export SNOW_INSTANCE_URL="https://fake.service-now.com"
  export SNOW_AUTH_TYPE="oauth_ropc"
  unset SNOW_CLIENT_ID
  export SNOW_CLIENT_SECRET="secret"
  export SNOW_USERNAME="user"
  export SNOW_PASSWORD="pass"
  run bash "$SCRIPT_PATH" query incident
  assert_failure
  assert_output --partial "SNOW_CLIENT_ID"
}

@test "env: oauth_ropc requires SNOW_CLIENT_SECRET" {
  export SNOW_INSTANCE_URL="https://fake.service-now.com"
  export SNOW_AUTH_TYPE="oauth_ropc"
  export SNOW_CLIENT_ID="clientid"
  unset SNOW_CLIENT_SECRET
  export SNOW_USERNAME="user"
  export SNOW_PASSWORD="pass"
  run bash "$SCRIPT_PATH" query incident
  assert_failure
  assert_output --partial "SNOW_CLIENT_SECRET"
}

@test "env: oauth_ropc requires SNOW_USERNAME" {
  export SNOW_INSTANCE_URL="https://fake.service-now.com"
  export SNOW_AUTH_TYPE="oauth_ropc"
  export SNOW_CLIENT_ID="clientid"
  export SNOW_CLIENT_SECRET="secret"
  unset SNOW_USERNAME
  export SNOW_PASSWORD="pass"
  run bash "$SCRIPT_PATH" query incident
  assert_failure
  assert_output --partial "SNOW_USERNAME"
}

@test "env: oauth_ropc requires SNOW_PASSWORD" {
  export SNOW_INSTANCE_URL="https://fake.service-now.com"
  export SNOW_AUTH_TYPE="oauth_ropc"
  export SNOW_CLIENT_ID="clientid"
  export SNOW_CLIENT_SECRET="secret"
  export SNOW_USERNAME="user"
  unset SNOW_PASSWORD
  run bash "$SCRIPT_PATH" query incident
  assert_failure
  assert_output --partial "SNOW_PASSWORD"
}

# ── OAuth Client Credentials required fields ─────────────────────────

@test "env: oauth_client_credentials requires SNOW_CLIENT_ID" {
  export SNOW_INSTANCE_URL="https://fake.service-now.com"
  export SNOW_AUTH_TYPE="oauth_client_credentials"
  unset SNOW_CLIENT_ID
  export SNOW_CLIENT_SECRET="secret"
  run bash "$SCRIPT_PATH" query incident
  assert_failure
  assert_output --partial "SNOW_CLIENT_ID"
}

@test "env: oauth_client_credentials requires SNOW_CLIENT_SECRET" {
  export SNOW_INSTANCE_URL="https://fake.service-now.com"
  export SNOW_AUTH_TYPE="oauth_client_credentials"
  export SNOW_CLIENT_ID="clientid"
  unset SNOW_CLIENT_SECRET
  run bash "$SCRIPT_PATH" query incident
  assert_failure
  assert_output --partial "SNOW_CLIENT_SECRET"
}

# ── No command argument ──────────────────────────────────────────────

@test "env: no command argument exits with error" {
  setup_fake_env
  run bash "$SCRIPT_PATH"
  assert_failure
}
