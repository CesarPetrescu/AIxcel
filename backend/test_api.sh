#!/bin/bash
# Comprehensive integration test for the AIXcel backend
# This script backs up existing data, runs extensive tests, and restores the data
# Usage: ./test_api.sh [BASE_URL]
# Default BASE_URL is http://localhost:6889

set -euo pipefail

BASE_URL="${1:-http://localhost:6889}"
BACKUP_FILE="/tmp/aixcel_backup_$(date +%s).json"
TEST_RESULTS=()

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

pass() { 
  echo -e "${GREEN}✓ PASS${NC} - $1"
  TEST_RESULTS+=("PASS: $1")
}

fail() { 
  echo -e "${RED}✗ FAIL${NC} - $1"
  TEST_RESULTS+=("FAIL: $1")
  restore_data
  echo -e "${RED}Test failed. Data has been restored.${NC}"
  exit 1
}

info() {
  echo -e "${BLUE}ℹ INFO${NC} - $1"
}

warn() {
  echo -e "${YELLOW}⚠ WARN${NC} - $1"
}

# Backup existing data
backup_data() {
  info "Backing up existing data..."
  curl -sf "$BASE_URL/cells" > "$BACKUP_FILE" || fail "Failed to backup data"
  local count=$(cat "$BACKUP_FILE" | jq 'length')
  info "Backed up $count cells to $BACKUP_FILE"
}

# Restore backed up data
restore_data() {
  if [[ -f "$BACKUP_FILE" ]]; then
    info "Restoring backed up data..."
    # Clear current data first
    local current_cells=$(curl -sf "$BASE_URL/cells" | jq -r '.[] | {row: .row, col: .col}' | jq -s '.')
    if [[ "$current_cells" != "[]" ]]; then
      curl -sf -X POST "$BASE_URL/cells/clear" -H 'Content-Type: application/json' \
        -d "{\"cells\":$current_cells}" >/dev/null || warn "Failed to clear current data"
    fi
    
    # Restore backup if it contains data
    local backup_count=$(cat "$BACKUP_FILE" | jq 'length')
    if [[ "$backup_count" -gt 0 ]]; then
      curl -sf -X POST "$BASE_URL/cells/bulk" -H 'Content-Type: application/json' \
        -d @"$BACKUP_FILE" >/dev/null || warn "Failed to restore backup data"
      info "Restored $backup_count cells"
    fi
    rm -f "$BACKUP_FILE"
  fi
}

# Clear all test data
clear_all_data() {
  local cells=$(curl -sf "$BASE_URL/cells" | jq -r '.[] | {row: .row, col: .col}' | jq -s '.')
  if [[ "$cells" != "[]" ]]; then
    curl -sf -X POST "$BASE_URL/cells/clear" -H 'Content-Type: application/json' \
      -d "{\"cells\":$cells}" >/dev/null || fail "clear all test data"
  fi
}

# Basic health check
test_health() {
  info "Testing health endpoint..."
  local res
  res=$(curl -sf "$BASE_URL/health" || fail "health endpoint unreachable")
  if [[ "$res" == "ok" ]]; then
    pass "health endpoint returns 'ok'"
  else
    fail "health returned '$res' instead of 'ok'"
  fi
}

