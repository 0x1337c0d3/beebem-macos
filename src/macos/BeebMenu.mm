/****************************************************************
BeebEm - BBC Micro and Master 128 Emulator
macOS NSMenuBar implementation.

Each NSMenuItem tag is the BeebEm IDM_ value (from Resource.h).
Actions go through -beebMenuAction: which calls mainWin->HandleCommand.
****************************************************************/

#import <Cocoa/Cocoa.h>
#include "Windows.h"
#include "Resource.h"
#include "BeebWin.h"
#include "Version.h"
#include "macos/BeebMenu.h"

extern BeebWin *mainWin;
extern int      done;

// ---------------------------------------------------------------------------
// Menu action target
// ---------------------------------------------------------------------------

@interface BeebMenuTarget : NSObject
- (void)beebMenuAction:(NSMenuItem *)sender;
- (void)beebQuit:(id)sender;
- (void)beebAbout:(id)sender;
@end

@implementation BeebMenuTarget

- (void)beebMenuAction:(NSMenuItem *)sender
{
    if (mainWin)
        mainWin->HandleCommand((UINT)sender.tag);
}

- (void)beebQuit:(id)sender
{
    (void)sender;
    done = 1;
    [NSApp terminate:nil];
}

- (void)beebAbout:(id)sender
{
    (void)sender;
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText     = @"BeebEm " VERSION_STRING;
    alert.informativeText = @VERSION_COPYRIGHT "\n\nmacOS port — BBC Micro and Master 128 Emulator";
    alert.alertStyle      = NSAlertStyleInformational;
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
}

@end

static BeebMenuTarget *s_target = nil;

// ---------------------------------------------------------------------------
// Helper: add an item to a menu with a BeebEm IDM_ tag
// ---------------------------------------------------------------------------
static NSMenuItem *AddItem(NSMenu *menu, NSString *title, int menuID,
                            NSString *key = @"",
                            NSEventModifierFlags mods = 0)
{
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title
                                                  action:@selector(beebMenuAction:)
                                           keyEquivalent:key];
    item.keyEquivalentModifierMask = mods ? mods : NSEventModifierFlagCommand;
    item.tag  = menuID;
    item.target = s_target;
    [menu addItem:item];
    return item;
}

static NSMenuItem *AddSeparator(NSMenu *menu)
{
    NSMenuItem *sep = [NSMenuItem separatorItem];
    [menu addItem:sep];
    return sep;
}

// ---------------------------------------------------------------------------
// Application menu (always first on macOS)
// ---------------------------------------------------------------------------
static void BuildAppMenu()
{
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"BeebEm"];

    // About
    NSMenuItem *about = [[NSMenuItem alloc] initWithTitle:@"About BeebEm"
                                                    action:@selector(beebAbout:)
                                             keyEquivalent:@""];
    about.target = s_target;
    [menu addItem:about];

    [menu addItem:[NSMenuItem separatorItem]];

    // Services
    NSMenuItem *services = [[NSMenuItem alloc] initWithTitle:@"Services"
                                                       action:nil
                                                keyEquivalent:@""];
    NSMenu *servicesMenu = [[NSMenu alloc] initWithTitle:@"Services"];
    services.submenu = servicesMenu;
    [NSApp setServicesMenu:servicesMenu];
    [menu addItem:services];

    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *hide = [[NSMenuItem alloc] initWithTitle:@"Hide BeebEm"
                                                   action:@selector(hide:)
                                            keyEquivalent:@"h"];
    [menu addItem:hide];

    NSMenuItem *hideOthers = [[NSMenuItem alloc] initWithTitle:@"Hide Others"
                                                         action:@selector(hideOtherApplications:)
                                                  keyEquivalent:@"h"];
    hideOthers.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagOption;
    [menu addItem:hideOthers];

    [menu addItem:[[NSMenuItem alloc] initWithTitle:@"Show All"
                                             action:@selector(unhideAllApplications:)
                                      keyEquivalent:@""]];

    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *quit = [[NSMenuItem alloc] initWithTitle:@"Quit BeebEm"
                                                   action:@selector(beebQuit:)
                                            keyEquivalent:@"q"];
    quit.target = s_target;
    [menu addItem:quit];

    NSMenuItem *appItem = [[NSMenuItem alloc] initWithTitle:@"BeebEm" action:nil keyEquivalent:@""];
    appItem.submenu = menu;
    [[NSApp mainMenu] addItem:appItem];
    // setAppleMenu: is a private API but works; suppress the warning
    if ([NSApp respondsToSelector:@selector(setAppleMenu:)])
        [NSApp performSelector:@selector(setAppleMenu:) withObject:menu];
}

