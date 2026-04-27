//
// FSR 2.2 Upscaling Compute Shader for Metal
// AMD FidelityFX Super Resolution 2.2 Implementation
// Optimized for Apple Silicon M3
// Author: FTEQW Development Team
// Based on AMD FSR 2.2 Algorithm
//

#include <metal_stdlib>
using namespace metal;

// MARK: - FSR Constants
constant float FSR_SHARPNESS_DEFAULT = 0.5;
constant int FSR_MAX_MIP_LEVELS = 16;

// MARK: - FSR Helper Functions

// Convert linear to sRGB
inline float toGamma(float linear) {
    return linear <= 0.0031308 ? linear * 12.92 : pow(linear, 1.0 / 2.4) * 1.055 - 0.055;
}

// Convert sRGB to linear
inline float toLinear(float gamma) {
    return gamma <= 0.04045 ? gamma / 12.92 : pow((gamma + 0.055) / 1.055, 2.4);
}

inline float3 toGamma3(float3 linear) {
    return float3(toGamma(linear.r), toGamma(linear.g), toGamma(linear.b));
}

inline float3 toLinear3(float3 gamma) {
    return float3(toLinear(gamma.r), toLinear(gamma.g), toLinear(gamma.b));
}

// Lanczos filter kernel
inline float lanczos(float x, float a) {
    if (abs(x) > a) return 0.0;
    if (abs(x) < 0.001) return 1.0;
    
    float pix = 3.14159265359 * x;
    return a * sin(pix) * sin(pix / a) / (pix * pix);
}

// Calculate motion vector magnitude
inline float motionMagnitude(float2 mv) {
    return length(mv);
}

// MARK: - FSR 2.2 Pre-Pass (Depth/Velocity Preparation)
kernel void fsr_prepass(
    texture2d<float, access::read> depthTex [[texture(0)]],
    texture2d<float, access::read> motionTex [[texture(1)]],
    texture2d<float, access::write> outputDepth [[texture(2)]],
    texture2d<float, access::write> outputMotion [[texture(3)]],
    
    constant float& inputWidth [[buffer(0)]],
    constant float& inputHeight [[buffer(1)]],
    
    uint2 gid [[thread_position_in_grid]],
    uint2 blockDim [[threads_per_grid]])
{
    if (gid.x >= blockDim.x || gid.y >= blockDim.y) {
        return;
    }
    
    // Read depth and motion vectors
    float depth = depthTex.read(gid).r;
    float2 motion = motionTex.read(gid).xy;
    
    // Dilate depth for better edge handling
    float maxDepth = depth;
    float2 texelSize = 1.0 / float2(inputWidth, inputHeight);
    
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            if (x == 0 && y == 0) continue;
            
            uint2 neighborPos = gid + uint2(x, y);
            if (neighborPos.x < inputWidth && neighborPos.y < inputHeight) {
                float neighborDepth = depthTex.read(neighborPos).r;
                maxDepth = max(maxDepth, neighborDepth);
            }
        }
    }
    
    // Write dilated depth
    outputDepth.write(float4(maxDepth, 0.0, 0.0, 0.0), gid);
    
    // Clamp and scale motion vectors
    float motionScale = 1.0;
    float2 clampedMotion = motion * motionScale;
    
    outputMotion.write(float4(clampedMotion, 0.0, 0.0), gid);
}

// MARK: - FSR 2.2 Reactive Mask (for transparency/temporal stability)
kernel void fsr_reactive(
    texture2d<float, access::read> colorTex [[texture(0)]],
    texture2d<float, access::read> preColorTex [[texture(1)]],
    texture2d<float, access::write> reactiveTex [[texture(2)]],
    
    constant float& sharpness [[buffer(0)]],
    
    uint2 gid [[thread_position_in_grid]],
    uint2 blockDim [[threads_per_grid]])
{
    if (gid.x >= blockDim.x || gid.y >= blockDim.y) {
        return;
    }
    
    float3 currentColor = colorTex.read(gid).rgb;
    float3 preColor = preColorTex.read(gid).rgb;
    
    // Calculate difference (reactivity based on change)
    float diff = length(currentColor - preColor);
    
    // Higher reactivity where there's more change
    float reactive = smoothstep(0.0, 0.5, diff);
    
    // Factor in sharpness
    reactive *= (1.0 - sharpness);
    
    reactiveTex.write(float4(reactive, 0.0, 0.0, 0.0), gid);
}

