#!/bin/bash
# AIXcel Mega Benchmark - Extreme Testing with Thousands of Columns and Operations
# This script tests the absolute limits of the AIXcel backend

set -euo pipefail

BACKEND_URL="${1:-http://192.168.10.161:6889}"
BACKUP_FILE="/tmp/aixcel_mega_backup_$(date +%s).json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Extreme benchmark configuration
THOUSAND_COLS=1000      # 1000 columns
FIVE_THOUSAND_COLS=5000 # 5000 columns
TEN_THOUSAND_COLS=10000 # 10000 columns
EXTREME_ROWS=1000       # Combined with columns for massive datasets
FORMULA_COMPLEXITY=5000 # Complex formula chains
CONCURRENT_CLIENTS=100  # Simulate 100 concurrent users
BULK_OPERATIONS=50000   # 50k bulk operations

# Test metrics
TOTAL_OPERATIONS=0
TOTAL_TIME=0
ERRORS=0

info() {
    echo -e "${BLUE}ℹ ${BOLD}$1${NC}"
}

mega() {
    echo -e "${MAGENTA}🚀 ${BOLD}MEGA: $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warn() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

fail() {
    echo -e "${RED}❌ $1${NC}"
    ((ERRORS++))
}

fatal() {
    echo -e "${RED}💀 FATAL: $1${NC}"
    restore_data
    exit 1
}

# Metrics tracking
start_timer() {
    echo $(date +%s.%N)
}

end_timer() {
    local start_time=$1
    local end_time=$(date +%s.%N)
    echo "scale=3; $end_time - $start_time" | bc
}

# Backup existing data
backup_data() {
    info "Backing up existing data..."
    curl -sf "$BACKEND_URL/cells" > "$BACKUP_FILE" || fatal "Failed to backup data"
    local count=$(cat "$BACKUP_FILE" | jq 'length')
    info "Backed up $count cells to $BACKUP_FILE"
}

# Restore backed up data
restore_data() {
    if [[ -f "$BACKUP_FILE" ]]; then
        info "Restoring backed up data..."
        # Clear current data first
        local current_cells=$(curl -sf "$BACKEND_URL/cells" | jq -r '.[] | {row: .row, col: .col}' | jq -s '.')
        if [[ "$current_cells" != "[]" ]]; then
            curl -sf -X POST "$BACKEND_URL/cells/clear" -H 'Content-Type: application/json' \
                -d "{\"cells\":$current_cells}" >/dev/null || warn "Failed to clear current data"
        fi
        
        # Restore backup if it contains data
        local backup_count=$(cat "$BACKUP_FILE" | jq 'length')
        if [[ "$backup_count" -gt 0 ]]; then
            curl -sf -X POST "$BACKEND_URL/cells/bulk" -H 'Content-Type: application/json' \
                -d @"$BACKUP_FILE" >/dev/null || warn "Failed to restore backup data"
            info "Restored $backup_count cells"
        fi
        rm -f "$BACKUP_FILE"
    fi
}

# Clear all test data
clear_all_data() {
    local cells=$(curl -sf "$BACKEND_URL/cells" | jq -r '.[] | {row: .row, col: .col}' | jq -s '.')
    if [[ "$cells" != "[]" ]]; then
        curl -sf -X POST "$BACKEND_URL/cells/clear" -H 'Content-Type: application/json' \
            -d "{\"cells\":$cells}" >/dev/null || fail "clear all test data"
    fi
}

# Generate massive column datasets
generate_mega_columns() {
    local num_cols=$1
    local num_rows=${2:-10}
    local base_row=${3:-1000}
    
    mega "Generating $num_cols columns × $num_rows rows = $(($num_cols * $num_rows)) cells"
    
    local data='['
    for ((row=0; row<num_rows; row++)); do
        for ((col=0; col<num_cols; col++)); do
            local actual_row=$(($base_row + $row))
            local value=""
            local bg_color=""
            local font_weight=""
            
            # Vary data types across columns
            case $(($col % 5)) in
                0) value="\"Text_${actual_row}_${col}\"" ;;
                1) value=$(($RANDOM % 10000)) ;;
                2) value="$(echo "scale=2; $RANDOM / 100" | bc)" ;;
                3) value="true" ;;
                4) value="\"=A${actual_row}+B${actual_row}\"" ;;
            esac
            
            # Add formatting to some cells
            if (( $col % 100 == 0 )); then
                bg_color="\"#FFD700\""
                font_weight="\"bold\""
            fi
            
            if [[ $row -gt 0 || $col -gt 0 ]]; then
                data+=','
            fi
            
            data+="{\"row\":$actual_row,\"col\":$col,\"value\":$value"
            if [[ -n "$bg_color" ]]; then
                data+=",\"bg_color\":$bg_color"
            fi
            if [[ -n "$font_weight" ]]; then
                data+=",\"font_weight\":$font_weight"
            fi
            data+="}"
        done
    done
    data+=']'
    
    echo "$data"
}