// ---------------------------------------------------------------------------
// File menu
// ---------------------------------------------------------------------------
static void BuildFileMenu()
{
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"File"];

    AddItem(menu, @"Load Disc 0…",  IDM_LOADDISC0, @"o");
    AddItem(menu, @"Load Disc 1…",  IDM_LOADDISC1, @"");
    AddItem(menu, @"Eject Disc 0",  IDM_EJECTDISC0, @"");
    AddItem(menu, @"Eject Disc 1",  IDM_EJECTDISC1, @"");
    AddItem(menu, @"New Disc 0…",   IDM_NEWDISC0, @"");
    AddItem(menu, @"New Disc 1…",   IDM_NEWDISC1, @"");
    AddSeparator(menu);
    AddItem(menu, @"Run Disc",      IDM_RUNDISC, @"");
    AddSeparator(menu);
    AddItem(menu, @"Load Tape…",    IDM_LOADTAPE, @"");
    AddItem(menu, @"Rewind Tape",   IDM_REWINDTAPE, @"");
    AddItem(menu, @"Unlock Tape",   IDM_UNLOCKTAPE, @"");
    AddItem(menu, @"Tape Control…", IDM_TAPECONTROL, @"");
    AddSeparator(menu);
    AddItem(menu, @"Load State…",   IDM_LOADSTATE, @"");
    AddItem(menu, @"Save State…",   IDM_SAVESTATE, @"");
    AddItem(menu, @"Quick Save",    IDM_QUICKSAVE, @"s");
    AddItem(menu, @"Quick Load",    IDM_QUICKLOAD, @"l");
    AddSeparator(menu);
    AddItem(menu, @"Capture Screenshot…", IDM_CAPTURESCREEN, @"");
    AddSeparator(menu);
    AddItem(menu, @"Save Preferences", IDM_SAVE_PREFS, @"");
    AddSeparator(menu);

    // Auto-save submenu
    NSMenu *autoSave = [[NSMenu alloc] initWithTitle:@"Auto-save Preferences"];
    AddItem(autoSave, @"Save CMOS on Exit",    IDM_AUTOSAVE_PREFS_CMOS,    @"");
    AddItem(autoSave, @"Save Folders on Exit", IDM_AUTOSAVE_PREFS_FOLDERS, @"");
    AddItem(autoSave, @"Save All on Exit",     IDM_AUTOSAVE_PREFS_ALL,     @"");
    NSMenuItem *autoSaveItem = [[NSMenuItem alloc] initWithTitle:@"Auto-save Preferences"
                                                          action:nil keyEquivalent:@""];
    autoSaveItem.submenu = autoSave;
    [menu addItem:autoSaveItem];

    NSMenuItem *fileItem = [[NSMenuItem alloc] initWithTitle:@"File" action:nil keyEquivalent:@""];
    fileItem.submenu = menu;
    [[NSApp mainMenu] addItem:fileItem];
}

