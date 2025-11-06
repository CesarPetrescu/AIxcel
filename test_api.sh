#!/bin/bash

# AIxcel API Test Script
# This script performs comprehensive API testing of the AIxcel backend

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
BACKEND_URL="${BACKEND_URL:-http://localhost:6889}"
TEST_SHEET="test_$(date +%s)"

# Counter for tests
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Function to print test results
print_test() {
    local name="$1"
    local result="$2"
    TESTS_RUN=$((TESTS_RUN + 1))
    if [ "$result" == "PASS" ]; then
        echo -e "${GREEN}✓${NC} $name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} $name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Function to make API calls with error handling
api_call() {
    local method="$1"
    local endpoint="$2"
    local data="$3"

    if [ "$method" == "GET" ]; then
        curl -s -w "\n%{http_code}" "$BACKEND_URL$endpoint"
    else
        curl -s -w "\n%{http_code}" -X "$method" \
            -H "Content-Type: application/json" \
            -d "$data" \
            "$BACKEND_URL$endpoint"
    fi
}

echo "========================================="
echo "AIxcel API Comprehensive Test Suite"
echo "========================================="
echo "Backend URL: $BACKEND_URL"
echo "Test Sheet: $TEST_SHEET"
echo ""

# Test 1: Health Check
echo "Running Health Check Tests..."
RESPONSE=$(api_call GET "/health")
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | head -n -1)

if [ "$HTTP_CODE" == "200" ] && [ "$BODY" == "ok" ]; then
    print_test "Health endpoint returns 200 OK" "PASS"
else
    print_test "Health endpoint returns 200 OK" "FAIL"
fi

# Test 2: Create a Cell
echo ""
echo "Running Cell CRUD Tests..."
CELL_DATA='{
    "sheet": "'"$TEST_SHEET"'",
    "row": 0,
    "col": 0,
    "value": "Test Value"
}'
RESPONSE=$(api_call POST "/cells" "$CELL_DATA")
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [ "$HTTP_CODE" == "200" ]; then
    print_test "Create cell returns 200" "PASS"
else
    print_test "Create cell returns 200" "FAIL"
fi

# Test 3: List Cells
RESPONSE=$(api_call GET "/cells?sheet=$TEST_SHEET")
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | head -n -1)

if [ "$HTTP_CODE" == "200" ] && echo "$BODY" | grep -q "Test Value"; then
    print_test "List cells returns created cell" "PASS"
else
    print_test "List cells returns created cell" "FAIL"
fi

# Test 4: Update Cell
CELL_DATA='{
    "sheet": "'"$TEST_SHEET"'",
    "row": 0,
    "col": 0,
    "value": "Updated Value"
}'
RESPONSE=$(api_call POST "/cells" "$CELL_DATA")
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [ "$HTTP_CODE" == "200" ]; then
    print_test "Update cell returns 200" "PASS"
else
    print_test "Update cell returns 200" "FAIL"
fi

RESPONSE=$(api_call GET "/cells?sheet=$TEST_SHEET")
BODY=$(echo "$RESPONSE" | head -n -1)

if echo "$BODY" | grep -q "Updated Value"; then
    print_test "Cell value was updated correctly" "PASS"
else
    print_test "Cell value was updated correctly" "FAIL"
fi

# Test 5: Cell with Formatting
echo ""
echo "Running Formatting Tests..."
FORMATTED_CELL='{
    "sheet": "'"$TEST_SHEET"'",
    "row": 1,
    "col": 0,
    "value": "Formatted",
    "font_weight": "bold",
    "font_style": "italic",
    "background_color": "#ff0000"
}'
RESPONSE=$(api_call POST "/cells" "$FORMATTED_CELL")
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [ "$HTTP_CODE" == "200" ]; then
    print_test "Create formatted cell returns 200" "PASS"
else
    print_test "Create formatted cell returns 200" "FAIL"
fi

RESPONSE=$(api_call GET "/cells?sheet=$TEST_SHEET")
BODY=$(echo "$RESPONSE" | head -n -1)

if echo "$BODY" | grep -q '"font_weight":"bold"' && \
   echo "$BODY" | grep -q '"font_style":"italic"' && \
   echo "$BODY" | grep -q '"background_color":"#ff0000"'; then
    print_test "Formatting persisted correctly" "PASS"
