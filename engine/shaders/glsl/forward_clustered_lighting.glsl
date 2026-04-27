# Forward+ Clustered Lighting Shader
// Target: Forward+ Renderer, Metal/GLSL 4.5
// Features: 1024+ lights, 3D clustering, shadows, M3 optimized

#pragma version 450
#pragma option nv_unroll_all_funcs

// ============================================================================
// CLUSTERING CONFIGURATION
// ============================================================================

#define CLUSTER_GRID_X 16
#define CLUSTER_GRID_Y 8
#define CLUSTER_GRID_Z 8
#define MAX_LIGHTS_PER_CLUSTER 64
#define MAX_TOTAL_LIGHTS 1024
#define TILE_SIZE 16

// ============================================================================
// UNIFORM BUFFERS
// ============================================================================

layout(std140, binding = 0) uniform ClusterParams {
    mat4 viewMatrix;
    mat4 projMatrix;
    mat4 previousViewProj;
    vec4 frustumPlanes[6];  // View frustum for culling
    vec4 clusterDimensions; // Grid size + tile counts
    vec4 screenParams;      // Screen width/height + inverses
    float zNear;
    float zFar;
    float zLogarithmic;     // 1.0 = use log Z distribution
    int totalLights;
} clusterParams;

// Light structure matching C-side layout
struct Light {
    vec4 position;      // xyz = world pos, w = type (0=point, 1=spot, 2=dir)
    vec4 color;         // xyz = RGB, w = intensity
    vec4 direction;     // xyz = dir, w = spot exponent
    vec4 attenuation;   // const, linear, quad, cutoff
    mat4 shadowMatrix;  // For shadow mapping
    int shadowMapIndex; // Shadow map array index
    int enabled;        // Light active flag
    int padding[3];
};

layout(std140, binding = 1) uniform LightBuffer {
    Light lights[MAX_TOTAL_LIGHTS];
} lightBuffer;

// Cluster data structure (computed via compute shader)
struct Cluster {
    uint lightOffset;
    uint lightCount;
    uint lightIndices[MAX_LIGHTS_PER_CLUSTER];
};

layout(std140, binding = 2) uniform ClusterData {
    Cluster clusters[CLUSTER_GRID_X * CLUSTER_GRID_Y * CLUSTER_GRID_Z];
} clusterData;

// ============================================================================
// TEXTURE BINDINGS
// ============================================================================

uniform sampler2D texAlbedo;
uniform sampler2D texNormal;
uniform sampler2D texRoughness;
uniform sampler2D texEmissive;
uniform sampler2DArrayShadow texShadowMaps; // Shadow map array

// ============================================================================
// INPUT/OUTPUT
// ============================================================================

layout(location = 0) in vec3 inWorldPos;
layout(location = 1) in vec3 inWorldNormal;
layout(location = 2) in vec2 inTexCoord;
layout(location = 3) in vec3 inTangent;
layout(location = 4) in vec3 inBitangent;
layout(location = 5) in vec3 inViewDir;

layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outMotionVector; // For FSR

// ============================================================================
// PBR MATERIAL PARAMETERS
// ============================================================================

layout(std140, binding = 3) uniform MaterialParams {
    vec4 baseColorFactor;     // RGBA
    float metallic;
    float roughness;
    float normalScale;
    float emissiveStrength;
    int alphaMode;            // 0=opaque, 1=mask, 2=blend
    float alphaCutoff;
    int doubleSided;
} material;

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

