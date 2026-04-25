# BeebEm Linux → macOS (Cocoa + Metal) Port Plan

## Context

BeebEm Linux is a BBC Micro emulator written in C/C++. The codebase has a clean separation between the platform-agnostic emulator core (6502, CRTC, Video ULA, disk, tape, serial emulation) and a platform-specific display/input/audio layer. The Linux version uses SDL for everything: rendering, audio callbacks, and events. On top of SDL there's a custom widget toolkit (`gui/`) used for all dialogs. A `posix/Windows.h` shim layer stubs out Windows API types (HWND, HDC, DirectX interfaces) so the codebase compiles on Linux without the actual Windows APIs.

The goal is to replace the SDL+custom-GUI layer with native macOS Cocoa (NSApplication, NSWindow, AppKit dialogs) and a Metal renderer, keeping the emulator core entirely untouched.

---

## What Does NOT Need to Change

- `Video.cpp` — writes into `m_screen` (800×600 8-bit indexed buffer) entirely platform-agnostically
- `6502core.cpp`, `BeebMem.cpp`, `SysVia.cpp`, `UserVia.cpp`, `Tube.cpp`, `Disc*.cpp`, etc. — all emulator core
- `Sound.cpp` — synthesis logic (SN76489, tape, samples); only the audio output backend changes
- `Preferences.cpp` — text-file storage is portable; just the path changes on macOS
- `ARMulator/`, `Z80.cpp`, etc. — co-processor emulators

---

## Work Areas (Layers)

### Layer 1 — Application Entry Point & Event Loop
**File:** `Main.cpp`

Currently: `main()` calls `SDL_Init`, enters a manual `SDL_PollEvent` loop, dispatches keyboard/mouse events, drives the emulator tick via `Exec6502Instruction()`.

**Replace with:**
- `main.mm` — Objective-C++ entry: `NSApplicationMain(argc, argv)` or manual `[NSApplication sharedApplication]; [app run];`
- `AppDelegate.mm` — `applicationDidFinishLaunching:` creates `BeebWin`, starts the emulator loop
- Emulator timing loop: `CVDisplayLink` callback or a dedicated `NSThread` / GCD serial queue calling `Exec6502Instruction()` at 2MHz
- Keyboard/mouse events: override `keyDown:`, `keyUp:`, `mouseMoved:` in the Metal view subclass

**Effort:** ~1 week

---

### Layer 2 — Window & Metal View
**Files:** `BeebWin.h`, `BeebWin.cpp`, `Sdl.h`, `Sdl.cpp`

Currently: `Create_Screen()` calls `SDL_SetVideoMode()`; `RenderLine()` calls `SDL_BlitSurface()` + `SDL_UpdateRect()`. `BeebWin` holds `m_hDC`, `m_hDCBitmap` (void* stubs on Linux).

**Replace with:**
- `NSWindow` containing a custom `BeebMetalView : MTKView` (or `NSView` with `CAMetalLayer`)
- `BeebWin::CreateBeebWindow()` → create `NSWindow`, set content view to `BeebMetalView`
- `BeebWin::m_screen` (800×512 uint8 buffer) stays; add `m_palette[256]` as BGRA expansion table
- On each frame: CPU-expand `m_screen` through palette into a `uint32_t[800×512]` staging buffer, upload to `MTLTexture` via `replaceRegion:mipmapLevel:withBytes:bytesPerRow:`
- Metal render pass: full-screen textured quad (vertex + fragment shader), optional scanline/CRT effect shader
- `RenderLine()` becomes a no-op accumulator; actual GPU upload happens at end-of-frame in `MTKViewDelegate drawInMTKView:`
- Remove all DirectX member variables from `BeebWin`

**New files:** `BeebMetalView.mm`, `BeebRenderer.mm`, `Shaders.metal`

**Effort:** ~2–3 weeks

---

### Layer 3 — Custom GUI Widget Toolkit Replacement
**Directory:** `gui/` (30 files, SDL-based widgets: button, checkbox, window, label, slider, tabs, radio groups, etc.)

This is the **largest risk item**. Every preferences dialog, ROM config dialog, joystick dialog, keyboard dialog, etc. uses this custom SDL widget system.

**Options (pick one):**

**Option A — AppKit (recommended for authenticity)**
- Replace each dialog with an `NSWindowController` + `.xib` or programmatic `NSView` layout
- `Dialog` base class → `NSWindowController` subclass
- `FileDialog` → `NSOpenPanel` / `NSSavePanel`
- `FolderSelectDialog` → `NSOpenPanel` (directory mode)
- `ComboBox` → `NSComboBox`, `ListView` → `NSTableView`
- `Messages.h` WM_APP codes → `NSNotificationCenter` notifications
- Menu system → `NSMenu` / `NSMenuItem` with action selectors
- ~15–20 dialog classes need individual ports

**Option B — Dear ImGui (fastest path)**
- Drop `gui/` entirely; add Dear ImGui with its Metal+Cocoa backend
- All dialogs rewritten as ImGui windows (immediate-mode)
- Renders inside the same Metal view as the BBC screen
- Minimal platform coupling; easy to style

