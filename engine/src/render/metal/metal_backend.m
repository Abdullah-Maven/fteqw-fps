/*
 * Metal Backend for FTEQW Engine
 * Optimized for Apple Silicon (M1/M2/M3)
 * Forward+ Rendering with Clustered Lighting
 * 
 * Author: FTEQW Development Team
 * License: GPL-2.0
 */

#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#include "../render_common.h"
#include "../../common.h"

// MARK: - Metal Device Manager
typedef struct {
    id<MTLDevice> device;
    id<MTLCommandQueue> commandQueue;
    id<MTLLibrary> shaderLibrary;
    CVDisplayLinkRef displayLink;
    NSUInteger frameIndex;
    double frameTime;
    int width, height;
    bool vsync;
    bool hdr;
} metal_context_t;

static metal_context_t g_metal_ctx;

// MARK: - Buffer Management
typedef struct {
    id<MTLBuffer> vertexBuffer;
    id<MTLBuffer> indexBuffer;
    id<MTLBuffer> uniformBuffer;
    id<MTLBuffer> lightBuffer;
    id<MTLBuffer> clusterBuffer;
    size_t vertexSize;
    size_t indexSize;
    size_t uniformSize;
    size_t lightCount;
    size_t clusterCount;
} metal_buffers_t;

static metal_buffers_t g_buffers;

// MARK: - Pipeline States
typedef struct {
    id<MTLRenderPipelineState> forwardPipeline;
    id<MTLRenderPipelineState> waterPipeline;
    id<MTLRenderPipelineState> spritePipeline;
    id<MTLRenderPipelineState> skyPipeline;
    id<MTLComputePipelineState> lightClusterPipeline;
    id<MTLComputePipelineState> ssrPipeline;
    id<MTLComputePipelineState> fsrPipeline;
    id<MTLDepthStencilState> depthState;
    id<MTLDepthStencilState> depthNoWriteState;
} metal_pipelines_t;

static metal_pipelines_t g_pipelines;

// MARK: - Texture Management
#define MAX_METAL_TEXTURES 4096
typedef struct {
    id<MTLTexture> texture;
    id<MTLSamplerState> sampler;
    char name[256];
    int width, height;
    bool isRenderTarget;
    bool hasMipmaps;
} metal_texture_t;

static metal_texture_t g_textures[MAX_METAL_TEXTURES];
static int g_textureCount = 0;

// MARK: - Forward+ Clustering Constants
#define MAX_LIGHTS_PER_CLUSTER 64
#define MAX_TOTAL_LIGHTS 2048
#define CLUSTER_GRID_X 16
#define CLUSTER_GRID_Y 16
#define CLUSTER_GRID_Z 16

typedef struct {
    vector3f position;
    float radius;
    vector3f color;
    float intensity;
    vector3f direction;
    float spotAngle;
    int type; // 0=point, 1=spot, 2=directional
    float pad;
} metal_light_t;

typedef struct {
    matrix4x4 viewProj;
    matrix4x4 invViewProj;
    vector3f cameraPos;
    float deltaTime;
    vector4f clusters[CLUSTER_GRID_X * CLUSTER_GRID_Y * CLUSTER_GRID_Z];
    int lightCount;
    int clusterCount;
    int frameIndex;
    int resolutionScale;
} metal_uniforms_t;

