/****************************************************************
BeebEm - BBC Micro and Master 128 Emulator
macOS Metal view — keyboard/mouse event handler + MTKView host
****************************************************************/

#pragma once

#import <MetalKit/MetalKit.h>

@class BeebRenderer;

@interface BeebMetalView : MTKView

- (instancetype)initWithFrame:(CGRect)frame device:(id<MTLDevice>)device;

@end
