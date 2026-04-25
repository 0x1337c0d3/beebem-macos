/****************************************************************
BeebEm - BBC Micro and Master 128 Emulator
macOS native NSMenu integration.
****************************************************************/

#pragma once

// This header is safe to include from pure C++ translation units.
// Builds the application NSMenuBar and installs it.
// Call once from -applicationDidFinishLaunching:.
#ifdef __OBJC__
@class NSObject;
void BeebMenuBuild(id delegate);
#else
void BeebMenuBuild(void *delegate);
#endif

// Update check/enable state of a menu item by its BeebEm IDM_ tag.
// Thread-safe: dispatches to main queue.
void BeebMenuSetChecked(int menuID, bool checked);
void BeebMenuSetEnabled(int menuID, bool enabled);
void BeebMenuSetText(int menuID, const char *text);
