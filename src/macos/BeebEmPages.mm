/****************************************************************
BeebEm - BBC Micro and Master 128 Emulator
macOS BeebEmPages stubs — replaces BeebEmPages.cpp on Apple builds.

The SDL custom-GUI widget system (EG_*) is replaced here with no-ops.
Each dialog will be progressively replaced with an NSWindowController
(Option A) or Dear ImGui window (Option B) in later iterations.
This file makes the build link without the gui/ widget toolkit.
****************************************************************/

#import <Cocoa/Cocoa.h>
#include "BeebEmPages.h"

// Global GUI struct — all pointers null on macOS (no SDL widgets).
BeebEmGUI gui = {};

// ------------------------------------------------------------------
// Menu / option state — mirrors the Windows.mm lookup table.
// Kept separate here so BeebWin.cpp menu methods still compile.
// ------------------------------------------------------------------
static int s_guiOptions[0x10000] = {};

int UpdateGUIOption(int windowsMenuId, int isSelected)
{
    int prev = s_guiOptions[windowsMenuId & 0xFFFF];
    s_guiOptions[windowsMenuId & 0xFFFF] = isSelected;
    return prev;
}

int GetGUIOption(int windowsMenuId)
{
    return s_guiOptions[windowsMenuId & 0xFFFF];
}

int SetGUIOptionCaption(int /*windowsMenuId*/, const char * /*str*/)
{
    // TODO: update NSMenuItem title
    return 1;
}

// ------------------------------------------------------------------
// GUI lifecycle
// ------------------------------------------------------------------
void Show_Main()
{
    // TODO: show native macOS preferences / menu window.
    NSLog(@"Show_Main: GUI not yet implemented on macOS");
}

bool InitializeBeebEmGUI(void * /*screen_ptr*/)
{
    return true;
}

void DestroyBeebEmGUI() {}

// ------------------------------------------------------------------
// Display helpers
// ------------------------------------------------------------------
void Update_FDC_Buttons()   {}
void Update_Resolution_Buttons() {}

void SetNameForDisc(int /*drive*/, char * /*name_ptr*/) {}

void SetFullScreenTickbox(bool /*state*/) {}

void ClearWindowsBackgroundCacheAndResetSurface() {}

// ------------------------------------------------------------------
// EG_* stub functions — called from posix/Windows.cpp path
// (on macOS this file replaces posix/Windows.cpp, but in case any
//  translation unit still pulls them in via macros, provide stubs).
// ------------------------------------------------------------------
bool EG_Initialize()           { return true; }
void EG_Draw_FlushEventQueue() {}
float EG_Draw_GetScale()       { return 1.0f; }
void EG_Draw_SetToLowResolution()  {}
void EG_Draw_SetToHighResolution() {}

// RenderFullscreenFPS — no-op (OSD will be drawn in Metal pass later).
void RenderFullscreenFPS(const char * /*str*/, int /*y*/) {}
