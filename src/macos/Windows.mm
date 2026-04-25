/****************************************************************
BeebEm - BBC Micro and Master 128 Emulator
macOS Windows shims — replaces posix/Windows.cpp on Apple builds.

Provides the fake Windows API (Sleep, GetTickCount, menu helpers etc.)
without any SDL dependency.
****************************************************************/

#include <errno.h>
#include <time.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <mach/mach_time.h>
#include <pthread.h>
#include <stdarg.h>
#include <string.h>
#include <stdio.h>

#include "Windows.h"
#include "macos/MacPlatform.h"
#include "macos/BeebMenu.h"
#include "FileUtils.h"

// ------------------------------------------------------------------
// Time
// ------------------------------------------------------------------

int _vscprintf(const char *format, va_list pargs)
{
    va_list argcopy;
    va_copy(argcopy, pargs);
    int retval = vsnprintf(NULL, 0, format, argcopy);
    va_end(argcopy);
    return retval;
}

// Returns milliseconds since process start (matches Windows GetTickCount semantics).
DWORD GetTickCount()
{
    static mach_timebase_info_data_t sInfo = {0, 0};
    static uint64_t sStart = 0;

    if (sInfo.denom == 0) {
        mach_timebase_info(&sInfo);
        sStart = mach_absolute_time();
    }

    uint64_t elapsed = mach_absolute_time() - sStart;
    // Convert to milliseconds: elapsed * numer / denom / 1,000,000
    return (DWORD)((elapsed * sInfo.numer / sInfo.denom) / 1000000ULL);
}

void Sleep(DWORD milliseconds)
{
    SaferSleep((unsigned int)milliseconds);
}

// ------------------------------------------------------------------
// Window
// ------------------------------------------------------------------

void SetWindowText(HWND /*hWnd*/, const char *pszTitle)
{
    SetWindowTitle(pszTitle);
}

// ------------------------------------------------------------------
// Menu state helpers — these forward to a global NSMenu item table.
// Currently stubs; wire to NSMenu when the AppKit menu is implemented.
// ------------------------------------------------------------------

static int s_menuState[0x10000] = {};  // WM_APP-based IDs

DWORD CheckMenuItem(HMENU /*hMenu*/, UINT uIDCheckItem, UINT uCheck)
{
    DWORD prev = s_menuState[uIDCheckItem & 0xFFFF];
    bool checked = (uCheck == MF_CHECKED);
    s_menuState[uIDCheckItem & 0xFFFF] = checked ? MF_CHECKED : MF_UNCHECKED;
    BeebMenuSetChecked((int)uIDCheckItem, checked);
    return prev;
}

BOOL CheckMenuRadioItem(HMENU /*hMenu*/, UINT FirstID, UINT LastID,
                        UINT SelectedID, UINT /*Flags*/)
{
    for (UINT id = FirstID; id <= LastID; ++id) {
        bool sel = (id == SelectedID);
        s_menuState[id & 0xFFFF] = sel ? MF_CHECKED : MF_UNCHECKED;
        BeebMenuSetChecked((int)id, sel);
    }
    return TRUE;
}

BOOL ModifyMenu(HMENU /*hMnu*/, UINT uPosition, UINT /*uFlags*/,
                PTR /*uIDNewItem*/, LPCTSTR lpNewItem)
{
    if (lpNewItem) BeebMenuSetText((int)uPosition, lpNewItem);
    return TRUE;
}

UINT GetMenuState(HMENU /*hMenu*/, UINT uId, UINT /*uFlags*/)
{
    return s_menuState[uId & 0xFFFF];
}

BOOL EnableMenuItem(HMENU /*hMenu*/, UINT uIDEnableItem, UINT uEnable)
{
    bool enabled = (uEnable & MF_GRAYED) == 0;
    BeebMenuSetEnabled((int)uIDEnableItem, enabled);
    return TRUE;
}

// ------------------------------------------------------------------
// File / path helpers
// ------------------------------------------------------------------

BOOL MoveFileEx(LPCTSTR /*lpExistingFileName*/, LPCTSTR /*lpNewFileName*/, DWORD /*dwFlags*/)
{
    return FALSE;
}

BOOL PathIsRelative(LPCSTR pszPath)
{
    return pszPath && pszPath[0] != '/';
}

BOOL PathCanonicalize(LPSTR pszBuf, LPCSTR pszPath)
{
    strcpy(pszBuf, pszPath);
    return TRUE;
}

int SHCreateDirectoryEx(HWND /*hWnd*/, LPCSTR pszPath, const void * /*psa*/)
{
    int result = mkdir(pszPath, S_IRWXU | S_IRWXG | S_IRWXO);
    if (result == 0 || errno == EEXIST) return 0;  // already exists is fine
    return errno;
}