// ---------------------------------------------------------------------------
// Emulator menu
// ---------------------------------------------------------------------------
static void BuildEmulatorMenu()
{
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Emulator"];

    AddItem(menu, @"Reset",       IDM_FILE_RESET, @"r");
    AddItem(menu, @"Pause",       IDM_PAUSE,      @"p");
    AddSeparator(menu);

    // Machine model
    AddItem(menu, @"BBC Model B",           IDM_MODELB,     @"");
    AddItem(menu, @"BBC Model B (Int HW)",  IDM_MODELBINT,  @"");
    AddItem(menu, @"BBC Model B+",          IDM_MODELBPLUS, @"");
    AddItem(menu, @"Master 128",            IDM_MASTER128,  @"");
    AddItem(menu, @"Master ET",             IDM_MASTER_ET,  @"");
    AddSeparator(menu);

    // Tube
    NSMenu *tubeMenu = [[NSMenu alloc] initWithTitle:@"Second Processor"];
    AddItem(tubeMenu, @"None",          IDM_TUBE_NONE,       @"");
    AddItem(tubeMenu, @"Acorn 65C02",   IDM_TUBE_ACORN65C02, @"");
    AddItem(tubeMenu, @"Master 512",    IDM_TUBE_MASTER512,  @"");
    AddItem(tubeMenu, @"Acorn Z80",     IDM_TUBE_ACORNZ80,   @"");
    AddItem(tubeMenu, @"Torch Z80",     IDM_TUBE_TORCHZ80,   @"");
    AddItem(tubeMenu, @"Acorn ARM",     IDM_TUBE_ACORNARM,   @"");
    AddItem(tubeMenu, @"Sprow ARM7TDMI",IDM_TUBE_SPROWARM,   @"");
    NSMenuItem *tubeItem = [[NSMenuItem alloc] initWithTitle:@"Second Processor" action:nil keyEquivalent:@""];
    tubeItem.submenu = tubeMenu;
    [menu addItem:tubeItem];

    AddSeparator(menu);

    // Speed
    NSMenu *speedMenu = [[NSMenu alloc] initWithTitle:@"Speed"];
    AddItem(speedMenu, @"Real Time",    IDM_REALTIME,        @"");
    AddItem(speedMenu, @"50 fps",       IDM_50FPS,           @"");
    AddItem(speedMenu, @"25 fps",       IDM_25FPS,           @"");
    AddItem(speedMenu, @"10 fps",       IDM_10FPS,           @"");
    AddItem(speedMenu, @"5 fps",        IDM_5FPS,            @"");
    AddItem(speedMenu, @"1 fps",        IDM_1FPS,            @"");
    [speedMenu addItem:[NSMenuItem separatorItem]];
    AddItem(speedMenu, @"100×",         IDM_FIXEDSPEED100,   @"");
    AddItem(speedMenu, @"50×",          IDM_FIXEDSPEED50,    @"");
    AddItem(speedMenu, @"10×",          IDM_FIXEDSPEED10,    @"");
    AddItem(speedMenu, @"5×",           IDM_FIXEDSPEED5,     @"");
    AddItem(speedMenu, @"2×",           IDM_FIXEDSPEED2,     @"");
    AddItem(speedMenu, @"1.5×",         IDM_FIXEDSPEED1_5,   @"");
    AddItem(speedMenu, @"1.25×",        IDM_FIXEDSPEED1_25,  @"");
    AddItem(speedMenu, @"1.1×",         IDM_FIXEDSPEED1_1,   @"");
    AddItem(speedMenu, @"0.9×",         IDM_FIXEDSPEED0_9,   @"");
    AddItem(speedMenu, @"0.75×",        IDM_FIXEDSPEED0_75,  @"");
    AddItem(speedMenu, @"0.5×",         IDM_FIXEDSPEED0_5,   @"");
    AddItem(speedMenu, @"0.25×",        IDM_FIXEDSPEED0_25,  @"");
    AddItem(speedMenu, @"0.1×",         IDM_FIXEDSPEED0_1,   @"");
    NSMenuItem *speedItem = [[NSMenuItem alloc] initWithTitle:@"Speed" action:nil keyEquivalent:@""];
    speedItem.submenu = speedMenu;
    [menu addItem:speedItem];

    AddSeparator(menu);
    AddItem(menu, @"ROM Configuration…", IDM_ROMCONFIG, @"");
    AddItem(menu, @"Select User Data Folder…", IDM_SELECT_USER_DATA_FOLDER, @"");
    AddItem(menu, @"Select Hard Drive Folder…", IDM_SELECT_HARD_DRIVE_FOLDER, @"");

    NSMenuItem *emulatorItem = [[NSMenuItem alloc] initWithTitle:@"Emulator" action:nil keyEquivalent:@""];
    emulatorItem.submenu = menu;
    [[NSApp mainMenu] addItem:emulatorItem];
}

