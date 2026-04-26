/****************************************************************
BeebEm - BBC Micro and Master 128 Emulator
BeebMetalView — MTKView subclass that handles keyboard & mouse input.
Keyboard events are translated to BBC key matrix (row, col) and
forwarded to BeebKeyDown / BeebKeyUp in the emulator core.
****************************************************************/

#import "BeebMetalView.h"
#include "macos/MacPlatform.h"

// Windows types must come before BeebWin.h
#include "Windows.h"
#include "6502core.h"
#include "BeebWin.h"
#include "SysVia.h"    // BeebKeyDown / BeebKeyUp
#include "Main.h"
#include "UserVia.h"   // AMXButtons declaration

extern BeebWin *mainWin;

#define AMX_LEFT_BUTTON   0x01
#define AMX_MIDDLE_BUTTON 0x02
#define AMX_RIGHT_BUTTON 0x04

struct HeldKey {
    int row;
    int col;
    int repeat_counter;
    bool is_repeat;
};

static const int KEY_REPEAT_DELAY = 50;
static const int KEY_REPEAT_INTERVAL = 5;
static const int MAX_HELD_KEYS = 16;
static HeldKey m_HeldKeys[MAX_HELD_KEYS];
static int m_NumHeldKeys = 0;

void ProcessKeyRepeat()
{
    for (int i = 0; i < m_NumHeldKeys; i++)
    {
        HeldKey& key = m_HeldKeys[i];
        if (!key.is_repeat)
        {
            key.repeat_counter++;
            if (key.repeat_counter >= KEY_REPEAT_DELAY)
            {
                key.is_repeat = true;
                key.repeat_counter = 0;
            }
        }
        else
        {
            key.repeat_counter++;
            if (key.repeat_counter >= KEY_REPEAT_INTERVAL)
            {
                BeebKeyUp(key.row, key.col);
                BeebKeyDown(key.row, key.col);
                key.repeat_counter = 0;
            }
        }
    }
}

void AddHeldKey(int row, int col)
{
    if (row < 0 || col < 0 || m_NumHeldKeys >= MAX_HELD_KEYS)
        return;

    for (int i = 0; i < m_NumHeldKeys; i++)
    {
        if (m_HeldKeys[i].row == row && m_HeldKeys[i].col == col)
            return;
    }

    m_HeldKeys[m_NumHeldKeys].row = row;
    m_HeldKeys[m_NumHeldKeys].col = col;
    m_HeldKeys[m_NumHeldKeys].repeat_counter = 0;
    m_HeldKeys[m_NumHeldKeys].is_repeat = false;
    m_NumHeldKeys++;
}

void RemoveHeldKey(int row, int col)
{
    for (int i = 0; i < m_NumHeldKeys; i++)
    {
        if (m_HeldKeys[i].row == row && m_HeldKeys[i].col == col)
        {
            for (int j = i; j < m_NumHeldKeys - 1; j++)
            {
                m_HeldKeys[j] = m_HeldKeys[j + 1];
            }
            m_NumHeldKeys--;
            break;
        }
    }
}

// ------------------------------------------------------------------
// macOS virtual key code → BBC key matrix table
// Based on the SDL keymap in Sdl.cpp, re-mapped to Mac VKs.
// ------------------------------------------------------------------
struct MacBeebKeyTrans {
    unsigned short vkCode;
    int row;
    int col;
};

// Mac VK constants (from Carbon / IOKit, stable values)
static const unsigned short
    MVK_A=0x00, MVK_S=0x01, MVK_D=0x02, MVK_F=0x03, MVK_H=0x04,
    MVK_G=0x05, MVK_Z=0x06, MVK_X=0x07, MVK_C=0x08, MVK_V=0x09,
    MVK_B=0x0B, MVK_Q=0x0C, MVK_W=0x0D, MVK_E=0x0E, MVK_R=0x0F,
    MVK_Y=0x10, MVK_T=0x11,
    MVK_1=0x12, MVK_2=0x13, MVK_3=0x14, MVK_4=0x15,
    MVK_6=0x16, MVK_5=0x17, MVK_Equal=0x18, MVK_9=0x19,
    MVK_7=0x1A, MVK_Minus=0x1B, MVK_8=0x1C, MVK_0=0x1D,
    MVK_RightBracket=0x1E, MVK_O=0x1F, MVK_U=0x20, MVK_LeftBracket=0x21,
    MVK_I=0x22, MVK_P=0x23, MVK_Return=0x24,
    MVK_L=0x25, MVK_J=0x26, MVK_Quote=0x27, MVK_K=0x28,
    MVK_Semicolon=0x29, MVK_Backslash=0x2A, MVK_Comma=0x2B,
    MVK_Slash=0x2C, MVK_N=0x2D, MVK_M=0x2E, MVK_Period=0x2F,
    MVK_Tab=0x30, MVK_Space=0x31, MVK_Grave=0x32,
    MVK_Delete=0x33, MVK_Escape=0x35,
    MVK_RightCmd=0x36, MVK_Command=0x37,
    MVK_Shift=0x38, MVK_CapsLock=0x39, MVK_Option=0x3A,
    MVK_Control=0x3B, MVK_RightShift=0x3C, MVK_RightOption=0x3D,
    MVK_RightControl=0x3E,
    MVK_ForwardDelete=0x75,
    MVK_End=0x77,
    MVK_F1=0x7A, MVK_F2=0x78, MVK_F3=0x63, MVK_F4=0x76,
    MVK_F5=0x60, MVK_F6=0x61, MVK_F7=0x62, MVK_F8=0x64,
    MVK_F9=0x65, MVK_F10=0x6D, MVK_F11=0x67,
    MVK_Left=0x7B, MVK_Right=0x7C, MVK_Down=0x7D, MVK_Up=0x7E;

