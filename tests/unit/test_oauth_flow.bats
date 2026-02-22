#!/usr/bin/env bats
# Tests for OAuth token management (acquire, refresh, ensure, auth headers)

setup() {
  load '../helpers/test_helper'
  load '../helpers/mock_curl'
  setup_mock_curl
}

teardown() {
  teardown_mock_curl
  teardown_env
}

# ── OAuth ROPC ───────────────────────────────────────────────────────

@test "oauth: ROPC acquires token on startup" {
  export SNOW_INSTANCE_URL="https://fake.service-now.com"
  export SNOW_AUTH_TYPE="oauth_ropc"
  export SNOW_CLIENT_ID="test_client"
  export SNOW_CLIENT_SECRET="test_secret"
  export SNOW_USERNAME="admin"
  export SNOW_PASSWORD="password"

  # Call 1: token acquisition
  mock_curl_response_sequence 1 \
    '{"access_token":"mock_token_123","refresh_token":"mock_refresh_456","expires_in":1800}' 200
  # Call 2: actual API call
  mock_curl_response_sequence 2 '{"result":[]}' 200

  run_sn query incident --limit 1
  assert_success

  # First curl call should be POST to oauth_token.do
  local first_call
  first_call=$(mock_curl_call_args 1)
  [[ "$first_call" == *"oauth_token.do"* ]]
  [[ "$first_call" == *"POST"* ]]
  [[ "$first_call" == *"grant_type=password"* ]] || [[ "$first_call" == *"grant_type"* ]]
}

@test "oauth: ROPC uses Bearer token in API call" {
  export SNOW_INSTANCE_URL="https://fake.service-now.com"
  export SNOW_AUTH_TYPE="oauth_ropc"
  export SNOW_CLIENT_ID="test_client"
  export SNOW_CLIENT_SECRET="test_secret"
  export SNOW_USERNAME="admin"
  export SNOW_PASSWORD="password"

  mock_curl_response_sequence 1 \
    '{"access_token":"my_bearer_token","refresh_token":"refresh","expires_in":1800}' 200
  mock_curl_response_sequence 2 '{"result":[]}' 200

  run_sn query incident --limit 1
  assert_success

  # Second call (API call) should use Bearer auth
  local api_call
  api_call=$(mock_curl_call_args 2)
  [[ "$api_call" == *"Bearer my_bearer_token"* ]]
}

# ── OAuth Client Credentials ────────────────────────────────────────

@test "oauth: client_credentials uses correct grant_type" {
  export SNOW_INSTANCE_URL="https://fake.service-now.com"
  export SNOW_AUTH_TYPE="oauth_client_credentials"
  export SNOW_CLIENT_ID="test_client"
  export SNOW_CLIENT_SECRET="test_secret"

  mock_curl_response_sequence 1 \
    '{"access_token":"cc_token_abc","expires_in":1800}' 200
  mock_curl_response_sequence 2 '{"result":[]}' 200

  run_sn query incident --limit 1
  assert_success

  local first_call
  first_call=$(mock_curl_call_args 1)
  [[ "$first_call" == *"oauth_token.do"* ]]
  [[ "$first_call" == *"grant_type=client_credentials"* ]] || [[ "$first_call" == *"client_credentials"* ]]
}

# ── Token failure ────────────────────────────────────────────────────

@test "oauth: token acquisition failure exits with error" {
  export SNOW_INSTANCE_URL="https://fake.service-now.com"
  export SNOW_AUTH_TYPE="oauth_ropc"
  export SNOW_CLIENT_ID="bad_client"
  export SNOW_CLIENT_SECRET="bad_secret"
  export SNOW_USERNAME="admin"
  export SNOW_PASSWORD="wrong_pass"

  mock_curl_response_sequence 1 \
    '{"error":"invalid_grant","error_description":"Invalid username or password"}' 400

  run_sn query incident
  assert_failure
  assert_output --partial "OAuth token acquisition failed"
}

@test "oauth: token failure includes error_description" {
  export SNOW_INSTANCE_URL="https://fake.service-now.com"
  export SNOW_AUTH_TYPE="oauth_ropc"
  export SNOW_CLIENT_ID="bad_client"
  export SNOW_CLIENT_SECRET="bad_secret"
  export SNOW_USERNAME="admin"
  export SNOW_PASSWORD="wrong_pass"

  mock_curl_response_sequence 1 \
    '{"error":"invalid_grant","error_description":"Credentials are invalid"}' 400

  run_sn query incident
  assert_failure
  assert_output --partial "Credentials are invalid"
}

# ── Basic auth ───────────────────────────────────────────────────────

@test "oauth: basic auth makes no token acquisition call" {
  setup_fake_env
  mock_curl_response '{"result":[]}' 200

  run_sn query incident --limit 1
  assert_success

  # Should be exactly 1 curl call (the API call), not 2
  local count
  count=$(mock_curl_call_count)
  assert_equal "$count" "1"
}

@test "oauth: basic auth uses -u flag" {
  setup_fake_env
  mock_curl_response '{"result":[]}' 200

  run_sn query incident --limit 1
  assert_success

  local args
  args=$(mock_curl_call_args 1)
  [[ "$args" == *"-u"* ]]
  [[ "$args" == *"testuser:testpass"* ]]
}

@test "oauth: OAuth uses Bearer header not -u flag" {
  export SNOW_INSTANCE_URL="https://fake.service-now.com"
  export SNOW_AUTH_TYPE="oauth_ropc"
  export SNOW_CLIENT_ID="test_client"
  export SNOW_CLIENT_SECRET="test_secret"
  export SNOW_USERNAME="admin"
  export SNOW_PASSWORD="password"

  mock_curl_response_sequence 1 \
    '{"access_token":"bearer_tok","refresh_token":"refresh","expires_in":1800}' 200
  mock_curl_response_sequence 2 '{"result":[]}' 200

  run_sn query incident --limit 1
  assert_success

  local api_call
  api_call=$(mock_curl_call_args 2)
  [[ "$api_call" == *"Bearer"* ]]
  [[ "$api_call" != *"-u admin:password"* ]]
}
