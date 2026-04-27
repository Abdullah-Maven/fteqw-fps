// Advanced Water Shader with Screen Space Reflections
// Target: Forward+ Renderer, Metal/GLSL 4.5
// Features: SSR @ 50% dynamic res, Refraction, Caustics, Absorption

#pragma version 450
#pragma option nv_unroll_all_funcs

// ============================================================================
// UNIFORM BUFFERS
// ============================================================================

layout(std140, binding = 0) uniform WaterParams {
    mat4 modelMatrix;
    mat4 viewMatrix;
    mat4 projMatrix;
    vec4 waterColor;          // RGB + absorption coefficient
    vec4 waterDepth;          // Min/Max depth for fog
    vec4 causticsScale;       // Scale + speed for caustics animation
    vec4 normalMapScale;      // UV scale + scroll speed
    float roughness;
    float fresnelPower;
    float ssrQuality;         // 0.5 = half res, 1.0 = full
    int ssrSteps;
} waterParams;

layout(std140, binding = 1) uniform LightBuffer {
    vec4 position;            // xyz = pos, w = type
    vec4 color;               // RGB + intensity
    vec4 direction;           // For spot lights
    vec4 attenuation;         // const, linear, quad, cutoff
} lights[64];

uniform sampler2D texNormal0;     // Water normal map frame 0
uniform sampler2D texNormal1;     // Water normal map frame 1
uniform sampler2D texCaustics0;   // Caustics texture frame 0
uniform sampler2D texCaustics1;   // Caustics texture frame 1
uniform sampler2D texScreenColor; // Screen color buffer
uniform sampler2D texScreenDepth; // Screen depth buffer
uniform sampler2D texSkybox;      // Environment cubemap

// ============================================================================
// INPUT/OUTPUT
// ============================================================================

layout(location = 0) in vec3 inWorldPos;
layout(location = 1) in vec3 inWorldNormal;
layout(location = 2) in vec2 inTexCoord;
layout(location = 3) in vec3 inViewDir;

layout(location = 0) out vec4 outColor;

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

// Reconstruct world position from screen-space UV and depth
vec3 ReconstructWorldPos(vec2 screenUV, float depth) {
    vec4 clipPos = vec4(screenUV * 2.0 - 1.0, depth, 1.0);
    vec4 viewPos = inverse(waterParams.projMatrix) * clipPos;
    viewPos /= viewPos.w;
    return (inverse(waterParams.viewMatrix) * vec4(viewPos.xyz, 1.0)).xyz;
}

// Get scene depth at screen position
float GetSceneDepth(vec2 screenUV) {
    return texture(texScreenDepth, screenUV).r;
}

// Fresnel-Schlick approximation
float FresnelSchlick(float cosTheta, float F0, float power) {
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, power);
}

// ============================================================================
// SCREEN SPACE REFLECTIONS
// ============================================================================

