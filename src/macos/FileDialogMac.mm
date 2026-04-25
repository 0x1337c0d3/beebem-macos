/****************************************************************
BeebEm - BBC Micro and Master 128 Emulator
macOS file/folder dialog implementations using NSOpenPanel, NSSavePanel,
and NSOpenPanel (directory mode) — replaces FileDialog.cpp and
FolderSelectDialog.cpp on Apple builds.
****************************************************************/

#import <Cocoa/Cocoa.h>
#include <string.h>

#include "FileDialog.h"
#include "FolderSelectDialog.h"

// ---------------------------------------------------------------------------
// FileDialog
// ---------------------------------------------------------------------------

FileDialog::FileDialog(HWND /*hwndOwner*/, LPTSTR Result, DWORD ResultLength,
                       LPCTSTR InitialFolder, LPCTSTR /*Filter*/)
{
    m_pszTitle     = nullptr;
    m_pszFileName  = Result;
    m_ResultLength = ResultLength;
    if (InitialFolder && *InitialFolder)
        strncpy(m_szInitialFolder, InitialFolder, sizeof(m_szInitialFolder) - 1);
    else
        m_szInitialFolder[0] = '\0';
}

void FileDialog::SetFilterIndex(DWORD /*Index*/) {}

void FileDialog::AllowMultiSelect()
{
    m_AllowMultiSelect = true;
}

void FileDialog::NoOverwritePrompt()
{
    m_NoOverwritePrompt = true;
}

void FileDialog::SetTitle(LPCTSTR Title)
{
    m_pszTitle = Title;
}

DWORD FileDialog::GetFilterIndex() const
{
    return 1;
}

static void RunOnMainThread(void (^block)(void))
{
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}

bool FileDialog::ShowDialog(bool open)
{
    __block bool result = false;

    RunOnMainThread(^{
        if (open) {
            NSOpenPanel *panel = [NSOpenPanel openPanel];
            panel.canChooseFiles    = YES;
            panel.canChooseDirectories = NO;
            panel.allowsMultipleSelection = m_AllowMultiSelect;
            if (m_pszTitle)
                panel.message = [NSString stringWithUTF8String:m_pszTitle];
            if (m_szInitialFolder[0])
                panel.directoryURL = [NSURL fileURLWithPath:
                    [NSString stringWithUTF8String:m_szInitialFolder]];

            if ([panel runModal] == NSModalResponseOK) {
                if (m_AllowMultiSelect) {
                    // Multiple: NUL-separate paths, double-NUL terminate
                    size_t off = 0;
                    for (NSURL *url in panel.URLs) {
                        const char *p = url.fileSystemRepresentation;
                        size_t len = strlen(p);
                        if (off + len + 2 < m_ResultLength) {
                            memcpy(m_pszFileName + off, p, len + 1);
                            off += len + 1;
                        }
                    }
                    m_pszFileName[off] = '\0';
                } else {
                    strncpy(m_pszFileName,
                            panel.URL.fileSystemRepresentation,
                            m_ResultLength - 1);
                    m_pszFileName[m_ResultLength - 1] = '\0';
                }
                result = true;
            }
        } else {
            NSSavePanel *panel = [NSSavePanel savePanel];
            if (m_pszTitle)
                panel.message = [NSString stringWithUTF8String:m_pszTitle];
            if (m_szInitialFolder[0])
                panel.directoryURL = [NSURL fileURLWithPath:
                    [NSString stringWithUTF8String:m_szInitialFolder]];
            if (!m_NoOverwritePrompt)
                panel.canCreateDirectories = YES;

            if ([panel runModal] == NSModalResponseOK) {
                strncpy(m_pszFileName,
                        panel.URL.fileSystemRepresentation,
                        m_ResultLength - 1);
                m_pszFileName[m_ResultLength - 1] = '\0';
                result = true;
            }
        }
    });

    return result;
}

bool FileDialog::Open()
{
    return ShowDialog(true);
}

bool FileDialog::Save()
{
    return ShowDialog(false);
}

// ---------------------------------------------------------------------------
// FolderSelectDialog
// ---------------------------------------------------------------------------

FolderSelectDialog::FolderSelectDialog(HWND /*hwndOwner*/,
                                       const char *Title,
                                       const char *InitialFolder)
    : m_InitialFolder(InitialFolder ? InitialFolder : ""),
      m_Title(Title ? Title : "")
{
    m_Buffer[0] = '\0';
}

FolderSelectDialog::Result FolderSelectDialog::DoModal()
{
    __block FolderSelectDialog::Result res = FolderSelectDialog::Result::Cancel;
    __block std::string chosen;

    RunOnMainThread(^{
        NSOpenPanel *panel = [NSOpenPanel openPanel];
        panel.canChooseFiles        = NO;
        panel.canChooseDirectories  = YES;
        panel.allowsMultipleSelection = NO;
        panel.canCreateDirectories  = YES;

        if (!m_Title.empty())
            panel.message = [NSString stringWithUTF8String:m_Title.c_str()];
        if (!m_InitialFolder.empty())
            panel.directoryURL = [NSURL fileURLWithPath:
                [NSString stringWithUTF8String:m_InitialFolder.c_str()]];

        if ([panel runModal] == NSModalResponseOK) {
            chosen = panel.URL.fileSystemRepresentation;
            res = FolderSelectDialog::Result::OK;
        }
    });

    if (res == FolderSelectDialog::Result::OK) {
        strncpy(m_Buffer, chosen.c_str(), sizeof(m_Buffer) - 1);
        m_Buffer[sizeof(m_Buffer) - 1] = '\0';
    }
    return res;
}

std::string FolderSelectDialog::GetFolder() const
{
    return m_Buffer;
}

int CALLBACK FolderSelectDialog::BrowseCallbackProc(
    HWND /*hWnd*/, UINT /*uMsg*/, LPARAM /*lParam*/, LPARAM /*lpData*/)
{
    return 0;
}
