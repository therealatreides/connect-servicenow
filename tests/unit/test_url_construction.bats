#!/usr/bin/env bats
# Tests for URL building, endpoint paths, and parameter encoding

setup() {
  load '../helpers/test_helper'
  load '../helpers/mock_curl'
  setup_fake_env
  setup_mock_curl
  mock_curl_response '{"result":[]}' 200
}

teardown() {
  teardown_mock_curl
  teardown_env
}

# ── Endpoint paths ───────────────────────────────────────────────────

@test "url: query uses /api/now/table/{table}" {
  run_sn query incident
  assert_success
  local args
  args=$(mock_curl_call_args 1)
  [[ "$args" == *"/api/now/table/incident?"* ]]
}

@test "url: get includes sys_id in path" {
  mock_curl_response '{"result":{"sys_id":"6816f79cc0a8016401c5a33be04be441"}}' 200
  run_sn get incident "$VALID_SYS_ID"
  assert_success
  local args
  args=$(mock_curl_call_args 1)
  [[ "$args" == *"/api/now/table/incident/6816f79cc0a8016401c5a33be04be441"* ]]
}

@test "url: create uses POST to /api/now/table/{table}" {
  mock_curl_response '{"result":{"sys_id":"abc12345def67890abc12345def67890","number":"INC001"}}' 200
  run_sn create incident '{"short_description":"test"}'
  assert_success
  local args
  args=$(mock_curl_call_args 1)
  [[ "$args" == *"POST"* ]]
  [[ "$args" == *"/api/now/table/incident"* ]]
  # Should NOT have a sys_id in the path
  [[ "$args" != *"/api/now/table/incident/"* ]] || [[ "$args" == *"/api/now/table/incident -"* ]]
}

@test "url: update uses PATCH with sys_id in path" {
  mock_curl_response '{"result":{"sys_id":"6816f79cc0a8016401c5a33be04be441"}}' 200
  run_sn update incident "$VALID_SYS_ID" '{"short_description":"updated"}'
  assert_success
  local args
  args=$(mock_curl_call_args 1)
  [[ "$args" == *"PATCH"* ]]
  [[ "$args" == *"/api/now/table/incident/6816f79cc0a8016401c5a33be04be441"* ]]
}

@test "url: delete uses DELETE with sys_id in path" {
  mock_curl_response '' 204
  run_sn delete incident "$VALID_SYS_ID" --confirm
  assert_success
  local args
  args=$(mock_curl_call_args 1)
  [[ "$args" == *"DELETE"* ]]
  [[ "$args" == *"/api/now/table/incident/6816f79cc0a8016401c5a33be04be441"* ]]
}

@test "url: aggregate uses /api/now/stats/{table}" {
  mock_curl_response '{"result":{"stats":{"count":"5"}}}' 200
  run_sn aggregate incident --type COUNT
  assert_success
  local args
  args=$(mock_curl_call_args 1)
  [[ "$args" == *"/api/now/stats/incident"* ]]
}

@test "url: schema queries sys_dictionary" {
  mock_curl_response "$(cat "$FIXTURES_DIR/mock_responses/schema_response.json")" 200
  run_sn schema incident
  assert_success
  local args
  args=$(mock_curl_call_args 1)
  [[ "$args" == *"/api/now/table/sys_dictionary"* ]]
  [[ "$args" == *"name=incident"* ]]
}

@test "url: attach list uses /api/now/attachment" {
  mock_curl_response '{"result":[]}' 200
  run_sn attach list incident "$VALID_SYS_ID"
  assert_success
  local args
  args=$(mock_curl_call_args 1)
  [[ "$args" == *"/api/now/attachment"* ]]
}

@test "url: attach download uses /api/now/attachment/{id}/file" {
  local tmp_file
  tmp_file=$(mktemp)
  run_sn attach download "$VALID_SYS_ID" "$tmp_file"
  assert_success
  local args
  args=$(mock_curl_call_args 1)
  [[ "$args" == *"/api/now/attachment/6816f79cc0a8016401c5a33be04be441/file"* ]]
  rm -f "$tmp_file"
}

@test "url: query parameters are joined correctly" {
  run_sn query incident --query "active=true" --fields "number,state" --limit 5
  assert_success
  local args
  args=$(mock_curl_call_args 1)
  # Should have & between parameters, not && or missing &
  [[ "$args" == *"sysparm_limit=5"* ]]
  [[ "$args" == *"sysparm_query="* ]]
  [[ "$args" == *"sysparm_fields="* ]]
}

@test "url: COUNT aggregate uses sysparm_count=true" {
  mock_curl_response '{"result":{"stats":{"count":"5"}}}' 200
  run_sn aggregate incident --type COUNT
  assert_success
  local args
  args=$(mock_curl_call_args 1)
  [[ "$args" == *"sysparm_count=true"* ]]
}

@test "url: AVG aggregate uses sysparm_avg_fields" {
  mock_curl_response '{"result":{"stats":{"avg":{"reassignment_count":"1.5"}}}}' 200
  run_sn aggregate incident --type AVG --field reassignment_count
  assert_success
  local args
  args=$(mock_curl_call_args 1)
  [[ "$args" == *"sysparm_avg_fields="* ]]
}
