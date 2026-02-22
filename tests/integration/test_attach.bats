#!/usr/bin/env bats
# Integration: attachment commands against live PDI

setup() {
  load '../helpers/test_helper'
  load '../helpers/integration_helper'
  load_test_env
}

teardown() {
  cleanup_test_records
}

@test "attach: list attachments on record with no attachments returns empty array" {
  local sys_id
  sys_id=$(create_test_incident "attach_empty_test")
  assert [ "$sys_id" != "FAILED_TO_CREATE" ]

  run_sn attach list incident "$sys_id"
  assert_success
  local count
  count=$(json_output | jq 'length')
  assert_equal "$count" "0"
}

@test "attach: upload a file and verify it appears in list" {
  local sys_id
  sys_id=$(create_test_incident "attach_upload_test")
  assert [ "$sys_id" != "FAILED_TO_CREATE" ]

  # Upload the sample attachment
  run_sn attach upload incident "$sys_id" "$FIXTURES_DIR/sample_attachment.txt" "text/plain"
  assert_success

  # List attachments and verify our file is there
  run_sn attach list incident "$sys_id"
  assert_success
  local filename
  filename=$(json_output | jq -r '.[0].file_name // "none"')
  assert_equal "$filename" "sample_attachment.txt"
}

@test "attach: download an uploaded attachment" {
  local sys_id
  sys_id=$(create_test_incident "attach_download_test")
  assert [ "$sys_id" != "FAILED_TO_CREATE" ]

  # Upload
  run_sn attach upload incident "$sys_id" "$FIXTURES_DIR/sample_attachment.txt" "text/plain"
  assert_success

  # Get attachment sys_id
  local list_result
  list_result=$(bash "$SCRIPT_PATH" attach list incident "$sys_id" 2>/dev/null)
  local att_id
  att_id=$(echo "$list_result" | jq -r '.[0].sys_id // empty')
  assert [ -n "$att_id" ]

  # Download to temp file
  local tmp_file
  tmp_file=$(mktemp)
  run_sn attach download "$att_id" "$tmp_file"
  assert_success

  # Verify content matches original
  local original_content downloaded_content
  original_content=$(cat "$FIXTURES_DIR/sample_attachment.txt")
  downloaded_content=$(cat "$tmp_file")
  assert_equal "$downloaded_content" "$original_content"

  rm -f "$tmp_file"
}

@test "attach: upload with custom content_type sets correct type" {
  local sys_id
  sys_id=$(create_test_incident "attach_ctype_test")
  assert [ "$sys_id" != "FAILED_TO_CREATE" ]

  run_sn attach upload incident "$sys_id" "$FIXTURES_DIR/sample_attachment.txt" "text/plain"
  assert_success

  # List and check content_type
  run_sn attach list incident "$sys_id"
  assert_success
  local ctype
  ctype=$(json_output | jq -r '.[0].content_type // "none"')
  assert_equal "$ctype" "text/plain"
}