// MARK: - FSR 2.2 Temporal Upscale (Main Pass)
kernel void fsr_upscale(
    texture2d<float, access::read> inputColor [[texture(0)]],
    texture2d<float, access::read> inputDepth [[texture(1)]],
    texture2d<float, access::read> inputMotion [[texture(2)]],
    texture2d<float, access::read> historyColor [[texture(3)]],
    texture2d<float, access::read> reactiveMask [[texture(4)]],
    texture2d<float, access::write> outputColor [[texture(5)]],
    texture2d<float, access::write> outputHistory [[texture(6)]],
    
    constant float& inputWidth [[buffer(0)]],
    constant float& inputHeight [[buffer(1)]],
    constant float& outputWidth [[buffer(2)]],
    constant float& outputHeight [[buffer(3)]],
    constant float& sharpness [[buffer(4)]],
    constant float& deltaTime [[buffer(5)]],
    constant float4x4& viewProj [[buffer(6)]],
    constant float4x4& prevViewProj [[buffer(7)]],
    
    uint2 gid [[thread_position_in_grid]],
    uint2 blockDim [[threads_per_grid]])
{
    if (gid.x >= blockDim.x || gid.y >= blockDim.y) {
        return;
    }
    
    // Output UV
    float2 outUV = (float2(gid) + 0.5) / float2(outputWidth, outputHeight);
    
    // Map to input space
    float2 inputUV = outUV * float2(inputWidth / outputWidth, inputHeight / outputHeight);
    
    // Sample input color (bilinear)
    float2 inputTexelSize = 1.0 / float2(inputWidth, inputHeight);
    float2 baseUV = floor(inputUV / inputTexelSize) * inputTexelSize;
    
    float3 color[4];
    float weights[4];
    
    // Bilinear sampling
    float2 f = fract(inputUV / inputTexelSize);
    
    uint2 pos00 = uint2(baseUV / inputTexelSize);
    uint2 pos10 = pos00 + uint2(1, 0);
    uint2 pos01 = pos00 + uint2(0, 1);
    uint2 pos11 = pos00 + uint2(1, 1);
    
    color[0] = inputColor.read(pos00).rgb;
    color[1] = inputColor.read(pos10).rgb;
    color[2] = inputColor.read(pos01).rgb;
    color[3] = inputColor.read(pos11).rgb;
    
    float w00 = (1.0 - f.x) * (1.0 - f.y);
    float w10 = f.x * (1.0 - f.y);
    float w01 = (1.0 - f.x) * f.y;
    float w11 = f.x * f.y;
    
    float3 upsampledColor = color[0] * w00 + color[1] * w10 + color[2] * w01 + color[3] * w11;
    
    // Sample depth
    float depth = inputDepth.read(pos00).r;
    
    // Calculate motion vector for this pixel
    float4 worldPos = float4(outUV * 2.0 - 1.0, depth, 1.0);
    float4 prevWorldPos = worldPos; // Simplified - would need full reconstruction
    
    // Reproject to previous frame
    float4 prevClipPos = prevViewProj * prevWorldPos;
    float2 prevUV = (prevClipPos.xy / prevClipPos.w) * 0.5 + 0.5;
    
    // Sample history
    uint2 historyPos = uint2(prevUV * float2(outputWidth, outputHeight));
    float3 historySample = float3(0.0);
    
    if (historyPos.x < outputWidth && historyPos.y < outputHeight) {
        historySample = historyColor.read(historyPos).rgb;
    }
    
    // Get reactive mask value
    float reactive = 0.0;
    uint2 reactivePos = uint2(inputUV / inputTexelSize);
    if (reactivePos.x < inputWidth && reactivePos.y < inputHeight) {
        reactive = reactiveMask.read(reactivePos).r;
    }
    
    // Temporal accumulation with adaptive blending
    float blendFactor = 0.1 + reactive * 0.8; // More reactive = trust history less
    blendFactor = clamp(blendFactor, 0.05, 0.95);
    
    float3 finalColor = mix(historySample, upsampledColor, blendFactor);
    
    // Apply sharpening
    if (sharpness > 0.0) {
        // Simple unsharp mask
        float3 neighbors[4];
        neighbors[0] = inputColor.read(pos10).rgb;
        neighbors[1] = inputColor.read(pos00).rgb;
        neighbors[2] = inputColor.read(pos11).rgb;
        neighbors[3] = inputColor.read(pos01).rgb;
        
        float3 avgNeighbors = (neighbors[0] + neighbors[1] + neighbors[2] + neighbors[3]) * 0.25;
        finalColor += (upsampledColor - avgNeighbors) * sharpness;
    }
    
    // Tone mapping (simple ACES approximation)
    float3 a = 2.51;
    float3 b = 0.03;
    float3 c = 2.43;
    float3 d = 0.59;
    float3 e = 0.14;
    finalColor = saturate((finalColor * (a * finalColor + b)) / (finalColor * (c * finalColor + d) + e));
    
    // Write output
    outputColor.write(float4(finalColor, 1.0), gid);
    outputHistory.write(float4(finalColor, 1.0), gid);
}

