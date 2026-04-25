/****************************************************************
BeebEm - BBC Micro and Master 128 Emulator
macOS platform layer — replaces Sdl.cpp on Apple builds.

Provides:
  • 8-bit indexed video buffer (g_videoBuffer) that Video.cpp writes into
  • 256-entry BGRA palette (g_paletteBGRA) expanded by SetBeebEmEmulatorCoresPalette()
  • Sound ring buffer (same API as Sdl.cpp so Sound.cpp is unchanged)
  • SaferSleep / GetTickCount helpers
  • SetWindowTitle forwarded to NSWindow
****************************************************************/

#import <Cocoa/Cocoa.h>
#import <ImageIO/ImageIO.h>
#include <unistd.h>
#include <mach/mach_time.h>
#include <string.h>
#include <vector>

#include "MacPlatform.h"
#include "RomConfigFile.h"
#include "Model.h"

// ------------------------------------------------------------------
// Video buffer — 800×600 8-bit indexed (same size as Sdl.cpp's video_output).
// BeebRenderer reads the first 800×512 rows for display.
// ------------------------------------------------------------------
uint8_t  g_videoBuffer[BEEBEM_VIDEO_CORE_SCREEN_WIDTH * BEEBEM_VIDEO_CORE_SCREEN_HEIGHT];

// ------------------------------------------------------------------
// Palette — 256 BGRA entries.
// Index 0–7: BBC pixel colours.  Index 64–67: LED colours.
// ------------------------------------------------------------------
uint32_t g_paletteBGRA[256];

// ------------------------------------------------------------------
// Global config booleans
// ------------------------------------------------------------------
bool cfg_EmulateCrtGraphics = false;
bool cfg_EmulateCrtTeletext = false;
bool cfg_WantLowLatencySound = true;

int cfg_Windowed_Resolution  = RESOLUTION_640X512;
int cfg_Fullscreen_Resolution = RESOLUTION_640X512;
int cfg_VerticalOffset = 0;

// ------------------------------------------------------------------
// Sound ring buffer (mirrors Sdl.cpp implementation exactly)
// ------------------------------------------------------------------
#define SOUND_BUFFER_SIZE (1024 * 100)

static uint8_t  s_soundBuf[SOUND_BUFFER_SIZE];
static unsigned long s_soundIn  = 0;
static unsigned long s_soundOut = 0;
static unsigned long s_soundHave = 0;

// Number of samples CoreAudio requests per callback (set during init).
static int s_audioSamples = 1024;

void InitializeSoundBuffer()
{
    s_soundIn = s_soundOut = s_soundHave = 0;
    memset(s_soundBuf, 0, sizeof(s_soundBuf));
}

void AddBytesToSDLSoundBuffer(void *p, int len)
{
    const uint8_t *pp = (const uint8_t *)p;
    for (int i = 0; i < len; ++i) {
        s_soundBuf[s_soundIn] = *pp++;
        if (++s_soundIn >= SOUND_BUFFER_SIZE) s_soundIn = 0;
    }
    s_soundHave += len;
}

unsigned long HowManyBytesLeftInSDLSoundBuffer()
{
    return s_soundHave;
}

int GetBytesFromSDLSoundBuffer(int len, uint8_t *dst)
{
    if ((unsigned long)len > s_soundHave) len = (int)s_soundHave;

    for (int i = 0; i < len; ++i) {
        dst[i] = s_soundBuf[s_soundOut];
        if (++s_soundOut >= SOUND_BUFFER_SIZE) s_soundOut = 0;
    }
    s_soundHave -= len;

    // Drop excess samples if latency grows too large (matches Sdl.cpp behaviour).
    if (cfg_WantLowLatencySound && s_soundHave > (unsigned long)(s_audioSamples * 5)) {
        CatchupSound();
    }

    return len;
}