// MARK: - Initialization
qboolean Metal_Init(void *wnd, int width, int height) {
    Con_Printf("Metal_Init: Initializing Metal backend for Apple Silicon\n");
    
    // Get default Metal device
    g_metal_ctx.device = MTLCreateSystemDefaultDevice();
    if (!g_metal_ctx.device) {
        Con_Printf("Metal_Init: ERROR - No Metal device found\n");
        return false;
    }
    
    Con_Printf("Metal_Init: Device name: %s\n", [g_metal_ctx.device.name UTF8String]);
    Con_Printf("Metal_Init: Low power: %s\n", g_metal_ctx.device.lowPower ? "yes" : "no");
    Con_Printf("Metal_Init: Headless: %s\n", g_metal_ctx.device.headless ? "yes" : "no");
    
    // Create command queue
    NSError *error = nil;
    g_metal_ctx.commandQueue = [g_metal_ctx.device newCommandQueue];
    if (!g_metal_ctx.commandQueue) {
        Con_Printf("Metal_Init: ERROR - Failed to create command queue\n");
        return false;
    }
    
    // Load shader library from bundled .metallib
    NSString *path = [[NSBundle mainBundle] pathForResource:"default" ofType:"metallib"];
    if (path) {
        NSURL *url = [NSURL fileURLWithPath:path];
        NSData *data = [NSData dataWithContentsOfURL:url];
        g_metal_ctx.shaderLibrary = [g_metal_ctx.device newLibraryWithData:data error:&error];
        if (!g_metal_ctx.shaderLibrary) {
            Con_Printf("Metal_Init: WARNING - Could not load metallib: %s\n", [[error localizedDescription] UTF8String]);
        }
    }
    
    // Initialize context
    g_metal_ctx.width = width;
    g_metal_ctx.height = height;
    g_metal_ctx.vsync = true;
    g_metal_ctx.hdr = true;
    g_metal_ctx.frameIndex = 0;
    
    // Allocate buffers (triple buffered)
    const size_t uniformSize = sizeof(metal_uniforms_t);
    const size_t lightSize = sizeof(metal_light_t) * MAX_TOTAL_LIGHTS;
    const size_t clusterSize = sizeof(uint32_t) * CLUSTER_GRID_X * CLUSTER_GRID_Y * CLUSTER_GRID_Z * MAX_LIGHTS_PER_CLUSTER;
    
    g_buffers.uniformSize = uniformSize;
    g_buffers.lightCount = MAX_TOTAL_LIGHTS;
    g_buffers.clusterCount = CLUSTER_GRID_X * CLUSTER_GRID_Y * CLUSTER_GRID_Z;
    
    g_buffers.uniformBuffer = [g_metal_ctx.device newBufferWithLength:uniformSize * 3
                                                              options:MTLResourceStorageModeShared];
    g_buffers.lightBuffer = [g_metal_ctx.device newBufferWithLength:lightSize
                                                            options:MTLResourceStorageModeShared];
    g_buffers.clusterBuffer = [g_metal_ctx.device newBufferWithLength:clusterSize
                                                              options:MTLResourceStorageModePrivate];
    
    Con_Printf("Metal_Init: Buffers allocated (%zu KB uniforms, %zu KB lights)\n", 
               uniformSize * 3 / 1024, lightSize / 1024);
    
    // Create pipelines (implemented in separate file)
    Metal_CreatePipelines();
    
    // Create depth stencil states
    MTLDepthStencilDescriptor *depthDesc = [[MTLDepthStencilDescriptor alloc] init];
    depthDesc.depthCompareFunction = MTLCompareFunctionLess;
    depthDesc.depthWriteEnabled = YES;
    g_pipelines.depthState = [g_metal_ctx.device newDepthStencilStateWithDescriptor:depthDesc];
    
    MTLDepthStencilDescriptor *depthNoWriteDesc = [[MTLDepthStencilDescriptor alloc] init];
    depthNoWriteDesc.depthCompareFunction = MTLCompareFunctionLess;
    depthNoWriteDesc.depthWriteEnabled = NO;
    g_pipelines.depthNoWriteState = [g_metal_ctx.device newDepthStencilStateWithDescriptor:depthNoWriteDesc];
    
    Con_Printf("Metal_Init: Successfully initialized\n");
    return true;
}

void Metal_Shutdown(void) {
    Con_Printf("Metal_Shutdown: Cleaning up Metal resources\n");
    
    // Release all resources
    for (int i = 0; i < g_textureCount; i++) {
        if (g_textures[i].texture) {
            [g_textures[i].texture release];
        }
        if (g_textures[i].sampler) {
            [g_textures[i].sampler release];
        }
    }
    
    [g_buffers.vertexBuffer release];
    [g_buffers.indexBuffer release];
    [g_buffers.uniformBuffer release];
    [g_buffers.lightBuffer release];
    [g_buffers.clusterBuffer release];
    
    [g_pipelines.forwardPipeline release];
    [g_pipelines.waterPipeline release];
    [g_pipelines.spritePipeline release];
    [g_pipelines.skyPipeline release];
    [g_pipelines.lightClusterPipeline release];
    [g_pipelines.ssrPipeline release];
    [g_pipelines.fsrPipeline release];
    [g_pipelines.depthState release];
    [g_pipelines.depthNoWriteState release];
    
    [g_metal_ctx.shaderLibrary release];
    [g_metal_ctx.commandQueue release];
    [g_metal_ctx.device release];
    
    memset(&g_metal_ctx, 0, sizeof(g_metal_ctx));
    memset(&g_buffers, 0, sizeof(g_buffers));
    memset(&g_pipelines, 0, sizeof(g_pipelines));
    g_textureCount = 0;
}

