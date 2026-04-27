// FSR 2.2 Implementation - Edge Adaptive Spatial Upsampling + Robust Contrast Adaptive Sharpening
// Based on AMD FidelityFX FSR 2.2.1
// Target: Forward+ Renderer, Metal/GLSL 4.5
// Features: Temporal Upscaling, Motion Vectors, Reactive Mask

#pragma version 450
#pragma option nv_unroll_all_funcs

// ============================================================================
// UNIFORM BUFFERS
// ============================================================================

layout(std140, binding = 0) uniform FSRParams {
    mat4 projectionMatrix;
    mat4 previousProjectionMatrix;
    vec2 renderSize;          // Internal render resolution
    vec2 displaySize;         // Target display resolution
    vec2 jitterOffset;        // Current frame sub-pixel jitter
    vec2 previousJitterOffset;// Previous frame sub-pixel jitter
    float sharpness;          // Sharpening strength (0.0-2.0, default 0.2)
    float frameTime;
    int frameCount;
    qboolean enableFSR;
} fsrParams;

// ============================================================================
// TEXTURE BINDINGS
// ============================================================================

uniform sampler2D texInputColor;       // Current frame color (render res)
uniform sampler2D texInputDepth;       // Current frame depth (render res)
uniform sampler2D texMotionVectors;    // Motion vectors (render res)
uniform sampler2D texPreviousColor;    // Previous upscaled frame (display res)
uniform sampler2D texPreviousDepth;    // Previous depth (display res)
uniform sampler2D texReactiveMask;     // Transparency/overlay mask (render res)

// ============================================================================
// OUTPUT
// ============================================================================

layout(location = 0) out vec4 outColor;

// ============================================================================
// CONSTANTS
// ============================================================================

#define FSR_PIC_OFFSET 1.0
#define FSR_EPSILON 0.0001
#define FSR_MAX_MOTION 1000.0

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

// Convert from linear to sRGB
vec3 LinearToSRGB(vec3 linearRGB) {
    bvec3 cutoff = lessThan(linearRGB, vec3(0.0031308));
    vec3 lower = linearRGB * vec3(12.92);
    vec3 higher = vec3(1.055) * pow(linearRGB, vec3(1.0 / 2.4)) - vec3(0.055);
    return mix(higher, lower, vec3(cutoff));
}

// Convert from sRGB to linear
vec3 SRGBToLinear(vec3 srgbRGB) {
    bvec3 cutoff = lessThan(srgbRGB, vec3(0.04045));
    vec3 lower = srgbRGB / vec3(12.92);
    vec3 higher = pow((srgbRGB + vec3(0.055)) / vec3(1.055), vec3(2.4));
    return mix(higher, lower, vec3(cutoff));
}

// Clamp with epsilon
float ClampEpsilon(float value) {
    return clamp(value, FSR_EPSILON, 1.0);
}

// ============================================================================
// MOTION VECTOR RECONSTRUCTION
// ============================================================================

vec2 ReconstructMotionVector(vec2 currentUV, float currentDepth) {
    // Get stored motion vector
    vec2 motion = texture(texMotionVectors, currentUV).xy;
    
    // Apply jitter compensation
    vec2 jitterDelta = fsrParams.jitterOffset - fsrParams.previousJitterOffset;
    vec2 renderPixelSize = 1.0 / fsrParams.renderSize;
    vec2 displayPixelSize = 1.0 / fsrParams.displaySize;
    
    motion += jitterDelta * (renderPixelSize / displayPixelSize);
    
    return motion;
}

// ============================================================================
// TEMPORAL REPROJECTION
// ============================================================================

vec2 Reproject(vec2 currentUV, float currentDepth, vec2 motion) {
    // Calculate previous position
    vec2 previousUV = currentUV - motion;
    
    // Depth-based validity check
    float previousDepth = texture(texPreviousDepth, previousUV).r;
    float depthThreshold = 0.01 * currentDepth;
    
    if (abs(previousDepth - currentDepth) > depthThreshold) {
        return vec2(-1.0); // Invalid - depth discontinuity
    }
    
    return previousUV;
}

// ============================================================================
// NEIGHBORHOOD CLAMPING
// ============================================================================