# Test basic cell operations
test_basic_cell_operations() {
  info "Testing basic cell operations..."
  
  # Test adding a simple cell
  curl -sf -X POST "$BASE_URL/cells" -H 'Content-Type: application/json' \
    -d '{"row":0,"col":0,"value":"Hello World"}' >/dev/null || fail "add simple text cell"
  pass "add simple text cell"
  
  # Test adding a number cell
  curl -sf -X POST "$BASE_URL/cells" -H 'Content-Type: application/json' \
    -d '{"row":0,"col":1,"value":"42"}' >/dev/null || fail "add number cell"
  pass "add number cell"
  
  # Test listing cells
  local cells
  cells=$(curl -sf "$BASE_URL/cells" | jq -e '.' || fail "list cells")
  local count=$(echo "$cells" | jq 'length')
  if [[ "$count" -eq 2 ]]; then
    pass "list cells returns correct count ($count)"
  else
    fail "expected 2 cells, got $count"
  fi
  
  # Verify cell content
  local cell1_value=$(echo "$cells" | jq -r '.[] | select(.row==0 and .col==0) | .value')
  local cell2_value=$(echo "$cells" | jq -r '.[] | select(.row==0 and .col==1) | .value')
  
  if [[ "$cell1_value" == "Hello World" ]]; then
    pass "cell (0,0) contains correct value"
  else
    fail "cell (0,0) value is '$cell1_value', expected 'Hello World'"
  fi
  
  if [[ "$cell2_value" == "42" ]]; then
    pass "cell (0,1) contains correct value"
  else
    fail "cell (0,1) value is '$cell2_value', expected '42'"
  fi
}

# Test cell formatting (colors, bold, italic)
test_cell_formatting() {
  info "Testing cell formatting..."
  
  # Test bold text
  curl -sf -X POST "$BASE_URL/cells" -H 'Content-Type: application/json' \
    -d '{"row":1,"col":0,"value":"Bold Text","font_weight":"bold"}' >/dev/null || fail "add bold cell"
  pass "add cell with bold formatting"
  
  # Test italic text
  curl -sf -X POST "$BASE_URL/cells" -H 'Content-Type: application/json' \
    -d '{"row":1,"col":1,"value":"Italic Text","font_style":"italic"}' >/dev/null || fail "add italic cell"
  pass "add cell with italic formatting"
  
  # Test background color
  curl -sf -X POST "$BASE_URL/cells" -H 'Content-Type: application/json' \
    -d '{"row":1,"col":2,"value":"Colored","background_color":"#ff0000"}' >/dev/null || fail "add colored cell"
  pass "add cell with background color"
  
  # Test combination formatting
  curl -sf -X POST "$BASE_URL/cells" -H 'Content-Type: application/json' \
    -d '{"row":1,"col":3,"value":"All Formats","font_weight":"bold","font_style":"italic","background_color":"#00ff00"}' >/dev/null || fail "add fully formatted cell"
  pass "add cell with multiple formats"
  
  # Verify formatting is preserved
  local cells=$(curl -sf "$BASE_URL/cells")
  local bold_cell=$(echo "$cells" | jq -r '.[] | select(.row==1 and .col==0)')
  local font_weight=$(echo "$bold_cell" | jq -r '.font_weight')
  
  if [[ "$font_weight" == "bold" ]]; then
    pass "bold formatting preserved"
  else
    fail "bold formatting not preserved, got '$font_weight'"
  fi
  
  local colored_cell=$(echo "$cells" | jq -r '.[] | select(.row==1 and .col==2)')
  local bg_color=$(echo "$colored_cell" | jq -r '.background_color')
  
  if [[ "$bg_color" == "#ff0000" ]]; then
    pass "background color preserved"
  else
    fail "background color not preserved, got '$bg_color'"
  fi
}

