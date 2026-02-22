#!/usr/bin/env bats
# Tests for command argument parsing across all 10 commands

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

# ════════════════════════════════════════════════════════════════════
# query command
# ════════════════════════════════════════════════════════════════════

@test "query: table name is required" {
  run_sn query
  assert_failure
}

@test "query: default limit is 20" {
  run_sn query incident
  assert_success
  local args
  args=$(mock_curl_call_args 1)
  [[ "$args" == *"sysparm_limit=20"* ]]
}

@test "query: --limit overrides default" {
  run_sn query incident --limit 50
  assert_success
  local args
  args=$(mock_curl_call_args 1)
  [[ "$args" == *"sysparm_limit=50"* ]]
}

@test "query: --query adds sysparm_query" {
  run_sn query incident --query "active=true"
  assert_success
  local args
  args=$(mock_curl_call_args 1)
  [[ "$args" == *"sysparm_query="* ]]
}

@test "query: --fields adds sysparm_fields" {
  run_sn query incident --fields "number,state"
  assert_success
  local args
  args=$(mock_curl_call_args 1)
  [[ "$args" == *"sysparm_fields="* ]]
}

@test "query: --offset adds sysparm_offset" {
  run_sn query incident --offset 20
  assert_success
  local args
  args=$(mock_curl_call_args 1)
  [[ "$args" == *"sysparm_offset=20"* ]]
}

@test "query: --orderby adds sysparm_orderby" {
  run_sn query incident --orderby "sys_created_on"
  assert_success
  local args
  args=$(mock_curl_call_args 1)
  [[ "$args" == *"sysparm_orderby="* ]]
}

@test "query: --display adds sysparm_display_value" {
  run_sn query incident --display true
  assert_success
  local args
  args=$(mock_curl_call_args 1)
  [[ "$args" == *"sysparm_display_value="* ]]
}

@test "query: multiple options combine correctly" {
  run_sn query incident --query "active=true" --fields "number" --limit 5 --offset 10 --orderby "number" --display true
  assert_success
  local args
  args=$(mock_curl_call_args 1)
  [[ "$args" == *"sysparm_limit=5"* ]]
  [[ "$args" == *"sysparm_query="* ]]
  [[ "$args" == *"sysparm_fields="* ]]
  [[ "$args" == *"sysparm_offset=10"* ]]
  [[ "$args" == *"sysparm_orderby="* ]]
  [[ "$args" == *"sysparm_display_value="* ]]
}

@test "query: unknown option fails" {
  run_sn query incident --bogus value
  assert_failure
  assert_output --partial "Unknown option"
}

@test "query: --offset validates as number" {
  run_sn query incident --offset abc
  assert_failure
  assert_output --partial "Expected a number"
}

@test "query: output has record_count and results" {
  mock_curl_response '{"result":[{"sys_id":"abc12345def67890abc12345def67890"}]}' 200
  run_sn query incident
  assert_success
  json_output | jq -e '.record_count' >/dev/null
  json_output | jq -e '.results' >/dev/null
}

# ════════════════════════════════════════════════════════════════════
# get command
# ════════════════════════════════════════════════════════════════════

@test "get: requires table and sys_id" {
  run_sn get
  assert_failure
}

@test "get: requires sys_id" {
  run_sn get incident
  assert_failure
}

@test "get: retrieves record successfully" {
  mock_curl_response '{"result":{"sys_id":"6816f79cc0a8016401c5a33be04be441","number":"INC001"}}' 200
  run_sn get incident "$VALID_SYS_ID"
  assert_success
  json_output | jq -e '.sys_id' >/dev/null
}

@test "get: --fields parameter works" {
  mock_curl_response '{"result":{"sys_id":"6816f79cc0a8016401c5a33be04be441"}}' 200
  run_sn get incident "$VALID_SYS_ID" --fields "number,state"
  assert_success
  local args
  args=$(mock_curl_call_args 1)
  [[ "$args" == *"sysparm_fields="* ]]
}

@test "get: --display parameter works" {
  mock_curl_response '{"result":{"sys_id":"6816f79cc0a8016401c5a33be04be441"}}' 200
  run_sn get incident "$VALID_SYS_ID" --display true
  assert_success
  local args
  args=$(mock_curl_call_args 1)
  [[ "$args" == *"sysparm_display_value="* ]]
}