// Calculate cluster index from screen position and depth
uvec3 GetClusterIndex(vec2 screenUV, float depth) {
    uvec3 cluster;
    
    // XY from screen coordinates
    cluster.xy = screenUV * vec2(CLUSTER_GRID_X, CLUSTER_GRID_Y);
    cluster.xy = clamp(cluster.xy, uvec2(0), uvec2(CLUSTER_GRID_X - 1, CLUSTER_GRID_Y - 1));
    
    // Z from depth (logarithmic distribution for better precision)
    float ndcDepth = depth * 2.0 - 1.0;
    float viewZ = -clusterParams.zFar / (clusterParams.zLogarithmic > 0.5 ? 
                        exp(mix(log(clusterParams.zNear), log(clusterParams.zFar), (ndcDepth + 1.0) * 0.5)) :
                        mix(clusterParams.zNear, clusterParams.zFar, (ndcDepth + 1.0) * 0.5));
    
    float zSlice = (viewZ - clusterParams.zNear) / (clusterParams.zFar - clusterParams.zNear);
    cluster.z = uint(zSlice * float(CLUSTER_GRID_Z));
    cluster.z = clamp(cluster.z, 0u, uint(CLUSTER_GRID_Z - 1));
    
    return cluster;
}

// Convert cluster index to flat index
uint ClusterToFlat(uvec3 cluster) {
    return cluster.z * (CLUSTER_GRID_X * CLUSTER_GRID_Y) + 
           cluster.y * CLUSTER_GRID_X + 
           cluster.x;
}

// ============================================================================
// LIGHT CULLING (Per-Pixel)
// ============================================================================

bool IsLightAffectingCluster(Light light, uvec3 cluster) {
    // Reconstruct cluster bounds in view space
    float xMin = float(cluster.x) / float(CLUSTER_GRID_X);
    float xMax = float(cluster.x + 1) / float(CLUSTER_GRID_X);
    float yMin = float(cluster.y) / float(CLUSTER_GRID_Y);
    float yMax = float(cluster.y + 1) / float(CLUSTER_GRID_Y);
    float zMin, zMax;
    
    if (clusterParams.zLogarithmic > 0.5) {
        float zMinNorm = float(cluster.z) / float(CLUSTER_GRID_Z);
        float zMaxNorm = float(cluster.z + 1) / float(CLUSTER_GRID_Z);
        zMin = clusterParams.zNear * pow(clusterParams.zFar / clusterParams.zNear, zMinNorm);
        zMax = clusterParams.zNear * pow(clusterParams.zFar / clusterParams.zNear, zMaxNorm);
    } else {
        zMin = clusterParams.zNear + float(cluster.z) / float(CLUSTER_GRID_Z) * (clusterParams.zFar - clusterParams.zNear);
        zMax = clusterParams.zNear + float(cluster.z + 1) / float(CLUSTER_GRID_Z) * (clusterParams.zFar - clusterParams.zNear);
    }
    
    // Simple sphere-AABB test
    float lightRadius = light.attenuation.w; // Use cutoff as radius approximation
    vec3 lightPosView = (clusterParams.viewMatrix * light.position).xyz;
    
    // Check if light sphere intersects cluster box
    float xDist = max(xMin - lightPosView.x, max(lightPosView.x - xMax, 0.0));
    float yDist = max(yMin - lightPosView.y, max(lightPosView.y - yMax, 0.0));
    float zDist = max(zMin - lightPosView.z, max(lightPosView.z - zMax, 0.0));
    
    return (xDist * xDist + yDist * yDist + zDist * zDist) < (lightRadius * lightRadius);
}

// ============================================================================
// SHADOW SAMPLING
// ============================================================================

float SampleShadow(vec4 shadowCoord, int shadowMapIndex) {
    if (shadowMapIndex < 0) return 1.0;
    
    // Perspective division
    vec3 projCoords = shadowCoord.xyz / shadowCoord.w;
    projCoords = projCoords * 0.5 + 0.5;
    
    // Check bounds
    if (projCoords.z < 0.0 || projCoords.z > 1.0 ||
        projCoords.x < 0.0 || projCoords.x > 1.0 ||
        projCoords.y < 0.0 || projCoords.y > 1.0) {
        return 1.0;
    }
    
    // PCF sampling
    float visibility = 0.0;
    vec2 texelSize = 1.0 / 1024.0; // Assuming 1024x1024 shadow maps
    
    for (int x = -1; x <= 1; ++x) {
        for (int y = -1; y <= 1; ++y) {
            vec2 offset = vec2(float(x), float(y)) * texelSize;
            visibility += texture(texShadowMaps, vec3(projCoords.xy + offset, shadowMapIndex));
        }
    }
    
    return visibility / 9.0;
}

