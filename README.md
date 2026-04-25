# BeebEm — macOS Port

BBC Micro and Master 128 emulator for macOS, ported from
[beebem-linux](http://codeberg.org/chrisn/beebem-linux/)

## Lineage

```
BeebEm (Windows, original)
  └─ beebem-linux  (SDL + custom gui/ widget toolkit)
       └─ this repo  (Cocoa + Metal + CoreAudio, macOS-native)
```

The emulator core (6502, CRTC, Video ULA, disk controllers, tape, serial,
ARMulator, Z80) is taken directly from beebem-linux and is **unchanged**.
Only the platform layer has been replaced:

| Component       | beebem-linux         | This port                         |
|-----------------|----------------------|-----------------------------------|
| Window/events   | SDL                  | Cocoa (NSApplication, NSWindow)   |
| Rendering       | SDL surfaces         | Metal (MTKView, .metal shaders)   |
| Audio           | SDL_OpenAudio        | CoreAudio (AURemoteIO)            |
| Dialogs         | gui/ (SDL widgets)   | AppKit (NSPanel, NSTableView, …)  |
| File dialogs    | Custom SDL dialog    | NSOpenPanel / NSSavePanel         |
| Screen capture  | WIN32-only stub      | ImageIO (PNG/JPEG/GIF/BMP)        |

## Requirements

- macOS 13 or later (Apple Silicon or Intel)
- Xcode 15 or later (for the Metal toolchain)
- CMake 3.21 or later

## Building

```sh
git clone <this-repo> beebem-macos
cd beebem-macos
cmake -B build -G Xcode
cmake --build build --config Debug
```

The built app is at `build/Debug/BeebEm.app`.  ROM files and configuration
are seeded from `UserData/` into `~/Library/Application Support/BeebEm` on
first build.

## ROM files

ROM images are included in this repository (copyright Acorn/others).
Place your ROM files under `UserData/BeebFile/` in the subdirectory matching
the model (`BBC/`, `BPLUS/`, `M128/`, `Master ET/`, `BBCINT/`) and rebuild,
or drop them into `~/Library/Application Support/BeebEm/BeebFile/` directly.

## Status

| Feature                     | Status                        |
|-----------------------------|-------------------------------|
| BBC B / B+ / Master 128 / Master ET emulation | Working |
| Metal renderer (all video modes) | Working              |
| CoreAudio output            | Working                       |
| Keyboard input              | Working                       |
| Disc image loading (SSD/DSD/IMG/ADF) | Working            |
| Tape loading (UEF/CSW)      | Working                       |
| Save / restore state        | Working                       |
| Screen capture (PNG/JPEG/GIF/BMP) | Working              |
| ROM configuration dialog    | Working                       |
| Keyboard mapping dialog     | Not available (macOS)         |
| Built-in debugger           | Not available (macOS)         |

## Credits

- BeebEm original authors: Mike Wyatt, Nigel Magnay, and many contributors
- beebem-linux: the Stardot community
- macOS port: based on the porting plan in `docs/porting-plan.md`
