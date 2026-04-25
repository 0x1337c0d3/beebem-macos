/****************************************************************
BeebEm - BBC Micro and Master 128 Emulator
macOS Cocoa entry point — replaces Main.cpp on Apple builds.
****************************************************************/

#import <Cocoa/Cocoa.h>
#import "AppDelegate.h"

// Global command-line args referenced by the emulator core.
int    __argc = 0;
char **__argv = nullptr;

// ------------------------------------------------------------------
// Globals declared extern in Main.h / macos/MacMain.h
// ------------------------------------------------------------------
#include "Windows.h"
#include "BeebWin.h"
#include "Model.h"

int       done              = 0;
Model     MachineType;
BeebWin  *mainWin           = nullptr;
HINSTANCE hInst             = nullptr;
HWND      hCurrentDialog    = nullptr;
HACCEL    hCurrentAccelTable = nullptr;

// ------------------------------------------------------------------
// Platform-level helpers called from within the emulator core.
// ------------------------------------------------------------------

void Quit()
{
    done = 1;
    [NSApp terminate:nil];
}

bool ToggleFullScreen()
{
    if (mainWin == nullptr) return false;
    mainWin->SetFullScreenToggle(!mainWin->IsFullScreen());
    // NSWindow fullscreen toggle
    [[NSApp mainWindow] toggleFullScreen:nil];
    return mainWin->IsFullScreen();
}

void ShowingMenu() {}
void NoMenuShown()  {}

// ------------------------------------------------------------------
int main(int argc, char *argv[])
{
    __argc = argc;
    __argv = argv;

    // Initialise AppDelegate via Info.plist principal class, or manually:
    NSApplication *app = [NSApplication sharedApplication];
    AppDelegate *delegate = [[AppDelegate alloc] init];
    app.delegate = delegate;
    [app run];
    return 0;
}
