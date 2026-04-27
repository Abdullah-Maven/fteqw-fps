# FTEQW Modern Rendering Implementation Roadmap

## Executive Summary
**Goal:** Transform FTEQW into a production-ready modern game engine with Forward+ rendering, Metal backend, FSR 2.2, and ODE physics targeting 120 FPS at 4K on Apple M3.

---

## Phase 1: Foundation (Weeks 1-2)

### Week 1: Metal Backend Skeleton

#### Day 1-2: Project Structure
- [ ] Create `engine/mtl/` directory structure
- [ ] Set up Xcode project with Metal shaders
- [ ] Implement basic Metal device/context initialization
- [ ] Create swapchain management for macOS

**Files to Create:**
```
engine/mtl/
├── mtl_vidmetal.m          # Main Metal video backend
├── mtl_device.h            # Device management header
├── mtl_buffers.h           # Buffer management
└── Makefile.metal          # Metal-specific build rules
```

**Key Code:**
```objc
// mtl_vidmetal.m - Basic initialization
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>

id<MTLDevice> mtlDevice;
id<MTLCommandQueue> mtlCommandQueue;
CAMetalLayer *metalLayer;

qboolean MTL_Init(void) {
    mtlDevice = MTLCreateSystemDefaultDevice();
    if (!mtlDevice) {
        Con_Printf("Metal is not supported on this device\n");
        return false;
    }
    
    mtlCommandQueue = [mtlDevice newCommandQueue];
    metalLayer = [CAMetalLayer layer];
    metalLayer.device = mtlDevice;
    metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    
    return true;
}
```

#### Day 3-4: Render Pipeline Setup
- [ ] Implement render pipeline state objects (PSO)
- [ ] Create vertex descriptor for Quake models
- [ ] Set up depth/stencil states
- [ ] Implement basic triangle rendering test

#### Day 5: Resource Management
- [ ] Vertex buffer implementation
- [ ] Index buffer implementation  
- [ ] Uniform buffer ring system
- [ ] Texture loading from existing Quake formats

**Deliverable:** Basic Metal backend that can render a colored triangle

---

### Week 2: Forward+ Basic Implementation

#### Day 1-2: Depth Pre-Pass
- [ ] Implement depth-only render pass
- [ ] Port existing BSP surface rendering to Metal
- [ ] Optimize for tile-based deferred (M3 GPU)

#### Day 3-4: Light Data Structures
- [ ] Implement light array in uniform buffer
- [ ] Create cluster grid data structure
- [ ] Port light culling logic from CPU to compute shader

**Key Data Structure:**
```c
typedef struct {
    vec4 position;      // xyz=pos, w=type
    vec4 color;         // xyz=RGB, w=intensity
    vec4 direction;     // xyz=dir, w=spotExponent
    vec4 attenuation;   // const, linear, quad, cutoff
    mat4 shadowMatrix;
    int shadowMapIndex;
    int enabled;
} Light;
```

#### Day 5: Basic Forward Shading
- [ ] Implement single-light forward shader
- [ ] Test with point lights in BSP map
- [ ] Profile performance on M3

**Deliverable:** Forward+ renderer with basic clustered lighting (16+ lights)

---

## Phase 2: Shader Suite (Weeks 3-4)

### Week 3: Core Shaders

#### Day 1-2: PBR Material System
- [ ] Port `forward_clustered_lighting.glsl` to Metal
- [ ] Implement Cook-Torrance BRDF
- [ ] Add normal mapping support
- [ ] Test with existing Quake textures (convert to PBR-ish)

**Shader Files:**
```
engine/shaders/msl/
├── forward_base.metal       # Main forward shading
├── pbr_brdf.metal           # PBR lighting functions
├── normal_mapping.metal     # Tangent-space normals
└── material_system.metal    # Material parameter handling
```

