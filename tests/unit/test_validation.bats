#!/usr/bin/env bats
# Tests for input validation functions (sn.sh lines 51-66)
# validate_table_name, validate_sys_id, validate_number, uri_encode

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

# ── validate_table_name ──────────────────────────────────────────────

@test "validation: valid table name - lowercase letters" {
  run_sn query incident
  assert_success
}

@test "validation: valid table name - with underscores" {
  run_sn query change_request
  assert_success
}

@test "validation: valid table name - with digits" {
  run_sn query u_custom_table_01
  assert_success
}

@test "validation: valid table name - digits at start" {
  # regex ^[a-z0-9_]+$ allows starting with digit
  run_sn query 123table
  assert_success
}

@test "validation: invalid table name - uppercase letters" {
  run_sn query Incident
  assert_failure
  assert_output --partial "Invalid table name"
}

@test "validation: invalid table name - contains hyphen" {
  run_sn query change-request
  assert_failure
  assert_output --partial "Invalid table name"
}

@test "validation: invalid table name - contains space" {
  run_sn query "change request"
  assert_failure
  assert_output --partial "Invalid table name"
}

@test "validation: invalid table name - contains dot" {
  run_sn query sys.user
  assert_failure
  assert_output --partial "Invalid table name"
}

@test "validation: invalid table name - special characters" {
  run_sn query "incident;drop"
  assert_failure
  assert_output --partial "Invalid table name"
}

@test "validation: invalid table name - SQL injection attempt" {
  run_sn query "incident' OR '1'='1"
  assert_failure
  assert_output --partial "Invalid table name"
}

# ── validate_sys_id ──────────────────────────────────────────────────

@test "validation: valid sys_id - 32 hex chars lowercase" {
  mock_curl_response '{"result":{"sys_id":"6816f79cc0a8016401c5a33be04be441"}}' 200
  run_sn get incident 6816f79cc0a8016401c5a33be04be441
  assert_success
}

@test "validation: invalid sys_id - too short (31 chars)" {
  run_sn get incident 6816f79cc0a8016401c5a33be04be44
  assert_failure
  assert_output --partial "Invalid sys_id format"
}

@test "validation: invalid sys_id - too long (33 chars)" {
  run_sn get incident 6816f79cc0a8016401c5a33be04be4411
  assert_failure
  assert_output --partial "Invalid sys_id format"
}

@test "validation: invalid sys_id - uppercase hex" {
  run_sn get incident 6816F79CC0A8016401C5A33BE04BE441
  assert_failure
  assert_output --partial "Invalid sys_id format"
}

@test "validation: invalid sys_id - non-hex characters" {
  run_sn get incident 6816f79cc0a8016401c5a33be04bexyz
  assert_failure
  assert_output --partial "Invalid sys_id format"
}

@test "validation: invalid sys_id - UUID format with hyphens" {
  run_sn get incident 6816f79c-c0a8-0164-01c5-a33be04be441
  assert_failure
  assert_output --partial "Invalid sys_id format"
}

@test "validation: invalid sys_id - empty string" {
  run_sn get incident ""
  assert_failure
}

# ── validate_number ──────────────────────────────────────────────────

@test "validation: valid number - digits only" {
  run_sn query incident --limit 100
  assert_success
}

@test "validation: valid number - zero" {
  run_sn query incident --limit 0
  assert_success
}

@test "validation: valid number - large number" {
  run_sn query incident --limit 99999
  assert_success
}

@test "validation: invalid number - contains letters" {
  run_sn query incident --limit abc
  assert_failure
  assert_output --partial "Expected a number"
}

@test "validation: invalid number - negative" {
  run_sn query incident --limit -5
  assert_failure
  assert_output --partial "Expected a number"
}

@test "validation: invalid number - decimal" {
  run_sn query incident --limit 3.5
  assert_failure
  assert_output --partial "Expected a number"
}

@test "validation: invalid number - empty string" {
  run_sn query incident --limit ""
  assert_failure
  assert_output --partial "Expected a number"
}

@test "validation: invalid offset - not a number" {
  run_sn query incident --offset abc
  assert_failure
  assert_output --partial "Expected a number"
}

# ── JSON validation ──────────────────────────────────────────────────

@test "validation: valid JSON accepted by create" {
  mock_curl_response '{"result":{"sys_id":"abc12345def67890abc12345def67890","number":"INC001"}}' 200
  run_sn create incident '{"short_description":"test"}'
  assert_success
}

@test "validation: invalid JSON rejected by create" {
  run_sn create incident '{bad json}'
  assert_failure
  assert_output --partial "Invalid JSON"
}

@test "validation: invalid JSON rejected by update" {
  run_sn update incident "$VALID_SYS_ID" '{not valid}'
  assert_failure
  assert_output --partial "Invalid JSON"
}
