#!/bin/bash
# Simple integration test for the AIXcel backend using curl
# Usage: ./test_api.sh [BASE_URL]
# Default BASE_URL is http://localhost:6889

set -euo pipefail

BASE_URL="${1:-http://localhost:6889}"

pass() { echo -e "\e[32mPASS\e[0m - $1"; }
fail() { echo -e "\e[31mFAIL\e[0m - $1"; exit 1; }

check_health() {
  local res
  res=$(curl -sf "$BASE_URL/health" || fail "health endpoint unreachable")
  if [[ "$res" == "ok" ]]; then
    pass "health"
  else
    fail "health returned '$res'"
  fi
}

list_cells() {
  curl -sf "$BASE_URL/cells" | jq -e '.' >/dev/null || fail "list cells"
  pass "list cells"
}

add_cell() {
  curl -sf -X POST "$BASE_URL/cells" -H 'Content-Type: application/json' \
    -d '{"row":0,"col":0,"value":"42"}' >/dev/null || fail "add cell"
  pass "add cell"
}

evaluate_formula() {
  local res
  res=$(curl -sf -X POST "$BASE_URL/evaluate" -H 'Content-Type: application/json' \
    -d '{"expr":"=SUM(1,2,3)"}' || fail "evaluate")
  if [[ "$res" == "6" ]]; then
    pass "evaluate formula"
  else
    fail "evaluate returned '$res'"
  fi
}

clear_cell() {
  curl -sf -X POST "$BASE_URL/cells/clear" -H 'Content-Type: application/json' \
    -d '{"cells":[{"row":0,"col":0}]}' >/dev/null || fail "clear cell"
  pass "clear cell"
}

check_empty() {
  local count
  count=$(curl -sf "$BASE_URL/cells" | jq 'length') || fail "count cells"
  if [[ "$count" -eq 0 ]]; then
    pass "database empty"
  else
    fail "expected 0 cells, got $count"
  fi
}

check_health
list_cells
add_cell
list_cells
evaluate_formula
clear_cell
check_empty

echo "All tests passed."
