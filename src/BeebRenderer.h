/****************************************************************
BeebEm - BBC Micro and Master 128 Emulator
macOS Metal renderer — palette-expand + MTLTexture upload + draw
****************************************************************/

#pragma once

#import <MetalKit/MetalKit.h>

@interface BeebRenderer : NSObject <MTKViewDelegate>

- (instancetype)initWithMetalKitView:(MTKView *)mtkView;

// Called from the emulator thread to update the palette BGRA table.
// cols is the 8-entry index array filled by Video.cpp; Monitor selects colour filter.
- (void)updatePaletteWithCols:(unsigned char *)cols monitorType:(int)monitor;

@end