@test "get: validates table name" {
  run_sn get BAD-TABLE "$VALID_SYS_ID"
  assert_failure
  assert_output --partial "Invalid table name"
}

@test "get: validates sys_id" {
  run_sn get incident bad_sys_id
  assert_failure
  assert_output --partial "Invalid sys_id"
}

@test "get: unknown option fails" {
  mock_curl_response '{"result":{}}' 200
  run_sn get incident "$VALID_SYS_ID" --bogus value
  assert_failure
  assert_output --partial "Unknown option"
}

# ════════════════════════════════════════════════════════════════════
# create command
# ════════════════════════════════════════════════════════════════════

@test "create: requires table and json" {
  run_sn create
  assert_failure
}

@test "create: requires json argument" {
  run_sn create incident
  assert_failure
}

@test "create: valid JSON succeeds" {
  mock_curl_response '{"result":{"sys_id":"abc12345def67890abc12345def67890","number":"INC001"}}' 200
  run_sn create incident '{"short_description":"test"}'
  assert_success
}

@test "create: invalid JSON fails before API call" {
  run_sn create incident '{bad json'
  assert_failure
  assert_output --partial "Invalid JSON"
}

@test "create: validates table name" {
  run_sn create BAD-TABLE '{"x":"y"}'
  assert_failure
  assert_output --partial "Invalid table name"
}

@test "create: uses POST method" {
  mock_curl_response '{"result":{"sys_id":"abc12345def67890abc12345def67890","number":"INC001"}}' 200
  run_sn create incident '{"short_description":"test"}'
  assert_success
  local args
  args=$(mock_curl_call_args 1)
  [[ "$args" == *"POST"* ]]
}

@test "create: output has sys_id and number" {
  mock_curl_response '{"result":{"sys_id":"abc12345def67890abc12345def67890","number":"INC0099"}}' 200
  run_sn create incident '{"short_description":"test"}'
  assert_success
  json_output | jq -e '.sys_id' >/dev/null
  json_output | jq -e '.number' >/dev/null
}

# ════════════════════════════════════════════════════════════════════
# update command
# ════════════════════════════════════════════════════════════════════

@test "update: requires all three arguments" {
  run_sn update
  assert_failure
  run_sn update incident
  assert_failure
  run_sn update incident "$VALID_SYS_ID"
  assert_failure
}

@test "update: valid call succeeds" {
  mock_curl_response '{"result":{"sys_id":"6816f79cc0a8016401c5a33be04be441"}}' 200
  run_sn update incident "$VALID_SYS_ID" '{"short_description":"updated"}'
  assert_success
}

@test "update: invalid JSON fails" {
  run_sn update incident "$VALID_SYS_ID" '{not valid}'
  assert_failure
  assert_output --partial "Invalid JSON"
}

@test "update: validates table name" {
  run_sn update BAD-TABLE "$VALID_SYS_ID" '{"x":"y"}'
  assert_failure
  assert_output --partial "Invalid table name"
}

@test "update: validates sys_id" {
  run_sn update incident bad_id '{"x":"y"}'
  assert_failure
  assert_output --partial "Invalid sys_id"
}

@test "update: uses PATCH method" {
  mock_curl_response '{"result":{"sys_id":"6816f79cc0a8016401c5a33be04be441"}}' 200
  run_sn update incident "$VALID_SYS_ID" '{"short_description":"updated"}'
  assert_success
  local args
  args=$(mock_curl_call_args 1)
  [[ "$args" == *"PATCH"* ]]
}

# ════════════════════════════════════════════════════════════════════
# delete command
# ════════════════════════════════════════════════════════════════════

@test "delete: requires table and sys_id" {
  run_sn delete
  assert_failure
  run_sn delete incident
  assert_failure
}

@test "delete: fails without --confirm" {
  run_sn delete incident "$VALID_SYS_ID"
  assert_failure
  assert_output --partial "Must pass --confirm"
}

@test "delete: succeeds with --confirm and 204 response" {
  mock_curl_response '' 204
  run_sn delete incident "$VALID_SYS_ID" --confirm
  assert_success
  assert_output --partial '"status": "deleted"'
}

@test "delete: succeeds with --confirm and 200 response" {
  mock_curl_response '' 200
  run_sn delete incident "$VALID_SYS_ID" --confirm
  assert_success
  assert_output --partial '"status": "deleted"'
}

