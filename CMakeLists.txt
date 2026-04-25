cmake_minimum_required(VERSION 3.21)
project(BeebEm LANGUAGES CXX OBJCXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(SRC ${CMAKE_SOURCE_DIR}/src)

# ---------------------------------------------------------------------------
# Source files — emulator core (platform-agnostic, unchanged from Linux port)
# ---------------------------------------------------------------------------
set(BEEBEM_CORE_SOURCES
    ${SRC}/6502core.cpp
    ${SRC}/Arm.cpp
    ${SRC}/ArmDisassembler.cpp
    ${SRC}/AtoDConv.cpp
    ${SRC}/AviWriter.cpp
    ${SRC}/Bcd.cpp
    ${SRC}/BeebEmPages.cpp      # replaced by macos/ version below on Apple
    ${SRC}/BeebMem.cpp
    ${SRC}/BeebWin.cpp
    ${SRC}/BeebWinDx.cpp
    ${SRC}/BeebWinIo.cpp
    ${SRC}/BeebWinPrefs.cpp
    ${SRC}/BeebWinSpeech.cpp
    ${SRC}/ComboBox.cpp
    ${SRC}/Csw.cpp
    ${SRC}/Debug.cpp
    ${SRC}/DebugTrace.cpp
    ${SRC}/Dialog.cpp
    ${SRC}/Disc1770.cpp
    ${SRC}/Disc8271.cpp
    ${SRC}/DiscEdit.cpp
    ${SRC}/DiscInfo.cpp
    ${SRC}/Econet.cpp
    ${SRC}/Ext1770.cpp
    ${SRC}/FileDialog.cpp
    ${SRC}/FileType.cpp
    ${SRC}/FileUtils.cpp
    ${SRC}/FolderSelectDialog.cpp
    ${SRC}/IC32Latch.cpp
    ${SRC}/Ide.cpp
    ${SRC}/IP232.cpp
    ${SRC}/JoystickController.cpp
    ${SRC}/JoystickDialog.cpp
    ${SRC}/JoystickOptions.cpp
    ${SRC}/KeyboardLinksDialog.cpp
    ${SRC}/KeyMap.cpp
    ${SRC}/ListView.cpp
    ${SRC}/Log.cpp
    ${SRC}/Master512CoPro.cpp
    ${SRC}/Model.cpp
    ${SRC}/Music5000.cpp
    ${SRC}/PALRom.cpp
    ${SRC}/Preferences.cpp
    ${SRC}/RingBuffer.cpp
    ${SRC}/RomConfigFile.cpp
    ${SRC}/Rtc.cpp
    ${SRC}/Sasi.cpp
    ${SRC}/Scsi.cpp
    ${SRC}/Serial.cpp
    ${SRC}/SerialPort.cpp
    ${SRC}/Socket.cpp
    ${SRC}/Sound.cpp
    ${SRC}/SoundStreamer.cpp
    ${SRC}/Speech.cpp
    ${SRC}/SprowCoPro.cpp
    ${SRC}/StringUtils.cpp
    ${SRC}/SysVia.cpp
    ${SRC}/TapeControlDialog.cpp
    ${SRC}/TapeMap.cpp
    ${SRC}/Teletext.cpp
    ${SRC}/Thread.cpp
    ${SRC}/TouchScreen.cpp
    ${SRC}/Tube.cpp
    ${SRC}/Uef.cpp
    ${SRC}/UefState.cpp
    ${SRC}/UserKeyboardDialog.cpp
    ${SRC}/UserPortBreakoutBox.cpp
    ${SRC}/UserPortRTC.cpp
    ${SRC}/UserVia.cpp
    ${SRC}/Via.cpp
    ${SRC}/Video.cpp
    ${SRC}/WindowUtils.cpp
    ${SRC}/Z80.cpp
    ${SRC}/Z80Disassembler.cpp
    ${SRC}/Z80Support.cpp
    ${SRC}/ARMulator/armdis.cpp
    ${SRC}/ARMulator/armemu.cpp
    ${SRC}/ARMulator/arminit.cpp
    ${SRC}/ARMulator/armsupp.cpp
    ${SRC}/ARMulator/thumbemu.cpp
    ${SRC}/Hardware/Acorn1770/Acorn.cpp
    ${SRC}/Hardware/OpusDDOS/Opus.cpp
    ${SRC}/Hardware/Watford/Watford.cpp
)

# ---------------------------------------------------------------------------
# macOS-specific sources (Layers 1–5)
# ---------------------------------------------------------------------------
if(APPLE)
    set(BEEBEM_PLATFORM_SOURCES
        # Layer 1 — entry point & event loop
        ${SRC}/main.mm
        ${SRC}/AppDelegate.mm
        # Layer 2 — Metal view & renderer
        ${SRC}/BeebMetalView.mm
        ${SRC}/BeebRenderer.mm
        # Layer 4 — CoreAudio backend
        ${SRC}/CoreAudioStreamer.mm
        # Layer 5 — platform shims (replaces posix/Windows.cpp)
        ${SRC}/macos/Windows.mm
        # macOS platform API (replaces Sdl.cpp)
        ${SRC}/macos/MacPlatform.mm
        # NSMenu hierarchy
        ${SRC}/macos/BeebMenu.mm
        # GUI stubs (replaces BeebEmPages.cpp + gui/ widget toolkit)
        ${SRC}/macos/BeebEmPages.mm
        # File/folder dialogs (replaces FileDialog.cpp + FolderSelectDialog.cpp)
        ${SRC}/macos/FileDialogMac.mm
        # ARMulator stubs for missing functions (ARMul_Debug, XScale, etc.)
        ${SRC}/ARMulator/armstubs.cpp
    )

    # Remove the Linux/Windows-specific files from core list.
    list(REMOVE_ITEM BEEBEM_CORE_SOURCES
        ${SRC}/Main.cpp
        ${SRC}/Sdl.cpp
        ${SRC}/BeebEmPages.cpp
        ${SRC}/posix/Windows.cpp
        ${SRC}/FileDialog.cpp
        ${SRC}/FolderSelectDialog.cpp
    )
else()
    # Linux build keeps the original SDL-based files.
    set(BEEBEM_PLATFORM_SOURCES
        ${SRC}/Main.cpp
        ${SRC}/Sdl.cpp
        ${SRC}/BeebEmPages.cpp
        ${SRC}/posix/Windows.cpp
        ${SRC}/gui/box.c
        ${SRC}/gui/button.c
        ${SRC}/gui/functions.c
        ${SRC}/gui/label.c
        ${SRC}/gui/log.c
        ${SRC}/gui/messagebox.c
        ${SRC}/gui/progressbar.c
        ${SRC}/gui/radiobutton.c
        ${SRC}/gui/radiogroup.c
        ${SRC}/gui/sdl.c
        ${SRC}/gui/slidebar.c
        ${SRC}/gui/tabgroup.c
        ${SRC}/gui/tabpage.c
        ${SRC}/gui/tickbox.c
        ${SRC}/gui/togglebutton.c
        ${SRC}/gui/widget_shared.c
        ${SRC}/gui/widget.c
        ${SRC}/gui/window.c
    )
endif()

# ---------------------------------------------------------------------------
# Executable
# ---------------------------------------------------------------------------
add_executable(BeebEm
    ${BEEBEM_CORE_SOURCES}
    ${BEEBEM_PLATFORM_SOURCES}
)

# ---------------------------------------------------------------------------
# Include paths
# ---------------------------------------------------------------------------
target_include_directories(BeebEm PRIVATE
    ${SRC}
    ${SRC}/ARMulator
    ${SRC}/Hardware/Acorn1770
    ${SRC}/Hardware/OpusDDOS
    ${SRC}/Hardware/Watford
    # posix/Windows.h provides the fake Windows type definitions on both platforms.
    ${SRC}/posix
)

# ---------------------------------------------------------------------------
# Compile options
# ---------------------------------------------------------------------------
target_compile_options(BeebEm PRIVATE
    -Wall
    -Wno-unused-parameter
)

if(APPLE)
    # ARC and ObjC++ apply only to .mm files; set per-file rather than globally
    # so that .cpp files are compiled as plain C++, avoiding ObjC runtime conflicts.
    file(GLOB_RECURSE BEEBEM_MM_SOURCES "${SRC}/*.mm")
    set_source_files_properties(${BEEBEM_MM_SOURCES} PROPERTIES
        COMPILE_FLAGS "-fobjc-arc"
        LANGUAGE OBJCXX
    )

    target_compile_definitions(BeebEm PRIVATE
        __APPLE__
        DATA_DIR="Resources"
        MODE32
    )
else()
    target_compile_definitions(BeebEm PRIVATE
        DATA_DIR="/usr/share/beebem"
    )
    find_package(SDL REQUIRED)
    target_include_directories(BeebEm PRIVATE ${SDL_INCLUDE_DIR})
    target_link_libraries(BeebEm PRIVATE ${SDL_LIBRARY})
endif()

# ---------------------------------------------------------------------------
# macOS frameworks (Layers 1–4)
# ---------------------------------------------------------------------------
if(APPLE)
    target_link_libraries(BeebEm PRIVATE
        "-framework Cocoa"
        "-framework Metal"
        "-framework MetalKit"
        "-framework AVFoundation"
        "-framework CoreAudio"
        "-framework AudioToolbox"
        "-framework GameController"
        "-framework ImageIO"
        z
    )

    # Metal shader compilation
    # The .metal source is compiled by Xcode automatically; with CMake we invoke
    # xcrun to produce a .metallib and embed it in the app bundle.
    find_program(XCRUN xcrun REQUIRED)
    set(METAL_SRC  "${SRC}/Shaders.metal")
    set(METAL_AIR  "${CMAKE_BINARY_DIR}/Shaders.air")
    set(METAL_LIB  "${CMAKE_BINARY_DIR}/default.metallib")

    add_custom_command(
        OUTPUT  ${METAL_AIR}
        COMMAND ${XCRUN} -sdk macosx metal -c ${METAL_SRC} -o ${METAL_AIR}
        DEPENDS ${METAL_SRC}
        COMMENT "Compiling Shaders.metal"
    )
    add_custom_command(
        OUTPUT  ${METAL_LIB}
        COMMAND ${XCRUN} -sdk macosx metallib ${METAL_AIR} -o ${METAL_LIB}
        DEPENDS ${METAL_AIR}
        COMMENT "Linking default.metallib"
    )
    add_custom_target(MetalShaders ALL DEPENDS ${METAL_LIB})
    add_dependencies(BeebEm MetalShaders)

    # Bundle structure
    set_target_properties(BeebEm PROPERTIES
        MACOSX_BUNDLE TRUE
        MACOSX_BUNDLE_BUNDLE_NAME "BeebEm"
        MACOSX_BUNDLE_GUI_IDENTIFIER "au.com.beebem.BeebEm"
        MACOSX_BUNDLE_SHORT_VERSION_STRING "1.0"
        MACOSX_BUNDLE_BUNDLE_VERSION "1"
    )

    # Copy the metallib into the bundle Resources.
    add_custom_command(TARGET BeebEm POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy
            ${METAL_LIB}
            "$<TARGET_BUNDLE_CONTENT_DIR:BeebEm>/Resources/default.metallib"
        COMMENT "Installing default.metallib into bundle"
    )

    # Copy UserData (ROMs, config, fonts) into the bundle Resources.
    # These become the app's read-only data files (m_AppPath on macOS).
    if(EXISTS "${CMAKE_SOURCE_DIR}/UserData")
        add_custom_command(TARGET BeebEm POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_directory
                "${CMAKE_SOURCE_DIR}/UserData"
                "$<TARGET_BUNDLE_CONTENT_DIR:BeebEm>/Resources"
            COMMENT "Copying UserData into bundle Resources"
        )
    endif()

    # Seed ~/Library/Application Support/BeebEm with UserData if not already present.
    if(EXISTS "${CMAKE_SOURCE_DIR}/UserData")
        add_custom_command(TARGET BeebEm POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E make_directory
                "$ENV{HOME}/Library/Application Support/BeebEm"
            COMMAND ${CMAKE_COMMAND} -E copy_directory_if_different
                "${CMAKE_SOURCE_DIR}/UserData"
                "$ENV{HOME}/Library/Application Support/BeebEm"
            COMMENT "Seeding ~/Library/Application Support/BeebEm from UserData"
        )
    endif()
endif()