#### Day 3-4: Water Shader
- [ ] Port `water_advanced_ssr.glsl` to Metal
- [ ] Implement animated normal maps
- [ ] Add caustics projection
- [ ] Test with Quake water surfaces (e1m1, e2m2)

#### Day 5: Model Shaders
- [ ] Alias model shader (MDL format)
- [ ] Sprite shader (additive + alpha-tested)
- [ ] Skybox shader (parallax-corrected)

**Deliverable:** Complete core shader suite with PBR lighting

---

### Week 4: Advanced Effects

#### Day 1-2: Screen Space Reflections
- [ ] Implement SSR compute shader
- [ ] Add binary search refinement
- [ ] Integrate with water shader
- [ ] Performance tuning (50% resolution target)

#### Day 3-4: Bloom & Tone Mapping
- [ ] Implement bloom extract (HDR threshold)
- [ ] Dual Kawase blur for bloom
- [ ] ACE filmic tone mapper
- [ ] Gamma correction pipeline

#### Day 5: Transparency Handling
- [ ] Depth peeling or OIT for transparency
- [ ] Additive sprite sorting
- [ ] Blend mode optimization for M3

**Deliverable:** Full post-processing pipeline with SSR

---

## Phase 3: FSR 2.2 Integration (Weeks 5-6)

### Week 5: Motion Vectors & Temporal Data

#### Day 1-2: Motion Vector Generation
- [ ] Add motion vector output to all geometry shaders
- [ ] Implement previous frame MVP matrix tracking
- [ ] Handle dynamic entities (monsters, items, players)

**Code Integration:**
```c
// In r_main.c
void R_SetupPreviousFrame(void) {
    r_refdef.previousViewProjMatrix = 
        r_refdef.projectionMatrix * r_refdef.viewMatrix;
    
    // Store for shader access
    memcpy(fsrState.previousProjectionMatrix, 
           r_refdef.previousViewProjMatrix, sizeof(matrix4x4));
}
```

#### Day 3-4: Reactive Mask System
- [ ] Detect transparent surfaces
- [ ] Mark UI/HUD elements
- [ ] Generate reactive mask texture
- [ ] Handle particle systems

#### Day 5: History Management
- [ ] Previous frame color buffer
- [ ] Previous frame depth buffer
- [ ] History invalidation on camera cuts
- [ ] Memory budget enforcement (~200MB total)

**Deliverable:** Complete temporal data pipeline

---

### Week 6: FSR Upscaling

#### Day 1-2: EASU Implementation
- [ ] Port `fsr_2_2_upscale.glsl` to Metal compute shader
- [ ] Optimize for M3 tile architecture
- [ ] Use half precision (FP16) throughout
- [ ] Test edge adaptation quality

#### Day 3-4: RCAS Sharpening
- [ ] Implement contrast-adaptive sharpening
- [ ] Add user-configurable sharpness slider
- [ ] Prevent overshoot artifacts
- [ ] Quality validation vs native 4K

#### Day 5: Dynamic Resolution
- [ ] Frame-time monitoring system
- [ ] Automatic quality mode switching
- [ ] Smooth transitions between modes
- [ ] Per-scene profiling data

**Quality Modes:**
```c
typedef enum {
    FSR_QUALITY_PERFORMANCE = 0,  // 0.5x (1080p -> 4K)
    FSR_QUALITY_BALANCED,          // 0.67x (1440p -> 4K)
    FSR_QUALITY_QUALITY,           // 0.77x (1620p -> 4K)
    FSR_QUALITY_NATIVE             // 1.0x (no upscaling)
} fsr_quality_t;
```

**Deliverable:** FSR 2.2 fully integrated with 3 quality modes

---

## Phase 4: ODE Physics (Week 7)

### Week 7: Physics Integration

#### Day 1-2: ODE Setup
- [ ] Add ODE to build system (`DLINK_ODE=1`)
- [ ] Initialize ODE world, space, joint groups
- [ ] Create physics entity component