void CatchupSound()
{
    while (s_soundHave > (unsigned long)(s_audioSamples * 2)) {
        if (++s_soundOut >= SOUND_BUFFER_SIZE) s_soundOut = 0;
        --s_soundHave;
    }
}

// ------------------------------------------------------------------
// Video
// ------------------------------------------------------------------
unsigned char *GetSDLScreenLinePtr(int line)
{
    if (line < 0) line = 0;
    if (line >= BEEBEM_VIDEO_CORE_SCREEN_HEIGHT)
        line = BEEBEM_VIDEO_CORE_SCREEN_HEIGHT - 1;
    return g_videoBuffer + line * BEEBEM_VIDEO_CORE_SCREEN_WIDTH;
}

static inline uint32_t makeBGRA(uint8_t r, uint8_t g, uint8_t b)
{
    return (0xFFu << 24) | ((uint32_t)r << 16) | ((uint32_t)g << 8) | b;
}

void SetBeebEmEmulatorCoresPalette(unsigned char *cols, MonitorType monitor)
{
    // Fill the index array (Video.cpp expects indices 0..7).
    for (int i = 0; i < 8; ++i) cols[i] = (unsigned char)i;

    // Build the BGRA palette for the 8 BBC colours.
    for (int i = 0; i < 8; ++i) {
        float r = (float)(i & 1)       * 255.0f;
        float g = (float)((i >> 1) & 1) * 255.0f;
        float b = (float)((i >> 2) & 1) * 255.0f;

        switch (monitor) {
            case MonitorType::Amber:
                r *= 1.0f; g *= 0.8f; b *= 0.1f; break;
            case MonitorType::Green:
                r *= 0.2f; g *= 0.9f; b *= 0.1f; break;
            case MonitorType::BW:
                r = g = b = 0.299f*r + 0.587f*g + 0.114f*b; break;
            default: break;
        }

        g_paletteBGRA[i] = makeBGRA((uint8_t)r, (uint8_t)g, (uint8_t)b);
    }

    // LED colours at indices 64–67.
    g_paletteBGRA[64] = makeBGRA(127, 0, 0);
    g_paletteBGRA[65] = makeBGRA(255, 0, 0);
    g_paletteBGRA[66] = makeBGRA(0, 127, 0);
    g_paletteBGRA[67] = makeBGRA(0, 255, 0);

    // Menu/GUI colours at 68–71 (grey shades).
    uint8_t base = 127 + 64;
    g_paletteBGRA[68] = makeBGRA(base, base, base);
    g_paletteBGRA[69] = makeBGRA(base*2/3, base*2/3, base*2/3);
    g_paletteBGRA[70] = makeBGRA(255, 255, 255);
    g_paletteBGRA[71] = makeBGRA(base*9/10, base*9/10, base*9/10);
}

// RenderLine is a no-op on macOS — BeebRenderer uploads the whole buffer each frame.
void RenderLine(int /*line*/, bool /*isTeletext*/, int /*xoffset*/) {}

void ClearVideoWindow()
{
    memset(g_videoBuffer, 0, sizeof(g_videoBuffer));
}

// ------------------------------------------------------------------
// Window title
// ------------------------------------------------------------------
void SetWindowTitle(const char *pszTitle)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSApp.mainWindow.title = [NSString stringWithUTF8String:pszTitle];
    });
}

// ------------------------------------------------------------------
// Timing
// ------------------------------------------------------------------
void SaferSleep(unsigned int milliseconds)
{
    if (milliseconds == 0) return;
    usleep(milliseconds * 1000u);
}

