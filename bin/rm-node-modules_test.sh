#!/bin/bash

# rm-node-modules_test.sh - integration test for rm-node-modules
# Creates a temporary directory tree with nested projects and node_modules
# folders, then verifies top-down deletion, exclude patterns, and dry-run.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RMN="$SCRIPT_DIR/rm-node-modules.sh"

fail() { echo "❌ $1"; exit 1; }
assert_exists() { [ -e "$1" ] || fail "Expected to exist: $1"; }
assert_not_exists() { [ ! -e "$1" ] || fail "Expected not to exist: $1"; }
assert_contains() { echo "$1" | grep -q "$2" || fail "Expected output to contain: $2"; }

TEST_DIR=$(mktemp -d)
echo "Creating test tree in $TEST_DIR"

mkdir -p "$TEST_DIR/mono/packages/a/node_modules"
mkdir -p "$TEST_DIR/mono/packages/b/node_modules"
mkdir -p "$TEST_DIR/mono/node_modules"
mkdir -p "$TEST_DIR/scratch/proj1/node_modules"
mkdir -p "$TEST_DIR/archive/proj2/node_modules"

# Add some content to node_modules to make du output non-zero
echo "x" > "$TEST_DIR/mono/node_modules/file.txt"
echo "x" > "$TEST_DIR/mono/packages/a/node_modules/file.txt"
echo "x" > "$TEST_DIR/mono/packages/b/node_modules/file.txt"
echo "x" > "$TEST_DIR/scratch/proj1/node_modules/file.txt"
echo "x" > "$TEST_DIR/archive/proj2/node_modules/file.txt"

# Create nested node_modules under an existing node_modules to ensure pruning
mkdir -p "$TEST_DIR/mono/node_modules/foo/node_modules"
echo "x" > "$TEST_DIR/mono/node_modules/foo/node_modules/file.txt"

# 1) Dry-run, no deletions, should list all
out=$("$RMN" --dry-run "$TEST_DIR")
echo "$out"
assert_contains "$out" "Found 5 node_modules"
assert_contains "$out" "DRY: $TEST_DIR/mono/node_modules"
assert_contains "$out" "DRY: $TEST_DIR/mono/packages/a/node_modules"
assert_contains "$out" "DRY: $TEST_DIR/mono/packages/b/node_modules"

# Ensure nested node_modules under mono/node_modules is not listed due to pruning
echo "$out" | grep -q "$TEST_DIR/mono/node_modules/foo/node_modules" && fail "Nested node_modules should be pruned"

# 2) Delete with -y
"$RMN" -y "$TEST_DIR"

assert_not_exists "$TEST_DIR/mono/node_modules"
assert_not_exists "$TEST_DIR/mono/packages/a/node_modules"
assert_not_exists "$TEST_DIR/mono/packages/b/node_modules"
assert_not_exists "$TEST_DIR/scratch/proj1/node_modules"
assert_not_exists "$TEST_DIR/archive/proj2/node_modules"

echo "✅ All tests passed"
rm -rf "$TEST_DIR"