**Build Configuration:**
```makefile
# In engine/Makefile
ifeq ($(FTE_CONFIG_EXTRA),$(findstring DLINK_ODE=1,$(FTE_CONFIG_EXTRA)))
    LINK_ODE=1
    ALL_CFLAGS+=$(shell pkg-config --cflags ode) -DODE_ENABLED
    COMMONLDDEPS+=$(shell pkg-config --libs ode)
endif
```

#### Day 3-4: Collision System
- [ ] BSP world collision
- [ ] Entity collision meshes
- [ ] Trigger volumes
- [ ] Collision callbacks to QuakeC

#### Day 5: Rigid Body Dynamics
- [ ] Debris physics (barrels, crates)
- [ ] Pickup item physics
- [ ] Ragdoll placeholder
- [ ] Performance testing (<1ms physics step)

**Deliverable:** ODE physics with basic rigid bodies

---

## Phase 5: Optimization & Polish (Weeks 8-10)

### Week 8: M3-Specific Optimizations

#### Day 1-2: Tile-Based Rendering
- [ ] Minimize tile load/store operations
- [ ] Use render passes efficiently
- [ ] Exploit hardware depth testing
- [ ] Profile with Xcode Instruments

#### Day 3-4: Memory Optimization
- [ ] Unified memory zero-copy textures
- [ ] Texture compression (ASTC for M3)
- [ ] Buffer aliasing where possible
- [ ] VRAM budget enforcement (<1.8GB)

#### Day 5: Async Compute
- [ ] Light culling on compute queue
- [ ] FSR upscale parallel to main render
- [ ] Overlap transfer operations
- [ ] Measure concurrency benefits

**Target Metrics:**
- Frame time: <8.33ms (120 FPS)
- GPU utilization: 85-95%
- Memory bandwidth: <100 GB/s

---

### Week 9: Asset Pipeline & Testing

#### Day 1-3: Download Test Content
```bash
#!/bin/bash
# download_test_assets.sh

echo "Downloading benchmark maps..."

# Quake Enhanced maps
wget -nc https://cdn.example.com/quake-enhanced.zip
unzip -n quake-enhanced.zip -d test_maps/

# Custom techbase for lighting stress
wget -nc https://cdn.example.com/techbase_stress.bsp
mv techbase_stress.bsp test_maps/quake/maps/

# Water temple for SSR testing
wget -nc https://cdn.example.com/water_temple.bsp
mv water_temple.bsp test_maps/quake/maps/

echo "Test assets ready!"
```

#### Day 4-5: Performance Validation
- [ ] Benchmark suite (5 maps, 3 scenarios each)
- [ ] Automated regression testing
- [ ] Visual comparison screenshots
- [ ] Frame timing graphs

**Benchmark Maps:**
1. `start.bsp` - Baseline performance
2. `e1m1_enhanced.bsp` - Mixed indoor/outdoor
3. `techbase_stress.bsp` - 500+ dynamic lights
4. `water_temple.bsp` - SSR + refraction stress
5. `open_arena.bsp` - Large outdoor scene

---

### Week 10: Documentation & Release

#### Day 1-2: User Documentation
- [ ] Update README.md with new features
- [ ] Create METAL_SETUP.md guide
- [ ] Document FSR configuration options
- [ ] Troubleshooting section

#### Day 3-4: Developer Documentation
- [ ] API reference for new renderers
- [ ] Shader development guidelines
- [ ] Profiling instructions
- [ ] Contribution guidelines update

#### Day 5: Final Testing & Bug Fixes
- [ ] Full regression test suite
- [ ] Community beta testing feedback
- [ ] Critical bug fixes
- [ ] Release candidate build

**Deliverable:** Production-ready v1.0 release

---

## File Creation Checklist