vec3 NeighborhoodClamping(vec3 center, vec2 uv, float threshold) {
    vec3 minVal = center;
    vec3 maxVal = center;
    
    // Sample 4 neighbors
    vec2 offset = 1.0 / fsrParams.displaySize;
    
    vec3 samples[4];
    samples[0] = texture(texPreviousColor, uv + vec2(-offset.x, -offset.y)).rgb;
    samples[1] = texture(texPreviousColor, uv + vec2( offset.x, -offset.y)).rgb;
    samples[2] = texture(texPreviousColor, uv + vec2(-offset.x,  offset.y)).rgb;
    samples[3] = texture(texPreviousColor, uv + vec2( offset.x,  offset.y)).rgb;
    
    // Find min/max
    for (int i = 0; i < 4; i++) {
        minVal = min(minVal, samples[i]);
        maxVal = max(maxVal, samples[i]);
    }
    
    // Expand range by threshold
    vec3 range = maxVal - minVal;
    minVal -= range * threshold;
    maxVal += range * threshold;
    
    return clamp(center, minVal, maxVal);
}

// ============================================================================
// EASU - EDGE ADAPTIVE SPATIAL UPSAMPLING
// ============================================================================

vec3 EASU(vec2 uv) {
    // Calculate derivatives for edge detection
    vec2 dx = dFdx(uv);
    vec2 dy = dFdy(uv);
    
    // Sample 4 corners of the pixel quad
    vec3 tl = texture(texInputColor, uv + vec2(-dx.x, -dx.y)).rgb;
    vec3 tr = texture(texInputColor, uv + vec2( dx.x, -dx.y)).rgb;
    vec3 bl = texture(texInputColor, uv + vec2(-dx.x,  dx.y)).rgb;
    vec3 br = texture(texInputColor, uv + vec2( dx.x,  dx.y)).rgb;
    
    // Edge adaptive weights
    float weightTL = 1.0 / (length(tl - tr) + length(tl - bl) + FSR_EPSILON);
    float weightTR = 1.0 / (length(tr - tl) + length(tr - br) + FSR_EPSILON);
    float weightBL = 1.0 / (length(bl - tl) + length(bl - br) + FSR_EPSILON);
    float weightBR = 1.0 / (length(br - tr) + length(br - bl) + FSR_EPSILON);
    
    float totalWeight = weightTL + weightTR + weightBL + weightBR;
    
    vec3 result = (tl * weightTL + tr * weightTR + bl * weightBL + br * weightBR) / totalWeight;
    
    return result;
}

// ============================================================================
// RCAS - ROBUST CONTRAST ADAPTIVE SHARPENING
// ============================================================================

vec3 RCAS(vec3 inputColor, vec2 uv) {
    float sharpening = fsrParams.sharpness;
    
    // Sample 5-tap cross pattern
    vec3 center = texture(texInputColor, uv).rgb;
    vec3 left = texture(texInputColor, uv + vec2(-1.0/fsrParams.renderSize.x, 0.0)).rgb;
    vec3 right = texture(texInputColor, uv + vec2( 1.0/fsrParams.renderSize.x, 0.0)).rgb;
    vec3 top = texture(texInputColor, uv + vec2(0.0, -1.0/fsrParams.renderSize.y)).rgb;
    vec3 bottom = texture(texInputColor, uv + vec2(0.0,  1.0/fsrParams.renderSize.y)).rgb;
    
    // Calculate contrast
    vec3 maxNeighbor = max(max(left, right), max(top, bottom));
    vec3 minNeighbor = min(min(left, right), min(top, bottom));
    
    // Adaptive sharpening based on local contrast
    vec3 contrast = maxNeighbor - minNeighbor;
    vec3 adaptiveWeight = sharpening / (contrast + FSR_EPSILON);
    adaptiveWeight = clamp(adaptiveWeight, 0.0, 4.0);
    
    // Apply sharpening
    vec3 sum = left + right + top + bottom;
    vec3 sharpened = center + (center * 4.0 - sum) * adaptiveWeight * 0.25;
    
    // Blend with original based on sharpening strength
    return mix(center, sharpened, sharpening);
}

// ============================================================================
// REACTIVE MASK GENERATION
// ============================================================================

float GenerateReactiveMask(vec2 uv) {
    // Sample reactive mask (pre-computed transparency/overlay indicator)
    float mask = texture(texReactiveMask, uv).r;
    
    // Also detect high-frequency content that might cause temporal instability
    vec3 color = texture(texInputColor, uv).rgb;
    vec3 dx = dFdx(color);
    vec3 dy = dFdy(color);
    
    float frequency = length(dx) + length(dy);
    float highFreq = smoothstep(0.1, 0.5, frequency);
    
    return max(mask, highFreq);
}

// ============================================================================
// MAIN FSR 2.2 PASS
// ============================================================================

