# Metal Backend for FTEQW Engine

## Overview

This directory contains the **Metal rendering backend** optimized for Apple Silicon (M1/M2/M3) Macs. It implements:

- **Forward+ Rendering** with clustered lighting
- **Screen Space Reflections (SSR)** at 50% resolution with dynamic scaling
- **FSR 2.2 Upscaling** for performance boost
- **Dynamic Resolution Scaling** to maintain 120 FPS target
- **HDR Rendering** with tone mapping

## Files

### Core Implementation
- `metal_backend.m` - Main Metal backend implementation (712 lines)
- `compile_shaders.sh` - Shader compilation script

### Metal Shaders (in `../shaders/`)
- `forward_plus.metal` - Forward+ vertex/fragment shaders with clustered lighting
- `ssr.metal` - Screen space reflections compute shaders
- `fsr_2_2.metal` - FSR 2.2 temporal upscaling shaders
- `cluster_lighting.metal` - Light clustering compute shaders

## Building on macOS M3

### Prerequisites
```bash
# Install Xcode Command Line Tools
xcode-select --install

# Ensure you have macOS 13.0+ (Ventura or later)
sw_vers
```

### Compile Shaders
```bash
cd engine/src/render/metal
./compile_shaders.sh
```

This will:
1. Find all `.metal` files in the shaders directory
2. Compile each to AIR intermediate format
3. Link into `default.metallib`
4. Output library ready for bundling

### Build Engine with Metal Support
```bash
cd engine
gmake makelibs FTE_TARGET=SDL2 METAL=1
gmake gl-rel FTE_TARGET=SDL2 METAL=1
```

## Console Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `r_metal_debug` | 0 | Enable debug output |
| `r_metal_wireframe` | 0 | Wireframe mode |
| `r_metal_hdr` | 1 | HDR rendering |
| `r_metal_vsync` | 1 | Vertical sync |
| `r_metal_dynamic_res` | 1 | Dynamic resolution scaling |
| `r_metal_target_fps` | 120 | Target FPS for dynamic res |
| `r_metal_ssr_quality` | 1 | SSR quality level (0-2) |
| `r_metal_fsr_sharpness` | 0.5 | FSR sharpening amount |

## Performance Targets

### MacBook Air M3 (8-core GPU)
- **Resolution**: 3024x1964 (native) or 4K external
- **Target**: 120 FPS
- **Dynamic Resolution**: 50%-100% based on frame time
- **Expected Performance**:
  - Quake maps: 120+ FPS native
  - Complex scenes: 90-120 FPS with FSR Quality
  - Heavy SSR: 80-100 FPS with dynamic scaling

### Optimization Techniques Used
1. **Tile-Based Deferred Rendering** (TBDR) - Leverages M3's tile-based GPU
2. **Argument Buffers** - Reduced state changes
3. **Compute Shaders** - Offloaded clustering, SSR, FSR to compute
4. **Resource Aliasing** - Reused render targets where possible
5. **Asynchronous Compute** - Overlapped graphics and compute workloads

## Architecture

### Forward+ Pipeline
```
Vertex Input → Vertex Shader → Cluster Assignment → Fragment Shader (Clustered Lighting)
                              ↓
                         Compute Shader (Light Clustering)
```

### SSR Pipeline
```
G-Buffer (Depth/Normal) → Ray March (Compute) → Blur (Compute) → Composite
```

### FSR 2.2 Pipeline
```
Render @ Low Res → Prepass → Reactive Mask → Temporal Upscale → Sharpen → Output
                      ↓
                  History Buffer (reprojected)
```

## Debugging

### View Cluster Visualization
```
r_metal_debug 1
r_metal_visualize_clusters 1
```

### Profile GPU Time
```
/metal_stats
```

### Force Specific Resolution Scale
```
r_metal_dynamic_res 0
r_metal_resolution_scale 0.75
```

## Troubleshooting

### "No Metal device found"
- Ensure you're running on macOS 10.15+
- Check System Report > Graphics/Displays

### Shaders fail to compile
- Update Xcode to latest version
- Ensure macOS SDK is installed: `xcode-select --install`

### Poor performance
- Lower `r_metal_ssr_quality` to 0
- Set `r_metal_target_fps` to 60
- Disable HDR: `r_metal_hdr 0`

## Future Enhancements

- [ ] Mesh shaders for model rendering
- [ ] Variable rate shading (VRS)
- [ ] Ray tracing fallback for M3 Max/Ultra
- [ ] Temporal anti-aliasing (TAAU)
- [ ] Contact hardening shadows

## License

GPL-2.0 - Same as FTEQW engine

## Credits

- Based on FTEQW rendering architecture
- Metal optimization by FTEQW Development Team
- FSR algorithm by AMD
- SSR techniques from various open-source engines
