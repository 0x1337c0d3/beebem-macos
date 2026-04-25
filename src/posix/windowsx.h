#pragma once
// Stub for Windows <windowsx.h> — message-cracker macros as no-ops on POSIX.

#ifndef WINDOWSX_H
#define WINDOWSX_H

#ifndef LOWORD
#define LOWORD(l) ((WORD)((DWORD_PTR)(l) & 0xFFFF))
#endif
#ifndef HIWORD
#define HIWORD(l) ((WORD)((DWORD_PTR)(l) >> 16))
#endif

#define GET_X_LPARAM(lp) ((int)(short)LOWORD(lp))
#define GET_Y_LPARAM(lp) ((int)(short)HIWORD(lp))

// ComboBox message constants
#define CB_RESETCONTENT 0x014B
#define CB_ADDSTRING    0x0143
#define CB_GETITEMDATA  0x0150
#define CB_SETITEMDATA  0x0151
#define CB_GETCOUNT     0x0146
#define CB_GETCURSEL    0x0147
#define CB_SETCURSEL    0x014E
#ifndef CB_ERR
#define CB_ERR (-1)
#endif

// ComboBox macros — stubs that always succeed/return 0
#define ComboBox_ResetContent(hwnd)              ((void)(hwnd), 0)
#define ComboBox_AddString(hwnd, lpsz)           ((void)(hwnd), (void)(lpsz), 0)
#define ComboBox_GetItemData(hwnd, index)        ((void)(hwnd), (void)(index), (LPARAM)0)
#define ComboBox_SetItemData(hwnd, index, data)  ((void)(hwnd), (void)(index), (void)(data), 0)
#define ComboBox_GetCount(hwnd)                  ((void)(hwnd), 0)
#define ComboBox_GetCurSel(hwnd)                 ((void)(hwnd), 0)
#define ComboBox_SetCurSel(hwnd, index)          ((void)(hwnd), (void)(index), 0)

// ListBox macros
#define ListBox_ResetContent(hwnd)               ((void)(hwnd), 0)
#define ListBox_AddString(hwnd, lpsz)            ((void)(hwnd), (void)(lpsz), 0)
#define ListBox_GetCount(hwnd)                   ((void)(hwnd), 0)
#define ListBox_GetCurSel(hwnd)                  ((void)(hwnd), 0)
#define ListBox_SetCurSel(hwnd, index)           ((void)(hwnd), (void)(index), 0)
#define ListBox_GetText(hwnd, i, buf)            ((void)(hwnd), (void)(i), (void)(buf), 0)
#define ListBox_GetTextLen(hwnd, i)              ((void)(hwnd), (void)(i), 0)

// Button macros
#define Button_GetCheck(hwnd)                    ((void)(hwnd), 0)
#define Button_SetCheck(hwnd, check)             ((void)(hwnd), (void)(check), 0)

// Edit macros
#define Edit_GetText(hwnd, lpsz, ccMax)          ((void)(hwnd), (void)(lpsz), (void)(ccMax), 0)
#define Edit_SetText(hwnd, lpsz)                 ((void)(hwnd), (void)(lpsz), 0)
#define Edit_GetTextLength(hwnd)                 ((void)(hwnd), 0)
#define Edit_LimitText(hwnd, cchMax)             ((void)(hwnd), (void)(cchMax), 0)

#endif // WINDOWSX_H