// MARK: - Texture Upload
int Metal_UploadTexture(const byte *data, int width, int height, const char *name, qboolean mipmap) {
    if (g_textureCount >= MAX_METAL_TEXTURES) {
        Con_Printf("Metal_UploadTexture: ERROR - Texture limit reached\n");
        return -1;
    }
    
    metal_texture_t *tex = &g_textures[g_textureCount];
    
    // Create texture descriptor
    MTLTextureDescriptor *desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                                                   width:(NSUInteger)width
                                                                                  height:(NSUInteger)height
                                                                               mipmapped:mipmap];
    desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
    if (mipmap) {
        desc.usage |= MTLTextureUsageRenderTarget;
    }
    
    // Create texture
    tex->texture = [g_metal_ctx.device newTextureWithDescriptor:desc];
    if (!tex->texture) {
        Con_Printf("Metal_UploadTexture: ERROR - Failed to create texture\n");
        return -1;
    }
    
    // Upload data
    MTLRegion region = MTLRegionMake2D(0, 0, (NSUInteger)width, (NSUInteger)height);
    [tex->texture replaceRegion:region
                  mipmapLevel:0
                    withBytes:data
                  bytesPerRow:(NSUInteger)(width * 4)];
    
    // Generate mipmaps if requested
    if (mipmap) {
        // Mipmap generation would be done via compute shader or CPU
        // For now, skip for performance
    }
    
    // Create sampler
    MTLSamplerDescriptor *samplerDesc = [[MTLSamplerDescriptor alloc] init];
    samplerDesc.minFilter = mipmap ? MTLSamplerMinMagFilterLinearMipmapLinear : MTLSamplerMinMagFilterLinear;
    samplerDesc.magFilter = mipmap ? MTLSamplerMinMagFilterLinearMipmapLinear : MTLSamplerMinMagFilterLinear;
    samplerDesc.mipFilter = mipmap ? MTLSamplerMipFilterLinear : MTLSamplerMipFilterNotMipmapped;
    samplerDesc.sAddressMode = MTLSamplerAddressModeRepeat;
    samplerDesc.tAddressMode = MTLSamplerAddressModeRepeat;
    samplerDesc.maxAnisotropy = 16;
    tex->sampler = [g_metal_ctx.device newSamplerStateWithDescriptor:samplerDesc];
    
    strncpy(tex->name, name, sizeof(tex->name) - 1);
    tex->width = width;
    tex->height = height;
    tex->isRenderTarget = false;
    tex->hasMipmaps = mipmap;
    
    int texId = g_textureCount++;
    Con_DPrintf("Metal_UploadTexture: Created texture '%s' (%dx%d, mipmap=%s)\n", 
                name, width, height, mipmap ? "yes" : "no");
    
    return texId;
}

// MARK: - Render Target Creation
int Metal_CreateRenderTarget(const char *name, int width, int height, qboolean depth) {
    if (g_textureCount >= MAX_METAL_TEXTURES) {
        return -1;
    }
    
    metal_texture_t *tex = &g_textures[g_textureCount];
    
    MTLTextureDescriptor *desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA16Float
                                                                                   width:(NSUInteger)width
                                                                                  height:(NSUInteger)height
                                                                               mipmapped:NO];
    desc.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite | MTLTextureUsageRenderTarget;
    desc.storageMode = MTLStorageModePrivate; // Tile-based on M3
    
    tex->texture = [g_metal_ctx.device newTextureWithDescriptor:desc];
    if (!tex->texture) {
        return -1;
    }
    
    strncpy(tex->name, name, sizeof(tex->name) - 1);
    tex->width = width;
    tex->height = height;
    tex->isRenderTarget = true;
    tex->hasMipmaps = false;
    
    return g_textureCount++;
}