// ============================================================================
// PBR LIGHTING CALCULATION
// ============================================================================

// Cook-Torrance BRDF
vec3 DistributionGGX(vec3 N, vec3 H, float roughness) {
    float a = roughness * roughness;
    float a2 = a * a;
    float NdotH = max(dot(N, H), 0.0);
    float NdotH2 = NdotH * NdotH;
    
    float nom = a2;
    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = 3.14159265359 * denom * denom;
    
    return nom / denom;
}

float GeometrySchlickGGX(float NdotV, float roughness) {
    float r = (roughness + 1.0);
    float k = (r * r) / 8.0;
    
    float num = NdotV;
    float denom = NdotV * (1.0 - k) + k;
    
    return num / denom;
}

float GeometrySmith(vec3 N, vec3 V, vec3 L, float roughness) {
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    float ggx2 = GeometrySchlickGGX(NdotV, roughness);
    float ggx1 = GeometrySchlickGGX(NdotL, roughness);
    
    return ggx1 * ggx2;
}

vec3 FresnelSchlick(float cosTheta, vec3 F0) {
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

// Calculate lighting from a single light
vec3 CalculateLighting(Light light, vec3 worldPos, vec3 N, vec3 V, vec3 albedo, float metallic, float roughness) {
    vec3 L;
    float distance;
    float attenuation;
    
    if (light.position.w == 2.0) {
        // Directional light
        L = normalize(-light.direction.xyz);
        distance = 1000.0;
        attenuation = 1.0;
    } else {
        // Point or spot light
        vec3 lightVec = light.position.xyz - worldPos;
        distance = length(lightVec);
        L = normalize(lightVec);
        
        // Attenuation
        attenuation = 1.0 / (light.attenuation.x + 
                            light.attenuation.y * distance + 
                            light.attenuation.z * distance * distance);
        
        // Spot light cutoff
        if (light.position.w == 1.0) {
            float theta = dot(L, normalize(-light.direction.xyz));
            float epsilon = light.attenuation.w - 0.95; // Soft edge
            attenuation *= smoothstep(0.0, epsilon, theta);
        }
    }
    
    // Early out if too dim
    if (attenuation < 0.01) return vec3(0.0);
    
    // Shadow calculation
    float shadow = 1.0;
    if (light.shadowMapIndex >= 0) {
        vec4 shadowCoord = light.shadowMatrix * vec4(worldPos, 1.0);
        shadow = SampleShadow(shadowCoord, light.shadowMapIndex);
    }
    
    // PBR calculations
    vec3 H = normalize(V + L);
    float NdotL = max(dot(N, L), 0.0);
    float NdotV = max(dot(N, V), 0.0);
    
    // Reflectance at normal incidence
    vec3 F0 = vec3(0.04);
    F0 = mix(F0, albedo, metallic);
    
    // Cook-Torrance BRDF
    vec3 F = FresnelSchlick(max(dot(H, V), 0.0), F0);
    vec3 D = DistributionGGX(N, H, roughness);
    float G = GeometrySmith(N, V, L, roughness);
    
    vec3 numerator = D * F * G;
    float denominator = 4.0 * NdotV * NdotL + 0.0001;
    vec3 specular = numerator / denominator;
    
    // Diffuse (energy conservation)
    vec3 kd = vec3(1.0) - F;
    kd *= 1.0 - metallic;
    
    vec3 diffuse = kd * albedo / 3.14159265359;
    
    // Final lighting
    vec3 radiance = light.color.rgb * light.color.w * attenuation * shadow;
    return (diffuse + specular) * radiance * NdotL;
}

// ============================================================================
// MOTION VECTOR GENERATION (For FSR)
// ============================================================================

vec2 CalculateMotionVector(vec3 worldPos) {
    // Current frame position
    vec4 currentPos = clusterParams.projMatrix * clusterParams.viewMatrix * vec4(worldPos, 1.0);
    currentPos /= currentPos.w;
    
    // Previous frame position
    vec4 previousPos = clusterParams.previousViewProj * vec4(worldPos, 1.0);
    previousPos /= previousPos.w;
    
    // Motion in screen space
    vec2 motion = currentPos.xy - previousPos.xy;
    
    return motion * 0.5; // Scale to [-0.5, 0.5] range
}

// ============================================================================
// MAIN SHADER
// ============================================================================

void main() {
    // Sample textures
    vec4 albedoSample = texture(texAlbedo, inTexCoord) * material.baseColorFactor;
    vec3 albedo = albedoSample.rgb;
    float alpha = albedoSample.a;
    
    vec3 tangentNormal = texture(texNormal, inTexCoord).rgb * 2.0 - 1.0;
    tangentNormal *= material.normalScale;
    
    float roughness = texture(texRoughness, inTexCoord).r * material.roughness;
    vec3 emissive = texture(texEmissive, inTexCoord).rgb * material.emissiveStrength;
    
    // Alpha test
    if (material.alphaMode == 1 && alpha < material.alphaCutoff) {
        discard;
    }
    
    // Build TBN matrix
    mat3 TBN = mat3(normalize(inTangent), 
                    normalize(inBitangent), 
                    normalize(inWorldNormal));
    
    // Transform normal to world space
    vec3 N = normalize(TBN * tangentNormal);
    if (material.doubleSided == 1 && dot(N, inViewDir) < 0.0) {
        N = -N;
    }
    
    // View direction
    vec3 V = normalize(inViewDir);
    
    // Get cluster for this pixel
    vec2 screenUV = gl_FragCoord.xy / clusterParams.screenParams.xy;
    float depth = gl_FragCoord.z;
    uvec3 cluster = GetClusterIndex(screenUV, depth);
    uint clusterIdx = ClusterToFlat(cluster);
    
    // Accumulate lighting
    vec3 finalColor = vec3(0.0);
    
    // Process all lights in cluster
    Cluster currentCluster = clusterData.clusters[clusterIdx];
    for (uint i = 0; i < currentCluster.lightCount && i < MAX_LIGHTS_PER_CLUSTER; i++) {
        uint lightIdx = currentCluster.lightIndices[i];
        if (lightIdx >= MAX_TOTAL_LIGHTS) break;
        
        Light light = lightBuffer.lights[lightIdx];
        if (light.enabled == 0) continue;
        
        finalColor += CalculateLighting(light, inWorldPos, N, V, albedo, material.metallic, roughness);
    }
    
    // Add emissive
    finalColor += emissive;
    
    // Tone mapping (simple Reinhard)
    finalColor = finalColor / (finalColor + vec3(1.0));
    
    // Gamma correction
    finalColor = pow(finalColor, vec3(1.0 / 2.2));
    
    // Output color
    outColor = vec4(finalColor, alpha);
    
    // Output motion vector for FSR
    vec2 motion = CalculateMotionVector(inWorldPos);
    outMotionVector = vec4(motion, 0.0, 1.0);
}

// ============================================================================
// METAL IMPLEMENTATION NOTES
// ============================================================================

/*
Metal Shader Signature:

struct VertexOut {
    float4 position [[position]];
    float3 worldPos;
    float3 worldNormal;
    float2 texCoord;
    float3 tangent;
    float3 bitangent;
    float3 viewDir;
};

fragment void forwardFragment(VertexOut in [[stage_in]],
                              constant ClusterParams &params [[buffer(0)]],
                              constant LightBuffer &lights [[buffer(1)]],
                              constant ClusterData &clusters [[buffer(2)]],
                              constant MaterialParams &mat [[buffer(3)]],
                              texture2d<float> albedoTex [[texture(0)]],
                              texture2d<float> normalTex [[texture(1)]],
                              sampler texSampler [[sampler(0)]]) {
    
    // Use half precision where possible for M3
    // Use threadgroup memory for shared cluster data
    // Implement same algorithm as GLSL
}

M3 Optimizations:
- Use simd_broadcast for cluster data sharing
- Use argument buffers for efficient binding
- Exploit tile memory for intermediate results
- Use FP16 for lighting calculations
*/