void main() {
    // Calculate UV in render space
    vec2 renderUV = gl_FragCoord.xy / fsrParams.renderSize;
    vec2 displayUV = gl_FragCoord.xy / fsrParams.displaySize;
    
    // Early out if FSR disabled
    if (!fsrParams.enableFSR) {
        outColor = texture(texInputColor, renderUV);
        return;
    }
    
    // Step 1: Get current frame color and depth
    vec3 currentColor = EASU(renderUV);
    float currentDepth = texture(texInputDepth, renderUV).r;
    
    // Step 2: Calculate motion vector
    vec2 motion = ReconstructMotionVector(renderUV, currentDepth);
    
    // Step 3: Temporal reprojection
    vec2 previousUV = Reproject(displayUV, currentDepth, motion);
    
    vec3 finalColor = currentColor;
    
    if (previousUV.x >= 0.0) {
        // Step 4: Sample previous frame
        vec3 previousColor = texture(texPreviousColor, previousUV).rgb;
        
        // Step 5: Generate reactive mask
        float reactiveMask = GenerateReactiveMask(renderUV);
        
        // Step 6: Neighborhood clamping to prevent ghosting
        vec3 clampedPrevious = NeighborhoodClamping(currentColor, displayUV, 0.1);
        previousColor = clamp(previousColor, clampedPrevious.rgb, clampedPrevious.rgb);
        
        // Step 7: Blend current and previous based on reactive mask
        float blendFactor = 1.0 - reactiveMask;
        finalColor = mix(previousColor, currentColor, blendFactor);
    }
    
    // Step 8: Apply RCAS sharpening
    finalColor = RCAS(finalColor, renderUV);
    
    // Step 9: Output
    outColor = vec4(finalColor, 1.0);
}

// ============================================================================
// COMPUTE SHADER VERSION (For better performance)
// ============================================================================

/*
Compute Shader Layout (GLSL 4.5):

layout(local_size_x = 16, local_size_y = 16) in;

layout(rgba16f, binding = 0) uniform image2D outputImage;
layout(binding = 1) uniform sampler2D inputColor;
// ... other bindings

void main() {
    ivec2 dispatchThreadID = ivec2(gl_GlobalInvocationID.xy);
    vec2 uv = (vec2(dispatchThreadID) + 0.5) / fsrParams.displaySize;
    
    // Same FSR logic as above
    vec3 result = FSR_Upscale(uv);
    
    imageStore(outputImage, dispatchThreadID, vec4(result, 1.0));
}
*/

// ============================================================================
// METAL IMPLEMENTATION NOTES
// ============================================================================

/*
Metal Compute Shader Implementation:

kernel void fsrUpscale(texture2d<half, access::write> output [[texture(0)]],
                       texture2d<half, access::sample> inputColor [[texture(1)]],
                       texture2d<half, access::sample> motionVectors [[texture(2)]],
                       constant FSRParams &params [[buffer(0)]],
                       uint2 gid [[thread_position_in_grid]]) {
    
    // Use half precision for M3 efficiency
    half2 uv = (half2(gid) + 0.5h) / params.displaySize;
    
    // Implement same algorithm as GLSL
    // Use simd functions for neighbor sampling
    // Exploit threadgroup memory for shared data
    
    half3 result = fsr_upscale(uv, inputColor, motionVectors, params);
    output.write(half4(result, 1.0h), gid);
}

M3 Optimizations:
- Use half precision throughout (M3 GPU is optimized for FP16)
- Use threadgroup memory for neighbor caching
- Use simd_shuffle for efficient neighbor communication
- Align textures to tile size (16x16 or 32x32)
- Use argument buffers for efficient resource binding
*/

// ============================================================================
// PERFORMANCE TUNING GUIDELINES
// ============================================================================

/*
Quality Modes:
- Performance: renderSize = displaySize * 0.5  (4K -> 1080p)
- Balanced:    renderSize = displaySize * 0.67 (4K -> 1440p)
- Quality:     renderSize = displaySize * 0.77 (4K -> 1620p)

Recommended Settings for M3 @ 4K 120Hz:
- Quality Mode: Balanced (0.67)
- Sharpening: 0.2-0.3
- SSR Quality: 0.5 (50% resolution)
- Dynamic Resolution: Target 8.33ms frame time

Memory Budget:
- Motion Vectors: 1920x1080 x RG16F = 8MB
- Previous Color: 3840x2160 x RGBA16F = 128MB
- Previous Depth: 3840x2160 x R32F = 64MB
- Reactive Mask: 1920x1080 x R8 = 4MB
Total: ~204MB

Optimization Tips:
1. Use compute shaders instead of fragment shaders (async compute)
2. Tile-based processing for M3 GPU
3. Reduce temporal history when motion is high
4. Skip FSR for UI/HUD elements
5. Use variable rate shading for periphery
*/