@test "delete: validates table name" {
  run_sn delete BAD-TABLE "$VALID_SYS_ID" --confirm
  assert_failure
  assert_output --partial "Invalid table name"
}

@test "delete: validates sys_id" {
  run_sn delete incident bad_id --confirm
  assert_failure
  assert_output --partial "Invalid sys_id"
}

@test "delete: handles 404 response" {
  mock_curl_response '' 404
  run_sn delete incident "$VALID_SYS_ID" --confirm
  assert_failure
  assert_output --partial "Record not found"
}

@test "delete: handles non-204 non-404 response" {
  mock_curl_response '' 500
  run_sn delete incident "$VALID_SYS_ID" --confirm
  assert_failure
  assert_output --partial "Delete failed"
}

@test "delete: unknown option fails" {
  run_sn delete incident "$VALID_SYS_ID" --bogus
  assert_failure
  assert_output --partial "Unknown option"
}

@test "delete: output has status, sys_id, and table" {
  mock_curl_response '' 204
  run_sn delete incident "$VALID_SYS_ID" --confirm
  assert_success
  json_output | jq -e '.status' >/dev/null
  json_output | jq -e '.sys_id' >/dev/null
  json_output | jq -e '.table' >/dev/null
}

# ════════════════════════════════════════════════════════════════════
# aggregate command
# ════════════════════════════════════════════════════════════════════

@test "aggregate: requires table" {
  run_sn aggregate
  assert_failure
}

@test "aggregate: requires --type" {
  run_sn aggregate incident
  assert_failure
  assert_output --partial "--type"
}

@test "aggregate: COUNT works without --field" {
  mock_curl_response '{"result":{"stats":{"count":"42"}}}' 200
  run_sn aggregate incident --type COUNT
  assert_success
}

@test "aggregate: AVG requires --field" {
  run_sn aggregate incident --type AVG
  assert_failure
  assert_output --partial "requires --field"
}

@test "aggregate: MIN requires --field" {
  run_sn aggregate incident --type MIN
  assert_failure
  assert_output --partial "requires --field"
}

@test "aggregate: MAX requires --field" {
  run_sn aggregate incident --type MAX
  assert_failure
  assert_output --partial "requires --field"
}

@test "aggregate: SUM requires --field" {
  run_sn aggregate incident --type SUM
  assert_failure
  assert_output --partial "requires --field"
}

@test "aggregate: AVG with --field succeeds" {
  mock_curl_response '{"result":{"stats":{"avg":{"reassignment_count":"1.5"}}}}' 200
  run_sn aggregate incident --type AVG --field reassignment_count
  assert_success
}

@test "aggregate: --type is case-insensitive" {
  mock_curl_response '{"result":{"stats":{"count":"42"}}}' 200
  run_sn aggregate incident --type count
  assert_success
}

@test "aggregate: --query adds sysparm_query" {
  mock_curl_response '{"result":{"stats":{"count":"5"}}}' 200
  run_sn aggregate incident --type COUNT --query "active=true"
  assert_success
  local args
  args=$(mock_curl_call_args 1)
  [[ "$args" == *"sysparm_query="* ]]
}

@test "aggregate: --group-by adds sysparm_group_by" {
  mock_curl_response '{"result":[{"stats":{"count":"5"},"groupby_fields":[{"field":"priority","value":"1"}]}]}' 200
  run_sn aggregate incident --type COUNT --group-by priority
  assert_success
  local args
  args=$(mock_curl_call_args 1)
  [[ "$args" == *"sysparm_group_by="* ]]
}

@test "aggregate: --display adds sysparm_display_value" {
  mock_curl_response '{"result":{"stats":{"count":"42"}}}' 200
  run_sn aggregate incident --type COUNT --display true
  assert_success
  local args
  args=$(mock_curl_call_args 1)
  [[ "$args" == *"sysparm_display_value="* ]]
}

@test "aggregate: unknown option fails" {
  run_sn aggregate incident --type COUNT --bogus value
  assert_failure
  assert_output --partial "Unknown option"
}

# ════════════════════════════════════════════════════════════════════
# schema command
# ════════════════════════════════════════════════════════════════════

@test "schema: requires table" {
  run_sn schema
  assert_failure
}