// ------------------------------------------------------------------
// Dialog / reporting
// ------------------------------------------------------------------
int MacReport(int type, const char *title, const char *message)
{
    __block int result = 1;
    void (^showAlert)(void) = ^{
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText     = [NSString stringWithUTF8String:title   ? title   : "BeebEm"];
        alert.informativeText = [NSString stringWithUTF8String:message ? message : ""];

        if (type == 2) { // question: Yes / No
            [alert addButtonWithTitle:@"Yes"];
            [alert addButtonWithTitle:@"No"];
            alert.alertStyle = NSAlertStyleWarning;
            result = ([alert runModal] == NSAlertFirstButtonReturn) ? 1 : 0;
        } else if (type == 3) { // confirm: OK / Cancel
            [alert addButtonWithTitle:@"OK"];
            [alert addButtonWithTitle:@"Cancel"];
            alert.alertStyle = NSAlertStyleWarning;
            result = ([alert runModal] == NSAlertFirstButtonReturn) ? 1 : 0;
        } else {
            alert.alertStyle = (type == 0) ? NSAlertStyleCritical : NSAlertStyleInformational;
            [alert addButtonWithTitle:@"OK"];
            [alert runModal];
            result = 1;
        }
    };

    if ([NSThread isMainThread]) {
        showAlert();
    } else {
        dispatch_sync(dispatch_get_main_queue(), showAlert);
    }
    return result;
}

// ------------------------------------------------------------------
// Lifecycle
// ------------------------------------------------------------------
bool MacPlatformInit(int soundFrequency)
{
    s_audioSamples = 1024;  // matches REQUESTED_NUMBER_OF_SAMPLES in Sdl.cpp
    (void)soundFrequency;

    memset(g_videoBuffer, 0, sizeof(g_videoBuffer));
    memset(g_paletteBGRA, 0, sizeof(g_paletteBGRA));
    InitializeSoundBuffer();
    return true;
}

void MacPlatformFree()
{
    // Nothing to release.
}

int MacGetClipboardText(char *buf, int maxLen)
{
    __block int result = 0;
    void (^readPaste)(void) = ^{
        NSPasteboard *pb = [NSPasteboard generalPasteboard];
        NSString *str = [pb stringForType:NSPasteboardTypeString];
        if (str && maxLen > 0) {
            const char *utf8 = [str UTF8String];
            int len = (int)strlen(utf8);
            if (len > maxLen) len = maxLen;
            memcpy(buf, utf8, (size_t)len);
            result = len;
        }
    };
    if ([NSThread isMainThread]) readPaste();
    else dispatch_sync(dispatch_get_main_queue(), readPaste);
    return result;
}

const char *GetBundleResourcesPath()
{
    static char s_path[4096] = {};
    if (s_path[0] == '\0') {
        NSString *rp = [[NSBundle mainBundle] resourcePath];
        strlcpy(s_path, [rp UTF8String], sizeof(s_path));
    }
    return s_path;
}

// ------------------------------------------------------------------
// ROM Configuration Dialog
// ------------------------------------------------------------------

static void RunOnMainThread(void (^block)(void));  // forward declaration

static std::string RomRelativeToBeebFile(const std::string& absPath,
                                          const std::string& udPath)
{
    std::string prefix = udPath + "/BeebFile/";
    if (absPath.size() > prefix.size() &&
        absPath.compare(0, prefix.size(), prefix) == 0)
        return absPath.substr(prefix.size());
    return absPath;
}

@interface _BeebRomCfgCtrl : NSObject <NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate>
@end

@implementation _BeebRomCfgCtrl {
    RomConfigFile *_cfg;
    int            _model;
    NSWindow      *_win;
    NSTableView   *_table;
    NSPopUpButton *_pop;
    NSString      *_udPath;
    BOOL           _accepted;
    BOOL           _stopped;
}

- (instancetype)initWithConfig:(const RomConfigFile&)cfg userDataPath:(const char*)udp
{
    if (!(self = [super init])) return nil;
    _cfg      = new RomConfigFile(cfg);
    _model    = 0;
    _udPath   = udp ? [NSString stringWithUTF8String:udp] : @"";
    _accepted = NO;
    _stopped  = NO;
    [self buildWindow];
    return self;
}

- (void)dealloc { delete _cfg; }

