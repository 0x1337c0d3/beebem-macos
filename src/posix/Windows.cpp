/****************************************************************
BeebEm - BBC Micro and Master 128 Emulator
Copyright (C) 2006  David Eggleston

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public
License along with this program; if not, write to the Free
Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
Boston, MA  02110-1301, USA.
****************************************************************/

#include <errno.h>
#include <time.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <sys/stat.h>

#include "gui/gui.h"

#include "log.h"
#include "Windows.h"
#include "BeebEmPages.h"
#include "FileUtils.h"

#include "Sdl.h"

// Fake windows stuff:

int _vscprintf(const char *format, va_list pargs)
{
	int retval;
	va_list argcopy;
	va_copy(argcopy, pargs);
	retval = vsnprintf(NULL, 0, format, argcopy);
	va_end(argcopy);
	return retval;
}

void SetWindowText(HWND /* hWnd */, const char *pszTitle)
{
	SetWindowTitle(pszTitle);
}

void Sleep(DWORD ticks)
{
	SaferSleep((unsigned int)ticks);
}

DWORD GetTickCount()
{
	return SDL_GetTicks();
}

BOOL ModifyMenu(HMENU /* hMenu */,
                UINT uPosition,
                UINT /* uFlags */,
                PTR /* uIDNewItem */,
                LPCTSTR lpNewItem)
{
	// Only supports changing the title.
	//SetGUIOptionCaption(int windows_menu_id, const char *str)

	int v = SetGUIOptionCaption((int)uPosition, (const char*)lpNewItem);

	return v == EG_TRUE;
}

UINT GetMenuState(HMENU /* hMenu */, UINT uId, UINT /* uFlags */)
{
	int v = GetGUIOption(uId);

	return v ? MF_CHECKED : MF_UNCHECKED;
}

DWORD CheckMenuItem(HMENU /* hMenu */, UINT uIDCheckItem, UINT uCheck)
{
	if (uCheck == MF_CHECKED)
	{
		return UpdateGUIOption(uIDCheckItem, 1);
	}
	else
	{
		return UpdateGUIOption(uIDCheckItem, 0);
	}
}

BOOL CheckMenuRadioItem(HMENU /* hMenu */, UINT FirstID, UINT LastID, UINT SelectedID, UINT /* Flags */)
{
	for (UINT MenuItemID = FirstID; MenuItemID < LastID; MenuItemID++)
	{
		UpdateGUIOption(MenuItemID, MenuItemID == SelectedID);
	}

	return TRUE;
}

BOOL MoveFileEx(LPCTSTR /* lpExistingFileName */, LPCTSTR /* lpNewFileName */, DWORD /* dwFlags */)
{
	printf("MoveFileEx\n");
	return FALSE;
}

BOOL EnableMenuItem(HMENU /* hMenu */, UINT /* uIDEnableItem */, UINT /* uEnable */)
{
	return TRUE;
}

int WSACleanup()
{
	return 0;
}

void GetLocalTime(SYSTEMTIME* pTime)
{
	time_t Time;
	time(&Time);
	struct tm *pTM = localtime(&Time);

	pTime->wYear = pTM->tm_year + 1900;
	pTime->wMonth = pTM->tm_mon + 1;
	pTime->wDayOfWeek = pTM->tm_wday;
	pTime->wDay = pTM->tm_mday;
	pTime->wHour = pTM->tm_hour;
	pTime->wMinute = pTM->tm_min;
	pTime->wSecond = pTM->tm_sec;
	pTime->wMilliseconds = 0;
}

int ioctlsocket(SOCKET Socket, long Cmd, unsigned long* pArg)
{
	return ioctl(Socket, Cmd, pArg);
}

void ZeroMemory(PVOID Destination, SIZE_T Length)
{
	memset(Destination, 0, Length);
}

UINT_PTR SetTimer(HWND /* hWnd */, UINT_PTR /* nIDEvent */, UINT /* uElapse */, TIMERPROC /* lpTimerFunc */)
{
	// TODO
	return 0;
}

BOOL KillTimer(HWND /* hWnd */, UINT_PTR /* nIDEvent */)
{
	// TODO
	return FALSE;
}

BOOL PathIsRelative(LPCSTR pszPath)
{
	return pszPath[0] != '/';
}

BOOL PathCanonicalize(LPSTR pszBuf, LPCSTR pszPath)
{
	// TODO
	strcpy(pszBuf, pszPath);

	return TRUE;
}

int SHCreateDirectoryEx(HWND /* hWnd */, LPCSTR pszPath, const void * /* psa */)
{
	int Result = mkdir(pszPath, S_IRWXU | S_IRWXG | S_IRWXO);

	return Result == 0 ? 0 : errno;
}

DWORD GetFullPathName(LPCSTR /* pszFileName */, DWORD /* BufferLength */, LPSTR /* pszBuffer */, LPSTR* /* pszFilePart */)
{
	// TODO
	return 0;
}


void InitializeCriticalSection(CRITICAL_SECTION* /* pCriticalSection */)
{
	// TODO
}

void DeleteCriticalSection(CRITICAL_SECTION* /* pCriticalSection */)
{
	// TODO
}

void EnterCriticalSection(CRITICAL_SECTION* /* pCriticalSection */)
{
	// TODO
}

void LeaveCriticalSection(CRITICAL_SECTION* /* pCriticalSection */)
{
	// TODO
}

BOOL GetWindowRect(HWND /* hWnd */, RECT* pRect)
{
	ZeroMemory(pRect, sizeof(RECT));

	return TRUE;
}

BOOL MessageBeep(UINT /* uType */)
{
	return TRUE;
}

void _makepath(char *path,
               const char *drive,
               const char *dir,
               const char *fname,
               const char *ext)
{
	strcpy(path, drive);
	AppendPath(path, dir);
	AppendPath(path, fname);
	strcat(path, ext);
}

void OutputDebugString(const char* pszMessage)
{
	fputs(pszMessage, stdout);
}