// MARK: - Render Begin/End
void Metal_BeginFrame(int width, int height) {
    g_metal_ctx.width = width;
    g_metal_ctx.height = height;
    g_metal_ctx.frameIndex = (g_metal_ctx.frameIndex + 1) % 3;
}

void Metal_EndFrame(void *drawable) {
    id<CAMetalDrawable> metalDrawable = (__bridge id<CAMetalDrawable>)drawable;
    
    id<MTLCommandBuffer> cmdBuffer = [g_metal_ctx.commandQueue commandBuffer];
    cmdBuffer.label = @"Frame";
    
    MTLRenderPassDescriptor *passDesc = [MTLRenderPassDescriptor renderPassDescriptor];
    passDesc.colorAttachments[0].texture = metalDrawable.texture;
    passDesc.colorAttachments[0].loadAction = MTLLoadActionClear;
    passDesc.colorAttachments[0].storeAction = MTLStoreActionStore;
    passDesc.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
    
    if (g_metal_ctx.hdr) {
        passDesc.colorAttachments[0].texture = g_textures[0].texture; // HDR buffer
        passDesc.colorAttachments[0].storeAction = MTLStoreActionStore;
    }
    
    id<MTLRenderCommandEncoder> encoder = [cmdBuffer renderCommandEncoderWithDescriptor:passDesc];
    encoder.label = @"MainPass";
    
    // Set viewport
    [encoder setViewport:(MTLViewport){0.0, 0.0, (double)g_metal_ctx.width, (double)g_metal_ctx.height, 0.0, 1.0}];
    
    // Render scene (called from main renderer)
    // Metal_RenderScene(encoder);
    
    [encoder endEncoding];
    
    [cmdBuffer presentDrawable:metalDrawable];
    [cmdBuffer commit];
    
    if (g_metal_ctx.vsync) {
        [cmdBuffer waitUntilCompleted];
    }
}

// MARK: - Light Clustering (Compute Shader)
void Metal_ComputeLightClusters(const matrix4x4 viewProj, const vector3f cameraPos, metal_light_t *lights, int lightCount) {
    id<MTLCommandBuffer> cmdBuffer = [g_metal_ctx.commandQueue commandBuffer];
    cmdBuffer.label = @"LightClustering";
    
    id<MTLComputeCommandEncoder> encoder = [cmdBuffer computeCommandEncoderWithBuffer:cmdBuffer];
    encoder.label = @"ClusterCompute";
    
    [encoder setComputePipelineState:g_pipelines.lightClusterPipeline];
    
    // Update uniforms
    metal_uniforms_t *uniforms = (metal_uniforms_t *)[g_buffers.uniformBuffer contents];
    uniforms->viewProj = *(matrix4x4*)viewProj.m;
    Matrix4x4_Invert_Simple(&uniforms->invViewProj, &uniforms->viewProj);
    uniforms->cameraPos = cameraPos;
    uniforms->lightCount = lightCount;
    uniforms->clusterCount = CLUSTER_GRID_X * CLUSTER_GRID_Y * CLUSTER_GRID_Z;
    uniforms->frameIndex = g_metal_ctx.frameIndex;
    
    // Upload lights
    memcpy([g_buffers.lightBuffer contents], lights, sizeof(metal_light_t) * lightCount);
    
    [encoder setBuffer:g_buffers.lightBuffer offset:0 atIndex:0];
    [encoder setBuffer:g_buffers.clusterBuffer offset:0 atIndex:1];
    [encoder setBuffer:g_buffers.uniformBuffer offset:g_buffers.uniformSize * g_metal_ctx.frameIndex atIndex:2];
    
    MTLSize threadGroupSize = MTLSizeMake(8, 8, 1);
    MTLSize threadGroups = MTLSizeMake(CLUSTER_GRID_X / 8, CLUSTER_GRID_Y / 8, CLUSTER_GRID_Z);
    
    [encoder dispatchThreadgroups:threadGroups threadsPerThreadgroup:threadGroupSize];
    [encoder endEncoding];
    
    [cmdBuffer commit];
}