# Test massive column creation
test_mega_columns() {
    local num_cols=$1
    local test_name="$2"
    
    mega "Testing $test_name ($num_cols columns)"
    clear_all_data
    
    local start_time=$(start_timer)
    local data=$(generate_mega_columns $num_cols 5)
    local gen_time=$(end_timer $start_time)
    
    info "Generated data in ${gen_time}s"
    
    # Send bulk data
    start_time=$(start_timer)
    local response=$(curl -sf -X POST "$BACKEND_URL/cells/bulk" \
        -H 'Content-Type: application/json' \
        -d "$data" 2>/dev/null)
    local send_time=$(end_timer $start_time)
    
    if echo "$response" | jq -e .success >/dev/null; then
        success "$test_name: $(($num_cols * 5)) cells created in ${send_time}s"
        TOTAL_OPERATIONS=$(($TOTAL_OPERATIONS + $num_cols * 5))
        TOTAL_TIME=$(echo "$TOTAL_TIME + $send_time" | bc)
    else
        fail "$test_name: Failed to create mega columns"
        return 1
    fi
    
    # Test retrieval speed
    start_time=$(start_timer)
    local cells=$(curl -sf "$BACKEND_URL/cells" | jq 'length')
    local retrieve_time=$(end_timer $start_time)
    
    success "$test_name: Retrieved $cells cells in ${retrieve_time}s"
    
    # Test individual cell access across columns
    start_time=$(start_timer)
    for ((i=0; i<10; i++)); do
        local rand_col=$(($RANDOM % $num_cols))
        curl -sf "$BACKEND_URL/cells?row=1000&col=$rand_col" >/dev/null
    done
    local access_time=$(end_timer $start_time)
    
    success "$test_name: Random cell access (10 cells) in ${access_time}s"
    
    return 0
}

