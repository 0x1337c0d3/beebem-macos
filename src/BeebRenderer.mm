/****************************************************************
BeebEm - BBC Micro and Master 128 Emulator
BeebRenderer — Metal rendering pipeline.

Each frame:
  1. CPU-expand m_screen (8-bit indexed) through palette → BGRA staging buf
  2. Upload to MTLTexture via replaceRegion:
  3. Render full-screen textured quad using Shaders.metal
****************************************************************/

#import "BeebRenderer.h"
#import "macos/MacPlatform.h"

#define SCREEN_W BEEBEM_VIDEO_CORE_SCREEN_WIDTH   // 800
#define SCREEN_H 512                               // display-active lines

// Palette shared with MacPlatform.mm.
// 256 BGRA entries; index 0–7 are the BBC colours, rest are LED/menu colours.
extern uint32_t g_paletteBGRA[256];

// The 8-bit indexed video buffer exposed by MacPlatform.mm
extern uint8_t g_videoBuffer[BEEBEM_VIDEO_CORE_SCREEN_WIDTH * BEEBEM_VIDEO_CORE_SCREEN_HEIGHT];

@implementation BeebRenderer
{
    id<MTLDevice>              _device;
    id<MTLCommandQueue>        _commandQueue;
    id<MTLRenderPipelineState> _pipeline;
    id<MTLTexture>             _texture;

    // CPU-side BGRA staging buffer — expanded from g_videoBuffer each frame.
    uint32_t _staging[SCREEN_W * SCREEN_H];

    // Scanline effect toggle (controlled via preferences later).
    bool _scanlines;
    id<MTLBuffer> _scanlinesBuffer;
}

- (instancetype)initWithMetalKitView:(MTKView *)mtkView
{
    self = [super init];
    if (!self) return nil;

    _device = mtkView.device;
    _commandQueue = [_device newCommandQueue];
    _scanlines = false;

    [self buildPipelineWithView:mtkView];
    [self buildTexture];

    // Constant buffer for the scanlines bool flag
    _scanlinesBuffer = [_device newBufferWithLength:sizeof(bool)
                                            options:MTLResourceStorageModeShared];
    *(bool *)_scanlinesBuffer.contents = _scanlines;

    return self;
}

- (void)buildPipelineWithView:(MTKView *)mtkView
{
    NSError *error = nil;
    id<MTLLibrary> lib = [_device newDefaultLibrary];
    if (lib == nil) {
        // Fallback: load compiled .metallib from bundle.
        NSURL *url = [[NSBundle mainBundle] URLForResource:@"default" withExtension:@"metallib"];
        lib = [_device newLibraryWithURL:url error:&error];
    }

    id<MTLFunction> vertFn   = [lib newFunctionWithName:@"beeb_vertex"];
    id<MTLFunction> fragFn   = [lib newFunctionWithName:@"beeb_fragment"];

    MTLRenderPipelineDescriptor *desc = [[MTLRenderPipelineDescriptor alloc] init];
    desc.vertexFunction             = vertFn;
    desc.fragmentFunction           = fragFn;
    desc.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat;

    _pipeline = [_device newRenderPipelineStateWithDescriptor:desc error:&error];
    if (_pipeline == nil) {
        NSLog(@"BeebRenderer: pipeline creation failed: %@", error);
    }
}

- (void)buildTexture
{
    MTLTextureDescriptor *desc = [MTLTextureDescriptor
        texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm
                                     width:SCREEN_W
                                    height:SCREEN_H
                                 mipmapped:NO];
    desc.usage = MTLTextureUsageShaderRead;
    desc.storageMode = MTLStorageModeShared;
    _texture = [_device newTextureWithDescriptor:desc];
}

// ------------------------------------------------------------------
// Called from the emulator thread when the palette changes.
// ------------------------------------------------------------------
- (void)updatePaletteWithCols:(unsigned char *)cols monitorType:(int)monitor
{
    // Palette update is handled in MacPlatform.mm via SetBeebEmEmulatorCoresPalette().
    // This method is a hook for any renderer-side work (none currently needed).
    (void)cols; (void)monitor;
}

// ------------------------------------------------------------------
// MTKViewDelegate
// ------------------------------------------------------------------
- (void)drawInMTKView:(MTKView *)view
{
    // 1. Palette-expand the 8-bit indexed video buffer into BGRA staging.
    const uint8_t *src = g_videoBuffer;
    uint32_t      *dst = _staging;
    for (int i = 0; i < SCREEN_W * SCREEN_H; ++i) {
        dst[i] = g_paletteBGRA[src[i]];
    }

    // 2. Upload staging to MTLTexture.
    [_texture replaceRegion:MTLRegionMake2D(0, 0, SCREEN_W, SCREEN_H)
                mipmapLevel:0
                  withBytes:_staging
                bytesPerRow:SCREEN_W * sizeof(uint32_t)];

    // 3. Encode render pass.
    MTLRenderPassDescriptor *rpd = view.currentRenderPassDescriptor;
    if (rpd == nil) return;

    id<MTLCommandBuffer>        cmd    = [_commandQueue commandBuffer];
    id<MTLRenderCommandEncoder> enc    = [cmd renderCommandEncoderWithDescriptor:rpd];

    [enc setRenderPipelineState:_pipeline];
    [enc setFragmentTexture:_texture atIndex:0];
    [enc setFragmentBuffer:_scanlinesBuffer offset:0 atIndex:0];
    [enc drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
    [enc endEncoding];

    [cmd presentDrawable:view.currentDrawable];
    [cmd commit];
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size
{
    // Nothing to do — we always render into SCREEN_W×SCREEN_H texture
    // and let Metal scale it to the drawable.
    (void)view; (void)size;
}

@end
