//
// Light Clustering Compute Shader for Metal
// Forward+ Clustered Lighting Implementation
// Optimized for Apple Silicon M3
// Author: FTEQW Development Team
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Clustering Constants
constant int CLUSTER_GRID_X = 16;
constant int CLUSTER_GRID_Y = 16;
constant int CLUSTER_GRID_Z = 16;
constant int MAX_LIGHTS_PER_CLUSTER = 64;
constant int MAX_TOTAL_LIGHTS = 2048;
constant float NEAR_PLANE = 0.1;
constant float FAR_PLANE = 500.0;

// MARK: - Structures
struct Light {
    float3 position;
    float radius;
    float3 color;
    float intensity;
    float3 direction;
    float spotAngle;
    int type; // 0=point, 1=spot, 2=directional
    float pad;
};

struct Uniforms {
    float4x4 viewProj;
    float4x4 invViewProj;
    float3 cameraPos;
    float deltaTime;
    int lightCount;
    int clusterCount;
    int frameIndex;
    int resolutionScale;
};

// MARK: - Cluster Index Calculation
inline uint3 getClusterIndex(float3 worldPos, float3 cameraPos) {
    // Calculate view-space position
    float3 viewPos = worldPos - cameraPos;
    
    // Convert to cluster coordinates
    // X and Y are based on view frustum
    // Z is logarithmic for better depth distribution
    
    float z = length(viewPos);
    int clusterZ = (int)(log(z / NEAR_PLANE) / log(FAR_PLANE / NEAR_PLANE) * (CLUSTER_GRID_Z - 1));
    clusterZ = clamp(clusterZ, 0, CLUSTER_GRID_Z - 1);
    
    // For X and Y, we need to project to near plane
    float fovY = 1.0; // Would come from uniforms
    float aspect = 1.77; // 16:9
    
    float tanHalfFovY = tan(fovY * 0.5);
    float tanHalfFovX = tanHalfFovY * aspect;
    
    float nearHeight = 2.0 * NEAR_PLANE * tanHalfFovY;
    float nearWidth = 2.0 * NEAR_PLANE * tanHalfFovX;
    
    float xNorm = viewPos.x / (z * tanHalfFovX);
    float yNorm = viewPos.y / (z * tanHalfFovY);
    
    int clusterX = (int)((xNorm + 1.0) * 0.5 * (CLUSTER_GRID_X - 1));
    int clusterY = (int)((yNorm + 1.0) * 0.5 * (CLUSTER_GRID_Y - 1));
    
    clusterX = clamp(clusterX, 0, CLUSTER_GRID_X - 1);
    clusterY = clamp(clusterY, 0, CLUSTER_GRID_Y - 1);
    
    return uint3(clusterX, clusterY, clusterZ);
}

// MARK: - AABB-Box Intersection Test
inline bool boxSphereIntersect(
    float3 boxMin, float3 boxMax,
    float3 sphereCenter, float sphereRadius)
{
    float3 closestPoint = clamp(sphereCenter, boxMin, boxMax);
    float distSq = lengthSquared(sphereCenter - closestPoint);
    return distSq <= sphereRadius * sphereRadius;
}

// MARK: - Light-Cluster Assignment
kernel void cluster_lighting_compute(
    const device Light* lights [[buffer(0)]],
    device uint* clusterData [[buffer(1)]],
    constant Uniforms& uniforms [[buffer(2)]],
    
    constant float& nearPlane [[buffer(3)]],
    constant float& farPlane [[buffer(4)]],
    constant float& fovY [[buffer(5)]],
    constant float& aspect [[buffer(6)]],
    
    uint3 gid [[thread_position_in_grid]])
{
    // Each thread handles one cluster
    if (gid.x >= CLUSTER_GRID_X || gid.y >= CLUSTER_GRID_Y || gid.z >= CLUSTER_GRID_Z) {
        return;
    }
    
    uint clusterIdx = gid.x + gid.y * CLUSTER_GRID_X + gid.z * CLUSTER_GRID_X * CLUSTER_GRID_Y;
    
    // Calculate cluster bounds in view space
    float zMin = nearPlane * pow(farPlane / nearPlane, (float)gid.z / (CLUSTER_GRID_Z - 1));
    float zMax = nearPlane * pow(farPlane / nearPlane, (float)(gid.z + 1) / (CLUSTER_GRID_Z - 1));
    
    float tanHalfFovY = tan(fovY * 0.5);
    float tanHalfFovX = tanHalfFovY * aspect;
    
    float xMin = -zMin * tanHalfFovX * (1.0 - 2.0 * (float)gid.x / (CLUSTER_GRID_X - 1));
    float xMax = -zMin * tanHalfFovX * (1.0 - 2.0 * (float)(gid.x + 1) / (CLUSTER_GRID_X - 1));
    float yMin = -zMin * tanHalfFovY * (1.0 - 2.0 * (float)gid.y / (CLUSTER_GRID_Y - 1));
    float yMax = -zMin * tanHalfFovY * (1.0 - 2.0 * (float)(gid.y + 1) / (CLUSTER_GRID_Y - 1));
    
    // Swap if needed
    if (xMin > xMax) { float t = xMin; xMin = xMax; xMax = t; }
    if (yMin > yMax) { float t = yMin; yMin = yMax; yMax = t; }
    
    float3 clusterMin = float3(xMin, yMin, zMin);
    float3 clusterMax = float3(xMax, yMax, zMax);
    
    // Initialize cluster light count
    clusterData[clusterIdx * MAX_LIGHTS_PER_CLUSTER] = 0;
    
    // Test each light against this cluster
    uint lightCount = 0;
    
    for (int i = 0; i < uniforms.lightCount && lightCount < MAX_LIGHTS_PER_CLUSTER; i++) {
        Light light = lights[i];
        
        bool intersects = false;
        
        if (light.type == 0) { // Point light
            // Transform light position to view space
            float3 lightViewPos = light.position - uniforms.cameraPos;
            
            // Simple sphere-box test
            intersects = boxSphereIntersect(clusterMin, clusterMax, lightViewPos, light.radius);
            
        } else if (light.type == 1) { // Spot light
            float3 lightViewPos = light.position - uniforms.cameraPos;
            
            // Check sphere intersection first
            if (boxSphereIntersect(clusterMin, clusterMax, lightViewPos, light.radius)) {
                // Additional cone test could be added here
                intersects = true;
            }
            
        } else if (light.type == 2) { // Directional light
            // Directional lights affect all clusters
            intersects = true;
        }
        
        if (intersects) {
            clusterData[clusterIdx * MAX_LIGHTS_PER_CLUSTER + lightCount + 1] = i;
            lightCount++;
        }
    }
    
    // Store light count at the beginning of the cluster data
    clusterData[clusterIdx * MAX_LIGHTS_PER_CLUSTER] = lightCount;
}

