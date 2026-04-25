#pragma once
// Stub for Windows <commctrl.h> — common controls as no-ops on POSIX.

#ifndef COMMCTRL_H
#define COMMCTRL_H

// ListView styles and messages
#define LVS_REPORT          0x0001
#define LVS_SINGLESEL       0x0004
#define LVS_SHOWSELALWAYS   0x0008
#define LVS_NOSORTHEADER    0x8000

#define LVM_FIRST           0x1000
#define LVM_DELETEALLITEMS  (LVM_FIRST + 9)
#define LVM_GETITEMCOUNT    (LVM_FIRST + 4)
#define LVM_INSERTITEM      (LVM_FIRST + 7)
#define LVM_SETITEM         (LVM_FIRST + 6)
#define LVM_GETITEM         (LVM_FIRST + 5)
#define LVM_INSERTCOLUMN    (LVM_FIRST + 27)
#define LVM_SETCOLUMN       (LVM_FIRST + 26)
#define LVM_SETEXTENDEDLISTVIEWSTYLE (LVM_FIRST + 54)
#define LVM_GETNEXTITEM     (LVM_FIRST + 12)
#define LVM_GETSELECTEDCOUNT (LVM_FIRST + 50)
#define LVM_ENSUREVISIBLE   (LVM_FIRST + 19)
#define LVM_SETITEMSTATE    (LVM_FIRST + 43)

#define LVIF_TEXT   0x0001
#define LVIF_IMAGE  0x0002
#define LVIF_STATE  0x0008
#define LVIF_PARAM  0x0004

#define LVIS_SELECTED   0x0002
#define LVIS_FOCUSED    0x0001

#define LVNI_SELECTED   0x0002
#define LVNI_ALL        0x0000

#define LVCF_FMT    0x0001
#define LVCF_WIDTH  0x0002
#define LVCF_TEXT   0x0004
#define LVCF_SUBITEM 0x0008

#define LVCFMT_LEFT  0x0000
#define LVCFMT_RIGHT 0x0001

#define LVS_EX_FULLROWSELECT 0x00000020
#define LVS_EX_GRIDLINES     0x00000001

#define LVN_FIRST           ((UINT)-100)
#define LVN_ITEMCHANGED     (LVN_FIRST - 1)
#define LVN_GETDISPINFO     (LVN_FIRST - 77)
#define LVN_COLUMNCLICK     (LVN_FIRST - 8)

#define HDN_FIRST           ((UINT)-300)

typedef struct tagLVITEMA {
    UINT    mask;
    int     iItem;
    int     iSubItem;
    UINT    state;
    UINT    stateMask;
    char*   pszText;
    int     cchTextMax;
    int     iImage;
    LPARAM  lParam;
} LVITEM;

typedef struct tagLVCOLUMNA {
    UINT    mask;
    int     fmt;
    int     cx;
    char*   pszText;
    int     cchTextMax;
    int     iSubItem;
} LVCOLUMN;

typedef struct tagNMHDR {
    HWND    hwndFrom;
    UINT_PTR idFrom;
    UINT    code;
} NMHDR;

typedef struct tagNMLISTVIEW {
    NMHDR   hdr;
    int     iItem;
    int     iSubItem;
    UINT    uNewState;
    UINT    uOldState;
    UINT    uChanged;
    POINT   ptAction;
    LPARAM  lParam;
} NMLISTVIEW;

typedef struct tagNMLVDISPINFO {
    NMHDR   hdr;
    LVITEM  item;
} NMLVDISPINFO;

static inline BOOL InitCommonControls() { return TRUE; }
static inline BOOL InitCommonControlsEx(void* /*icc*/) { return TRUE; }

#define ListView_DeleteAllItems(hwnd)  ((void)(hwnd), TRUE)
#define ListView_GetItemCount(hwnd)    ((void)(hwnd), 0)
#define ListView_InsertItem(hwnd, pitem) ((void)(hwnd), (void)(pitem), 0)
#define ListView_SetItem(hwnd, pitem)  ((void)(hwnd), (void)(pitem), TRUE)
#define ListView_GetItem(hwnd, pitem)  ((void)(hwnd), (void)(pitem), TRUE)
#define ListView_InsertColumn(hwnd, iCol, pcol) ((void)(hwnd), (void)(iCol), (void)(pcol), 0)
#define ListView_SetExtendedListViewStyle(hwnd, dw) ((void)(hwnd), (void)(dw), 0)
#define ListView_GetNextItem(hwnd, i, flags) ((void)(hwnd), (void)(i), (void)(flags), -1)
#define ListView_GetSelectedCount(hwnd) ((void)(hwnd), 0)
#define ListView_EnsureVisible(hwnd, i, part) ((void)(hwnd), TRUE)
#define ListView_SetItemState(hwnd, i, data, mask) ((void)(hwnd))

#endif // COMMCTRL_H
