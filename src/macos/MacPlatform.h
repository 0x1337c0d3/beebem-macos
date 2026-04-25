/****************************************************************
BeebEm - BBC Micro and Master 128 Emulator
macOS platform layer — replaces Sdl.h on Apple builds.
Provides the same interface that BeebWin.cpp / Sound.cpp call.
****************************************************************/

#pragma once

#include <stdint.h>
#include "MonitorType.h"
#include "Types.h"

// Screen dimensions — match Sdl.h constants
#define BEEBEM_VIDEO_CORE_SCREEN_WIDTH  800
#define BEEBEM_VIDEO_CORE_SCREEN_HEIGHT 600

#define BEEBEM_WINDOW_WIDTH  640
#define BEEBEM_WINDOW_HEIGHT 512

// Global configuration booleans (queried by BeebWin)
extern bool cfg_EmulateCrtGraphics;
extern bool cfg_EmulateCrtTeletext;
extern bool cfg_WantLowLatencySound;

// Windowed / fullscreen resolution tokens (kept for preference compatibility)
#define RESOLUTION_640X512   0
#define RESOLUTION_640X480_S 1
#define RESOLUTION_640X480_V 2
#define RESOLUTION_320X240_S 3
#define RESOLUTION_320X240_V 4
#define RESOLUTION_320X256   5

extern int cfg_Windowed_Resolution;
extern int cfg_Fullscreen_Resolution;
extern int cfg_VerticalOffset;

// ------------------------------------------------------------------
// Video
// ------------------------------------------------------------------

// 8-bit indexed video buffer — BeebRenderer reads this each frame.
extern uint8_t g_videoBuffer[BEEBEM_VIDEO_CORE_SCREEN_WIDTH * BEEBEM_VIDEO_CORE_SCREEN_HEIGHT];

// Returns a pointer to the line in the 8-bit indexed video buffer.
// Called by Video.cpp / BeebWin.cpp for every scan line.
unsigned char *GetSDLScreenLinePtr(int line);

// Set the 8-colour BBC palette (called by BeebWin when monitor type changes).
void SetBeebEmEmulatorCoresPalette(unsigned char *cols, MonitorType monitor);

// Per-scanline render accumulator — on macOS this is a no-op.
// The actual upload happens in BeebRenderer::drawInMTKView:.
void RenderLine(int line, bool isTeletext, int xoffset);

// Clear the output window to black.
void ClearVideoWindow();

// ------------------------------------------------------------------
// Window
// ------------------------------------------------------------------
void SetWindowTitle(const char *pszTitle);

// ------------------------------------------------------------------
// Timing
// ------------------------------------------------------------------
// Replacement for SDL_Delay — backs Sleep() in Windows.mm.
void SaferSleep(unsigned int milliseconds);

// ------------------------------------------------------------------
// Sound ring buffer (same API as Sdl.cpp so Sound.cpp is unchanged)
// ------------------------------------------------------------------
void AddBytesToSDLSoundBuffer(void *p, int len);
void CatchupSound();

// Initialise the ring buffer (called from MacPlatform init).
void InitializeSoundBuffer();

// Returns how many bytes are currently queued.
unsigned long HowManyBytesLeftInSDLSoundBuffer();

// Drain up to 'len' bytes into dst; returns actual bytes copied.
int GetBytesFromSDLSoundBuffer(int len, unsigned char *dst);

// ------------------------------------------------------------------
// Dialog / reporting
// ------------------------------------------------------------------
// Show a modal message box. type: 0=error/warning, 1=info, 2=question, 3=confirm.
// Returns: 1=OK/Yes, 0=No/Cancel.
int MacReport(int type, const char *title, const char *message);

// ------------------------------------------------------------------
// Lifecycle (called from AppDelegate)
// ------------------------------------------------------------------
bool MacPlatformInit(int soundFrequency);
void MacPlatformFree();

// Returns the absolute path of the app bundle's Resources directory.
// Safe to call from C++; backed by [NSBundle mainBundle].
const char *GetBundleResourcesPath();

// ------------------------------------------------------------------
// Clipboard
// ------------------------------------------------------------------
// Read plain text from the macOS pasteboard. Returns bytes written (not NUL-terminated).
int MacGetClipboardText(char *buf, int maxLen);

// ------------------------------------------------------------------
// ROM Configuration Dialog
// ------------------------------------------------------------------
// Shows a native Cocoa dialog for editing ROM slot assignments.
// config is modified in-place on OK; returns true if user clicked OK.
class RomConfigFile;
bool MacEditRomConfig(RomConfigFile& config, const char *userDataPath);

// ------------------------------------------------------------------
// Screen capture
// ------------------------------------------------------------------
// Show an NSSavePanel filtered to the given extension (e.g. ".png").
// Fills outPath with the chosen path. Returns true if user confirmed.
bool MacGetImageSavePath(char *outPath, int maxLen, const char *extension);

// Crop+scale g_videoBuffer through g_paletteBGRA and save as imageTypeUTI.
// srcX/Y/W/H: region of g_videoBuffer to capture.
// canvasW/H: output image dimensions (filled black first).
// dstX/Y/W/H: where the scaled content lands within the canvas.
// imageTypeUTI: e.g. "public.png", "public.jpeg", "com.compuserve.gif", "com.microsoft.bmp".
bool MacCaptureBitmap(const char *filename,
                      int srcX, int srcY, int srcW, int srcH,
                      int canvasW, int canvasH,
                      int dstX, int dstY, int dstW, int dstH,
                      const char *imageTypeUTI);