// ---------------------------------------------------------------------------
// Sound menu
// ---------------------------------------------------------------------------
static void BuildSoundMenu()
{
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Sound"];

    AddItem(menu, @"Sound On/Off",     IDM_SOUNDONOFF,  @"");
    AddItem(menu, @"Beeper",           IDM_SOUNDCHIP,   @"");
    AddItem(menu, @"Music 5000",       IDM_MUSIC5000,   @"");
    AddItem(menu, @"Disc Drive Sounds",IDM_SFX_DISCDRIVES, @"");
    AddItem(menu, @"Tape Sounds",      IDM_TAPESOUND,   @"");
    AddItem(menu, @"Relay Click",      IDM_SFX_RELAY,   @"");
    AddItem(menu, @"Part Samples",     IDM_PART_SAMPLES, @"");
    AddSeparator(menu);

    // Sample rate
    AddItem(menu, @"44100 Hz",  IDM_44100KHZ,  @"");
    AddItem(menu, @"22050 Hz",  IDM_22050KHZ,  @"");
    AddItem(menu, @"11025 Hz",  IDM_11025KHZ,  @"");
    AddSeparator(menu);

    // Volume
    AddItem(menu, @"Full Volume",    IDM_FULLVOLUME,   @"");
    AddItem(menu, @"High Volume",    IDM_HIGHVOLUME,   @"");
    AddItem(menu, @"Medium Volume",  IDM_MEDIUMVOLUME, @"");
    AddItem(menu, @"Low Volume",     IDM_LOWVOLUME,    @"");
    AddItem(menu, @"Expanded Volume",IDM_EXPVOLUME,    @"");

    NSMenuItem *soundItem = [[NSMenuItem alloc] initWithTitle:@"Sound" action:nil keyEquivalent:@""];
    soundItem.submenu = menu;
    [[NSApp mainMenu] addItem:soundItem];
}

// ---------------------------------------------------------------------------
// Display menu
// ---------------------------------------------------------------------------
static void BuildDisplayMenu()
{
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Display"];

    AddItem(menu, @"Full Screen",         IDM_FULLSCREEN,          @"f");
    AddItem(menu, @"Maintain Aspect Ratio",IDM_MAINTAINASPECTRATIO,@"");
    AddItem(menu, @"Show Speed & FPS",    IDM_SHOW_SPEED_AND_FPS,  @"");
    AddItem(menu, @"Freeze When Inactive",IDM_FREEZEINACTIVE,      @"");
    AddSeparator(menu);

    // Monitor type
    AddItem(menu, @"RGB Monitor",   IDM_MONITOR_RGB,   @"");
    AddItem(menu, @"B&W Monitor",   IDM_MONITOR_BW,    @"");
    AddItem(menu, @"Amber Monitor", IDM_MONITOR_AMBER, @"");
    AddItem(menu, @"Green Monitor", IDM_MONITOR_GREEN, @"");
    AddSeparator(menu);

    // Motion blur
    AddItem(menu, @"No Blur",       IDM_BLUR_OFF, @"");
    AddItem(menu, @"2× Blur",       IDM_BLUR_2,   @"");
    AddItem(menu, @"4× Blur",       IDM_BLUR_4,   @"");
    AddItem(menu, @"8× Blur",       IDM_BLUR_8,   @"");
    AddSeparator(menu);

    AddItem(menu, @"Teletext Half Mode", IDM_TELETEXTHALFMODE, @"");
    AddItem(menu, @"Teletext Source…",   IDM_SELECT_TELETEXT_DATA_SOURCE, @"");

    NSMenuItem *displayItem = [[NSMenuItem alloc] initWithTitle:@"Display" action:nil keyEquivalent:@""];
    displayItem.submenu = menu;
    [[NSApp mainMenu] addItem:displayItem];
}