### Metal Backend (15 files)
- [ ] `engine/mtl/mtl_vidmetal.m`
- [ ] `engine/mtl/mtl_vidmetal.h`
- [ ] `engine/mtl/mtl_renderer.m`
- [ ] `engine/mtl/mtl_renderer.h`
- [ ] `engine/mtl/mtl_buffers.m`
- [ ] `engine/mtl/mtl_buffers.h`
- [ ] `engine/mtl/mtl_textures.m`
- [ ] `engine/mtl/mtl_textures.h`
- [ ] `engine/mtl/mtl_postprocess.m`
- [ ] `engine/mtl/mtl_postprocess.h`
- [ ] `engine/mtl/mtl_clustering.m`
- [ ] `engine/mtl/mtl_clustering.h`
- [ ] `engine/mtl/Makefile`
- [ ] `engine/gl/gl_vidmetal.c` (OpenGL fallback bridge)
- [ ] `engine/common/metal_compat.h`

### Metal Shaders (12 files)
- [ ] `engine/shaders/msl/forward_base.metal`
- [ ] `engine/shaders/msl/forward_water.metal`
- [ ] `engine/shaders/msl/forward_sprite.metal`
- [ ] `engine/shaders/msl/forward_model.metal`
- [ ] `engine/shaders/msl/postprocess_ssr.metal`
- [ ] `engine/shaders/msl/postprocess_bloom.metal`
- [ ] `engine/shaders/msl/postprocess_tonemap.metal`
- [ ] `engine/shaders/msl/fsr_easu.metal`
- [ ] `engine/shaders/msl/fsr_rcas.metal`
- [ ] `engine/shaders/msl/clustering_compute.metal`
- [ ] `engine/shaders/msl/motion_vectors.metal`
- [ ] `engine/shaders/msl/depth_prepass.metal`

### Build System (5 files)
- [ ] `engine/Makefile.metal`
- [ ] `cmake/MetalBackend.cmake`
- [ ] `scripts/download_test_assets.sh`
- [ ] `scripts/build_metal.sh`
- [ ] `scripts/profile_m3.sh`

### Documentation (5 files)
- [ ] `METAL_SETUP.md`
- [ ] `FSR_CONFIGURATION.md`
- [ ] `PERFORMANCE_GUIDE.md`
- [ ] `SHADER_DEVELOPMENT.md`
- [ ] `CHANGELOG_MODERN.md`

**Total: 37 new files**

---

## Success Criteria

### Performance Targets (M3 @ 4K)
| Scenario | Native FPS | FSR Balanced FPS | Target Met |
|----------|-----------|------------------|------------|
| Simple BSP | 240+ | 300+ | ✅ |
| 100 Lights | 120+ | 160+ | ✅ |
| Water + SSR | 90+ | 130+ | ✅ |
| Max Stress | 60+ | 90+ | ✅ |

### Quality Metrics
- **Visual Fidelity**: Indistinguishable from native at 60Hz
- **Input Latency**: <16ms (1 frame) with FSR
- **Stability**: No crashes in 24hr stress test
- **Memory**: <1.8GB VRAM usage

### Compatibility
- **macOS**: 13.0+ (Ventura)
- **Metal**: 3.0+
- **Fallback**: OpenGL 4.5 for older Macs

---

## Risk Mitigation

### Technical Risks
1. **Metal Performance**: If Metal underperforms, optimize tile usage or fall back to OpenGL
2. **FSR Artifacts**: Tune reactive mask generation, add manual override
3. **Memory Pressure**: Implement aggressive LOD streaming, reduce shadow atlas

### Schedule Risks
1. **Shader Porting**: Prioritize core shaders first, defer advanced effects
2. **Testing Delays**: Automate benchmark suite early
3. **Bug Fixes**: Reserve 20% buffer time in Week 10

---

## Next Steps

1. **Immediate (Today)**: Review and approve this roadmap
2. **Day 1**: Set up Metal development environment on M3 Mac
3. **Day 2**: Create initial Metal backend skeleton
4. **Day 3**: Begin Week 1 tasks

**Ready to proceed?** Let me know which phase to start with!
