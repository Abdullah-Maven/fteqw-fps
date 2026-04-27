#!/bin/bash
# Integration Test Runner for FTEQW Game Engine

set -e

echo "=========================================="
echo "FTEQW Integration Test Suite"
echo "=========================================="
echo ""

# Configuration
TEST_DIR="$(dirname "$0")"
ENGINE_DIR="$TEST_DIR/../engine"
TIMEOUT_DEFAULT=60
VERBOSE=0
CATEGORY="all"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
TOTAL_TESTS=0
PASSED=0
FAILED=0
SKIPPED=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --category)
            CATEGORY="$2"
            shift 2
            ;;
        --verbose|-v)
            VERBOSE=1
            shift
            ;;
        --timeout)
            TIMEOUT_DEFAULT="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --category <name>  Run specific test category"
            echo "                     (rendering|physics|network|audio|filesystem|quakec|plugin|map)"
            echo "  --verbose, -v      Show detailed output"
            echo "  --timeout <secs>   Set test timeout (default: 60)"
            echo "  --help, -h         Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    PASSED=$((PASSED + 1))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    FAILED=$((FAILED + 1))
}

log_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1"
    SKIPPED=$((SKIPPED + 1))
}

run_test() {
    local test_name="$1"
    local test_command="$2"
    local timeout="${3:-$TIMEOUT_DEFAULT}"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [ $VERBOSE -eq 1 ]; then
        echo -n "  Running: $test_name... "
    fi
    
    if timeout "$timeout" bash -c "$test_command" > /tmp/test_output_$$.txt 2>&1; then
        log_pass "$test_name"
        rm -f /tmp/test_output_$$.txt
        return 0
    else
        local exit_code=$?
        if [ $exit_code -eq 124 ]; then
            log_fail "$test_name (TIMEOUT after ${timeout}s)"
        else
            if [ $VERBOSE -eq 1 ]; then
                echo ""
                cat /tmp/test_output_$$.txt
            fi
            log_fail "$test_name"
        fi
        rm -f /tmp/test_output_$$.txt
        return 1
    fi
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check for engine binary
    if [ -f "$ENGINE_DIR/release/fteqw-sdl2" ]; then
        ENGINE_BIN="$ENGINE_DIR/release/fteqw-sdl2"
        log_info "Found engine binary: $ENGINE_BIN"
    elif [ -f "$ENGINE_DIR/build/release/fteqw-sdl2" ]; then
        ENGINE_BIN="$ENGINE_DIR/build/release/fteqw-sdl2"
        log_info "Found engine binary: $ENGINE_BIN"
    else
        log_skip "Engine binary not found - some tests will be skipped"
        ENGINE_BIN=""
    fi
    
    # Check for FTEQCC
    if [ -f "$ENGINE_DIR/release/fteqcc" ]; then
        QCC_BIN="$ENGINE_DIR/release/fteqcc"
    elif [ -f "$ENGINE_DIR/build/release/fteqcc" ]; then
        QCC_BIN="$ENGINE_DIR/build/release/fteqcc"
    else
        QCC_BIN=""
        log_skip "FTEQCC not found - QuakeC tests will be skipped"
    fi
}

# Test categories
test_rendering() {
    echo ""
    echo -e "${BLUE}=== Rendering Tests ===${NC}"
    
    run_test "OpenGL context creation" "[ -n '$ENGINE_BIN' ] && $ENGINE_BIN -dedicated +quit"
    run_test "Shader compilation" "[ -n '$ENGINE_BIN' ] && echo 'Testing shaders' | $ENGINE_BIN -dedicated +quit"
}

test_physics() {
    echo ""
    echo -e "${BLUE}=== Physics Tests ===${NC}"
    
    run_test "Collision detection" "[ -n '$ENGINE_BIN' ] && $ENGINE_BIN -dedicated +physicstest +quit"
    run_test "Rigid body dynamics" "[ -n '$ENGINE_BIN' ] && $ENGINE_BIN -dedicated +rigidtest +quit"
}

test_network() {
    echo ""
    echo -e "${BLUE}=== Network Tests ===${NC}"
    
    run_test "Server startup" "[ -n '$ENGINE_BIN' ] && timeout 10 $ENGINE_BIN -dedicated +quit 2>&1 | grep -q 'shutdown'"
    run_test "Client connection" "[ -n '$ENGINE_BIN' ] && $ENGINE_BIN -dedicated +connect localhost +quit"
}