static const MacBeebKeyTrans kMacToBeeb[] = {
    { MVK_Tab,           6, 0 },   // TAB
    { MVK_Return,        4, 9 },   // RETURN
    { MVK_Control,       0, 1 },   // CONTROL
    { MVK_RightControl,  0, 1 },
    { MVK_Shift,         0, 0 },   // SHIFT
    { MVK_RightShift,    0, 0 },
    { MVK_CapsLock,      4, 0 },   // CAPS LOCK
    { MVK_Escape,        7, 0 },   // ESCAPE
    { MVK_Space,         6, 2 },   // SPACE
    { MVK_Left,          1, 9 },   // LEFT
    { MVK_Up,            3, 9 },   // UP
    { MVK_Right,         7, 9 },   // RIGHT
    { MVK_Down,          2, 9 },   // DOWN
    { MVK_Delete,        5, 9 },   // DELETE (backspace)
    { MVK_ForwardDelete, 5, 9 },   // DELETE
    { MVK_End,           6, 9 },   // COPY
    { MVK_0,             2, 7 },
    { MVK_1,             3, 0 },
    { MVK_2,             3, 1 },
    { MVK_3,             1, 1 },
    { MVK_4,             1, 2 },
    { MVK_5,             1, 3 },
    { MVK_6,             3, 4 },
    { MVK_7,             2, 4 },
    { MVK_8,             1, 5 },
    { MVK_9,             2, 6 },
    { MVK_A,             4, 1 },
    { MVK_B,             6, 4 },
    { MVK_C,             5, 2 },
    { MVK_D,             3, 2 },
    { MVK_E,             2, 2 },
    { MVK_F,             4, 3 },
    { MVK_G,             5, 3 },
    { MVK_H,             5, 4 },
    { MVK_I,             2, 5 },
    { MVK_J,             4, 5 },
    { MVK_K,             4, 6 },
    { MVK_L,             5, 6 },
    { MVK_M,             6, 5 },
    { MVK_N,             5, 5 },
    { MVK_O,             3, 6 },
    { MVK_P,             3, 7 },
    { MVK_Q,             1, 0 },
    { MVK_R,             3, 3 },
    { MVK_S,             5, 1 },
    { MVK_T,             2, 3 },
    { MVK_U,             3, 5 },
    { MVK_V,             6, 3 },
    { MVK_W,             2, 1 },
    { MVK_X,             4, 2 },
    { MVK_Y,             4, 4 },
    { MVK_Z,             6, 1 },
    { MVK_F10,           2, 0 },   // BBC f0
    { MVK_F1,            7, 1 },
    { MVK_F2,            7, 2 },
    { MVK_F3,            7, 3 },
    { MVK_F4,            1, 4 },
    { MVK_F5,            7, 4 },
    { MVK_F6,            7, 5 },
    { MVK_F7,            1, 6 },
    { MVK_F8,            7, 6 },
    { MVK_F9,            7, 7 },
    { MVK_Minus,         5, 7 },   // "+" / ";"
    { MVK_Comma,         6, 6 },   // "<" / ","
    { MVK_Equal,         1, 7 },   // "=" / "-"
    { MVK_Period,        6, 7 },   // ">" / "."
    { MVK_Grave,         2, 8 },   // "-" / "¬"
    { MVK_Semicolon,     4, 7 },   // "@"
    { MVK_Quote,         4, 8 },   // "*" / ":"
    { MVK_Slash,         6, 8 },   // "/" / "?"
    { MVK_Backslash,     7, 8 },   // "\" / "|"
    { MVK_F11,          -2,-2 },   // BREAK
    { MVK_LeftBracket,   3, 8 },   // "["
    { MVK_RightBracket,  5, 8 },   // "]"
    { 0xFFFF,           -1,-1 }    // sentinel
};

static bool TranslateMacKey(unsigned short vk, int *row, int *col)
{
    for (const MacBeebKeyTrans *p = kMacToBeeb; p->vkCode != 0xFFFF; ++p) {
        if (p->vkCode == vk) {
            *row = p->row;
            *col = p->col;
            return true;
        }
    }
    return false;
}

