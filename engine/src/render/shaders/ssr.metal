//
// Screen Space Reflections Compute Shader for Metal
// Optimized for Apple Silicon M3 with Tile-Based Rendering
// Author: FTEQW Development Team
//

#include <metal_stdlib>
using namespace metal;

// MARK: - SSR Constants
constant int MAX_STEPS = 64;
constant float STEP_SIZE = 0.5;
constant float THICKNESS = 0.1;
constant float EPSILON = 0.001;

// MARK: - SSR Input/Output
struct SSROutput {
    float3 color;
    float hitDistance;
    float hitT;
    bool hit;
};

// MARK: - Helper Functions
inline float2 getUVFromPos(thread const float3& pos, thread const float4x4& proj) {
    float4 projected = proj * float4(pos, 1.0);
    float2 uv = projected.xy / projected.w;
    return uv * 0.5 + 0.5;
}

inline float3 getViewRay(thread const float2& uv, thread const float4x4& invViewProj) {
    float4 clipPos = float4(uv * 2.0 - 1.0, 1.0, 1.0);
    float4 worldPos = invViewProj * clipPos;
    return normalize(worldPos.xyz / worldPos.w);
}

// MARK: - SSR Compute Shader
kernel void ssr_compute(
    texture2d<float, access::read> colorTex [[texture(0)]],
    texture2d<float, access::read> depthTex [[texture(1)]],
    texture2d<float, access::read> normalTex [[texture(2)]],
    texture2d<float, access::write> outputTex [[texture(3)]],
    
    constant float& roughness [[buffer(0)]],
    constant float& stepSize [[buffer(1)]],
    constant int& maxSteps [[buffer(2)]],
    constant float4x4& viewProj [[buffer(3)]],
    constant float4x4& invViewProj [[buffer(4)]],
    constant float3& cameraPos [[buffer(5)]],
    
    uint2 gid [[thread_position_in_grid]],
    uint2 blockDim [[threads_per_grid]])
{
    // Check bounds
    if (gid.x >= blockDim.x || gid.y >= blockDim.y) {
        return;
    }
    
    // Get current pixel UV
    float2 uv = (float2(gid) + 0.5) / float2(colorTex.get_width(), colorTex.get_height());
    
    // Sample depth and normal
    float depth = depthTex.sample(sampler(coord::normalized), uv).r;
    float3 normal = normalTex.sample(sampler(coord::normalized), uv).xyz;
    float3 color = colorTex.sample(sampler(coord::normalized), uv).xyz;
    
    // Reconstruct world position from depth
    float4 clipPos = float4(uv * 2.0 - 1.0, depth, 1.0);
    float4 worldPos = invViewProj * clipPos;
    worldPos /= worldPos.w;
    
    // Calculate reflection vector
    float3 viewDir = normalize(worldPos.xyz - cameraPos);
    float3 reflectDir = reflect(-viewDir, normal);
    
    // Add roughness-based jitter
    if (roughness > 0.01) {
        float jitter = roughness * 0.1;
        reflectDir += float3(
            fract(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453) * 2.0 - 1.0,
            fract(sin(dot(uv, float2(12.9898, 78.233) + 1.0)) * 43758.5453) * 2.0 - 1.0,
            fract(sin(dot(uv, float2(12.9898, 78.233) + 2.0)) * 43758.5453) * 2.0 - 1.0
        ) * jitter;
        reflectDir = normalize(reflectDir);
    }
    
    // March along reflection ray
    float3 currentPos = worldPos.xyz + reflectDir * 0.1; // Offset to avoid self-intersection
    float totalDist = 0.1;
    bool hit = false;
    float hitT = 0.0;
    
    for (int i = 0; i < maxSteps && !hit; i++) {
        // Project current position to screen space
        float4 projected = viewProj * float4(currentPos, 1.0);
        float2 currentUV = (projected.xy / projected.w) * 0.5 + 0.5;
        
        // Check if within screen bounds
        if (currentUV.x < 0.0 || currentUV.x > 1.0 || 
            currentUV.y < 0.0 || currentUV.y > 1.0) {
            break;
        }
        
        // Sample scene depth at this UV
        float sceneDepth = depthTex.sample(sampler(coord::normalized), currentUV).r;
        
        // Reconstruct scene world position
        float4 sceneClipPos = float4(currentUV * 2.0 - 1.0, sceneDepth, 1.0);
        float4 sceneWorldPos = invViewProj * sceneClipPos;
        sceneWorldPos /= sceneWorldPos.w;
        
        // Check for intersection
        float distToScene = distance(currentPos, sceneWorldPos.xyz);
        
        if (distToScene < THICKNESS && sceneDepth < projected.z) {
            hit = true;
            hitT = (float)i / (float)maxSteps;
            break;
        }
        
        // Step forward
        currentPos += reflectDir * stepSize;
        totalDist += stepSize;
        
        // Early exit if too far
        if (totalDist > 100.0) {
            break;
        }
    }
    
    // Output result
    float3 resultColor;
    if (hit) {
        // Sample the reflected color from the hit position
        float4 hitProjected = viewProj * float4(currentPos, 1.0);
        float2 hitUV = (hitProjected.xy / hitProjected.w) * 0.5 + 0.5;
        
        if (hitUV.x >= 0.0 && hitUV.x <= 1.0 && hitUV.y >= 0.0 && hitUV.y <= 1.0) {
            resultColor = colorTex.sample(sampler(coord::normalized), hitUV).xyz;
            
            // Fade based on hit distance and roughness
            float fade = 1.0 - smoothstep(0.0, 1.0, hitT);
            fade *= (1.0 - roughness);
            resultColor *= fade;
        } else {
            resultColor = float3(0.0);
        }
    } else {
        resultColor = float3(0.0);
    }
    
    // Write output (RGBA: color + hit info in alpha channels)
    outputTex.write(float4(resultColor, hit ? 1.0 : 0.0), gid);
}

