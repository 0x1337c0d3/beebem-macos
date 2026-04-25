#pragma once
// Stub for Windows <shlobj.h> — shell object functions as no-ops on POSIX.

#ifndef SHLOBJ_H
#define SHLOBJ_H

// Shell folder constants
#define BIF_RETURNONLYFSDIRS    0x0001
#define BIF_NEWDIALOGSTYLE      0x0040
#define BIF_EDITBOX             0x0010
#define BFFM_INITIALIZED        1
#define BFFM_SETSELECTION       (WM_USER + 102)

// Folder browser
typedef int (*BFFCALLBACK)(HWND hwnd, UINT uMsg, LPARAM lParam, LPARAM lpData);

typedef struct tagBROWSEINFO {
    HWND        hwndOwner;
    const void* pidlRoot;
    char*       pszDisplayName;
    const char* lpszTitle;
    UINT        ulFlags;
    BFFCALLBACK lpfn;
    LPARAM      lParam;
    int         iImage;
} BROWSEINFO;

static inline void* SHBrowseForFolder(BROWSEINFO* /*pbi*/) { return nullptr; }
static inline BOOL  SHGetPathFromIDList(const void* /*pidl*/, char* /*pszPath*/) { return FALSE; }
static inline void  CoTaskMemFree(void* /*pv*/) {}

// Path functions
static inline HRESULT SHGetFolderPath(HWND /*hwnd*/, int /*csidl*/, HANDLE /*hToken*/,
                                       DWORD /*dwFlags*/, char* /*pszPath*/) { return 0; }

#define CSIDL_APPDATA 0x001A
#define CSIDL_COMMON_APPDATA 0x0023

#ifndef WM_USER
#define WM_USER 0x0400
#endif

#endif // SHLOBJ_H
