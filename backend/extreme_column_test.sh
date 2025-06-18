#!/bin/bash
# AIXcel Extreme Column Width Test
# Tests the absolute limits of column count and data distribution

set -euo pipefail

BACKEND_URL="${1:-http://192.168.10.161:6889}"
BACKUP_FILE="/tmp/aixcel_column_backup_$(date +%s).json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Extreme column test configurations
ULTRA_COLUMNS=50000      # 50,000 columns
MEGA_COLUMNS=100000      # 100,000 columns
SPARSE_TEST_COLS=200000  # 200,000 columns (sparse)

info() { echo -e "${BLUE}ℹ ${BOLD}$1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
extreme() { echo -e "${MAGENTA}🔥 ${BOLD}EXTREME: $1${NC}"; }
warn() { echo -e "${YELLOW}⚠ $1${NC}"; }
fail() { echo -e "${RED}❌ $1${NC}"; }

# Backup and restore functions
backup_data() {
    info "Backing up existing data..."
    curl -sf "$BACKEND_URL/cells" > "$BACKUP_FILE" || exit 1
    local count=$(cat "$BACKUP_FILE" | jq 'length')
    info "Backed up $count cells"
}

restore_data() {
    if [[ -f "$BACKUP_FILE" ]]; then
        info "Restoring data..."
        local current_cells=$(curl -sf "$BACKEND_URL/cells" | jq -r '.[] | {row: .row, col: .col}' | jq -s '.')
        if [[ "$current_cells" != "[]" ]]; then
            curl -sf -X POST "$BACKEND_URL/cells/clear" -H 'Content-Type: application/json' \
                -d "{\"cells\":$current_cells}" >/dev/null
        fi
        
        local backup_count=$(cat "$BACKUP_FILE" | jq 'length')
        if [[ "$backup_count" -gt 0 ]]; then
            curl -sf -X POST "$BACKEND_URL/cells/bulk" -H 'Content-Type: application/json' \
                -d @"$BACKUP_FILE" >/dev/null
        fi
        rm -f "$BACKUP_FILE"
    fi
}

# Clear all data
clear_all_data() {
    local cells=$(curl -sf "$BACKEND_URL/cells" | jq -r '.[] | {row: .row, col: .col}' | jq -s '.')
    if [[ "$cells" != "[]" ]]; then
        curl -sf -X POST "$BACKEND_URL/cells/clear" -H 'Content-Type: application/json' \
            -d "{\"cells\":$cells}" >/dev/null
    fi
}

# Generate ultra-wide spreadsheet data
generate_ultra_wide_data() {
    local num_cols=$1
    local rows=${2:-3}
    local sparse=${3:-false}
    
    extreme "Generating ultra-wide data: $num_cols columns × $rows rows"
    
    local data='['
    local cell_count=0
    
    for ((row=0; row<rows; row++)); do
        for ((col=0; col<num_cols; col++)); do
            # For sparse mode, only populate every 1000th column
            if [[ "$sparse" == "true" && $(($col % 1000)) -ne 0 ]]; then
                continue
            fi
            
            if [[ $cell_count -gt 0 ]]; then
                data+=','
            fi
            
            local value=""
            case $(($col % 6)) in
                0) value="\"UltraWide_${row}_${col}\"" ;;
                1) value=$(($col % 10000)) ;;
                2) value="$(echo "scale=3; $col / 1000" | bc)" ;;
                3) value="true" ;;
                4) value="\"=A1+B1\"" ;;
                5) value="\"🔥Col${col}\"" ;;
            esac
            
            data+="{\"row\":$row,\"col\":$col,\"value\":$value"
            
            # Add formatting to milestone columns
            if (( $col % 10000 == 0 )); then
                data+=",\"bg_color\":\"#FF6B6B\",\"font_weight\":\"bold\""
            elif (( $col % 1000 == 0 )); then
                data+=",\"bg_color\":\"#4ECDC4\""
            fi
            
            data+="}"
            ((cell_count++))
        done
    done
    
    data+=']'
    info "Generated $cell_count cells for ultra-wide test"
    echo "$data"
}