vec4 ScreenSpaceReflections(vec3 worldPos, vec3 normal, vec3 viewDir, float roughness) {
    vec3 reflectDir = reflect(-viewDir, normal);
    vec3 rayDir = normalize(reflectDir);
    
    // Project starting position to screen space
    vec4 startClip = waterParams.projMatrix * waterParams.viewMatrix * vec4(worldPos, 1.0);
    startClip /= startClip.w;
    vec2 startUV = startClip.xy * 0.5 + 0.5;
    
    // Early out if outside screen
    if (startUV.x < 0.0 || startUV.x > 1.0 || startUV.y < 0.0 || startUV.y > 1.0) {
        return vec4(0.0);
    }
    
    // Dynamic resolution for SSR
    float quality = waterParams.ssrQuality;
    ivec2 screenSize = textureSize(texScreenColor, 0);
    ivec2 ssrRes = ivec2(screenSize * quality);
    
    int steps = waterParams.ssrSteps;
    float stepSize = 0.02 / quality;
    float thickness = 0.01;
    
    vec3 currentPos = worldPos;
    float currentDepth = startClip.z;
    
    // Ray marching
    for (int i = 0; i < steps; i++) {
        currentPos += rayDir * stepSize;
        
        // Project to screen space
        vec4 clipPos = waterParams.projMatrix * waterParams.viewMatrix * vec4(currentPos, 1.0);
        clipPos /= clipPos.w;
        vec2 screenUV = clipPos.xy * 0.5 + 0.5;
        
        // Check bounds
        if (screenUV.x < 0.0 || screenUV.x > 1.0 || 
            screenUV.y < 0.0 || screenUV.y > 1.0) {
            break;
        }
        
        // Get scene depth at this position
        float sceneDepth = GetSceneDepth(screenUV);
        float rayDepth = clipPos.z;
        
        // Hit detection with thickness tolerance
        if (abs(rayDepth - sceneDepth) < thickness) {
            // Binary search refinement
            float refineStep = stepSize * 0.5;
            for (int j = 0; j < 4; j++) {
                refineStep *= 0.5;
                vec3 refinedPos = currentPos - rayDir * refineStep;
                vec4 refinedClip = waterParams.projMatrix * waterParams.viewMatrix * vec4(refinedPos, 1.0);
                refinedClip /= refinedClip.w;
                vec2 refinedUV = refinedClip.xy * 0.5 + 0.5;
                
                float refinedSceneDepth = GetSceneDepth(refinedUV);
                if (refinedClip.z > refinedSceneDepth) {
                    currentPos = refinedPos;
                }
            }
            
            // Sample reflected color
            vec2 finalUV = currentPos.xy;
            vec3 reflectedColor = texture(texScreenColor, finalUV).rgb;
            
            // Apply roughness blur (simple box filter for performance)
            if (roughness > 0.1) {
                float blurAmount = roughness * 0.02;
                vec3 blurSum = reflectedColor;
                blurSum += texture(texScreenColor, finalUV + vec2(blurAmount, 0.0)).rgb;
                blurSum += texture(texScreenColor, finalUV - vec2(blurAmount, 0.0)).rgb;
                blurSum += texture(texScreenColor, finalUV + vec2(0.0, blurAmount)).rgb;
                blurSum += texture(texScreenColor, finalUV - vec2(0.0, blurAmount)).rgb;
                reflectedColor = blurSum * 0.2;
            }
            
            // Fade at grazing angles and screen edges
            float edgeFade = 1.0 - smoothstep(0.0, 0.1, min(min(finalUV.x, 1.0-finalUV.x), 
                                                             min(finalUV.y, 1.0-finalUV.y)));
            float fresnelTerm = FresnelSchlick(abs(dot(viewDir, normal)), 0.02, waterParams.fresnelPower);
            
            return vec4(reflectedColor * fresnelTerm * edgeFade, 1.0);
        }
    }
    
    // No hit - fallback to skybox
    vec3 skyColor = texture(texSkybox, reflectDir).rgb;
    return vec4(skyColor * 0.3, 1.0); // Dimmed fallback
}

// ============================================================================
// WATER NORMAL CALCULATION
// ============================================================================

vec3 CalculateWaterNormal(vec2 uv, float time) {
    // Animated dual normal maps
    vec2 scroll0 = uv * waterParams.normalMapScale.xy + 
                   vec2(sin(time * waterParams.normalMapScale.z), 
                        cos(time * waterParams.normalMapScale.w)) * 0.1;
    vec2 scroll1 = uv * waterParams.normalMapScale.xy + 
                   vec2(cos(time * waterParams.normalMapScale.z * 0.7), 
                        sin(time * waterParams.normalMapScale.w * 0.8)) * 0.15;
    
    vec3 normal0 = texture(texNormal0, scroll0).rgb * 2.0 - 1.0;
    vec3 normal1 = texture(texNormal1, scroll1).rgb * 2.0 - 1.0;
    
    // Blend normals
    vec3 blendedNormal = normalize(normal0 + normal1);
    
    // Add large waves using sine function
    float wave = sin(uv.x * 10.0 + time) * cos(uv.y * 8.0 + time * 0.7) * 0.1;
    blendedNormal.z += wave;
    
    return normalize(blendedNormal);
}

// ============================================================================
// CAUSTICS CALCULATION
// ============================================================================

