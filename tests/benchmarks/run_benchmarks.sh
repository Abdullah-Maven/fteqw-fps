#!/bin/bash
# Run all benchmarks and generate report

set -e

echo "=========================================="
echo "FTEQW Benchmark Suite"
echo "=========================================="
echo ""

BENCHMARK_DIR="$(dirname "$0")"
RESULTS_DIR="$BENCHMARK_DIR/results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$RESULTS_DIR"

# System info
echo "System Information:"
echo "-------------------"
uname -a
echo ""

if command -v sysctl &> /dev/null; then
    echo "CPU: $(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo 'Unknown')"
    echo "Cores: $(sysctl -n hw.ncpu 2>/dev/null || echo 'Unknown')"
fi

if command -v nproc &> /dev/null; then
    echo "Cores: $(nproc)"
fi

echo "Date: $(date)"
echo ""

# Check for benchmark executables
check_benchmark() {
    local name="$1"
    if [ -f "$BENCHMARK_DIR/$name" ] && [ -x "$BENCHMARK_DIR/$name" ]; then
        return 0
    elif [ -f "$BENCHMARK_DIR/build/$name" ] && [ -x "$BENCHMARK_DIR/build/$name" ]; then
        BENCHMARK_DIR="$BENCHMARK_DIR/build"
        return 0
    else
        return 1
    fi
}

# Run individual benchmark
run_benchmark() {
    local name="$1"
    local args="${2:-}"
    
    echo "Running: $name $args"
    echo "----------------------------------------"
    
    local output_file="$RESULTS_DIR/${name}_${TIMESTAMP}.txt"
    local json_file="$RESULTS_DIR/${name}_${TIMESTAMP}.json"
    
    if check_benchmark "$name"; then
        timeout 300 "$BENCHMARK_DIR/$name" $args 2>&1 | tee "$output_file"
        echo ""
        echo "Results saved to: $output_file"
    else
        echo "WARNING: Benchmark '$name' not found or not executable"
        echo "Build with: cmake -DBUILD_BENCHMARKS=ON .."
    fi
    
    echo ""
}

# Main execution
main() {
    cd "$BENCHMARK_DIR/.."
    
    # Parse arguments
    case "${1:-all}" in
        rendering)
            run_benchmark "benchmark_rendering" "${2:-}"
            ;;
        physics)
            run_benchmark "benchmark_physics" "${2:-}"
            ;;
        network)
            run_benchmark "benchmark_network" "${2:-}"
            ;;
        audio)
            run_benchmark "benchmark_audio" "${2:-}"
            ;;
        loading)
            run_benchmark "benchmark_loading" "${2:-}"
            ;;
        all)
            run_benchmark "benchmark_rendering" "--duration 30"
            run_benchmark "benchmark_physics" "--objects 500 --duration 30"
            run_benchmark "benchmark_audio" "--channels 32 --duration 30"
            run_benchmark "benchmark_loading" "--iterations 3"
            ;;
        help|--help|-h)
            echo "Usage: $0 [benchmark] [args]"
            echo ""
            echo "Available benchmarks:"
            echo "  rendering  - Rendering performance"
            echo "  physics    - Physics simulation"
            echo "  network    - Network performance"
            echo "  audio      - Audio subsystem"
            echo "  loading    - Asset loading times"
            echo "  all        - Run all benchmarks (default)"
            echo "  help       - Show this help"
            ;;
        *)
            echo "Unknown benchmark: $1"
            echo "Run '$0 help' for usage information"
            exit 1
            ;;
    esac
    
    echo "=========================================="
    echo "Benchmark Complete"
    echo "=========================================="
    echo ""
    echo "Results directory: $RESULTS_DIR"
    echo ""
}

main "$@"