- (NSButton *)makeButton:(NSString *)title x:(CGFloat)x y:(CGFloat)y w:(CGFloat)w sel:(SEL)sel
{
    NSButton *b = [NSButton buttonWithTitle:title target:self action:sel];
    b.frame = NSMakeRect(x, y, w, 28);
    return b;
}

- (void)buildWindow
{
    const CGFloat W = 540, H = 460;
    _win = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, W, H)
        styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
        backing:NSBackingStoreBuffered
        defer:NO];
    _win.title = @"ROM Configuration";
    _win.releasedWhenClosed = NO;
    _win.delegate = self;

    NSView *cv = _win.contentView;

    // Model label + popup (top strip)
    NSTextField *lbl = [NSTextField labelWithString:@"Model:"];
    lbl.frame = NSMakeRect(12, H - 38, 50, 22);
    [cv addSubview:lbl];

    _pop = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(66, H - 40, 220, 26) pullsDown:NO];
    for (int i = 0; i < MODEL_COUNT; i++)
        [_pop addItemWithTitle:[NSString stringWithUTF8String:GetModelName((Model)i)]];
    [_pop setTarget:self];
    [_pop setAction:@selector(modelChanged:)];
    [cv addSubview:_pop];

    // ROM slot table
    NSScrollView *sv = [[NSScrollView alloc]
        initWithFrame:NSMakeRect(12, 118, W - 24, H - 168)];
    sv.hasVerticalScroller   = YES;
    sv.hasHorizontalScroller = NO;
    sv.autohidesScrollers    = YES;

    _table = [[NSTableView alloc] initWithFrame:sv.bounds];
    _table.usesAlternatingRowBackgroundColors = YES;
    _table.columnAutoresizingStyle =
        NSTableViewLastColumnOnlyAutoresizingStyle;
    _table.dataSource = self;
    _table.delegate   = self;

    NSTableColumn *cSlot = [[NSTableColumn alloc] initWithIdentifier:@"slot"];
    cSlot.title    = @"Slot";
    cSlot.width    = 55;
    cSlot.editable = NO;
    [_table addTableColumn:cSlot];

    NSTableColumn *cRom = [[NSTableColumn alloc] initWithIdentifier:@"rom"];
    cRom.title    = @"ROM File";
    cRom.width    = 430;
    cRom.editable = NO;
    [_table addTableColumn:cRom];

    sv.documentView = _table;
    [cv addSubview:sv];

    // Slot action buttons
    NSView *r1 = [self makeButton:@"Set ROM…"  x:12  y:82 w:90 sel:@selector(setRom:)];
    NSView *r2 = [self makeButton:@"Set EMPTY" x:112 y:82 w:92 sel:@selector(setEmpty:)];
    NSView *r3 = [self makeButton:@"Set RAM"   x:214 y:82 w:82 sel:@selector(setRam:)];
    [cv addSubview:r1]; [cv addSubview:r2]; [cv addSubview:r3];

    // Config file buttons
    NSView *c1 = [self makeButton:@"Load Config…" x:12  y:48 w:110 sel:@selector(loadConfig:)];
    NSView *c2 = [self makeButton:@"Save Config…" x:132 y:48 w:110 sel:@selector(saveConfig:)];
    [cv addSubview:c1]; [cv addSubview:c2];

    // OK / Cancel
    NSButton *ok = [self makeButton:@"OK" x:W-90 y:12 w:78 sel:@selector(okClicked:)];
    ok.keyEquivalent = @"\r";
    [cv addSubview:ok];
    NSButton *cancel = [self makeButton:@"Cancel" x:W-180 y:12 w:80 sel:@selector(cancelClicked:)];
    cancel.keyEquivalent = @"\033";
    [cv addSubview:cancel];
}

// NSTableViewDataSource
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv
{
    (void)tv;
    return ROM_BANK_COUNT + 1;
}