**Effort:** Option A ~6–10 weeks | Option B ~3–4 weeks

---

### Layer 4 — Audio Backend
**Files:** `Sdl.cpp` (audio section), `SoundStreamer.h`, `SoundStreamer.cpp`

Currently: `SDL_OpenAudio()` with `fill_audio()` pull callback, fed by a 100KB circular buffer (`SDLSoundBuffer`) written to by `AddBytesToSDLSoundBuffer()`.

**Replace with CoreAudio or AVAudioEngine:**
- Add `CoreAudioStreamer : SoundStreamer` implementing the existing streamer interface
- `AudioUnit` (AURemoteIO) render callback pulls from the same lock-free circular buffer
- Or: `AVAudioSourceNode` with render block (AVAudioEngine, simpler API)
- Keep `SDLSoundBuffer` ring buffer and `AddBytesToSDLSoundBuffer()` unchanged — only swap the consumer
- Sample rate: internally 44100Hz; macOS hardware often 48kHz → let CoreAudio handle SRC

**New file:** `CoreAudioStreamer.mm`

**Effort:** ~1 week

---

### Layer 5 — Platform Shims
**Files:** `posix/Windows.h`, `posix/Windows.cpp`

Currently stubs Windows types as `void*` and wires `Sleep()→SDL_Delay()`, `GetTickCount()→SDL_GetTicks()`, menu helpers → custom GUI system.

**Replace with macOS equivalents:**
- `Sleep(ms)` → `usleep(ms * 1000)` or `nanosleep()`
- `GetTickCount()` → `mach_absolute_time()` converted to ms
- `SetWindowText()` → `[window setTitle:]`
- Menu state helpers → forward to `NSMenuItem` enable/check
- `HWND` → `NSWindow*`, `HDC` → `CGContextRef` (or keep as `void*` — only used as opaque handles)
- Remove `SDL_GetTicks()` / `SDL_Delay()` dependencies

**Effort:** ~3–4 days

---

### Layer 6 — Build System

Currently no CMakeLists.txt or Makefile at root (likely a platform-specific project file not found during indexing).

**Create:**
- `CMakeLists.txt` with `if(APPLE)` branch linking `Cocoa`, `Metal`, `MetalKit`, `AVFoundation`, `CoreAudio`, `GameController`
- Or: Xcode `.xcodeproj` / `.xcworkspace`
- Compile `*.mm` files with Objective-C++ (`-ObjC++`)
- Link `Shaders.metal` via Xcode's default Metal compilation or `xcrun metal` in CMake

**Effort:** ~2–3 days

---

## Metal Rendering Pipeline

```
BBC CPU writes pixels
     │
     ▼
m_screen[800×512] (uint8, indexed)        ← Video.cpp, unchanged
     │  palette expand (CPU, per-frame)
     ▼
staging_buffer[800×512×4] (BGRA uint32)
     │  replaceRegion:
     ▼
MTLTexture (BGRA8, 800×512)
     │  fragment shader sample + scale
     ▼
MTKView drawable (display resolution)
     │  optional CRT/scanline pass
     ▼
Screen
```

Palette expansion is ~400KB/frame at 50fps = 20MB/s — trivially fast on CPU. No compute shader needed unless CRT effects demand it.

---

## Dependency Summary

| Component | Remove | Add |
|---|---|---|
| Window/events | SDL | Cocoa NSApplication, NSWindow, NSEvent |
| Rendering | SDL surfaces, SDL_BlitSurface | Metal MTLTexture, MTKView, .metal shaders |
| Audio | SDL_OpenAudio | CoreAudio AURemoteIO or AVAudioEngine |
| Dialogs | gui/ (SDL widgets) | AppKit NSWindowController (or Dear ImGui) |
| File dialogs | GTK stub | NSOpenPanel / NSSavePanel |
| Joystick | Not implemented | GCController or IOHIDManager |
| Build | (unknown) | CMakeLists.txt or .xcodeproj |
| Shims | SDL_Delay, SDL_GetTicks | mach_absolute_time, usleep |

---

## Effort Summary

| Layer | Effort |
|---|---|
| App entry + event loop | 1 week |
| Metal renderer + window | 2–3 weeks |
| Dialog system (Option A AppKit) | 6–10 weeks |
| Dialog system (Option B ImGui) | 3–4 weeks |
| CoreAudio backend | 1 week |
| Platform shims | 3–4 days |
| Build system | 2–3 days |
| **Total (Option A — native AppKit)** | **~11–16 weeks** |
| **Total (Option B — Dear ImGui)** | **~8–10 weeks** |

---

## Verification Checklist

- `clang++ -fobjc-arc -framework Cocoa -framework Metal -framework MetalKit -framework AVFoundation` clean compile
- BBC screen renders at correct 50Hz with palette-correct colors (test MODE 0–7)
- Audio plays at correct pitch with no glitches at all three sample rates (11025, 22050, 44100Hz)
- All preference dialogs open and save correctly
- Keyboard input correctly maps to BBC key matrix (test BASIC, games)
- Fullscreen toggle works with correct aspect ratio
- Disk/tape loading via file dialogs works
- Retina display: BBC screen scales cleanly without blurring