# Test formula chains across many columns
test_mega_formulas() {
    local num_formulas=$1
    
    mega "Testing $num_formulas interconnected formulas"
    clear_all_data
    
    # Create base data in first 100 columns
    local base_data='['
    for ((col=0; col<100; col++)); do
        if [[ $col -gt 0 ]]; then base_data+=','; fi
        base_data+="{\"row\":2000,\"col\":$col,\"value\":$(($col + 1))}"
    done
    base_data+=']'
    
    curl -sf -X POST "$BACKEND_URL/cells/bulk" \
        -H 'Content-Type: application/json' \
        -d "$base_data" >/dev/null || fail "Create base data for formulas"
    
    # Create formula chains
    local start_time=$(start_timer)
    local formula_data='['
    for ((i=0; i<num_formulas; i++)); do
        local row=2001
        local col=$(($i % 1000))  # Spread across 1000 columns
        local ref_col=$(($i % 100))  # Reference base data
        
        if [[ $i -gt 0 ]]; then formula_data+=','; fi
        
        case $(($i % 4)) in
            0) formula_data+="{\"row\":$row,\"col\":$col,\"value\":\"=SUM(A2000:J2000)\"}" ;;
            1) formula_data+="{\"row\":$row,\"col\":$col,\"value\":\"=AVERAGE(A2000:Z2000)\"}" ;;
            2) formula_data+="{\"row\":$row,\"col\":$col,\"value\":\"=A2000*B2000+C2000\"}" ;;
            3) formula_data+="{\"row\":$row,\"col\":$col,\"value\":\"=IF(A2000>50,\\\"HIGH\\\",\\\"LOW\\\")\"}" ;;
        esac
    done
    formula_data+=']'
    
    local response=$(curl -sf -X POST "$BACKEND_URL/cells/bulk" \
        -H 'Content-Type: application/json' \
        -d "$formula_data" 2>/dev/null)
    local formula_time=$(end_timer $start_time)
    
    if echo "$response" | jq -e .success >/dev/null; then
        success "Created $num_formulas formulas in ${formula_time}s"
        TOTAL_OPERATIONS=$(($TOTAL_OPERATIONS + $num_formulas))
        TOTAL_TIME=$(echo "$TOTAL_TIME + $formula_time" | bc)
    else
        fail "Failed to create mega formulas"
    fi
    
    # Test formula evaluation
    start_time=$(start_timer)
    for ((i=0; i<100; i++)); do
        local rand_col=$(($RANDOM % 1000))
        curl -sf "$BACKEND_URL/evaluate" \
            -H 'Content-Type: application/json' \
            -d "{\"formula\":\"=SUM(A2000:C2000)\",\"row\":2001,\"col\":$rand_col}" >/dev/null
    done
    local eval_time=$(end_timer $start_time)
    
    success "Evaluated 100 random formulas in ${eval_time}s"
}

# Simulate concurrent users with column operations
test_concurrent_mega_users() {
    local num_clients=$1
    
    mega "Simulating $num_clients concurrent users with column operations"
    clear_all_data
    
    # Create background tasks
    local pids=()
    local start_time=$(start_timer)
    
    for ((client=0; client<num_clients; client++)); do
        {
            local client_row=$(($client + 3000))
            local success_count=0
            local client_ops=50
            
            for ((op=0; op<client_ops; op++)); do
                local col=$(($RANDOM % 2000))  # Random column 0-1999
                local value="Client${client}_Op${op}_$(date +%s%N | tail -c 6)"
                
                if curl -sf -X POST "$BACKEND_URL/cells" \
                    -H 'Content-Type: application/json' \
                    -d "{\"row\":$client_row,\"col\":$col,\"value\":\"$value\"}" >/dev/null 2>&1; then
                    ((success_count++))
                fi
                
                # Add some random delays to simulate real usage
                sleep 0.0$((RANDOM % 5))
            done
            
            echo "Client $client completed $success_count/$client_ops operations"
        } &
        pids+=($!)
    done
    
    # Wait for all clients to complete
    for pid in "${pids[@]}"; do
        wait $pid
    done
    
    local concurrent_time=$(end_timer $start_time)
    success "Concurrent test completed in ${concurrent_time}s"
    
    # Check final state
    local final_cells=$(curl -sf "$BACKEND_URL/cells" | jq 'length')
    success "Final state: $final_cells cells after concurrent operations"
    
    TOTAL_TIME=$(echo "$TOTAL_TIME + $concurrent_time" | bc)
}