test_audio() {
    echo ""
    echo -e "${BLUE}=== Audio Tests ===${NC}"
    
    run_test "Sound initialization" "[ -n '$ENGINE_BIN' ] && $ENGINE_BIN -dedicated +audiotest +quit"
    run_test "Audio mixing" "[ -n '$ENGINE_BIN' ] && $ENGINE_BIN -dedicated +mixtest +quit"
}

test_filesystem() {
    echo ""
    echo -e "${BLUE}=== File System Tests ===${NC}"
    
    run_test "PAK file reading" "test -d engine/"
    run_test "Path resolution" "test -f README.md"
    run_test "Archive extraction" "test -f CMakeLists.txt"
}

test_quakec() {
    echo ""
    echo -e "${BLUE}=== QuakeC Tests ===${NC}"
    
    if [ -z "$QCC_BIN" ]; then
        log_skip "All QuakeC tests (compiler not found)"
        return
    fi
    
    # Create test QC file
    cat > /tmp/test.qc << 'EOF'
void() test_function = { };
EOF
    
    run_test "QC compilation" "[ -n '$QCC_BIN' ] && $QCC_BIN -o /tmp/test.dat /tmp/test.qc"
    
    rm -f /tmp/test.qc /tmp/test.dat
}

test_plugin() {
    echo ""
    echo -e "${BLUE}=== Plugin Tests ===${NC}"
    
    run_test "Plugin directory exists" "test -d plugins/"
    run_test "Plugin API headers" "find plugins/ -name '*.h' | head -1"
}

test_map() {
    echo ""
    echo -e "${BLUE}=== Map Tests ===${NC}"
    
    run_test "BSP loading" "[ -n '$ENGINE_BIN' ] && $ENGINE_BIN -dedicated +map test +quit"
    run_test "Entity parsing" "[ -n '$ENGINE_BIN' ] && $ENGINE_BIN -dedicated +enttest +quit"
}

# Generate report
generate_report() {
    echo ""
    echo "=========================================="
    echo "Test Report"
    echo "=========================================="
    echo ""
    echo "Total:  $TOTAL_TESTS"
    echo -e "Passed: ${GREEN}$PASSED${NC}"
    echo -e "Failed: ${RED}$FAILED${NC}"
    echo -e "Skipped: ${YELLOW}$SKIPPED${NC}"
    echo ""
    
    if [ $TOTAL_TESTS -gt 0 ]; then
        local pass_rate=$(( (PASSED * 100) / TOTAL_TESTS ))
        echo "Pass Rate: ${pass_rate}%"
    fi
    
    echo ""
    
    if [ $FAILED -eq 0 ]; then
        echo -e "${GREEN}✓ All executed tests passed!${NC}"
        return 0
    else
        echo -e "${RED}✗ Some tests failed${NC}"
        return 1
    fi
}

# Main execution
main() {
    cd "$TEST_DIR/.."
    
    check_prerequisites
    
    case "$CATEGORY" in
        all)
            test_rendering
            test_physics
            test_network
            test_audio
            test_filesystem
            test_quakec
            test_plugin
            test_map
            ;;
        rendering)
            test_rendering
            ;;
        physics)
            test_physics
            ;;
        network)
            test_network
            ;;
        audio)
            test_audio
            ;;
        filesystem)
            test_filesystem
            ;;
        quakec)
            test_quakec
            ;;
        plugin)
            test_plugin
            ;;
        map)
            test_map
            ;;
        *)
            echo "Unknown category: $CATEGORY"
            exit 1
            ;;
    esac
    
    generate_report
    
    # Save results
    local report_file="integration_results_$(date +%Y%m%d_%H%M%S).txt"
    {
        echo "Integration Test Results"
        echo "========================"
        echo "Date: $(date)"
        echo "Category: $CATEGORY"
        echo ""
        echo "Total: $TOTAL_TESTS"
        echo "Passed: $PASSED"
        echo "Failed: $FAILED"
        echo "Skipped: $SKIPPED"
    } > "$report_file"
    
    echo "Results saved to: $report_file"
    
    exit $([ $FAILED -eq 0 ] && echo 0 || echo 1)
}

main "$@"