else
    print_test "Formatting persisted correctly" "FAIL"
fi

# Test 6: Formula Evaluation - SUM
echo ""
echo "Running Formula Tests..."
EVAL_DATA='{"expr": "=SUM(1,2,3)", "sheet": "'"$TEST_SHEET"'"}'
RESPONSE=$(api_call POST "/evaluate" "$EVAL_DATA")
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | head -n -1)

if [ "$HTTP_CODE" == "200" ] && [ "$BODY" == "6" ]; then
    print_test "SUM formula evaluates correctly" "PASS"
else
    print_test "SUM formula evaluates correctly" "FAIL"
fi

# Test 7: Formula Evaluation - AVERAGE
EVAL_DATA='{"expr": "=AVERAGE(2,4,6)", "sheet": "'"$TEST_SHEET"'"}'
RESPONSE=$(api_call POST "/evaluate" "$EVAL_DATA")
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
BODY=$(echo "$RESPONSE" | head -n -1)

if [ "$HTTP_CODE" == "200" ] && [ "$BODY" == "4" ]; then
    print_test "AVERAGE formula evaluates correctly" "PASS"
else
    print_test "AVERAGE formula evaluates correctly" "FAIL"
fi

# Test 8: Formula in Cell
FORMULA_CELL='{
    "sheet": "'"$TEST_SHEET"'",
    "row": 2,
    "col": 0,
    "value": "=SUM(10,20,30)"
}'
RESPONSE=$(api_call POST "/cells" "$FORMULA_CELL")
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [ "$HTTP_CODE" == "200" ]; then
    print_test "Create formula cell returns 200" "PASS"
else
    print_test "Create formula cell returns 200" "FAIL"
fi

RESPONSE=$(api_call GET "/cells?sheet=$TEST_SHEET")
BODY=$(echo "$RESPONSE" | head -n -1)

if echo "$BODY" | grep -q '"row":2' && echo "$BODY" | grep -q '"value":"60"'; then
    print_test "Formula evaluated and stored correctly" "PASS"
else
    print_test "Formula evaluated and stored correctly" "FAIL"
fi

# Test 9: Formula with Cell References
echo ""
echo "Running Cell Reference Tests..."
CELL_A1='{"sheet": "'"$TEST_SHEET"'", "row": 10, "col": 0, "value": "5"}'
CELL_B1='{"sheet": "'"$TEST_SHEET"'", "row": 10, "col": 1, "value": "15"}'
CELL_C1='{"sheet": "'"$TEST_SHEET"'", "row": 10, "col": 2, "value": "=SUM(A11,B11)"}'

api_call POST "/cells" "$CELL_A1" > /dev/null
api_call POST "/cells" "$CELL_B1" > /dev/null
RESPONSE=$(api_call POST "/cells" "$CELL_C1")
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [ "$HTTP_CODE" == "200" ]; then
    print_test "Create formula with cell refs returns 200" "PASS"
else
    print_test "Create formula with cell refs returns 200" "FAIL"
fi

RESPONSE=$(api_call GET "/cells?sheet=$TEST_SHEET")
BODY=$(echo "$RESPONSE" | head -n -1)

if echo "$BODY" | grep -q '"row":10,"col":2' && echo "$BODY" | grep -q '"value":"20"'; then
    print_test "Cell reference formula evaluates correctly" "PASS"
else
    print_test "Cell reference formula evaluates correctly" "FAIL"
fi

# Test 10: Bulk Operations
echo ""
echo "Running Bulk Operation Tests..."
BULK_DATA='[
    {"sheet": "'"$TEST_SHEET"'", "row": 20, "col": 0, "value": "Bulk 1"},
    {"sheet": "'"$TEST_SHEET"'", "row": 21, "col": 0, "value": "Bulk 2"},
    {"sheet": "'"$TEST_SHEET"'", "row": 22, "col": 0, "value": "Bulk 3"}
]'
RESPONSE=$(api_call POST "/cells/bulk" "$BULK_DATA")
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [ "$HTTP_CODE" == "200" ]; then
    print_test "Bulk insert returns 200" "PASS"
else
    print_test "Bulk insert returns 200" "FAIL"
fi

RESPONSE=$(api_call GET "/cells?sheet=$TEST_SHEET")
BODY=$(echo "$RESPONSE" | head -n -1)

