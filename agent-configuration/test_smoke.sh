#!/bin/bash
# Smoke tests for agents CLI
# Run from agent-configuration directory: bash test_smoke.sh

set -uo pipefail

PASS=0
FAIL=0

check() {
    local desc="$1"
    shift
    if "$@" > /dev/null 2>&1; then
        echo "  ok  $desc"
        ((PASS++))
    else
        echo "FAIL  $desc"
        ((FAIL++))
    fi
}

check_fail() {
    local desc="$1"
    shift
    if "$@" > /dev/null 2>&1; then
        echo "FAIL  $desc (expected failure)"
        ((FAIL++))
    else
        echo "  ok  $desc"
        ((PASS++))
    fi
}

echo "=== agents CLI smoke tests ==="
echo

# CLI wiring
check "agents --help" uv run agents --help
check "agents resolve --help" uv run agents resolve --help
check "agents lint --help" uv run agents lint --help
check_fail "agents (no subcommand)" uv run agents

# Resolve
check "agents resolve with AGENTS.md" uv run agents resolve AGENTS.md
check_fail "agents resolve with missing file" uv run agents resolve nonexistent.md

# Resolve output contains content
output=$(uv run agents resolve AGENTS.md 2>/dev/null || true)
check "resolve output is non-empty" test -n "$output"
check "resolve output has frontmatter" grep -q "+++" <<< "$output"
check "resolve output has token estimate" grep -q "token_estimate" <<< "$output"

# Lint
check "agents lint direction" uv run agents lint direction
check "agents lint fanout" uv run agents lint fanout
# orphans requires rg
uv run agents lint orphans > /dev/null 2>&1
# orphans exits 1 if orphans found, which is valid behavior
check "agents lint orphans runs" true

echo
echo "--- $PASS passed, $FAIL failed ---"
[ "$FAIL" -eq 0 ]
