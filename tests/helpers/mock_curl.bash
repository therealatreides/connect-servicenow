#!/usr/bin/env bash
# PATH-based curl mock for unit tests.
#
# Creates a fake `curl` script in a temp directory and prepends it to $PATH
# so sn.sh calls our mock instead of the real curl.
#
# Usage in .bats files:
#   setup() {
#     load '../helpers/test_helper'
#     load '../helpers/mock_curl'
#     setup_fake_env
#     setup_mock_curl
#   }
#   teardown() {
#     teardown_mock_curl
#     teardown_env
#   }

setup_mock_curl() {
  MOCK_CURL_DIR="$(mktemp -d)"
  export MOCK_CURL_DIR

  # Default responses
  export MOCK_CURL_RESPONSE='{"result":[]}'
  export MOCK_CURL_HTTP_STATUS="200"
  export MOCK_CURL_EXIT_CODE="0"

  # Write the mock curl executable
  cat > "${MOCK_CURL_DIR}/curl" << 'MOCK_SCRIPT'
#!/usr/bin/env bash
# ── Mock curl ────────────────────────────────────────────────────────
# Reads MOCK_CURL_* env vars. Supports per-call sequencing via
# MOCK_CURL_RESPONSE_N / MOCK_CURL_HTTP_STATUS_N variables.

# Increment call counter
COUNTER_FILE="${MOCK_CURL_DIR}/.curl_call_count"
if [[ -f "$COUNTER_FILE" ]]; then
  count=$(<"$COUNTER_FILE")
  count=$((count + 1))
else
  count=1
fi
echo "$count" > "$COUNTER_FILE"

# Log the full argument list for later assertion
echo "$*" >> "${MOCK_CURL_DIR}/.curl_calls"

# Determine response for this call number
response_var="MOCK_CURL_RESPONSE_${count}"
status_var="MOCK_CURL_HTTP_STATUS_${count}"
exit_var="MOCK_CURL_EXIT_CODE_${count}"

if [[ -n "${!response_var:-}" ]]; then
  body="${!response_var}"
  http_status="${!status_var:-200}"
  exit_code="${!exit_var:-0}"
else
  body="${MOCK_CURL_RESPONSE}"
  http_status="${MOCK_CURL_HTTP_STATUS:-200}"
  exit_code="${MOCK_CURL_EXIT_CODE:-0}"
fi

# Detect calling pattern from arguments
args_str="$*"

if [[ "$args_str" == *"-o /dev/null"* ]]; then
  # sn_curl_status mode: only print HTTP status code
  printf "%s" "$http_status"
elif [[ "$args_str" == *"-w"* ]]; then
  # sn_curl mode: print body then status code on separate line
  echo "$body"
  echo "$http_status"
else
  # sn_curl_file mode or generic: just print body
  echo "$body"
fi

exit "$exit_code"
MOCK_SCRIPT

  chmod +x "${MOCK_CURL_DIR}/curl"

  # Also create a mock `sleep` to avoid delays in retry tests
  cat > "${MOCK_CURL_DIR}/sleep" << 'SLEEP_SCRIPT'
#!/usr/bin/env bash
# No-op sleep for fast unit tests
exit 0
SLEEP_SCRIPT
  chmod +x "${MOCK_CURL_DIR}/sleep"

  # Prepend mock directory to PATH
  export ORIGINAL_PATH="$PATH"
  export PATH="${MOCK_CURL_DIR}:${PATH}"
}

teardown_mock_curl() {
  if [[ -n "${ORIGINAL_PATH:-}" ]]; then
    export PATH="$ORIGINAL_PATH"
    unset ORIGINAL_PATH
  fi
  if [[ -n "${MOCK_CURL_DIR:-}" && -d "${MOCK_CURL_DIR:-}" ]]; then
    rm -rf "$MOCK_CURL_DIR"
  fi
  # Clean up all MOCK_CURL_* variables
  unset MOCK_CURL_DIR MOCK_CURL_RESPONSE MOCK_CURL_HTTP_STATUS MOCK_CURL_EXIT_CODE
  # Clean up numbered response variables (up to 10)
  for i in $(seq 1 10); do
    unset "MOCK_CURL_RESPONSE_${i}" "MOCK_CURL_HTTP_STATUS_${i}" "MOCK_CURL_EXIT_CODE_${i}" 2>/dev/null || true
  done
}

# ── Configuration helpers ────────────────────────────────────────────

# Set the default mock curl response (used when no per-call override matches)
# Usage: mock_curl_response '{"result":[]}' 200
mock_curl_response() {
  export MOCK_CURL_RESPONSE="$1"
  export MOCK_CURL_HTTP_STATUS="${2:-200}"
}

# Set per-call response for testing sequences (retry, OAuth+API, etc.)
# Usage: mock_curl_response_sequence 1 '{"access_token":"tok"}' 200
mock_curl_response_sequence() {
  local n="$1" body="$2" status="${3:-200}"
  export "MOCK_CURL_RESPONSE_${n}=${body}"
  export "MOCK_CURL_HTTP_STATUS_${n}=${status}"
}

# Get the number of times mock curl was called
mock_curl_call_count() {
  if [[ -f "${MOCK_CURL_DIR}/.curl_call_count" ]]; then
    cat "${MOCK_CURL_DIR}/.curl_call_count"
  else
    echo "0"
  fi
}

# Get the arguments of the Nth curl call (1-indexed)
mock_curl_call_args() {
  local n="$1"
  if [[ -f "${MOCK_CURL_DIR}/.curl_calls" ]]; then
    sed -n "${n}p" "${MOCK_CURL_DIR}/.curl_calls"
  else
    echo ""
  fi
}

# Reset call counter and logs (useful between sub-tests)
mock_curl_reset() {
  rm -f "${MOCK_CURL_DIR}/.curl_call_count" "${MOCK_CURL_DIR}/.curl_calls"
}
