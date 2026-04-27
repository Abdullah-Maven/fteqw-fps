# Integration Tests for FTEQW Game Engine

This directory contains integration tests that verify components work together correctly.

## Running Integration Tests

### Prerequisites

1. Build the engine:
   ```bash
   mkdir build && cd build
   cmake ..
   cmake --build . --config Release
   ```

2. Ensure test data is available:
   ```bash
   ./download_test_data.sh
   ```

### Execute Tests

```bash
# Run all integration tests
cd tests/integration
./run_integration_tests.sh

# Run specific test category
./run_integration_tests.sh --category rendering
./run_integration_tests.sh --category physics
./run_integration_tests.sh --category network

# Run with verbose output
./run_integration_tests.sh --verbose

# Run with custom timeout
./run_integration_tests.sh --timeout 300
```

## Test Categories

### 1. Rendering Tests

Verify rendering subsystem functionality:

- **test_gl_init**: OpenGL context creation and initialization
- **test_shader_compile**: GLSL shader compilation and linking
- **test_texture_load**: Texture loading from various formats (PNG, JPG, WAL)
- **test_model_render**: Model loading and rendering (MDL, MD2, MD3, IQM)
- **test_lighting**: Dynamic lighting and shadow mapping
- **test_particles**: Particle system effects
- **test_water**: Water rendering and reflections
- **test_sky**: Skybox and environment mapping

### 2. Physics Tests

Verify physics simulation:

- **test_collision**: Collision detection accuracy
- **test_rigidbody**: Rigid body dynamics
- **test_constraints**: Joint and constraint solving
- **test_triggers**: Trigger volumes and events
- **test_clipmodels**: Clip model interactions
- **test_gravity**: Gravity and movement physics

### 3. Network Tests

Verify networking functionality:

- **test_server_start**: Dedicated server initialization
- **test_client_connect**: Client connection handling
- **test_packet_loss**: Packet loss resilience
- **test_latency**: Latency compensation
- **test_prediction**: Client-side prediction
- **test_interpolation**: Entity interpolation
- **test_voice_chat**: Voice communication (Opus codec)

### 4. Audio Tests

Verify audio subsystem:

- **test_sound_load**: Sound file loading (WAV, OGG)
- **test_mixing**: Multi-channel sound mixing
- **test_3d_audio**: Spatial audio positioning
- **test_music**: Background music playback
- **test_effects**: Audio effects (reverb, echo)

### 5. File System Tests

Verify virtual file system:

- **test_pak_read**: PAK archive reading
- **test_pk3_read**: PK3/ZIP archive reading
- **test_path_resolution**: Virtual path resolution
- **test_autodownload**: Automatic asset downloading
- **test_manifest**: Manifest file parsing

### 6. QuakeC Tests

Verify QuakeC compiler and runtime:

- **test_qc_compile**: QuakeC compilation
- **test_qc_link**: Bytecode linking
- **test_qc_execute**: VM execution
- **test_qc_extensions**: FTEQCC extended opcodes
- **test_entity_spawn**: Entity creation and management
- **test_think_functions**: Think function scheduling

### 7. Plugin Tests

Verify plugin architecture:

- **test_plugin_load**: Dynamic plugin loading
- **test_plugin_api**: Plugin API compatibility
- **test_plugin_hotreload**: Hot-reloading without restart
- **test_plugin_dependencies**: Dependency resolution

### 8. Map Tests

Verify map loading and functionality:

- **test_bsp_load**: BSP map loading
- **test_entities**: Entity parsing and spawning
- **test_visibility**: PVS/PHS visibility calculations
- **test_lightmaps**: Lightmap loading and application
- **test_portals**: Portal rendering (if supported)

## Test Output

### Console Format

```
=====================================
Integration Test Suite
=====================================

Category: Rendering
  [PASS] test_gl_init (0.12s)
  [PASS] test_shader_compile (0.34s)
  [FAIL] test_texture_load (0.05s)
    Error: Failed to load texture 'base_wall.png'
  [PASS] test_model_render (0.89s)

Category: Physics
  [PASS] test_collision (0.23s)
  [PASS] test_rigidbody (0.45s)

=====================================
Results: 7 passed, 1 failed, 0 skipped
Total time: 2.08s
=====================================
```

### JUnit XML Format

For CI/CD integration:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<testsuites>
  <testsuite name="rendering" tests="4" failures="1" time="1.40">
    <testcase name="test_gl_init" time="0.12"/>
    <testcase name="test_shader_compile" time="0.34"/>
    <testcase name="test_texture_load" time="0.05">
      <failure message="Failed to load texture">...</failure>
    </testcase>
    <testcase name="test_model_render" time="0.89"/>
  </testsuite>
</testsuites>
```

## Writing New Integration Tests

### Test Structure

Create a new test file `test_<feature>.sh` or `test_<feature>.c`:

```bash
#!/bin/bash
# test_example.sh

source test_helpers.sh

test_setup() {
    # Initialize test environment
    export TEST_MAP="test_maps/example.bsp"
}

test_cleanup() {
    # Clean up after test
    rm -f /tmp/test_*.dat
}

test_example_feature() {
    # Your test logic here
    local result=$(./engine/release/fteqw-sdl2 -dedicated +map example +quit)
    
    if echo "$result" | grep -q "SUCCESS"; then
        return 0
    else
        return 1
    fi
}

# Register and run tests
register_test "test_example_feature" "Tests example feature"
run_all_tests
```

### C-Based Tests

For more complex tests:

```c
#include "test_framework.h"

TEST(rendering, shader_compilation) {
    // Setup
    gl_shader_t *shader = R_CompileShader("test.glsl");
    
    // Assertion
    ASSERT_NOT_NULL(shader);
    ASSERT_TRUE(shader->linked);
    
    // Cleanup
    R_DeleteShader(shader);
}

TEST_SUITE(rendering_tests) {
    RUN_TEST(rendering, shader_compilation);
}
```

## Continuous Integration

Integration tests run automatically in CI/CD:

- **On Pull Request**: Critical path tests only
- **Nightly**: Full test suite
- **Pre-Release**: All tests with extended duration

## Troubleshooting

### Common Issues

**Issue: Tests fail with "executable not found"**
- Solution: Build the engine first

**Issue: Tests timeout**
- Solution: Increase timeout with `--timeout` flag

**Issue: Random failures**
- Solution: Check for race conditions, increase stability

**Issue: Missing test data**
- Solution: Run `./download_test_data.sh`

### Debug Mode

Run tests with debug output:

```bash
./run_integration_tests.sh --verbose --debug-log=test.log
```

## Performance Expectations

Tests should complete within reasonable time:

- **Individual test**: < 10 seconds
- **Test category**: < 60 seconds
- **Full suite**: < 10 minutes

## Contributing

When adding new features:

1. Write corresponding integration tests
2. Ensure tests pass on all platforms
3. Document test purpose and expected behavior
4. Update this README if adding new categories

## License

Integration tests are part of FTEQW and licensed under the same terms.

---

For questions or issues, see main documentation or open an issue.