// ---------------------------------------------------------------------------
// Keyboard menu
// ---------------------------------------------------------------------------
static void BuildKeyboardMenu()
{
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Keyboard"];

    AddItem(menu, @"User Keyboard Mapping",    IDM_USERKYBDMAPPING,   @"");
    AddItem(menu, @"Default Keyboard Mapping", IDM_DEFAULTKYBDMAPPING,@"");
    AddItem(menu, @"Logical Keyboard Mapping", IDM_LOGICALKYBDMAPPING,@"");
    AddSeparator(menu);
    AddItem(menu, @"Define Keyboard Mapping…", IDM_DEFINEKEYMAP,      @"");
    AddItem(menu, @"Load Keyboard Mapping…",   IDM_LOADKEYMAP,        @"");
    AddItem(menu, @"Save Keyboard Mapping…",   IDM_SAVEKEYMAP,        @"");
    AddSeparator(menu);
    AddItem(menu, @"Hide Cursor",              IDM_HIDECURSOR,        @"");
    AddItem(menu, @"Capture Mouse",            IDM_CAPTUREMOUSE,      @"");
    AddSeparator(menu);
    AddItem(menu, @"Disable Windows Keys",   IDM_DISABLEKEYSWINDOWS,  @"");
    AddItem(menu, @"Disable Break Key",      IDM_DISABLEKEYSBREAK,    @"");
    AddItem(menu, @"Disable Escape Key",     IDM_DISABLEKEYSESCAPE,   @"");
    AddItem(menu, @"Disable Shortcut Keys",  IDM_DISABLEKEYSSHORTCUT, @"");
    AddItem(menu, @"Disable All Modifier Keys",IDM_DISABLEKEYSALL,    @"");
    AddSeparator(menu);
    AddItem(menu, @"Set Keyboard Links…",    IDM_SET_KEYBOARD_LINKS,  @"");

    NSMenuItem *kbdItem = [[NSMenuItem alloc] initWithTitle:@"Keyboard" action:nil keyEquivalent:@""];
    kbdItem.submenu = menu;
    [[NSApp mainMenu] addItem:kbdItem];
}

// ---------------------------------------------------------------------------
// Hardware menu
// ---------------------------------------------------------------------------
static void BuildHardwareMenu()
{
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Hardware"];

    AddItem(menu, @"Floppy Drive",       IDM_FLOPPY_DRIVE,   @"");
    AddItem(menu, @"8271 FDC",           IDM_8271,           @"");
    AddItem(menu, @"SCSI Hard Drive",    IDM_SCSI_HARD_DRIVE,@"");
    AddItem(menu, @"IDE Hard Drive",     IDM_IDE_HARD_DRIVE, @"");
    AddItem(menu, @"Solidisk SWRAM",     IDM_SOLIDISK_SWRAM_BOARD, @"");
    AddSeparator(menu);
    AddItem(menu, @"AMX Mouse",          IDM_AMXONOFF,       @"");
    AddItem(menu, @"User Port RTC",      IDM_USER_PORT_RTC_MODULE, @"");
    AddItem(menu, @"User Port Breakout", IDM_BREAKOUT,       @"");
    AddSeparator(menu);
    AddItem(menu, @"Music 5000",         IDM_MUSIC5000,      @"");
    AddItem(menu, @"Teletext Adapter",   IDM_TELETEXT,       @"");
    AddItem(menu, @"Serial / IP232",     IDM_SERIAL,         @"");
    AddSeparator(menu);
    AddItem(menu, @"Write Protect Disc 0", IDM_WRITE_PROTECT_DISC0, @"");
    AddItem(menu, @"Write Protect Disc 1", IDM_WRITE_PROTECT_DISC1, @"");
    AddItem(menu, @"Write Protect on Load",IDM_WRITE_PROTECT_ON_LOAD,@"");

    NSMenuItem *hwItem = [[NSMenuItem alloc] initWithTitle:@"Hardware" action:nil keyEquivalent:@""];
    hwItem.submenu = menu;
    [[NSApp mainMenu] addItem:hwItem];
}

