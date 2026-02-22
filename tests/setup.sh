#!/usr/bin/env bash
# Setup script for the test suite
# Downloads bats-core and helper libraries into tests/bats/
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BATS_DIR="${SCRIPT_DIR}/bats"

echo "=== Setting up bats-core test framework ==="

# Check prerequisites
if ! command -v git &>/dev/null; then
  echo "ERROR: git is required but not found in PATH"
  exit 1
fi

# Clone bats-core
if [[ ! -d "${BATS_DIR}/bats-core" ]]; then
  echo "Cloning bats-core..."
  git clone --depth 1 https://github.com/bats-core/bats-core.git "${BATS_DIR}/bats-core"
else
  echo "bats-core already present, skipping."
fi

# Clone bats-support
if [[ ! -d "${BATS_DIR}/bats-support" ]]; then
  echo "Cloning bats-support..."
  git clone --depth 1 https://github.com/bats-core/bats-support.git "${BATS_DIR}/bats-support"
else
  echo "bats-support already present, skipping."
fi

# Clone bats-assert
if [[ ! -d "${BATS_DIR}/bats-assert" ]]; then
  echo "Cloning bats-assert..."
  git clone --depth 1 https://github.com/bats-core/bats-assert.git "${BATS_DIR}/bats-assert"
else
  echo "bats-assert already present, skipping."
fi

# Verify
if [[ -x "${BATS_DIR}/bats-core/bin/bats" ]]; then
  echo ""
  echo "Setup complete! bats version:"
  "${BATS_DIR}/bats-core/bin/bats" --version
  echo ""
  echo "Next steps:"
  echo "  1. Copy tests/.env.test.example to tests/.env.test"
  echo "  2. Fill in your PDI credentials"
  echo "  3. Run: bash tests/run_tests.sh --unit"
else
  echo "ERROR: bats binary not found after setup"
  exit 1
fi