# Test ultra-wide spreadsheet creation
test_ultra_wide() {
    local num_cols=$1
    local test_name="$2"
    local sparse=${3:-false}
    
    extreme "$test_name ($num_cols columns, sparse=$sparse)"
    clear_all_data
    
    local start_time=$(date +%s.%N)
    local data=$(generate_ultra_wide_data $num_cols 2 $sparse)
    local gen_time=$(echo "$(date +%s.%N) - $start_time" | bc)
    
    info "Data generation took ${gen_time}s"
    
    # Send in chunks to avoid request size limits
    local chunk_size=5000
    local total_cells=$(echo "$data" | jq 'length')
    local chunks=$(( ($total_cells + $chunk_size - 1) / $chunk_size ))
    
    info "Sending $total_cells cells in $chunks chunks"
    
    start_time=$(date +%s.%N)
    for ((chunk=0; chunk<chunks; chunk++)); do
        local start_idx=$(($chunk * $chunk_size))
        local chunk_data=$(echo "$data" | jq ".[$start_idx:$start_idx+$chunk_size]")
        
        if ! curl -sf -X POST "$BACKEND_URL/cells/bulk" \
            -H 'Content-Type: application/json' \
            -d "$chunk_data" >/dev/null 2>&1; then
            fail "$test_name: Failed to send chunk $chunk"
            return 1
        fi
        
        if (( $chunk % 10 == 0 )); then
            info "Sent chunk $chunk/$chunks"
        fi
    done
    
    local send_time=$(echo "$(date +%s.%N) - $start_time" | bc)
    success "$test_name: Sent all chunks in ${send_time}s"
    
    # Verify data integrity
    start_time=$(date +%s.%N)
    local stored_cells=$(curl -sf "$BACKEND_URL/cells" | jq 'length')
    local verify_time=$(echo "$(date +%s.%N) - $start_time" | bc)
    
    success "$test_name: Verified $stored_cells cells in ${verify_time}s"
    
    # Test random column access across the ultra-wide range
    start_time=$(date +%s.%N)
    local access_tests=20
    local successful_accesses=0
    
    for ((i=0; i<access_tests; i++)); do
        local random_col=$(($RANDOM % $num_cols))
        if curl -sf "$BACKEND_URL/cells?row=0&col=$random_col" >/dev/null 2>&1; then
            ((successful_accesses++))
        fi
    done
    
    local access_time=$(echo "$(date +%s.%N) - $start_time" | bc)
    success "$test_name: Random access $successful_accesses/$access_tests successful in ${access_time}s"
    
    return 0
}

# Test column range queries
test_column_ranges() {
    extreme "Testing column range queries on ultra-wide data"
    
    local ranges=(
        "0-999"      # First 1000 columns
        "49000-49999" # Last 1000 columns  
        "25000-25999" # Middle 1000 columns
        "0-9"         # First 10 columns
        "49990-49999" # Last 10 columns
    )
    
    for range in "${ranges[@]}"; do
        local start_col=$(echo $range | cut -d'-' -f1)
        local end_col=$(echo $range | cut -d'-' -f2)
        
        local start_time=$(date +%s.%N)
        local count=0
        
        # Query each column in range
        for ((col=start_col; col<=end_col; col++)); do
            if curl -sf "$BACKEND_URL/cells?col=$col" >/dev/null 2>&1; then
                ((count++))
            fi
        done
        
        local query_time=$(echo "$(date +%s.%N) - $start_time" | bc)
        success "Column range $range: $count queries in ${query_time}s"
    done
}