// MARK: - Screen Space Reflections
void Metal_RenderSSR(id<MTLRenderCommandEncoder> encoder, int colorTex, int depthTex, int normalTex, float roughness) {
    [encoder setComputePipelineState:g_pipelines.ssrPipeline];
    
    // SSR parameters
    [encoder setFloat:roughness forKey:@"roughness"];
    [encoder setFloat:0.5f forKey:@"stepSize"]; // Dynamic based on performance
    [encoder setInt:8 forKey:@"maxSteps"];
    
    // Bind textures
    [encoder setTexture:g_textures[colorTex].texture atIndex:0];
    [encoder setTexture:g_textures[depthTex].texture atIndex:1];
    [encoder setTexture:g_textures[normalTex].texture atIndex:2];
    
    // Dispatch
    MTLSize threadGroupSize = MTLSizeMake(16, 16, 1);
    MTLSize threadGroups = MTLSizeMake((g_metal_ctx.width + 15) / 16, (g_metal_ctx.height + 15) / 16, 1);
    
    [encoder dispatchThreadgroups:threadGroups threadsPerThreadgroup:threadGroupSize];
}

// MARK: - FSR Upscaling
void Metal_ApplyFSR(id<MTLRenderCommandEncoder> encoder, int inputTex, int outputTex, float sharpness) {
    [encoder setComputePipelineState:g_pipelines.fsrPipeline];
    
    [encoder setFloat:sharpness forKey:@"sharpness"];
    [encoder setFloat:1.0f / g_metal_ctx.width forKey:@"inputPixelSize"];
    [encoder setFloat:1.0f / g_metal_ctx.height forKey:@"inputPixelSizeY"];
    
    // Bind textures
    [encoder setTexture:g_textures[inputTex].texture atIndex:0];
    [encoder setTexture:g_textures[outputTex].texture atIndex:1];
    
    // Dispatch
    MTLSize threadGroupSize = MTLSizeMake(16, 16, 1);
    MTLSize threadGroups = MTLSizeMake((g_metal_ctx.width + 15) / 16, (g_metal_ctx.height + 15) / 16, 1);
    
    [encoder dispatchThreadgroups:threadGroups threadsPerThreadgroup:threadGroupSize];
}

// MARK: - Dynamic Resolution Scaling
static float g_dynamicResScale = 1.0f;
static float g_targetFPS = 120.0f;
static float g_currentFPS = 120.0f;

void Metal_UpdateDynamicResolution(float frameTime) {
    g_currentFPS = 1.0f / frameTime;
    
    if (g_currentFPS < g_targetFPS - 5.0f) {
        // Too slow, reduce resolution
        g_dynamicResScale = fmax(0.5f, g_dynamicResScale - 0.05f);
    } else if (g_currentFPS > g_targetFPS + 10.0f && g_dynamicResScale < 1.0f) {
        // Too fast, increase resolution
        g_dynamicResScale = fmin(1.0f, g_dynamicResScale + 0.05f);
    }
    
    // Update uniform
    metal_uniforms_t *uniforms = (metal_uniforms_t *)[g_buffers.uniformBuffer contents];
    uniforms->resolutionScale = (int)(g_dynamicResScale * 100.0f);
}

float Metal_GetDynamicResolutionScale(void) {
    return g_dynamicResScale;
}

void Metal_SetTargetFPS(float fps) {
    g_targetFPS = fps;
}