// MARK: - SSR Blur Pass (for smoothing)
kernel void ssr_blur(
    texture2d<float, access::read> inputTex [[texture(0)]],
    texture2d<float, access::write> outputTex [[texture(1)]],
    
    constant float& blurRadius [[buffer(0)]],
    
    uint2 gid [[thread_position_in_grid]],
    uint2 blockDim [[threads_per_grid]])
{
    if (gid.x >= blockDim.x || gid.y >= blockDim.y) {
        return;
    }
    
    float2 uv = (float2(gid) + 0.5) / float2(inputTex.get_width(), inputTex.get_height());
    float2 texelSize = 1.0 / float2(inputTex.get_width(), inputTex.get_height());
    
    float4 center = inputTex.read(gid);
    
    // Skip if no hit
    if (center.a < 0.5) {
        outputTex.write(float4(0.0), gid);
        return;
    }
    
    float3 sum = float3(0.0);
    float weightSum = 0.0;
    
    // Simple box blur
    int radius = (int)blurRadius;
    for (int y = -radius; y <= radius; y++) {
        for (int x = -radius; x <= radius; x++) {
            uint2 samplePos = gid + uint2(x, y);
            
            if (samplePos.x < inputTex.get_width() && samplePos.y < inputTex.get_height()) {
                float4 sample = inputTex.read(samplePos);
                
                // Only blend with valid hits
                if (sample.a > 0.5) {
                    sum += sample.rgb;
                    weightSum += 1.0;
                }
            }
        }
    }
    
    if (weightSum > 0.0) {
        outputTex.write(float4(sum / weightSum, center.a), gid);
    } else {
        outputTex.write(float4(0.0), gid);
    }
}

// MARK: - SSR Composite Pass
kernel void ssr_composite(
    texture2d<float, access::read> colorTex [[texture(0)]],
    texture2d<float, access::read> ssrTex [[texture(1)]],
    texture2d<float, access::write> outputTex [[texture(2)]],
    
    constant float& ssrIntensity [[buffer(0)]],
    
    uint2 gid [[thread_position_in_grid]],
    uint2 blockDim [[threads_per_grid]])
{
    if (gid.x >= blockDim.x || gid.y >= blockDim.y) {
        return;
    }
    
    float3 color = colorTex.read(gid).rgb;
    float3 ssr = ssrTex.read(gid).rgb;
    
    // Additive blend SSR
    float3 result = color + ssr * ssrIntensity;
    
    outputTex.write(float4(result, 1.0), gid);
}