# Test formula evaluation across ultra-wide columns
test_ultra_wide_formulas() {
    extreme "Testing formulas across ultra-wide columns"
    
    clear_all_data
    
    # Create base numeric data in first 1000 columns
    local base_data='['
    for ((col=0; col<1000; col++)); do
        if [[ $col -gt 0 ]]; then base_data+=','; fi
        base_data+="{\"row\":0,\"col\":$col,\"value\":$(($col + 1))}"
    done
    base_data+=']'
    
    curl -sf -X POST "$BACKEND_URL/cells/bulk" \
        -H 'Content-Type: application/json' \
        -d "$base_data" >/dev/null
    
    # Create formulas that reference distant columns
    local formula_tests=(
        '{"row":1,"col":0,"value":"=SUM(A1:Z1)"}' 
        '{"row":1,"col":1000,"value":"=AVERAGE(A1:AAA1)")}'
        '{"row":1,"col":25000,"value":"=A1*Z1+AAA1"}'
        '{"row":1,"col":49000,"value":"=SUM(A1:J1)*COUNT(A1:J1)"}'
    )
    
    for formula in "${formula_tests[@]}"; do
        local start_time=$(date +%s.%N)
        
        if curl -sf -X POST "$BACKEND_URL/cells" \
            -H 'Content-Type: application/json' \
            -d "$formula" >/dev/null 2>&1; then
            local formula_time=$(echo "$(date +%s.%N) - $start_time" | bc)
            success "Ultra-wide formula created in ${formula_time}s"
        else
            fail "Ultra-wide formula failed"
        fi
    done
}

# Performance monitoring
monitor_performance() {
    extreme "Performance monitoring during ultra-wide operations"
    
    local backend_pid=$(pgrep -f "backend" | head -1)
    if [[ -z "$backend_pid" ]]; then
        warn "Could not find backend process for monitoring"
        return
    fi
    
    info "Monitoring backend process $backend_pid"
    
    # Monitor for 30 seconds during operations
    for ((i=0; i<30; i++)); do
        local cpu=$(ps -p $backend_pid -o %cpu= | tr -d ' ')
        local memory=$(ps -p $backend_pid -o rss= | tr -d ' ')
        
        echo "Time ${i}s: CPU=${cpu}% Memory=${memory}KB"
        
        # Perform some operations during monitoring
        curl -sf "$BACKEND_URL/cells?row=0&col=$(($RANDOM % 50000))" >/dev/null 2>&1 &
        
        sleep 1
    done
    
    success "Performance monitoring completed"
}

# Cleanup
cleanup() {
    info "Cleaning up extreme column test..."
    restore_data
}

trap cleanup EXIT

# Main execution
main() {
    extreme "AIXcel Extreme Column Width Test"
    echo -e "${BOLD}Backend URL: $BACKEND_URL${NC}"
    echo -e "${BOLD}Testing up to $SPARSE_TEST_COLS columns${NC}"
    echo ""
    
    backup_data
    
    # Health check
    if ! curl -sf "$BACKEND_URL/health" >/dev/null; then
        fail "Backend health check failed"
        exit 1
    fi
    
    # Progressive column width tests
    extreme "Phase 1: Ultra-Wide Dense Tests"
    test_ultra_wide 10000 "10K Dense Columns"
    test_ultra_wide 25000 "25K Dense Columns" 
    test_ultra_wide $ULTRA_COLUMNS "50K Dense Columns"
    
    extreme "Phase 2: Mega-Wide Sparse Tests"
    test_ultra_wide $MEGA_COLUMNS "100K Sparse Columns" true
    test_ultra_wide $SPARSE_TEST_COLS "200K Sparse Columns" true
    
    extreme "Phase 3: Column Range Queries"
    test_column_ranges
    
    extreme "Phase 4: Ultra-Wide Formulas"
    test_ultra_wide_formulas
    
    extreme "Phase 5: Performance Monitoring"
    monitor_performance
    
    extreme "EXTREME COLUMN TEST COMPLETED! 🔥"
    success "Your backend survived the extreme column width test!"
}

# Run the extreme test
main "$@"