// MARK: - Pipeline Creation (Forward+)
void Metal_CreatePipelines(void) {
    Con_Printf("Metal_CreatePipelines: Creating Forward+ render pipelines\n");
    
    // Load shader functions from library
    id<MTLFunction> forwardVert = nil;
    id<MTLFunction> forwardFrag = nil;
    id<MTLFunction> waterFrag = nil;
    id<MTLFunction> spriteFrag = nil;
    id<MTLFunction> clusterCompute = nil;
    id<MTLFunction> ssrCompute = nil;
    id<MTLFunction> fsrCompute = nil;
    
    if (g_metal_ctx.shaderLibrary) {
        forwardVert = [g_metal_ctx.shaderLibrary newFunctionWithName:@"forward_vertex_main"];
        forwardFrag = [g_metal_ctx.shaderLibrary newFunctionWithName:@"forward_fragment_main"];
        waterFrag = [g_metal_ctx.shaderLibrary newFunctionWithName:@"water_fragment_main"];
        spriteFrag = [g_metal_ctx.shaderLibrary newFunctionWithName:@"sprite_fragment_main"];
        clusterCompute = [g_metal_ctx.shaderLibrary newFunctionWithName:@"cluster_lighting_compute"];
        ssrCompute = [g_metal_ctx.shaderLibrary newFunctionWithName:@"ssr_compute"];
        fsrCompute = [g_metal_ctx.shaderLibrary newFunctionWithName:@"fsr_upscale_compute"];
    }
    
    // Create forward rendering pipeline
    MTLVertexDescriptor *vertexDesc = [MTLVertexDescriptor vertexDescriptor];
    vertexDesc.attributes[0].format = MTLVertexFormatFloat3;
    vertexDesc.attributes[0].offset = 0;
    vertexDesc.attributes[0].bufferIndex = 0;
    vertexDesc.attributes[1].format = MTLVertexFormatFloat2;
    vertexDesc.attributes[1].offset = sizeof(float) * 3;
    vertexDesc.attributes[1].bufferIndex = 0;
    vertexDesc.attributes[2].format = MTLVertexFormatFloat4;
    vertexDesc.attributes[2].offset = sizeof(float) * 5;
    vertexDesc.attributes[2].bufferIndex = 0;
    
    vertexDesc.layouts[0].stride = sizeof(float) * 9; // pos + texcoord + color/tangent
    
    MTLRenderPipelineDescriptor *forwardDesc = [[MTLRenderPipelineDescriptor alloc] init];
    forwardDesc.vertexFunction = forwardVert;
    forwardDesc.fragmentFunction = forwardFrag;
    forwardDesc.vertexDescriptor = vertexDesc;
    forwardDesc.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA16Float; // HDR
    forwardDesc.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    forwardDesc.sampleCount = 1;
    forwardDesc.rasterSampleCount = 1;
    
    // Enable blending for transparency
    forwardDesc.colorAttachments[0].blendingEnabled = YES;
    forwardDesc.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
    forwardDesc.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
    forwardDesc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
    forwardDesc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    forwardDesc.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorOne;
    forwardDesc.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorZero;
    
    NSError *error = nil;
    g_pipelines.forwardPipeline = [g_metal_ctx.device newRenderPipelineStateWithDescriptor:forwardDesc error:&error];
    if (!g_pipelines.forwardPipeline) {
        Con_Printf("Metal_CreatePipelines: WARNING - Forward pipeline failed: %s\n", [[error localizedDescription] UTF8String]);
    }
    
    // Water pipeline (with SSR)
    MTLRenderPipelineDescriptor *waterDesc = [[MTLRenderPipelineDescriptor alloc] init];
    waterDesc.vertexFunction = forwardVert;
    waterDesc.fragmentFunction = waterFrag;
    waterDesc.vertexDescriptor = vertexDesc;
    waterDesc.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA16Float;
    waterDesc.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    waterDesc.colorAttachments[0].blendingEnabled = YES;
    waterDesc.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
    waterDesc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
    waterDesc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    
    g_pipelines.waterPipeline = [g_metal_ctx.device newRenderPipelineStateWithDescriptor:waterDesc error:&error];
    
    // Sprite pipeline (additive blending)
    MTLRenderPipelineDescriptor *spriteDesc = [[MTLRenderPipelineDescriptor alloc] init];
    spriteDesc.vertexFunction = forwardVert;
    spriteDesc.fragmentFunction = spriteFrag;
    spriteDesc.vertexDescriptor = vertexDesc;
    spriteDesc.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA16Float;
    spriteDesc.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    spriteDesc.colorAttachments[0].blendingEnabled = YES;
    spriteDesc.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
    spriteDesc.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
    spriteDesc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorOne;
    spriteDesc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOne;
    spriteDesc.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorOne;
    spriteDesc.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOne;
    
    g_pipelines.spritePipeline = [g_metal_ctx.device newRenderPipelineStateWithDescriptor:spriteDesc error:&error];
    
    // Sky pipeline (no depth write, draws last)
    MTLRenderPipelineDescriptor *skyDesc = [[MTLRenderPipelineDescriptor alloc] init];
    skyDesc.vertexFunction = forwardVert;
    skyDesc.fragmentFunction = forwardFrag;
    skyDesc.vertexDescriptor = vertexDesc;
    skyDesc.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA16Float;
    skyDesc.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    skyDesc.depthAttachmentCompareFunction = MTLCompareFunctionLessEqual;
    
    g_pipelines.skyPipeline = [g_metal_ctx.device newRenderPipelineStateWithDescriptor:skyDesc error:&error];
    
    // Compute pipelines
    if (clusterCompute) {
        g_pipelines.lightClusterPipeline = [g_metal_ctx.device newComputePipelineStateWithFunction:clusterCompute error:&error];
    }
    if (ssrCompute) {
        g_pipelines.ssrPipeline = [g_metal_ctx.device newComputePipelineStateWithFunction:ssrCompute error:&error];
    }
    if (fsrCompute) {
        g_pipelines.fsrPipeline = [g_metal_ctx.device newComputePipelineStateWithFunction:fsrCompute error:&error];
    }
    
    Con_Printf("Metal_CreatePipelines: Pipelines created successfully\n");
}