@test "schema: default returns field objects with expected keys" {
  mock_curl_response "$(cat "$FIXTURES_DIR/mock_responses/schema_response.json")" 200
  run_sn schema incident
  assert_success
  # Check for expected keys in output
  json_output | jq -e '.[0].field' >/dev/null
  json_output | jq -e '.[0].label' >/dev/null
  json_output | jq -e '.[0].type' >/dev/null
}

@test "schema: --fields-only returns sorted array of field names" {
  mock_curl_response "$(cat "$FIXTURES_DIR/mock_responses/schema_response.json")" 200
  run_sn schema incident --fields-only
  assert_success
  # Output should be a JSON array of strings
  json_output | jq -e 'type == "array"' >/dev/null
  json_output | jq -e '.[0] | type == "string"' >/dev/null
}

@test "schema: filters out collection entries" {
  mock_curl_response "$(cat "$FIXTURES_DIR/mock_responses/schema_response.json")" 200
  run_sn schema incident
  assert_success
  # The mock has an entry with element="" (collection) — should be filtered out
  local count
  count=$(json_output | jq 'length')
  # Schema mock has 5 entries, 1 with empty element (collection) should be excluded → 4
  assert_equal "$count" "4"
}

@test "schema: validates table name" {
  run_sn schema BAD-TABLE
  assert_failure
  assert_output --partial "Invalid table name"
}

@test "schema: unknown option fails" {
  run_sn schema incident --bogus
  assert_failure
  assert_output --partial "Unknown option"
}

# ════════════════════════════════════════════════════════════════════
# attach command
# ════════════════════════════════════════════════════════════════════

@test "attach: requires subcommand" {
  run_sn attach
  assert_failure
}

@test "attach: unknown subcommand fails" {
  run_sn attach rename
  assert_failure
  assert_output --partial "Unknown attach subcommand"
}

@test "attach list: requires table and sys_id" {
  run_sn attach list
  assert_failure
  run_sn attach list incident
  assert_failure
}

@test "attach list: validates table name" {
  run_sn attach list BAD-TABLE "$VALID_SYS_ID"
  assert_failure
  assert_output --partial "Invalid table name"
}

@test "attach list: validates sys_id" {
  run_sn attach list incident bad_id
  assert_failure
  assert_output --partial "Invalid sys_id"
}

@test "attach list: returns JSON array" {
  mock_curl_response "$(cat "$FIXTURES_DIR/mock_responses/attach_list.json")" 200
  run_sn attach list incident "$VALID_SYS_ID"
  assert_success
  json_output | jq -e 'type == "array"' >/dev/null
}

@test "attach download: requires attachment_id and output_path" {
  run_sn attach download
  assert_failure
  run_sn attach download "$VALID_SYS_ID"
  assert_failure
}

@test "attach download: validates attachment sys_id" {
  run_sn attach download bad_id /tmp/out.txt
  assert_failure
  assert_output --partial "Invalid sys_id"
}

@test "attach download: returns success JSON" {
  local tmp_file
  tmp_file=$(mktemp)
  run_sn attach download "$VALID_SYS_ID" "$tmp_file"
  assert_success
  json_output | jq -e '.status == "downloaded"' >/dev/null
  rm -f "$tmp_file"
}

@test "attach upload: requires table, sys_id, and file_path" {
  run_sn attach upload
  assert_failure
  run_sn attach upload incident
  assert_failure
  run_sn attach upload incident "$VALID_SYS_ID"
  assert_failure
}

@test "attach upload: validates table name" {
  run_sn attach upload BAD-TABLE "$VALID_SYS_ID" /tmp/file.txt
  assert_failure
  assert_output --partial "Invalid table name"
}

@test "attach upload: validates sys_id" {
  run_sn attach upload incident bad_id /tmp/file.txt
  assert_failure
  assert_output --partial "Invalid sys_id"
}

@test "attach upload: uses POST method" {
  mock_curl_response '{"result":{"sys_id":"att123","file_name":"test.txt","size_bytes":"100","table_name":"incident","table_sys_id":"abc123"}}' 200
  run_sn attach upload incident "$VALID_SYS_ID" "$FIXTURES_DIR/sample_attachment.txt"
  assert_success
  local args
  args=$(mock_curl_call_args 1)
  [[ "$args" == *"POST"* ]]
}