- (id)tableView:(NSTableView *)tv
    objectValueForTableColumn:(NSTableColumn *)col
    row:(NSInteger)row
{
    (void)tv;
    if ([col.identifier isEqualToString:@"slot"])
        return (row == 0) ? @"OS" :
            [NSString stringWithFormat:@"Bank %d", ROM_BANK_COUNT - (int)row];
    const std::string& fn = _cfg->GetFileName((Model)_model, (int)row);
    return [NSString stringWithUTF8String:fn.c_str()];
}

// Actions
- (void)modelChanged:(id)sender
{
    (void)sender;
    _model = (int)[_pop indexOfSelectedItem];
    [_table reloadData];
}

- (void)setRom:(id)sender
{
    (void)sender;
    NSInteger row = _table.selectedRow;
    if (row < 0) { [self alertNoSelection]; return; }

    NSOpenPanel *p = [NSOpenPanel openPanel];
    p.canChooseFiles          = YES;
    p.canChooseDirectories    = NO;
    p.allowsMultipleSelection = NO;
    p.message                 = @"Choose ROM file";
    p.directoryURL = [NSURL fileURLWithPath:
        [_udPath stringByAppendingPathComponent:@"BeebFile"]];

    if ([p runModal] == NSModalResponseOK) {
        std::string chosen = p.URL.fileSystemRepresentation;
        std::string rel = RomRelativeToBeebFile(chosen, [_udPath UTF8String]);
        _cfg->SetFileName((Model)_model, (int)row, rel);
        [_table reloadData];
    }
}

- (void)setEmpty:(id)sender
{
    (void)sender;
    NSInteger row = _table.selectedRow;
    if (row < 0) { [self alertNoSelection]; return; }
    _cfg->SetFileName((Model)_model, (int)row, BANK_EMPTY);
    [_table reloadData];
}

- (void)setRam:(id)sender
{
    (void)sender;
    NSInteger row = _table.selectedRow;
    if (row < 0) { [self alertNoSelection]; return; }
    _cfg->SetFileName((Model)_model, (int)row, BANK_RAM);
    [_table reloadData];
}

- (void)loadConfig:(id)sender
{
    (void)sender;
    NSOpenPanel *p = [NSOpenPanel openPanel];
    p.canChooseFiles = YES;
    p.message        = @"Load ROM configuration file";
    p.directoryURL   = [NSURL fileURLWithPath:_udPath];
    if ([p runModal] == NSModalResponseOK) {
        _cfg->Load(p.URL.fileSystemRepresentation);
        [_table reloadData];
    }
}

- (void)saveConfig:(id)sender
{
    (void)sender;
    NSSavePanel *p = [NSSavePanel savePanel];
    p.message              = @"Save ROM configuration file";
    p.canCreateDirectories = YES;
    p.directoryURL         = [NSURL fileURLWithPath:_udPath];
    if ([p runModal] == NSModalResponseOK)
        _cfg->Save(p.URL.fileSystemRepresentation);
}

- (void)okClicked:(id)sender     { (void)sender; _accepted = YES; [self stopModal]; }
- (void)cancelClicked:(id)sender { (void)sender; _accepted = NO;  [self stopModal]; }

// NSWindowDelegate — treat close button as cancel
- (BOOL)windowShouldClose:(NSWindow *)sender
{
    (void)sender;
    [self cancelClicked:nil];
    return NO;
}

- (BOOL)runModal
{
    [_win center];
    [NSApp runModalForWindow:_win];
    [_win orderOut:nil];
    return _accepted;
}

- (RomConfigFile)result { return *_cfg; }

- (void)stopModal
{
    if (!_stopped) {
        _stopped = YES;
        [NSApp stopModal];
    }
}

- (void)alertNoSelection
{
    NSAlert *a = [[NSAlert alloc] init];
    a.messageText     = @"No slot selected";
    a.informativeText = @"Select a ROM slot in the table first.";
    [a addButtonWithTitle:@"OK"];
    [a runModal];
}

@end