vec3 CalculateCaustics(vec3 worldPos, float time) {
    vec2 causticsUV = worldPos.xz * waterParams.causticsScale.xy;
    
    // Animated dual caustics textures
    vec2 scroll0 = causticsUV + vec2(time * waterParams.causticsScale.z, 0.0);
    vec2 scroll1 = causticsUV + vec2(0.0, time * waterParams.causticsScale.w);
    
    float caustic0 = texture(texCaustics0, scroll0).r;
    float caustic1 = texture(texCaustics1, scroll1).r;
    
    // Combine caustics
    float caustics = (caustic0 + caustic1) * 0.5;
    caustics = pow(caustics, 2.0) * 1.5; // Enhance contrast
    
    return vec3(caustics) * waterParams.waterColor.rgb;
}

// ============================================================================
// ABSORPTION & SCATTERING
// ============================================================================

vec3 CalculateAbsorption(float depth, vec3 baseColor) {
    // Beer-Lambert law for light absorption
    float absorptionCoeff = waterParams.waterColor.a;
    float scatterCoeff = 0.1;
    
    float absorption = exp(-(absorptionCoeff + scatterCoeff) * depth);
    return baseColor * absorption;
}

// ============================================================================
// MAIN SHADER
// ============================================================================

void main() {
    float time = waterParams.causticsScale.z; // Use as time proxy
    
    // Calculate animated water normal
    vec3 waterNormal = CalculateWaterNormal(inTexCoord, time);
    
    // View direction
    vec3 viewDir = normalize(inViewDir);
    
    // Base water color
    vec3 baseColor = waterParams.waterColor.rgb;
    
    // Calculate depth for absorption
    float depth = length(inWorldPos - (waterParams.viewMatrix * vec4(0,0,0,1)).xyz);
    depth = clamp((depth - waterParams.waterDepth.x) / 
                  (waterParams.waterDepth.y - waterParams.waterDepth.x), 0.0, 1.0);
    
    // Absorption
    vec3 absorbedColor = CalculateAbsorption(depth, baseColor);
    
    // Screen Space Reflections
    vec4 ssrResult = ScreenSpaceReflections(inWorldPos, waterNormal, viewDir, waterParams.roughness);
    
    // Caustics
    vec3 caustics = CalculateCaustics(inWorldPos, time);
    
    // Refraction (simple offset based on normal)
    vec4 clipPos = waterParams.projMatrix * waterParams.viewMatrix * vec4(inWorldPos, 1.0);
    vec2 refractionUV = clipPos.xy / clipPos.w * 0.5 + 0.5;
    refractionUV += waterNormal.xy * 0.02; // Normal-based offset
    
    vec3 refractedColor = texture(texScreenColor, refractionUV).rgb;
    
    // Fresnel blend between reflection and refraction
    float fresnel = FresnelSchlick(abs(dot(viewDir, waterNormal)), 0.02, waterParams.fresnelPower);
    
    // Final composition
    vec3 finalColor = mix(refractedColor, ssrResult.rgb, fresnel);
    finalColor += caustics * 0.3; // Add caustics
    finalColor = mix(finalColor, absorbedColor, depth * 0.5); // Depth fog
    
    // Additive foam at edges (optional)
    float foam = smoothstep(0.95, 1.0, fresnel);
    finalColor += vec3(0.8) * foam * 0.5;
    
    outColor = vec4(finalColor, 0.95); // Slight transparency for sorting
}

// ============================================================================
// METAL EQUIVALENT NOTES
// ============================================================================
/*
Metal Implementation Differences:
- Use [[stage_in]] for inputs
- Use [[buffer(N)]] for uniform buffers
- Use threadgroup for shared memory in compute shaders
- Use simd functions for efficient reduction
- Texture sampling: texture.sample(sampler, coord)
- Use half precision where possible for M3 performance

Example Metal signature:
struct VertexOut {
    float4 position [[position]];
    float3 worldPos;
    float3 worldNormal;
    float2 texCoord;
    float3 viewDir;
};

fragment float4 waterFragment(VertexOut in [[stage_in]],
                              constant WaterParams &params [[buffer(0)]],
                              texture2d<float> texScreenColor,
                              sampler texSampler) {
    // Same logic as GLSL above
}
*/