@test "attach upload: includes file_name in URL" {
  mock_curl_response '{"result":{"sys_id":"att123","file_name":"sample_attachment.txt","size_bytes":"100","table_name":"incident","table_sys_id":"abc123"}}' 200
  run_sn attach upload incident "$VALID_SYS_ID" "$FIXTURES_DIR/sample_attachment.txt"
  assert_success
  local args
  args=$(mock_curl_call_args 1)
  [[ "$args" == *"file_name="* ]]
}

@test "attach upload: default content type is application/octet-stream" {
  mock_curl_response '{"result":{"sys_id":"att123","file_name":"test.txt","size_bytes":"100","table_name":"incident","table_sys_id":"abc123"}}' 200
  run_sn attach upload incident "$VALID_SYS_ID" "$FIXTURES_DIR/sample_attachment.txt"
  assert_success
  local args
  args=$(mock_curl_call_args 1)
  [[ "$args" == *"application/octet-stream"* ]]
}

@test "attach upload: custom content type is used" {
  mock_curl_response '{"result":{"sys_id":"att123","file_name":"test.txt","size_bytes":"100","table_name":"incident","table_sys_id":"abc123"}}' 200
  run_sn attach upload incident "$VALID_SYS_ID" "$FIXTURES_DIR/sample_attachment.txt" "text/plain"
  assert_success
  local args
  args=$(mock_curl_call_args 1)
  [[ "$args" == *"text/plain"* ]]
}

# ════════════════════════════════════════════════════════════════════
# batch command
# ════════════════════════════════════════════════════════════════════

@test "batch: requires table" {
  run_sn batch
  assert_failure
}

@test "batch: requires --action" {
  run_sn batch incident --query "active=true"
  assert_failure
  assert_output --partial "Missing --action"
}

@test "batch: --action must be update or delete" {
  run_sn batch incident --query "active=true" --action create
  assert_failure
  assert_output --partial "'update' or 'delete'"
}

@test "batch: requires --query" {
  run_sn batch incident --action update --fields '{"urgency":"3"}'
  assert_failure
  assert_output --partial "Missing --query"
}

@test "batch: update requires --fields" {
  run_sn batch incident --query "active=true" --action update
  assert_failure
  assert_output --partial "--fields required"
}

@test "batch: invalid JSON in --fields fails" {
  run_sn batch incident --query "active=true" --action update --fields '{broken}'
  assert_failure
  assert_output --partial "Invalid JSON"
}

@test "batch: default is dry-run" {
  mock_curl_response '{"result":[{"sys_id":"abc12345def67890abc12345def67890"}]}' 200
  run_sn batch incident --query "active=true" --action update --fields '{"urgency":"3"}'
  assert_success
  assert_output --partial '"dry_run": true'
}

@test "batch: --dry-run explicitly sets dry-run" {
  mock_curl_response '{"result":[{"sys_id":"abc12345def67890abc12345def67890"}]}' 200
  run_sn batch incident --query "active=true" --action update --fields '{"urgency":"3"}' --dry-run
  assert_success
  assert_output --partial '"dry_run": true'
}

@test "batch: --confirm disables dry-run" {
  mock_curl_response_sequence 1 '{"result":[{"sys_id":"abc12345def67890abc12345def67890"}]}' 200
  mock_curl_response_sequence 2 '{"result":{"sys_id":"abc12345def67890abc12345def67890"}}' 200
  run_sn batch incident --query "active=true" --action update --fields '{"urgency":"3"}' --confirm
  assert_success
  assert_output --partial '"processed": 1'
}

@test "batch: default limit is 200" {
  mock_curl_response '{"result":[]}' 200
  run_sn batch incident --query "active=true" --action update --fields '{"urgency":"3"}'
  assert_success
  local args
  args=$(mock_curl_call_args 1)
  [[ "$args" == *"sysparm_limit=200"* ]]
}

@test "batch: --limit overrides default" {
  mock_curl_response '{"result":[]}' 200
  run_sn batch incident --query "active=true" --action update --fields '{"urgency":"3"}' --limit 50
  assert_success
  local args
  args=$(mock_curl_call_args 1)
  [[ "$args" == *"sysparm_limit=50"* ]]
}

@test "batch: --limit validates as number" {
  run_sn batch incident --query "active=true" --action update --fields '{"urgency":"3"}' --limit abc
  assert_failure
  assert_output --partial "Expected a number"
}

