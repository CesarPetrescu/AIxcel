#!/bin/bash
# Quick Performance Benchmark - Lighter version for initial testing
set -euo pipefail

BACKEND_URL="${1:-http://192.168.10.161:6889}"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

success() { echo -e "${GREEN}✅ $1${NC}"; }
info() { echo -e "${BLUE}ℹ $1${NC}"; }
benchmark() { echo -e "${CYAN}🚀 ${BOLD}$1${NC}"; }

# Quick bulk insert test
test_bulk_performance() {
    benchmark "QUICK BULK INSERT TEST"
    
    for size in 100 500 1000; do
        info "Testing $size cells..."
        
        # Generate simple data
        local data='['
        for ((i=0; i<size; i++)); do
            local row=$((i / 10))
            local col=$((i % 10))
            if [[ $i -gt 0 ]]; then data+=','; fi
            data+="{\"row\":$row,\"col\":$col,\"value\":\"Test_$i\"}"
        done
        data+=']'
        
        local start_time=$(date +%s%N)
        curl -sf -X POST "$BACKEND_URL/cells/bulk" -H 'Content-Type: application/json' -d "$data" >/dev/null
        local end_time=$(date +%s%N)
        
        local duration_ms=$(( (end_time - start_time) / 1000000 ))
        local ops_per_sec=$(( size * 1000 / duration_ms ))
        
        success "Bulk insert $size cells: ${duration_ms}ms (${ops_per_sec} ops/sec)"
        
        # Clear data
        local clear_data='['
        for ((i=0; i<size; i++)); do
            local row=$((i / 10))
            local col=$((i % 10))
            if [[ $i -gt 0 ]]; then clear_data+=','; fi
            clear_data+="{\"row\":$row,\"col\":$col}"
        done
        clear_data+=']'
        
        curl -sf -X POST "$BACKEND_URL/cells/clear" -H 'Content-Type: application/json' -d "{\"cells\":$clear_data}" >/dev/null
    done
}

# Formula performance test
test_formula_performance() {
    benchmark "FORMULA PERFORMANCE TEST"
    
    local count=500
    info "Testing $count formula evaluations..."
    
    local formulas=(
        "=SUM(1,2,3,4,5)"
        "=AVERAGE(10,20,30)"
        "=10*5+20"
        "=SUM(1,2,3)+AVERAGE(4,5,6)"
    )
    
    local start_time=$(date +%s%N)
    for ((i=0; i<count; i++)); do
        local formula=${formulas[$((i % ${#formulas[@]}))]}
        curl -sf -X POST "$BACKEND_URL/evaluate" -H 'Content-Type: application/json' -d "{\"expr\":\"$formula\"}" >/dev/null
    done
    local end_time=$(date +%s%N)
    
    local duration_ms=$(( (end_time - start_time) / 1000000 ))
    local ops_per_sec=$(( count * 1000 / duration_ms ))
    
    success "Formula evaluations $count: ${duration_ms}ms (${ops_per_sec} ops/sec)"
}

# Individual operations test
test_individual_performance() {
    benchmark "INDIVIDUAL OPERATIONS TEST"
    
    local count=200
    info "Testing $count individual operations..."
    
    local start_time=$(date +%s%N)
    for ((i=0; i<count; i++)); do
        local row=$((i / 10))
        local col=$((i % 10))
        curl -sf -X POST "$BACKEND_URL/cells" -H 'Content-Type: application/json' -d "{\"row\":$row,\"col\":$col,\"value\":\"Individual_$i\"}" >/dev/null
    done
    local end_time=$(date +%s%N)
    
    local duration_ms=$(( (end_time - start_time) / 1000000 ))
    local ops_per_sec=$(( count * 1000 / duration_ms ))
    
    success "Individual operations $count: ${duration_ms}ms (${ops_per_sec} ops/sec)"
    
    # Clean up
    local clear_data='['
    for ((i=0; i<count; i++)); do
        local row=$((i / 10))
        local col=$((i % 10))
        if [[ $i -gt 0 ]]; then clear_data+=','; fi
        clear_data+="{\"row\":$row,\"col\":$col}"
    done
    clear_data+=']'
    
    curl -sf -X POST "$BACKEND_URL/cells/clear" -H 'Content-Type: application/json' -d "{\"cells\":$clear_data}" >/dev/null
}

echo -e "${CYAN}${BOLD}Quick Performance Benchmark${NC}"
echo "Backend: $BACKEND_URL"
echo ""

test_bulk_performance
test_formula_performance
test_individual_performance

echo ""
success "Quick benchmark completed!"