// MARK: - FSR 2.2 Quality Check (Optional Debug Pass)
kernel void fsr_quality_check(
    texture2d<float, access::read> inputColor [[texture(0)]],
    texture2d<float, access::read> upscaledColor [[texture(1)]],
    texture2d<float, access::write> diffTex [[texture(2)]],
    
    constant float& inputWidth [[buffer(0)]],
    constant float& inputHeight [[buffer(1)]],
    constant float& outputWidth [[buffer(2)]],
    constant float& outputHeight [[buffer(3)]],
    
    uint2 gid [[thread_position_in_grid]],
    uint2 blockDim [[threads_per_grid]])
{
    if (gid.x >= blockDim.x || gid.y >= blockDim.y) {
        return;
    }
    
    // Sample both images at same screen position
    float2 outUV = (float2(gid) + 0.5) / float2(outputWidth, outputHeight);
    float2 inUV = outUV * float2(inputWidth / outputWidth, inputHeight / outputHeight);
    
    uint2 inPos = uint2(inUV * float2(inputWidth, inputHeight));
    float3 inputSample = inputColor.read(inPos).rgb;
    float3 upscaledSample = upscaledColor.read(gid).rgb;
    
    // Calculate difference
    float diff = length(inputSample - upscaledSample);
    
    // Visualize difference (red = high diff, green = low diff)
    float3 visColor = lerp(float3(0.0, 1.0, 0.0), float3(1.0, 0.0, 0.0), smoothstep(0.0, 0.5, diff));
    
    diffTex.write(float4(visColor, 1.0), gid);
}

// MARK: - FSR 2.2 Auto-Exposure Pass
kernel void fsr_autod exposure(
    texture2d<float, access::read> inputColor [[texture(0)]],
    texture2d<float, access::write> luminanceTex [[texture(1)]],
    
    constant float& inputWidth [[buffer(0)]],
    constant float& inputHeight [[buffer(1)]],
    constant float& exposureTarget [[buffer(2)]],
    
    uint2 gid [[thread_position_in_grid]],
    uint2 blockDim [[threads_per_grid]])
{
    if (gid.x >= blockDim.x || gid.y >= blockDim.y) {
        return;
    }
    
    float3 color = inputColor.read(gid).rgb;
    
    // Convert to luminance (Rec. 709)
    float luminance = dot(color, float3(0.2126, 0.7152, 0.0722));
    
    // Log scale for HDR
    float logLum = log(luminance + 0.0001);
    
    luminanceTex.write(float4(logLum, luminance, 0.0, 0.0), gid);
}