# Memory and performance stress test
test_memory_stress() {
    mega "Memory and performance stress test"
    
    # Monitor memory usage
    local backend_pid=$(pgrep -f "backend" | head -1)
    if [[ -n "$backend_pid" ]]; then
        local initial_memory=$(ps -p $backend_pid -o rss= | tr -d ' ')
        info "Initial backend memory: ${initial_memory}KB"
    fi
    
    # Create massive dataset in chunks
    clear_all_data
    local chunk_size=1000
    local total_chunks=50  # 50k cells total
    
    local start_time=$(start_timer)
    for ((chunk=0; chunk<total_chunks; chunk++)); do
        local chunk_data=$(generate_mega_columns 100 10 $(($chunk * 100)))
        
        if ! curl -sf -X POST "$BACKEND_URL/cells/bulk" \
            -H 'Content-Type: application/json' \
            -d "$chunk_data" >/dev/null 2>&1; then
            fail "Memory stress: Failed at chunk $chunk"
            break
        fi
        
        if (( $chunk % 10 == 0 )); then
            info "Memory stress: Completed chunk $chunk/$total_chunks"
        fi
    done
    
    local stress_time=$(end_timer $start_time)
    
    if [[ -n "$backend_pid" ]]; then
        local final_memory=$(ps -p $backend_pid -o rss= | tr -d ' ')
        local memory_increase=$((final_memory - initial_memory))
        info "Final backend memory: ${final_memory}KB (+${memory_increase}KB)"
    fi
    
    local final_cells=$(curl -sf "$BACKEND_URL/cells" | jq 'length')
    success "Memory stress: Created $final_cells cells in ${stress_time}s"
    
    TOTAL_TIME=$(echo "$TOTAL_TIME + $stress_time" | bc)
}

# Performance metrics summary
show_metrics() {
    mega "PERFORMANCE METRICS SUMMARY"
    echo "=================================="
    echo -e "Total Operations: ${BOLD}$TOTAL_OPERATIONS${NC}"
    echo -e "Total Time: ${BOLD}${TOTAL_TIME}s${NC}"
    if [[ "$TOTAL_TIME" != "0" ]]; then
        local ops_per_sec=$(echo "scale=2; $TOTAL_OPERATIONS / $TOTAL_TIME" | bc)
        echo -e "Operations/Second: ${BOLD}$ops_per_sec${NC}"
    fi
    echo -e "Errors: ${BOLD}$ERRORS${NC}"
    echo "=================================="
}

# Cleanup function
cleanup() {
    info "Cleaning up..."
    restore_data
    show_metrics
}

# Trap cleanup on exit
trap cleanup EXIT

# Main execution
main() {
    mega "AIXcel Mega Benchmark Starting"
    echo -e "${BOLD}Backend URL: $BACKEND_URL${NC}"
    echo -e "${BOLD}Test Configuration:${NC}"
    echo "  - Max Columns: $TEN_THOUSAND_COLS"
    echo "  - Concurrent Clients: $CONCURRENT_CLIENTS"
    echo "  - Formula Tests: $FORMULA_COMPLEXITY"
    echo "  - Bulk Operations: $BULK_OPERATIONS"
    echo ""
    
    # Backup existing data
    backup_data
    
    # Health check
    if ! curl -sf "$BACKEND_URL/health" >/dev/null; then
        fatal "Backend health check failed"
    fi
    
    # Run mega tests
    mega "Phase 1: Column Scalability Tests"
    test_mega_columns $THOUSAND_COLS "1K Columns Test"
    test_mega_columns $FIVE_THOUSAND_COLS "5K Columns Test"
    test_mega_columns $TEN_THOUSAND_COLS "10K Columns Test"
    
    mega "Phase 2: Formula Complexity Tests"
    test_mega_formulas $FORMULA_COMPLEXITY
    
    mega "Phase 3: Concurrent User Simulation"
    test_concurrent_mega_users $CONCURRENT_CLIENTS
    
    mega "Phase 4: Memory and Performance Stress"
    test_memory_stress
    
    mega "MEGA BENCHMARK COMPLETED!"
    if [[ $ERRORS -eq 0 ]]; then
        success "All tests passed! 🎉"
    else
        warn "$ERRORS test(s) failed"
    fi
}

# Check dependencies
if ! command -v jq >/dev/null; then
    fatal "jq is required but not installed"
fi

if ! command -v bc >/dev/null; then
    fatal "bc is required but not installed"
fi

# Run the mega benchmark
main "$@"
