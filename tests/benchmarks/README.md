# Benchmarking Suite for FTEQW Game Engine

This directory contains performance benchmarks for measuring and tracking the engine's performance.

## Running Benchmarks

### Quick Start

```bash
# Build with benchmarks enabled
mkdir build && cd build
cmake -DBUILD_BENCHMARKS=ON ..
cmake --build . --config Release

# Run all benchmarks
./run_benchmarks.sh

# Run specific benchmark
./benchmark_rendering
./benchmark_physics
./benchmark_network
```

## Available Benchmarks

### 1. Rendering Benchmark (`benchmark_rendering`)

Measures rendering performance including:
- Frame rate (FPS) at different resolutions
- Polygon throughput
- Shader compilation time
- Texture loading performance
- Draw call overhead

**Usage:**
```bash
./benchmark_rendering --resolution 1920x1080 --duration 30
```

### 2. Physics Benchmark (`benchmark_physics`)

Tests physics simulation performance:
- Rigid body dynamics
- Collision detection
- Constraint solving
- Large scene simulation

**Usage:**
```bash
./benchmark_physics --objects 1000 --duration 60
```

### 3. Network Benchmark (`benchmark_network`)

Evaluates network performance:
- Latency measurement
- Packet throughput
- Client synchronization
- Bandwidth usage

**Usage:**
```bash
./benchmark_network --clients 16 --duration 120
```

### 4. Audio Benchmark (`benchmark_audio`)

Tests audio subsystem:
- Sound mixing performance
- Codec decoding speed
- 3D spatialization overhead
- Memory usage

**Usage:**
```bash
./benchmark_audio --channels 64 --duration 30
```

### 5. Loading Benchmark (`benchmark_loading`)

Measures asset loading times:
- Map loading speed
- Model loading performance
- Texture streaming
- Archive extraction

**Usage:**
```bash
./benchmark_loading --map e1m1 --iterations 5
```

## Benchmark Output

Benchmarks produce results in multiple formats:

### Console Output
```
=====================================
FTEQW Rendering Benchmark
=====================================
Resolution: 1920x1080
Duration: 30 seconds

Results:
  Average FPS: 144.5
  Minimum FPS: 120.3
  Maximum FPS: 165.8
  Frame Time: 6.92ms
  Draw Calls: 1,234
  Triangles: 45,678

Status: PASSED (Target: 60 FPS)
```

### JSON Output
```json
{
  "benchmark": "rendering",
  "timestamp": "2024-01-15T10:30:00Z",
  "system": {
    "cpu": "Apple M3",
    "gpu": "Apple M3 GPU",
    "memory": "16GB",
    "os": "macOS 14.2"
  },
  "results": {
    "avg_fps": 144.5,
    "min_fps": 120.3,
    "max_fps": 165.8,
    "frame_time_ms": 6.92,
    "draw_calls": 1234,
    "triangles": 45678
  },
  "status": "PASSED"
}
```

### CSV Export
For spreadsheet analysis:
```csv
benchmark,timestamp,avg_fps,min_fps,max_fps,status
rendering,2024-01-15T10:30:00Z,144.5,120.3,165.8,PASSED
```

## Performance Targets

### Minimum Requirements
- **FPS**: 60 frames per second (1080p)
- **Frame Time**: < 16.67ms
- **Load Time**: < 5 seconds for standard maps
- **Network Latency**: < 50ms local

### Recommended Targets
- **FPS**: 144+ frames per second (1080p)
- **Frame Time**: < 7ms
- **Load Time**: < 2 seconds for standard maps
- **Network Latency**: < 20ms local

### High-End Targets
- **FPS**: 240+ frames per second (1080p)
- **Frame Time**: < 4ms
- **Load Time**: < 1 second for standard maps
- **Network Latency**: < 10ms local

## Regression Testing

Automated regression testing compares current results against baseline:

```bash
# Set baseline
./run_benchmarks.sh --set-baseline

# Compare against baseline
./run_benchmarks.sh --compare

# Generate regression report
./run_benchmarks.sh --regression-report
```

## Continuous Integration

Benchmarks run automatically in CI/CD pipeline:
- On every pull request
- Nightly performance tracking
- Release validation

Results are uploaded as artifacts and tracked over time.

## System Information

Benchmarks automatically detect and log:
- CPU model and cores
- GPU information
- Memory size and speed
- Operating system version
- Compiler version
- Build configuration

## Tips for Accurate Results

1. **Close background applications** to reduce interference
2. **Run multiple iterations** and use average results
3. **Warm up the engine** before timing
4. **Use consistent settings** across runs
5. **Document hardware changes** that may affect results
6. **Run on dedicated hardware** (not VMs) for production benchmarks

## Troubleshooting

### Issue: Inconsistent results
**Solution**: Run more iterations, ensure thermal throttling isn't occurring

### Issue: Benchmarks crash
**Solution**: Check that engine is built in Release mode, verify dependencies

### Issue: Results seem too low
**Solution**: Verify you're not running in debug mode, check for background processes

## Contributing New Benchmarks

To add a new benchmark:

1. Create `benchmark_<name>.c` in this directory
2. Implement the benchmark interface:
   ```c
   void benchmark_init(void);
   void benchmark_run(void);
   void benchmark_shutdown(void);
   const char* benchmark_name(void);
   ```
3. Add to CMakeLists.txt
4. Document in this file
5. Set performance targets

## License

Benchmark suite is part of FTEQW and licensed under the same terms.

---

For questions or issues with benchmarks, see the main documentation or open an issue.