# Test formula evaluation
test_formulas() {
  info "Testing formula evaluation..."
  
  # Test SUM function
  local res
  res=$(curl -sf -X POST "$BASE_URL/evaluate" -H 'Content-Type: application/json' \
    -d '{"expr":"=SUM(1,2,3,4,5)"}' || fail "evaluate SUM formula")
  if [[ "$res" == "15" ]]; then
    pass "SUM formula evaluation"
  else
    fail "SUM formula returned '$res', expected '15'"
  fi
  
  # Test AVERAGE function
  res=$(curl -sf -X POST "$BASE_URL/evaluate" -H 'Content-Type: application/json' \
    -d '{"expr":"=AVERAGE(2,4,6)"}' || fail "evaluate AVERAGE formula")
  if [[ "$res" == "4" ]]; then
    pass "AVERAGE formula evaluation"
  else
    fail "AVERAGE formula returned '$res', expected '4'"
  fi
  
  # Test basic arithmetic
  res=$(curl -sf -X POST "$BASE_URL/evaluate" -H 'Content-Type: application/json' \
    -d '{"expr":"=10+5*2"}' || fail "evaluate arithmetic formula")
  if [[ "$res" == "20" ]]; then
    pass "arithmetic formula evaluation"
  else
    fail "arithmetic formula returned '$res', expected '20'"
  fi
  
  # Test complex expression
  res=$(curl -sf -X POST "$BASE_URL/evaluate" -H 'Content-Type: application/json' \
    -d '{"expr":"=SUM(1,2,3) + AVERAGE(4,6)"}' || fail "evaluate complex formula")
  if [[ "$res" == "11" ]]; then
    pass "complex formula evaluation"
  else
    fail "complex formula returned '$res', expected '11'"
  fi
}

# Test formula cells (cells that contain formulas)
test_formula_cells() {
  info "Testing formula cells..."
  
  # Add some data cells for formulas to reference
  curl -sf -X POST "$BASE_URL/cells" -H 'Content-Type: application/json' \
    -d '{"row":5,"col":0,"value":"10"}' >/dev/null || fail "add data cell A6"
  curl -sf -X POST "$BASE_URL/cells" -H 'Content-Type: application/json' \
    -d '{"row":5,"col":1,"value":"20"}' >/dev/null || fail "add data cell B6"
  curl -sf -X POST "$BASE_URL/cells" -H 'Content-Type: application/json' \
    -d '{"row":5,"col":2,"value":"30"}' >/dev/null || fail "add data cell C6"
  
  # Add formula cell that references other cells
  curl -sf -X POST "$BASE_URL/cells" -H 'Content-Type: application/json' \
    -d '{"row":6,"col":0,"value":"=SUM(A6,B6,C6)"}' >/dev/null || fail "add formula cell"
  pass "add formula cell with cell references"
  
  # Verify formula was evaluated
  local cells=$(curl -sf "$BASE_URL/cells")
  local formula_result=$(echo "$cells" | jq -r '.[] | select(.row==6 and .col==0) | .value')
  
  if [[ "$formula_result" == "60" ]]; then
    pass "formula cell evaluated correctly (60)"
  else
    fail "formula cell result is '$formula_result', expected '60'"
  fi
}

# Test bulk operations
test_bulk_operations() {
  info "Testing bulk operations..."
  
  # Test bulk insert
  local bulk_data='[
    {"row":10,"col":0,"value":"Bulk1","font_weight":"bold"},
    {"row":10,"col":1,"value":"Bulk2","font_style":"italic"},
    {"row":10,"col":2,"value":"Bulk3","background_color":"#0000ff"},
    {"row":10,"col":3,"value":"Bulk4"},
    {"row":10,"col":4,"value":"Bulk5"}
  ]'
  
  curl -sf -X POST "$BASE_URL/cells/bulk" -H 'Content-Type: application/json' \
    -d "$bulk_data" >/dev/null || fail "bulk insert cells"
  pass "bulk insert 5 cells"
  
  # Verify bulk insert
  local cells=$(curl -sf "$BASE_URL/cells")
  local bulk_count=$(echo "$cells" | jq '[.[] | select(.row==10)] | length')
  
  if [[ "$bulk_count" -eq 5 ]]; then
    pass "bulk insert created correct number of cells"
  else
    fail "bulk insert created $bulk_count cells, expected 5"
  fi
  
  # Test bulk clear
  local clear_data='[
    {"row":10,"col":0},
    {"row":10,"col":1},
    {"row":10,"col":2}
  ]'
  
  curl -sf -X POST "$BASE_URL/cells/clear" -H 'Content-Type: application/json' \
    -d "{\"cells\":$clear_data}" >/dev/null || fail "bulk clear cells"
  pass "bulk clear 3 cells"
  
  # Verify bulk clear
  cells=$(curl -sf "$BASE_URL/cells")
  local remaining_count=$(echo "$cells" | jq '[.[] | select(.row==10)] | length')
  
  if [[ "$remaining_count" -eq 2 ]]; then
    pass "bulk clear removed correct number of cells"
  else
    fail "bulk clear left $remaining_count cells, expected 2"
  fi
}

