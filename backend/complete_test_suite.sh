#!/bin/bash
# AIXcel Complete Test Suite Runner
# Runs all available tests with user selection

set -euo pipefail

BACKEND_URL="${1:-http://192.168.10.161:6889}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

info() { echo -e "${BLUE}ℹ ${BOLD}$1${NC}"; }
success() { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠ $1${NC}"; }
suite() { echo -e "${CYAN}🧪 ${BOLD}$1${NC}"; }

# Test definitions
declare -A TESTS=(
    ["basic"]="./test_api.sh|Basic API functionality test|Quick comprehensive test of all features"
    ["quick"]="./quick_benchmark.sh|Quick performance benchmark|Fast performance test (1-2 minutes)"
    ["benchmark"]="./benchmark.sh|Full performance benchmark|Comprehensive performance test (5-10 minutes)"
    ["mega"]="./mega_benchmark.sh|Mega benchmark|Extreme stress test with thousands of operations (15-30 minutes)"
    ["extreme"]="./extreme_test.sh|Extreme stress test|Ultimate stress test with concurrent users (20-45 minutes)"
    ["columns"]="./extreme_column_test.sh|Extreme column test|Tests up to 200,000 columns (30-60 minutes)"
)

# Show available tests
show_menu() {
    suite "AIXcel Complete Test Suite"
    echo -e "${BOLD}Backend URL: $BACKEND_URL${NC}"
    echo ""
    echo "Available tests:"
    echo ""
    
    local i=1
    for test_key in basic quick benchmark mega extreme columns; do
        local test_info="${TESTS[$test_key]}"
        local script=$(echo "$test_info" | cut -d'|' -f1)
        local name=$(echo "$test_info" | cut -d'|' -f2)
        local desc=$(echo "$test_info" | cut -d'|' -f3)
        
        echo -e "${BOLD}$i)${NC} ${GREEN}$name${NC}"
        echo -e "   Script: $script"
        echo -e "   Description: $desc"
        echo ""
        ((i++))
    done
    
    echo -e "${BOLD}7)${NC} ${MAGENTA}Run all tests (sequential)${NC}"
    echo -e "   Runs all tests one after another (can take 2+ hours)"
    echo ""
    echo -e "${BOLD}8)${NC} ${YELLOW}Health check only${NC}"
    echo -e "   Just check if backend is responding"
    echo ""
    echo -e "${BOLD}0)${NC} Exit"
    echo ""
}

# Health check
health_check() {
    info "Performing health check..."
    
    if curl -sf "$BACKEND_URL/health" >/dev/null 2>&1; then
        success "Backend is healthy and responding"
        
        # Get current data count
        local cell_count=$(curl -sf "$BACKEND_URL/cells" 2>/dev/null | jq 'length' 2>/dev/null || echo "unknown")
        info "Current spreadsheet contains $cell_count cells"
        return 0
    else
        warn "Backend health check failed!"
        echo "Make sure the backend is running on $BACKEND_URL"
        echo "You can start it with: cd backend && cargo run"
        return 1
    fi
}

# Run a specific test
run_test() {
    local test_key="$1"
    local test_info="${TESTS[$test_key]}"
    local script=$(echo "$test_info" | cut -d'|' -f1)
    local name=$(echo "$test_info" | cut -d'|' -f2)
    
    suite "Running: $name"
    echo -e "${BOLD}Script: $script${NC}"
    echo -e "${BOLD}Backend: $BACKEND_URL${NC}"
    echo ""
    
    if [[ ! -f "$script" ]]; then
        warn "Test script not found: $script"
        return 1
    fi
    
    if [[ ! -x "$script" ]]; then
        warn "Test script not executable: $script"
        echo "Making it executable..."
        chmod +x "$script"
    fi
    
    local start_time=$(date +%s)
    
    if "$script" "$BACKEND_URL"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        success "$name completed successfully in ${duration}s"
        return 0
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        warn "$name failed after ${duration}s"
        return 1
    fi
}

# Run all tests
run_all_tests() {
    suite "Running ALL tests sequentially"
    warn "This will take a VERY long time (2+ hours)"
    echo ""
    read -p "Are you sure you want to continue? (y/N): " confirm
    
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        info "Cancelled by user"
        return 0
    fi
    
    local total_start=$(date +%s)
    local passed=0
    local failed=0
    
    for test_key in basic quick benchmark mega extreme columns; do
        echo ""
        suite "Starting test: $test_key"
        
        if run_test "$test_key"; then
            ((passed++))
        else
            ((failed++))
            echo ""
            read -p "Test failed. Continue with remaining tests? (y/N): " continue_confirm
            if [[ "$continue_confirm" != "y" && "$continue_confirm" != "Y" ]]; then
                warn "Test suite aborted by user"
                break
            fi
        fi
        
        echo ""
        echo "=========================================="
    done
    
    local total_end=$(date +%s)
    local total_duration=$((total_end - total_start))
    local hours=$((total_duration / 3600))
    local minutes=$(((total_duration % 3600) / 60))
    local seconds=$((total_duration % 60))
    
    echo ""
    suite "ALL TESTS COMPLETED"
    echo "========================================"
    echo -e "Total time: ${BOLD}${hours}h ${minutes}m ${seconds}s${NC}"
    echo -e "Passed: ${GREEN}$passed${NC}"
    echo -e "Failed: ${RED}$failed${NC}"
    echo "========================================"
}

# Interactive mode
interactive_mode() {
    while true; do
        clear
        show_menu
        
        read -p "Select a test (0-8): " choice
        
        case $choice in
            1) run_test "basic" ;;
            2) run_test "quick" ;;
            3) run_test "benchmark" ;;
            4) run_test "mega" ;;
            5) run_test "extreme" ;;
            6) run_test "columns" ;;
            7) run_all_tests ;;
            8) health_check ;;
            0) 
                info "Goodbye!"
                exit 0
                ;;
            *)
                warn "Invalid choice: $choice"
                sleep 2
                ;;
        esac
        
        if [[ $choice -ne 0 ]]; then
            echo ""
            read -p "Press Enter to continue..."
        fi
    done
}