@test "batch: zero matched records handled gracefully" {
  mock_curl_response '{"result":[]}' 200
  run_sn batch incident --query "active=true" --action delete --confirm
  assert_success
  json_output | jq -e '.matched == 0' >/dev/null
  json_output | jq -e '.processed == 0' >/dev/null
}

@test "batch: delete action processes records" {
  mock_curl_response_sequence 1 '{"result":[{"sys_id":"abc12345def67890abc12345def67890"}]}' 200
  mock_curl_response_sequence 2 '' 204
  run_sn batch incident --query "active=true" --action delete --confirm
  assert_success
  json_output | jq -e '.processed == 1' >/dev/null
}

@test "batch: unknown option fails" {
  run_sn batch incident --query "active=true" --action update --fields '{}' --bogus
  assert_failure
  assert_output --partial "Unknown option"
}

# ════════════════════════════════════════════════════════════════════
# health command
# ════════════════════════════════════════════════════════════════════

@test "health: default check is all" {
  # Health "all" makes ~9 calls: 3 version (sys_properties), 1 nodes, 1 jobs, 1 semaphores, 4 stats
  # Calls 1-3: version (sys_properties queries)
  mock_curl_response_sequence 1 '{"result":[{"value":"test-build"}]}' 200
  mock_curl_response_sequence 2 '{"result":[{"value":"2025-01-01"}]}' 200
  mock_curl_response_sequence 3 '{"result":[{"value":"release/test"}]}' 200
  # Calls 4-6: nodes, jobs, semaphores (arrays)
  mock_curl_response_sequence 4 '{"result":[]}' 200
  mock_curl_response_sequence 5 '{"result":[]}' 200
  mock_curl_response_sequence 6 '{"result":[]}' 200
  # Calls 7-10: stats (incidents, p1, changes, problems)
  mock_curl_response_sequence 7 '{"result":{"stats":{"count":"0"}}}' 200
  mock_curl_response_sequence 8 '{"result":{"stats":{"count":"0"}}}' 200
  mock_curl_response_sequence 9 '{"result":{"stats":{"count":"0"}}}' 200
  mock_curl_response_sequence 10 '{"result":{"stats":{"count":"0"}}}' 200

  run_sn health
  assert_success
  # Should make multiple curl calls for all checks
  local count
  count=$(mock_curl_call_count)
  assert [ "$count" -gt 3 ]
}

@test "health: --check version only queries version" {
  mock_curl_response "$(cat "$FIXTURES_DIR/mock_responses/health_version.json")" 200
  run_sn health --check version
  assert_success
  json_output | jq -e '.version' >/dev/null
}

@test "health: --check nodes queries cluster state" {
  mock_curl_response '{"result":[{"node_id":"node1","status":"online","system_id":"sys1","most_recent_message":"ok"}]}' 200
  run_sn health --check nodes
  assert_success
  json_output | jq -e '.nodes' >/dev/null
}

@test "health: --check jobs queries sys_trigger" {
  mock_curl_response '{"result":[]}' 200
  run_sn health --check jobs
  assert_success
  json_output | jq -e '.jobs' >/dev/null
}

@test "health: --check semaphores queries semaphores" {
  mock_curl_response '{"result":[]}' 200
  run_sn health --check semaphores
  assert_success
  json_output | jq -e '.semaphores' >/dev/null
}

@test "health: --check stats queries multiple stats endpoints" {
  mock_curl_response '{"result":{"stats":{"count":"0"}}}' 200
  run_sn health --check stats
  assert_success
  json_output | jq -e '.stats' >/dev/null
  # Should have called curl multiple times (incidents, p1, changes, problems)
  local count
  count=$(mock_curl_call_count)
  assert [ "$count" -ge 4 ]
}

@test "health: invalid check name fails" {
  run_sn health --check bogus
  assert_failure
  assert_output --partial "Invalid check"
}

@test "health: output includes instance and timestamp" {
  mock_curl_response '{"result":[]}' 200
  run_sn health --check nodes
  assert_success
  json_output | jq -e '.instance' >/dev/null
  json_output | jq -e '.timestamp' >/dev/null
}

@test "health: output is valid JSON" {
  mock_curl_response "$(cat "$FIXTURES_DIR/mock_responses/health_version.json")" 200
  run_sn health --check version
  assert_success
  json_output | jq . >/dev/null
}

@test "health: unknown option fails" {
  run_sn health --bogus
  assert_failure
  assert_output --partial "Unknown option"
}
