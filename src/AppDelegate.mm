/****************************************************************
BeebEm - BBC Micro and Master 128 Emulator
macOS AppDelegate — creates window, initialises emulator, drives loop.
****************************************************************/

#import "AppDelegate.h"
#import "BeebMetalView.h"
#import "BeebRenderer.h"
#import "macos/MacPlatform.h"
#import "macos/BeebMenu.h"
#import "CoreAudioStreamer.h"

// Windows types must come before BeebWin.h (which uses DWORD, HWND etc.)
#include "Windows.h"
#include "BeebWin.h"
#include "6502core.h"
#include "Main.h"

// Declared in main.mm
extern BeebWin  *mainWin;
extern int       done;

static const int kSoundFrequency = 44100;

@implementation AppDelegate
{
    NSThread     *_emulatorThread;
    BeebRenderer *_renderer;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    // ------------------------------------------------------------------
    // 0. Build the native menu bar
    // ------------------------------------------------------------------
    BeebMenuBuild(self);

    // ------------------------------------------------------------------
    // 1. Initialise platform (video buffer, sound ring buffer, CoreAudio)
    // ------------------------------------------------------------------
    if (!MacPlatformInit(kSoundFrequency)) {
        NSLog(@"MacPlatformInit failed");
        [NSApp terminate:nil];
        return;
    }

    if (!CoreAudioInit(kSoundFrequency)) {
        NSLog(@"CoreAudioInit failed — continuing without sound");
    }

    // ------------------------------------------------------------------
    // 2. Create NSWindow
    // ------------------------------------------------------------------
    NSWindowStyleMask style = NSWindowStyleMaskTitled
                            | NSWindowStyleMaskClosable
                            | NSWindowStyleMaskMiniaturizable
                            | NSWindowStyleMaskResizable;

    self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 640, 512)
                                              styleMask:style
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];

    // Restore saved window position, or center if none saved.
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    double savedX = [ud doubleForKey:@"WindowX"];
    double savedY = [ud doubleForKey:@"WindowY"];
    if ([ud objectForKey:@"WindowX"] != nil) {
        [self.window setFrameOrigin:NSMakePoint(savedX, savedY)];
    } else {
        [self.window center];
    }
    self.window.title = @"BeebEm";

    // ------------------------------------------------------------------
    // 3. Create Metal view + renderer
    // ------------------------------------------------------------------
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (device == nil) {
        NSLog(@"No Metal device found");
        [NSApp terminate:nil];
        return;
    }

    self.beebView = [[BeebMetalView alloc] initWithFrame:self.window.contentLayoutRect device:device];
    _renderer = [[BeebRenderer alloc] initWithMetalKitView:self.beebView];

    self.window.contentView = self.beebView;
    self.window.backgroundColor = [NSColor blackColor];
    self.window.collectionBehavior = NSWindowCollectionBehaviorMoveToActiveSpace
                                   | NSWindowCollectionBehaviorFullScreenPrimary;
    [NSApp activateIgnoringOtherApps:YES];
    [self.window makeKeyAndOrderFront:nil];
    // Set delegate after ordering front to avoid premature Metal draws before the
    // window is on screen (which exhausts the drawable chain and deadlocks).
    self.beebView.delegate = _renderer;
    NSLog(@"[BeebEm] Window ordered front, visible=%d, mini=%d, zoomed=%d, frame=%@, screen=%@",
          (int)self.window.isVisible,
          (int)self.window.isMiniaturized,
          (int)self.window.isZoomed,
          NSStringFromRect(self.window.frame),
          self.window.screen ? NSStringFromRect(self.window.screen.frame) : @"(nil)");
    [self.window makeFirstResponder:self.beebView];

    // ------------------------------------------------------------------
    // 4. Create BeebWin and initialise emulator core
    // ------------------------------------------------------------------
    mainWin = new(std::nothrow) BeebWin();
    if (mainWin == nullptr || !mainWin->Initialise()) {
        NSLog(@"BeebWin::Initialise() failed");
        [NSApp terminate:nil];
        return;
    }

    // ------------------------------------------------------------------
    // 5. Launch emulator loop on a background thread
    // ------------------------------------------------------------------
    _emulatorThread = [[NSThread alloc] initWithTarget:self
                                              selector:@selector(emulatorLoop)
                                                object:nil];
    _emulatorThread.name = @"BeebEm 6502";
    _emulatorThread.qualityOfService = NSQualityOfServiceUserInteractive;
    [_emulatorThread start];
}

// ------------------------------------------------------------------
// Emulator tight loop — runs Exec6502Instruction() at 2 MHz.
// Timing is handled inside BeebWin::UpdateTiming() which calls Sleep().
// ------------------------------------------------------------------
- (void)emulatorLoop
{
    while (!done) {
        @autoreleasepool {
            if (mainWin && !mainWin->IsFrozen()) {
                Exec6502Instruction();
            } else {
                [NSThread sleepForTimeInterval:0.010];
            }
        }
    }
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    return YES;
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    done = 1;
    [_emulatorThread cancel];

    // Save window position for next launch.
    NSPoint origin = self.window.frame.origin;
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud setDouble:origin.x forKey:@"WindowX"];
    [ud setDouble:origin.y forKey:@"WindowY"];

    CoreAudioFree();
    MacPlatformFree();

    if (mainWin) {
        delete mainWin;
        mainWin = nullptr;
    }
}

@end