// ------------------------------------------------------------------
@implementation BeebMetalView

- (instancetype)initWithFrame:(CGRect)frame device:(id<MTLDevice>)device
{
    self = [super initWithFrame:frame device:device];
    if (self) {
        self.colorPixelFormat  = MTLPixelFormatBGRA8Unorm;
        self.preferredFramesPerSecond = 60;
        self.enableSetNeedsDisplay = NO;  // continuous rendering
        self.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
    }
    return self;
}

- (BOOL)acceptsFirstResponder { return YES; }
- (BOOL)canBecomeKeyView      { return YES; }

// ------------------------------------------------------------------
// Keyboard
// ------------------------------------------------------------------
- (void)keyDown:(NSEvent *)event
{
    // macOS auto-repeats keyDown; we now handle repeat internally synchronized
    // with the display frame rate to work correctly at all FPS settings.
    if (event.isARepeat) {
        // Track auto-repeated key press - continue tracking but don't re-add
        int row, col;
        if (TranslateMacKey(event.keyCode, &row, &col) && row >= 0) {
            AddHeldKey(row, col);
        }
        return;
    }

    int row, col;
    if (TranslateMacKey(event.keyCode, &row, &col)) {
        if (row == -2) {
            // BREAK key
            if (mainWin) mainWin->Break();
            return;
        }
        if (mainWin && mainWin->m_ShiftBooted) {
            mainWin->m_ShiftBooted = false;
            BeebKeyUp(0, 0);
        }
        BeebKeyDown(row, col);
        if (row >= 0) AddHeldKey(row, col);
    }
}

- (void)keyUp:(NSEvent *)event
{
    int row, col;
    if (TranslateMacKey(event.keyCode, &row, &col) && row >= 0) {
        BeebKeyUp(row, col);
        RemoveHeldKey(row, col);
    }
}

- (void)flagsChanged:(NSEvent *)event
{
    // Handle modifier keys (Shift, Control, CapsLock).
    NSEventModifierFlags flags = event.modifierFlags;

    auto applyMod = [](bool pressed, int row, int col) {
        if (pressed) {
            BeebKeyDown(row, col);
            AddHeldKey(row, col);
        }
        else {
            BeebKeyUp(row, col);
            RemoveHeldKey(row, col);
        }
    };

    applyMod((flags & NSEventModifierFlagShift)   != 0, 0, 0); // SHIFT
    applyMod((flags & NSEventModifierFlagControl) != 0, 0, 1); // CTRL
    // CapsLock is stateful — only fire down on transition.
    static bool capsWasOn = false;
    bool capsNow = (flags & NSEventModifierFlagCapsLock) != 0;
    if (capsNow != capsWasOn) {
        BeebKeyDown(4, 0);
        capsWasOn = capsNow;
    }
}

// ------------------------------------------------------------------
// Mouse
// ------------------------------------------------------------------
- (NSPoint)scaledPosition:(NSEvent *)event
{
    NSPoint p = [self convertPoint:event.locationInWindow fromView:nil];
    NSSize  s = self.bounds.size;
    return NSMakePoint((p.x / s.width)  * BEEBEM_WINDOW_WIDTH,
                       ((s.height - p.y) / s.height) * BEEBEM_WINDOW_HEIGHT);
}

- (void)mouseMoved:(NSEvent *)event
{
    if (mainWin) {
        NSPoint p = [self scaledPosition:event];
        mainWin->ScaleMousestick((unsigned int)p.x, (unsigned int)p.y);
        mainWin->SetAMXPosition((unsigned int)p.x, (unsigned int)p.y);
    }
}
- (void)mouseDragged:(NSEvent *)event  { [self mouseMoved:event]; }

- (void)mouseDown:(NSEvent *)event      { AMXButtons |=  AMX_LEFT_BUTTON; }
- (void)mouseUp:(NSEvent *)event        { AMXButtons &= ~AMX_LEFT_BUTTON; }
- (void)rightMouseDown:(NSEvent *)event { AMXButtons |=  AMX_RIGHT_BUTTON; }
- (void)rightMouseUp:(NSEvent *)event   { AMXButtons &= ~AMX_RIGHT_BUTTON; }
- (void)otherMouseDown:(NSEvent *)event { AMXButtons |=  AMX_MIDDLE_BUTTON; }
- (void)otherMouseUp:(NSEvent *)event   { AMXButtons &= ~AMX_MIDDLE_BUTTON; }

// Forward tracking-area mouse moves to the handler above.
- (void)updateTrackingAreas
{
    [super updateTrackingAreas];
    for (NSTrackingArea *ta in self.trackingAreas)
        [self removeTrackingArea:ta];

    NSTrackingArea *ta = [[NSTrackingArea alloc]
        initWithRect:self.bounds
             options:NSTrackingMouseMoved | NSTrackingActiveInKeyWindow
               owner:self
            userInfo:nil];
    [self addTrackingArea:ta];
}

@end
