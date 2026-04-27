//
// Forward+ Rendering Shaders for Metal
// Optimized for Apple Silicon M3
// Author: FTEQW Development Team
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Constants
constant int MAX_LIGHTS_PER_CLUSTER = 64;
constant int CLUSTER_GRID_X = 16;
constant int CLUSTER_GRID_Y = 16;
constant int CLUSTER_GRID_Z = 16;

// MARK: - Structures
struct VertexIn {
    float3 position [[attribute(0)]];
    float2 texcoord [[attribute(1)]];
    float4 color [[attribute(2)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texcoord;
    float4 color;
    float3 worldPos;
    float3 normal;
};

struct Light {
    float3 position;
    float radius;
    float3 color;
    float intensity;
    float3 direction;
    float spotAngle;
    int type;
    float pad;
};

struct Uniforms {
    float4x4 viewProj;
    float4x4 invViewProj;
    float3 cameraPos;
    float deltaTime;
    float4 clusters[CLUSTER_GRID_X * CLUSTER_GRID_Y * CLUSTER_GRID_Z];
    int lightCount;
    int clusterCount;
    int frameIndex;
    int resolutionScale;
};

// MARK: - Vertex Shader (Forward+)
vertex VertexOut forward_vertex_main(
    const device VertexIn* vertices [[buffer(0)]],
    constant float4x4& modelViewProj [[buffer(1)]],
    constant Uniforms& uniforms [[buffer(2)]],
    uint vertexID [[vertex_id]])
{
    VertexIn in = vertices[vertexID];
    
    VertexOut out;
    out.position = modelViewProj * float4(in.position, 1.0);
    out.texcoord = in.texcoord;
    out.color = in.color;
    
    // Calculate world position for lighting
    float4 worldPos = uniforms.invViewProj * float4(in.position, 1.0);
    out.worldPos = worldPos.xyz / worldPos.w;
    
    // Simple normal calculation (would be passed in real implementation)
    out.normal = float3(0, 0, 1);
    
    return out;
}

// MARK: - Fragment Shader (Forward+ with Clustered Lighting)
fragment float4 forward_fragment_main(
    VertexOut in [[stage_in]],
    texture2d<float> diffuseTex [[texture(0)]],
    sampler diffuseSampler [[sampler(0)]],
    constant Uniforms& uniforms [[buffer(2)]],
    const device Light* lights [[buffer(3)]],
    const device uint* clusterData [[buffer(4)]])
{
    // Sample diffuse texture
    float4 albedo = diffuseTex.sample(diffuseSampler, in.texcoord);
    if (albedo.a < 0.01) {
        discard_fragment();
    }
    
    albedo *= in.color;
    
    // Calculate which cluster this pixel belongs to
    float3 viewPos = in.worldPos - uniforms.cameraPos;
    int3 clusterIdx;
    clusterIdx.x = clamp((int)((viewPos.x + 100.0) / 200.0 * CLUSTER_GRID_X), 0, CLUSTER_GRID_X - 1);
    clusterIdx.y = clamp((int)((viewPos.y + 100.0) / 200.0 * CLUSTER_GRID_Y), 0, CLUSTER_GRID_Y - 1);
    clusterIdx.z = clamp((int)((viewPos.z + 10.0) / 500.0 * CLUSTER_GRID_Z), 0, CLUSTER_GRID_Z - 1);
    
    int clusterID = clusterIdx.x + clusterIdx.y * CLUSTER_GRID_X + clusterIdx.z * CLUSTER_GRID_X * CLUSTER_GRID_Y;
    
    // Get lights in this cluster
    int lightStart = clusterID * MAX_LIGHTS_PER_CLUSTER;
    int lightCount = min((int)clusterData[clusterID], MAX_LIGHTS_PER_CLUSTER);
    
    // Accumulate lighting
    float3 finalColor = float3(0);
    
    // Ambient term
    finalColor += float3(0.05);
    
    // Add lights in cluster
    for (int i = 0; i < lightCount; i++) {
        Light light = lights[lightStart + i];
        
        float3 lightDir = light.position - in.worldPos;
        float dist = length(lightDir);
        
        if (dist > light.radius) continue;
        
        lightDir /= dist;
        
        // Diffuse
        float NdotL = max(dot(in.normal, lightDir), 0.0);
        float3 diffuse = NdotL * light.color * light.intensity;
        
        // Attenuation
        float attenuation = 1.0 - (dist / light.radius);
        attenuation *= attenuation;
        
        finalColor += diffuse * attenuation;
    }
    
    return float4(finalColor * albedo.rgb, albedo.a);
}

// MARK: - Water Fragment Shader with SSR
fragment float4 water_fragment_main(
    VertexOut in [[stage_in]],
    texture2d<float> waterTex [[texture(0)]],
    sampler waterSampler [[sampler(0)]],
    texture2d<float> reflectionTex [[texture(1)]],
    sampler reflectionSampler [[sampler(1)]],
    constant Uniforms& uniforms [[buffer(2)]])
{
    // Sample water texture
    float4 waterColor = waterTex.sample(waterSampler, in.texcoord);
    
    // Sample screen-space reflections
    float2 ssrUV = in.texcoord;
    // In real implementation, SSR would be computed in compute shader
    float4 reflection = reflectionTex.sample(reflectionSampler, ssrUV);
    
    // Fresnel effect
    float3 viewDir = normalize(uniforms.cameraPos - in.worldPos);
    float fresnel = pow(1.0 - max(dot(viewDir, in.normal), 0.0), 3.0);
    
    // Mix water color with reflections
    float3 finalColor = mix(waterColor.rgb, reflection.rgb, fresnel * 0.8);
    
    // Add specular highlights
    // (simplified - would use actual light directions)
    finalColor += float3(0.1);
    
    return float4(finalColor, waterColor.a * 0.7);
}

// MARK: - Sprite Fragment Shader (Additive)
fragment float4 sprite_fragment_main(
    VertexOut in [[stage_in]],
    texture2d<float> spriteTex [[texture(0)]],
    sampler spriteSampler [[sampler(0)]])
{
    float4 color = spriteTex.sample(spriteSampler, in.texcoord);
    
    // Additive blending for sprites/particles
    if (color.a < 0.01) {
        discard_fragment();
    }
    
    return float4(color.rgb, color.a);
}

// MARK: - Sky Fragment Shader
fragment float4 sky_fragment_main(
    VertexOut in [[stage_in]],
    texture2d<float> skyTex [[texture(0)]],
    sampler skySampler [[sampler(0)]])
{
    return skyTex.sample(skySampler, in.texcoord);
}