// ---------------------------------------------------------------------------
// Edit menu
// ---------------------------------------------------------------------------
static void BuildEditMenu()
{
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Edit"];

    AddItem(menu, @"Copy Screen Text", IDM_EDIT_COPY,  @"c");
    AddItem(menu, @"Paste",            IDM_EDIT_PASTE, @"v");
    AddItem(menu, @"Translate CR/LF",  IDM_TRANSLATE_CRLF, @"");
    AddSeparator(menu);
    AddItem(menu, @"Debugger",         IDM_SHOWDEBUGGER, @"d");

    NSMenuItem *editItem = [[NSMenuItem alloc] initWithTitle:@"Edit" action:nil keyEquivalent:@""];
    editItem.submenu = menu;
    [[NSApp mainMenu] addItem:editItem];
}

// ---------------------------------------------------------------------------
// Window menu (standard macOS)
// ---------------------------------------------------------------------------
static void BuildWindowMenu()
{
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Window"];

    NSMenuItem *minimize = [[NSMenuItem alloc] initWithTitle:@"Minimize"
                                                       action:@selector(performMiniaturize:)
                                                keyEquivalent:@"m"];
    [menu addItem:minimize];

    NSMenuItem *zoom = [[NSMenuItem alloc] initWithTitle:@"Zoom"
                                                   action:@selector(performZoom:)
                                            keyEquivalent:@""];
    [menu addItem:zoom];

    NSMenuItem *windowItem = [[NSMenuItem alloc] initWithTitle:@"Window" action:nil keyEquivalent:@""];
    windowItem.submenu = menu;
    [[NSApp mainMenu] addItem:windowItem];
    [NSApp setWindowsMenu:menu];
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

void BeebMenuBuild(id /*delegate*/)
{
    s_target = [[BeebMenuTarget alloc] init];

    NSMenu *mainMenu = [[NSMenu alloc] initWithTitle:@"MainMenu"];
    [NSApp setMainMenu:mainMenu];

    BuildAppMenu();
    BuildFileMenu();
    BuildEditMenu();
    BuildEmulatorMenu();
    BuildSoundMenu();
    BuildDisplayMenu();
    BuildKeyboardMenu();
    BuildHardwareMenu();
    BuildWindowMenu();
}

static NSMenuItem *FindItemDeep(NSMenu *menu, NSInteger tag)
{
    for (NSMenuItem *item in menu.itemArray) {
        if (item.tag == tag) return item;
        if (item.submenu) {
            NSMenuItem *found = FindItemDeep(item.submenu, tag);
            if (found) return found;
        }
    }
    return nil;
}

void BeebMenuSetChecked(int menuID, bool checked)
{
    if (!s_target) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSMenuItem *item = FindItemDeep([NSApp mainMenu], menuID);
        if (item) item.state = checked ? NSControlStateValueOn : NSControlStateValueOff;
    });
}

void BeebMenuSetEnabled(int menuID, bool enabled)
{
    if (!s_target) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSMenuItem *item = FindItemDeep([NSApp mainMenu], menuID);
        if (item) item.enabled = enabled;
    });
}

void BeebMenuSetText(int menuID, const char *text)
{
    if (!s_target || !text) return;
    NSString *ns = [NSString stringWithUTF8String:text];
    dispatch_async(dispatch_get_main_queue(), ^{
        NSMenuItem *item = FindItemDeep([NSApp mainMenu], menuID);
        if (item) item.title = ns;
    });
}