bool MacEditRomConfig(RomConfigFile& config, const char *userDataPath)
{
    __block bool result = false;
    RunOnMainThread(^{
        _BeebRomCfgCtrl *ctrl = [[_BeebRomCfgCtrl alloc]
            initWithConfig:config userDataPath:userDataPath];
        if ([ctrl runModal]) {
            config = [ctrl result];
            result = true;
        }
    });
    return result;
}

// ------------------------------------------------------------------
// Screen capture
// ------------------------------------------------------------------

static void RunOnMainThread(void (^block)(void))
{
    if ([NSThread isMainThread]) block();
    else dispatch_sync(dispatch_get_main_queue(), block);
}

bool MacGetImageSavePath(char *outPath, int maxLen, const char *extension)
{
    __block bool result = false;

    RunOnMainThread(^{
        NSSavePanel *panel = [NSSavePanel savePanel];
        panel.canCreateDirectories = YES;
        panel.message = @"Save screen capture";

        NSString *ext = [NSString stringWithUTF8String:extension + 1]; // skip leading '.'
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        panel.allowedFileTypes = @[ext];
#pragma clang diagnostic pop
        panel.nameFieldStringValue = [@"BeebEm"
            stringByAppendingString:[NSString stringWithUTF8String:extension]];

        if ([panel runModal] == NSModalResponseOK) {
            strlcpy(outPath, panel.URL.fileSystemRepresentation, (size_t)maxLen);
            result = true;
        }
    });

    return result;
}

bool MacCaptureBitmap(const char *filename,
                      int srcX, int srcY, int srcW, int srcH,
                      int canvasW, int canvasH,
                      int dstX, int dstY, int dstW, int dstH,
                      const char *imageTypeUTI)
{
    const int fullW = BEEBEM_VIDEO_CORE_SCREEN_WIDTH;

    // Build BGRA canvas (Y-down, row 0 = screen top); fill opaque black.
    std::vector<uint32_t> canvas((size_t)(canvasW * canvasH), 0xFF000000u);

    // Nearest-neighbour crop + scale from g_videoBuffer into canvas.
    for (int dy = 0; dy < dstH; ++dy) {
        int sy = srcY + dy * srcH / dstH;
        const uint8_t *srcRow = g_videoBuffer + (size_t)(sy * fullW);
        uint32_t      *dstRow = canvas.data() + (size_t)((dstY + dy) * canvasW + dstX);
        for (int dx = 0; dx < dstW; ++dx) {
            int sx = srcX + dx * srcW / dstW;
            dstRow[dx] = g_paletteBGRA[srcRow[sx]];
        }
    }

    // Create CGImage from the BGRA canvas.
    // kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst matches our BGRA layout:
    // byte[0]=B, byte[1]=G, byte[2]=R, byte[3]=skipped-alpha.
    CGDataProviderRef provider = CGDataProviderCreateWithData(
        nullptr, canvas.data(), (size_t)(canvasW * canvasH * 4),
        [](void *, const void *, size_t) {}
    );

    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGImageRef img = CGImageCreate(
        (size_t)canvasW, (size_t)canvasH,
        8, 32, (size_t)(canvasW * 4),
        cs,
        kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst,
        provider, nullptr, false, kCGRenderingIntentDefault
    );
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(cs);

    if (!img) return false;

    CFURLRef url = CFURLCreateFromFileSystemRepresentation(
        nullptr, (const UInt8 *)filename, (CFIndex)strlen(filename), false
    );
    CFStringRef uti = CFStringCreateWithCString(nullptr, imageTypeUTI, kCFStringEncodingUTF8);
    CGImageDestinationRef dest = CGImageDestinationCreateWithURL(url, uti, 1, nullptr);
    CFRelease(uti);
    CFRelease(url);

    bool ok = false;
    if (dest) {
        CGImageDestinationAddImage(dest, img, nullptr);
        ok = (bool)CGImageDestinationFinalize(dest);
        CFRelease(dest);
    }

    CGImageRelease(img);
    return ok;
}
