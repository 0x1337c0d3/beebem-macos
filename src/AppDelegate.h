/****************************************************************
BeebEm - BBC Micro and Master 128 Emulator
macOS Cocoa + Metal port
****************************************************************/

#pragma once

#import <Cocoa/Cocoa.h>

@class BeebMetalView;

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (strong) NSWindow       *window;
@property (strong) BeebMetalView  *beebView;

@end