// MARK: - Rendering Functions
void Metal_ClearRenderTarget(int texId, float r, float g, float b, float a) {
    if (texId < 0 || texId >= g_textureCount) return;
    
    id<MTLCommandBuffer> cmdBuffer = [g_metal_ctx.commandQueue commandBuffer];
    MTLRenderPassDescriptor *passDesc = [MTLRenderPassDescriptor renderPassDescriptor];
    passDesc.colorAttachments[0].texture = g_textures[texId].texture;
    passDesc.colorAttachments[0].loadAction = MTLLoadActionClear;
    passDesc.colorAttachments[0].clearColor = MTLClearColorMake(r, g, b, a);
    
    id<MTLRenderCommandEncoder> encoder = [cmdBuffer renderCommandEncoderWithDescriptor:passDesc];
    [encoder endEncoding];
    [cmdBuffer commit];
}

void Metal_DrawGeometry(const float *vertices, int vertexCount, const uint16_t *indices, int indexCount, 
                        int textureId, matrix4x4 modelViewProj, qboolean transparent) {
    id<MTLCommandBuffer> cmdBuffer = [g_metal_ctx.commandQueue commandBuffer];
    
    // Update vertex buffer
    if (!g_buffers.vertexBuffer || g_buffers.vertexSize < vertexCount * sizeof(float) * 9) {
        g_buffers.vertexSize = vertexCount * sizeof(float) * 9 * 2;
        g_buffers.vertexBuffer = [g_metal_ctx.device newBufferWithLength:g_buffers.vertexSize
                                                                 options:MTLResourceStorageModeShared];
    }
    memcpy([g_buffers.vertexBuffer contents], vertices, vertexCount * sizeof(float) * 9);
    
    // Update index buffer
    if (!g_buffers.indexBuffer || g_buffers.indexSize < indexCount * sizeof(uint16_t)) {
        g_buffers.indexSize = indexCount * sizeof(uint16_t) * 2;
        g_buffers.indexBuffer = [g_metal_ctx.device newBufferWithLength:g_buffers.indexSize
                                                                options:MTLResourceStorageModeShared];
    }
    memcpy([g_buffers.indexBuffer contents], indices, indexCount * sizeof(uint16_t));
    
    // Get pipeline
    id<MTLRenderPipelineState> pipeline = transparent ? g_pipelines.waterPipeline : g_pipelines.forwardPipeline;
    
    MTLRenderPassDescriptor *passDesc = [MTLRenderPassDescriptor renderPassDescriptor];
    passDesc.colorAttachments[0].texture = g_textures[0].texture; // HDR buffer
    passDesc.colorAttachments[0].loadAction = MTLLoadActionLoad;
    passDesc.colorAttachments[0].storeAction = MTLStoreActionStore;
    passDesc.depthAttachment.texture = g_textures[1].texture; // Depth buffer
    passDesc.depthAttachment.loadAction = MTLLoadActionLoad;
    passDesc.depthAttachment.storeAction = MTLStoreActionStore;
    
    id<MTLRenderCommandEncoder> encoder = [cmdBuffer renderCommandEncoderWithDescriptor:passDesc];
    [encoder setViewport:(MTLViewport){0.0, 0.0, (double)g_metal_ctx.width, (double)g_metal_ctx.height, 0.0, 1.0}];
    [encoder setRenderPipelineState:pipeline];
    [encoder setDepthStencilState:transparent ? g_pipelines.depthNoWriteState : g_pipelines.depthState];
    
    // Set uniforms
    [encoder setVertexBytes:&modelViewProj length:sizeof(matrix4x4) atIndex:1];
    
    [encoder setVertexBuffer:g_buffers.vertexBuffer offset:0 atIndex:0];
    [encoder setVertexBuffer:g_buffers.uniformBuffer offset:g_buffers.uniformSize * g_metal_ctx.frameIndex atIndex:2];
    
    if (textureId >= 0 && textureId < g_textureCount) {
        [encoder setFragmentTexture:g_textures[textureId].texture atIndex:0];
        [encoder setFragmentSamplerState:g_textures[textureId].sampler atIndex:0];
    }
    
    [encoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                        indexCount:indexCount
                         indexType:MTLIndexTypeUInt16
                       indexBuffer:g_buffers.indexBuffer
                 indexBufferOffset:0];
    
    [encoder endEncoding];
    [cmdBuffer commit];
}