# Test large dataset performance
test_large_dataset() {
  info "Testing large dataset operations..."
  
  # Create a large bulk insert (100 cells)
  local large_data='['
  for i in {0..99}; do
    local row=$((i / 10))
    local col=$((i % 10))
    local value="Cell_${row}_${col}"
    local color=$(printf "#%02x%02x%02x" $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256)))
    
    if [[ $i -gt 0 ]]; then
      large_data+=','
    fi
    large_data+="{\"row\":$((row + 20)),\"col\":$col,\"value\":\"$value\",\"background_color\":\"$color\"}"
  done
  large_data+=']'
  
  curl -sf -X POST "$BASE_URL/cells/bulk" -H 'Content-Type: application/json' \
    -d "$large_data" >/dev/null || fail "insert large dataset"
  pass "insert large dataset (100 cells)"
  
  # Verify large dataset
  local cells=$(curl -sf "$BASE_URL/cells")
  local large_count=$(echo "$cells" | jq '[.[] | select(.row >= 20 and .row < 30)] | length')
  
  if [[ "$large_count" -eq 100 ]]; then
    pass "large dataset contains correct number of cells"
  else
    fail "large dataset contains $large_count cells, expected 100"
  fi
  
  # Test retrieving large dataset
  local start_time=$(date +%s%N)
  curl -sf "$BASE_URL/cells" >/dev/null || fail "retrieve large dataset"
  local end_time=$(date +%s%N)
  local duration=$(( (end_time - start_time) / 1000000 )) # Convert to milliseconds
  
  pass "retrieve large dataset (${duration}ms)"
  
  if [[ $duration -lt 1000 ]]; then
    pass "large dataset retrieval performance acceptable (<1s)"
  else
    warn "large dataset retrieval took ${duration}ms (>1s)"
  fi
}

# Test edge cases and error handling
test_edge_cases() {
  info "Testing edge cases..."
  
  # Test empty formula (should return empty result, not error)
  local res
  res=$(curl -sf -X POST "$BASE_URL/evaluate" -H 'Content-Type: application/json' \
    -d '{"expr":"="}' || fail "evaluate empty formula")
  if [[ "$res" == "()" ]]; then
    pass "empty formula returns empty result"
  else
    fail "empty formula returned '$res', expected '()'"
  fi
  
  # Test invalid formula (should return 400 error)
  local http_code
  res=$(curl -s -w "%{http_code}" -X POST "$BASE_URL/evaluate" -H 'Content-Type: application/json' \
    -d '{"expr":"=INVALID_FUNCTION(1,2)"}' 2>/dev/null || true)
  http_code="${res: -3}"  # Get last 3 characters (HTTP code)
  
  if [[ "$http_code" == "400" ]]; then
    pass "invalid formula returns 400 error"
  else
    fail "invalid formula returned HTTP $http_code, expected 400"
  fi
  
  # Test cell with extreme coordinates
  curl -sf -X POST "$BASE_URL/cells" -H 'Content-Type: application/json' \
    -d '{"row":999999,"col":999999,"value":"Edge case"}' >/dev/null || fail "add cell with large coordinates"
  pass "add cell with large coordinates"
  
  # Test very long cell value
  local long_value=$(printf 'A%.0s' {1..1000})
  curl -sf -X POST "$BASE_URL/cells" -H 'Content-Type: application/json' \
    -d "{\"row\":1000,\"col\":0,\"value\":\"$long_value\"}" >/dev/null || fail "add cell with long value"
  pass "add cell with very long value (1000 chars)"
  
  # Test special characters in cell value
  curl -sf -X POST "$BASE_URL/cells" -H 'Content-Type: application/json' \
    -d '{"row":1001,"col":0,"value":"Special: !@#$%^&*()[]{}|\\:;\"'"'"'<>?,."}' >/dev/null || fail "add cell with special characters"
  pass "add cell with special characters"
}