// MARK: - Cluster Visualization (Debug)
kernel void cluster_visualize(
    texture2d<float, access::write> outputTex [[texture(0)]],
    constant Uniforms& uniforms [[buffer(1)]],
    const device uint* clusterData [[buffer(2)]],
    
    uint2 gid [[thread_position_in_grid]],
    uint2 blockDim [[threads_per_grid]])
{
    if (gid.x >= blockDim.x || gid.y >= blockDim.y) {
        return;
    }
    
    // Create a visualization of cluster occupancy
    // Each pixel represents a cluster (X,Y), color shows light count
    
    float clusterX = (float)gid.x / blockDim.x * CLUSTER_GRID_X;
    float clusterY = (float)gid.y / blockDim.y * CLUSTER_GRID_Y;
    
    int cx = (int)clusterX;
    int cy = (int)clusterY;
    int cz = 0; // Visualize first Z slice
    
    uint clusterIdx = cx + cy * CLUSTER_GRID_X + cz * CLUSTER_GRID_X * CLUSTER_GRID_Y;
    uint lightCount = clusterData[clusterIdx * MAX_LIGHTS_PER_CLUSTER];
    
    // Color code by light count
    float intensity = (float)lightCount / MAX_LIGHTS_PER_CLUSTER;
    float3 color;
    
    if (lightCount == 0) {
        color = float3(0.0, 0.0, 0.0); // Black = no lights
    } else if (lightCount < 10) {
        color = float3(0.0, intensity, 0.0); // Green = few lights
    } else if (lightCount < 30) {
        color = float3(intensity, intensity, 0.0); // Yellow = medium
    } else {
        color = float3(intensity, 0.0, 0.0); // Red = many lights
    }
    
    outputTex.write(float4(color, 1.0), gid);
}

// MARK: - Cluster Frustum Culling
kernel void cluster_cull_lights(
    const device Light* lights [[buffer(0)]],
    device uint* visibleLights [[buffer(1)]],
    constant float4x4& viewProj [[buffer(2)]],
    device atomic_uint* lightCounter [[buffer(3)]],
    
    uint gid [[thread_index_in_grid]])
{
    if (gid >= MAX_TOTAL_LIGHTS) {
        return;
    }
    
    Light light = lights[gid];
    
    // Extract frustum planes from viewProj
    // (simplified - would normally cache these)
    
    // Test light sphere against frustum
    float3 center = light.position;
    float radius = light.radius;
    
    // Quick reject test
    // (full implementation would test all 6 planes)
    
    bool visible = true;
    
    if (visible) {
        uint idx = atomic_fetch_add_explicit(lightCounter, 1, memory_order_relaxed);
        if (idx < MAX_TOTAL_LIGHTS) {
            visibleLights[idx] = gid;
        }
    }
}

// MARK: - Cluster Sorting (for better cache coherence)
kernel void cluster_sort_lights(
    device uint* clusterData [[buffer(0)]],
    device uint* sortedData [[buffer(1)]],
    
    uint3 gid [[thread_position_in_grid]])
{
    if (gid.x >= CLUSTER_GRID_X || gid.y >= CLUSTER_GRID_Y || gid.z >= CLUSTER_GRID_Z) {
        return;
    }
    
    uint clusterIdx = gid.x + gid.y * CLUSTER_GRID_X + gid.z * CLUSTER_GRID_X * CLUSTER_GRID_Z;
    
    uint lightCount = clusterData[clusterIdx * MAX_LIGHTS_PER_CLUSTER];
    
    // Copy lights to sorted buffer
    for (uint i = 0; i < lightCount; i++) {
        sortedData[clusterIdx * MAX_LIGHTS_PER_CLUSTER + i] = 
            clusterData[clusterIdx * MAX_LIGHTS_PER_CLUSTER + i + 1];
    }
    
    // Could add sorting by distance/type here for better performance
}