// MARK: - Console Variables
cvar_t r_metal_debug = {"r_metal_debug", "0"};
cvar_t r_metal_wireframe = {"r_metal_wireframe", "0"};
cvar_t r_metal_hdr = {"r_metal_hdr", "1"};
cvar_t r_metal_vsync = {"r_metal_vsync", "1"};
cvar_t r_metal_dynamic_res = {"r_metal_dynamic_res", "1"};
cvar_t r_metal_target_fps = {"r_metal_target_fps", "120"};
cvar_t r_metal_ssr_quality = {"r_metal_ssr_quality", "1"};
cvar_t r_metal_fsr_sharpness = {"r_metal_fsr_sharpness", "0.5"};

void Metal_RegisterCvars(void) {
    Cvar_Register(&r_metal_debug);
    Cvar_Register(&r_metal_wireframe);
    Cvar_Register(&r_metal_hdr);
    Cvar_Register(&r_metal_vsync);
    Cvar_Register(&r_metal_dynamic_res);
    Cvar_Register(&r_metal_target_fps);
    Cvar_Register(&r_metal_ssr_quality);
    Cvar_Register(&r_metal_fsr_sharpness);
    
    g_metal_ctx.vsync = r_metal_vsync.value != 0;
    g_metal_ctx.hdr = r_metal_hdr.value != 0;
    g_targetFPS = r_metal_target_fps.value;
}

void Metal_UpdateCvars(void) {
    g_metal_ctx.vsync = r_metal_vsync.value != 0;
    g_metal_ctx.hdr = r_metal_hdr.value != 0;
    g_targetFPS = r_metal_target_fps.value;
}

// MARK: - Statistics
typedef struct {
    int drawCalls;
    int vertexCount;
    int indexCount;
    int textureBinds;
    int lightCount;
    int clusterCount;
    double gpuTime;
    double cpuTime;
} metal_stats_t;

static metal_stats_t g_stats;

void Metal_ResetStats(void) {
    memset(&g_stats, 0, sizeof(g_stats));
}

void Metal_GetStats(metal_stats_t *out) {
    *out = g_stats;
}

void Metal_PrintStats(void) {
    Con_Printf("Metal Statistics:\n");
    Con_Printf("  Draw Calls: %d\n", g_stats.drawCalls);
    Con_Printf("  Vertices: %d\n", g_stats.vertexCount);
    Con_Printf("  Indices: %d\n", g_stats.indexCount);
    Con_Printf("  Texture Binds: %d\n", g_stats.textureBinds);
    Con_Printf("  Lights: %d\n", g_stats.lightCount);
    Con_Printf("  Clusters: %d\n", g_stats.clusterCount);
    Con_Printf("  GPU Time: %.2f ms\n", g_stats.gpuTime);
    Con_Printf("  CPU Time: %.2f ms\n", g_stats.cpuTime);
    Con_Printf("  Dynamic Res: %.0f%%\n", g_dynamicResScale * 100.0f);
}