#!/bin/bash
# Quick test runner for AIXcel backend
# This script provides easy access to different types of tests

set -euo pipefail

BACKEND_URL="${1:-http://192.168.10.161:6889}"

echo "AIXcel Backend Test Runner"
echo "=========================="
echo "Backend URL: $BACKEND_URL"
echo ""

# Check if backend is running
if ! curl -sf "$BACKEND_URL/health" >/dev/null 2>&1; then
    echo "❌ Backend is not running at $BACKEND_URL"
    echo "   Please start the backend first with: cargo run"
    exit 1
fi

echo "✅ Backend is running"
echo ""

# Show current data count
CELL_COUNT=$(curl -sf "$BACKEND_URL/cells" | jq 'length' 2>/dev/null || echo "0")
echo "📊 Current spreadsheet contains $CELL_COUNT cells"
echo ""

# Menu
echo "Available tests:"
echo "1. Full comprehensive test suite (recommended)"
echo "2. Quick smoke test (basic functionality only)"
echo "3. Performance test (large dataset)"
echo "4. Show current spreadsheet data"
echo "5. Exit"
echo ""

read -p "Select option (1-5): " choice

case $choice in
    1)
        echo "Running full test suite..."
        ./test_api.sh "$BACKEND_URL"
        ;;
    2)
        echo "Running quick smoke test..."
        # Quick health check and basic operations
        echo "Testing health..."
        curl -sf "$BACKEND_URL/health" >/dev/null && echo "✅ Health OK"
        
        echo "Testing basic cell operations..."
        TEST_CELL='{"row":999,"col":999,"value":"test"}'
        curl -sf -X POST "$BACKEND_URL/cells" -H 'Content-Type: application/json' -d "$TEST_CELL" >/dev/null && echo "✅ Cell add OK"
        
        curl -sf "$BACKEND_URL/cells" | jq -e '.[] | select(.row==999 and .col==999)' >/dev/null && echo "✅ Cell retrieve OK"
        
        curl -sf -X POST "$BACKEND_URL/cells/clear" -H 'Content-Type: application/json' -d '{"cells":[{"row":999,"col":999}]}' >/dev/null && echo "✅ Cell clear OK"
        
        echo "✅ Quick smoke test passed!"
        ;;
    3)
        echo "Running performance test..."
        echo "Creating 1000 cells..."
        BULK_DATA='['
        for i in {0..999}; do
            row=$((i / 50))
            col=$((i % 50))
            if [[ $i -gt 0 ]]; then
                BULK_DATA+=','
            fi
            BULK_DATA+="{\"row\":$((row + 100)),\"col\":$col,\"value\":\"Perf_$i\"}"
        done
        BULK_DATA+=']'
        
        START_TIME=$(date +%s%N)
        curl -sf -X POST "$BACKEND_URL/cells/bulk" -H 'Content-Type: application/json' -d "$BULK_DATA" >/dev/null
        END_TIME=$(date +%s%N)
        INSERT_TIME=$(( (END_TIME - START_TIME) / 1000000 ))
        
        echo "✅ Bulk insert: ${INSERT_TIME}ms"
        
        START_TIME=$(date +%s%N)
        CELL_COUNT=$(curl -sf "$BACKEND_URL/cells" | jq 'length')
        END_TIME=$(date +%s%N)
        RETRIEVE_TIME=$(( (END_TIME - START_TIME) / 1000000 ))
        
        echo "✅ Retrieved $CELL_COUNT cells in ${RETRIEVE_TIME}ms"
        
        # Cleanup
        CLEAR_DATA=$(seq 0 999 | jq -R 'tonumber | {row: (. / 50 | floor) + 100, col: . % 50}' | jq -s '.')
        curl -sf -X POST "$BACKEND_URL/cells/clear" -H 'Content-Type: application/json' -d "{\"cells\":$CLEAR_DATA}" >/dev/null
        echo "✅ Performance test completed"
        ;;
    4)
        echo "Current spreadsheet data:"
        echo "========================"
        if [[ "$CELL_COUNT" -eq 0 ]]; then
            echo "(empty)"
        else
            curl -sf "$BACKEND_URL/cells" | jq -r '.[] | "(\(.row),\(.col)): \(.value) \(if .font_weight then "[" + .font_weight + "]" else "" end) \(if .background_color then "[" + .background_color + "]" else "" end)"' | head -20
            if [[ "$CELL_COUNT" -gt 20 ]]; then
                echo "... and $((CELL_COUNT - 20)) more cells"
            fi
        fi
        ;;
    5)
        echo "Goodbye!"
        exit 0
        ;;
    *)
        echo "Invalid option"
        exit 1
        ;;
esac