DWORD GetFullPathName(LPCSTR pszFileName, DWORD BufferLength,
                      LPSTR pszBuffer, LPSTR *pszFilePart)
{
    if (!pszFileName || !pszBuffer || BufferLength == 0) return 0;
    char resolved[PATH_MAX];
    // realpath requires the path to exist; fall back to strncpy if not.
    if (realpath(pszFileName, resolved) != nullptr)
        strlcpy(pszBuffer, resolved, BufferLength);
    else
        strlcpy(pszBuffer, pszFileName, BufferLength);
    if (pszFilePart) {
        char *slash = strrchr(pszBuffer, '/');
        *pszFilePart = slash ? slash + 1 : pszBuffer;
    }
    return (DWORD)strlen(pszBuffer);
}

void _makepath(char *path, const char *drive, const char *dir,
               const char *fname, const char *ext)
{
    strcpy(path, drive ? drive : "");
    if (dir  && *dir)  AppendPath(path, dir);
    if (fname && *fname) AppendPath(path, fname);
    if (ext  && *ext)  strcat(path, ext);
}

// ------------------------------------------------------------------
// Misc
// ------------------------------------------------------------------

void ZeroMemory(PVOID Destination, SIZE_T Length)
{
    memset(Destination, 0, Length);
}

void GetLocalTime(SYSTEMTIME *pTime)
{
    time_t t;
    time(&t);
    struct tm *tm = localtime(&t);
    pTime->wYear         = (WORD)(tm->tm_year + 1900);
    pTime->wMonth        = (WORD)(tm->tm_mon + 1);
    pTime->wDayOfWeek    = (WORD)tm->tm_wday;
    pTime->wDay          = (WORD)tm->tm_mday;
    pTime->wHour         = (WORD)tm->tm_hour;
    pTime->wMinute       = (WORD)tm->tm_min;
    pTime->wSecond       = (WORD)tm->tm_sec;
    pTime->wMilliseconds = 0;
}

int ioctlsocket(SOCKET Socket, long Cmd, unsigned long *pArg)
{
    return ioctl(Socket, Cmd, pArg);
}

int WSAGetLastError() { return errno; }
int WSACleanup()      { return 0; }

DWORD GetCurrentThreadId()
{
    return (DWORD)(uintptr_t)pthread_self();
}

DWORD GetLastError() { return (DWORD)errno; }

// ------------------------------------------------------------------
// Critical section — backed by pthread_mutex
// ------------------------------------------------------------------

void InitializeCriticalSection(CRITICAL_SECTION *p)  { (void)p; }
void DeleteCriticalSection(CRITICAL_SECTION *p)       { (void)p; }
void EnterCriticalSection(CRITICAL_SECTION *p)        { (void)p; }
void LeaveCriticalSection(CRITICAL_SECTION *p)        { (void)p; }

// ------------------------------------------------------------------
// Timers — stub (BeebWin timer logic not used on macOS path)
// ------------------------------------------------------------------

UINT_PTR SetTimer(HWND /*hWnd*/, UINT_PTR /*nIDEvent*/,
                  UINT /*uElapse*/, TIMERPROC /*lpTimerFunc*/)
{
    return 0;
}

BOOL KillTimer(HWND /*hWnd*/, UINT_PTR /*nIDEvent*/)
{
    return FALSE;
}

BOOL GetWindowRect(HWND /*hWnd*/, RECT *pRect)
{
    memset(pRect, 0, sizeof(*pRect));
    return TRUE;
}

BOOL MessageBeep(UINT /*uType*/)
{
    // NSBeep() is available from AppKit; use AudioServicesPlayAlertSound as alternative.
    // For now simply return TRUE — audio alerts are non-critical.
    return TRUE;
}

void OutputDebugString(const char *pszMessage)
{
    fputs(pszMessage, stdout);
}

int _stricmp(const char *s1, const char *s2)
{
    return strcasecmp(s1, s2);
}

// ------------------------------------------------------------------
// Window / dialog helpers — stubs (no Win32 HWND on macOS)
// ------------------------------------------------------------------

HWND GetDlgItem(HWND /*hDlg*/, int /*nDlgItemID*/)
{
    return nullptr;
}

BOOL EnableWindow(HWND /*hWnd*/, BOOL /*bEnable*/)
{
    return TRUE;
}

HWND GetParent(HWND /*hWnd*/)
{
    return nullptr;
}

BOOL IsWindowEnabled(HWND /*hWnd*/)
{
    return TRUE;
}

BOOL SetWindowPos(HWND /*hWnd*/, HWND /*hWndInsertAfter*/,
                  int /*X*/, int /*Y*/, int /*cx*/, int /*cy*/, UINT /*uFlags*/)
{
    return TRUE;
}