# Test cell updates (overwriting existing cells)
test_cell_updates() {
  info "Testing cell updates..."
  
  # Add initial cell
  curl -sf -X POST "$BASE_URL/cells" -H 'Content-Type: application/json' \
    -d '{"row":50,"col":0,"value":"Original","background_color":"#ff0000"}' >/dev/null || fail "add original cell"
  pass "add original cell"
  
  # Update the same cell
  curl -sf -X POST "$BASE_URL/cells" -H 'Content-Type: application/json' \
    -d '{"row":50,"col":0,"value":"Updated","font_weight":"bold","background_color":"#00ff00"}' >/dev/null || fail "update cell"
  pass "update existing cell"
  
  # Verify update
  local cells=$(curl -sf "$BASE_URL/cells")
  local cell_count=$(echo "$cells" | jq '[.[] | select(.row==50 and .col==0)] | length')
  local cell_value=$(echo "$cells" | jq -r '.[] | select(.row==50 and .col==0) | .value')
  local cell_color=$(echo "$cells" | jq -r '.[] | select(.row==50 and .col==0) | .background_color')
  local cell_weight=$(echo "$cells" | jq -r '.[] | select(.row==50 and .col==0) | .font_weight')
  
  if [[ "$cell_count" -eq 1 ]]; then
    pass "cell update doesn't create duplicates"
  else
    fail "cell update created $cell_count entries, expected 1"
  fi
  
  if [[ "$cell_value" == "Updated" ]]; then
    pass "cell value updated correctly"
  else
    fail "cell value is '$cell_value', expected 'Updated'"
  fi
  
  if [[ "$cell_color" == "#00ff00" ]]; then
    pass "cell background color updated correctly"
  else
    fail "cell background color is '$cell_color', expected '#00ff00'"
  fi
  
  if [[ "$cell_weight" == "bold" ]]; then
    pass "cell font weight updated correctly"
  else
    fail "cell font weight is '$cell_weight', expected 'bold'"
  fi
}

# Run all tests
run_all_tests() {
  echo -e "${BLUE}Starting comprehensive AIXcel backend tests...${NC}"
  echo "Base URL: $BASE_URL"
  echo "Backup file: $BACKUP_FILE"
  echo ""
  
  backup_data
  clear_all_data
  
  test_health
  test_basic_cell_operations
  test_cell_formatting
  test_formulas
  test_formula_cells
  test_bulk_operations
  test_large_dataset
  test_edge_cases
  test_cell_updates
  
  clear_all_data
  restore_data
}

# Cleanup function
cleanup() {
  info "Cleaning up..."
  restore_data
}

# Set trap for cleanup
trap cleanup EXIT

# Main execution
run_all_tests

echo ""
echo -e "${GREEN}🎉 All tests completed successfully!${NC}"
echo ""
echo "Test Summary:"
for result in "${TEST_RESULTS[@]}"; do
  if [[ "$result" == PASS* ]]; then
    echo -e "  ${GREEN}✓${NC} ${result#PASS: }"
  else
    echo -e "  ${RED}✗${NC} ${result#FAIL: }"
  fi
done

echo ""
echo -e "${BLUE}Total tests passed: $(printf '%s\n' "${TEST_RESULTS[@]}" | grep -c "^PASS")${NC}"
echo -e "${BLUE}Backend is fully functional!${NC}"