if echo "$BODY" | grep -q "Bulk 1" && \
   echo "$BODY" | grep -q "Bulk 2" && \
   echo "$BODY" | grep -q "Bulk 3"; then
    print_test "Bulk insert created all cells" "PASS"
else
    print_test "Bulk insert created all cells" "FAIL"
fi

# Test 11: Clear Cells
echo ""
echo "Running Clear Operation Tests..."
CLEAR_DATA='{
    "cells": [
        {"sheet": "'"$TEST_SHEET"'", "row": 20, "col": 0},
        {"sheet": "'"$TEST_SHEET"'", "row": 21, "col": 0}
    ]
}'
RESPONSE=$(api_call POST "/cells/clear" "$CLEAR_DATA")
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [ "$HTTP_CODE" == "200" ]; then
    print_test "Clear cells returns 200" "PASS"
else
    print_test "Clear cells returns 200" "FAIL"
fi

RESPONSE=$(api_call GET "/cells?sheet=$TEST_SHEET")
BODY=$(echo "$RESPONSE" | head -n -1)

if ! echo "$BODY" | grep -q '"row":20' && \
   ! echo "$BODY" | grep -q '"row":21' && \
   echo "$BODY" | grep -q '"row":22'; then
    print_test "Specified cells were cleared" "PASS"
else
    print_test "Specified cells were cleared" "FAIL"
fi

# Test 12: Edge Cases
echo ""
echo "Running Edge Case Tests..."

# Empty formula
EVAL_DATA='{"expr": "=", "sheet": "'"$TEST_SHEET"'"}'
RESPONSE=$(api_call POST "/evaluate" "$EVAL_DATA")
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [ "$HTTP_CODE" != "200" ]; then
    print_test "Empty formula returns error" "PASS"
else
    print_test "Empty formula returns error" "FAIL"
fi

# Invalid formula
EVAL_DATA='{"expr": "=INVALID(1,2,3)", "sheet": "'"$TEST_SHEET"'"}'
RESPONSE=$(api_call POST "/evaluate" "$EVAL_DATA")
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [ "$HTTP_CODE" != "200" ]; then
    print_test "Invalid formula returns error" "PASS"
else
    print_test "Invalid formula returns error" "FAIL"
fi

# Large number
EVAL_DATA='{"expr": "=SUM(999999999,999999999)", "sheet": "'"$TEST_SHEET"'"}'
RESPONSE=$(api_call POST "/evaluate" "$EVAL_DATA")
HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)

if [ "$HTTP_CODE" == "200" ]; then
    print_test "Large number calculation succeeds" "PASS"
else
    print_test "Large number calculation succeeds" "FAIL"
fi

# Test 13: Multiple Sheets
echo ""
echo "Running Multi-Sheet Tests..."
SHEET1_CELL='{"sheet": "sheet1", "row": 0, "col": 0, "value": "Sheet 1 Data"}'
SHEET2_CELL='{"sheet": "sheet2", "row": 0, "col": 0, "value": "Sheet 2 Data"}'

api_call POST "/cells" "$SHEET1_CELL" > /dev/null
api_call POST "/cells" "$SHEET2_CELL" > /dev/null

RESPONSE=$(api_call GET "/cells?sheet=sheet1")
BODY=$(echo "$RESPONSE" | head -n -1)

if echo "$BODY" | grep -q "Sheet 1 Data" && ! echo "$BODY" | grep -q "Sheet 2 Data"; then
    print_test "Sheet1 contains only its data" "PASS"
else
    print_test "Sheet1 contains only its data" "FAIL"
fi

RESPONSE=$(api_call GET "/cells?sheet=sheet2")
BODY=$(echo "$RESPONSE" | head -n -1)

if echo "$BODY" | grep -q "Sheet 2 Data" && ! echo "$BODY" | grep -q "Sheet 1 Data"; then
    print_test "Sheet2 contains only its data" "PASS"
else
    print_test "Sheet2 contains only its data" "FAIL"
fi

# Summary
echo ""
echo "========================================="
echo "Test Summary"
echo "========================================="
echo -e "Tests Run:    $TESTS_RUN"
echo -e "${GREEN}Tests Passed: $TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${RED}Tests Failed: $TESTS_FAILED${NC}"
else
    echo -e "${GREEN}Tests Failed: $TESTS_FAILED${NC}"
fi
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    exit 1
fi