# Command line mode
command_line_mode() {
    local test_name="$1"
    
    case "$test_name" in
        "basic"|"quick"|"benchmark"|"mega"|"extreme"|"columns")
            if ! health_check; then
                exit 1
            fi
            run_test "$test_name"
            ;;
        "all")
            if ! health_check; then
                exit 1
            fi
            run_all_tests
            ;;
        "health")
            health_check
            ;;
        "list")
            show_menu
            ;;
        *)
            echo "Usage: $0 [backend_url] [test_name]"
            echo ""
            echo "Available test names:"
            echo "  basic     - Basic API functionality test"
            echo "  quick     - Quick performance benchmark" 
            echo "  benchmark - Full performance benchmark"
            echo "  mega      - Mega benchmark with thousands of operations"
            echo "  extreme   - Extreme stress test with concurrent users"
            echo "  columns   - Extreme column width test (up to 200K columns)"
            echo "  all       - Run all tests sequentially"
            echo "  health    - Health check only"
            echo "  list      - Show detailed test menu"
            echo ""
            echo "If no test name is provided, interactive mode will start."
            exit 1
            ;;
    esac
}

# Main
main() {
    # Check if backend URL is provided as first argument
    if [[ $# -gt 0 && "$1" =~ ^https?:// ]]; then
        BACKEND_URL="$1"
        shift
    fi
    
    # Check dependencies
    for cmd in curl jq bc; do
        if ! command -v "$cmd" >/dev/null; then
            warn "Required command not found: $cmd"
            echo "Please install $cmd and try again."
            exit 1
        fi
    done
    
    # Check if we're in the right directory
    if [[ ! -f "./test_api.sh" ]]; then
        warn "Test scripts not found in current directory"
        echo "Please run this script from the backend directory:"
        echo "  cd backend && ./complete_test_suite.sh"
        exit 1
    fi
    
    # Command line mode if test name provided
    if [[ $# -gt 0 ]]; then
        command_line_mode "$1"
    else
        # Interactive mode
        if ! health_check; then
            echo ""
            read -p "Backend is not responding. Continue anyway? (y/N): " force_continue
            if [[ "$force_continue" != "y" && "$force_continue" != "Y" ]]; then
                exit 1
            fi
        fi
        
        interactive_mode
    fi
}

main "$@"
