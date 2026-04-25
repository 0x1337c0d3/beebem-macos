/****************************************************************
BeebEm - BBC Micro and Master 128 Emulator
macOS replacement for Main.h — provides the same extern globals
without pulling in SDL or the custom gui/ widget toolkit.
****************************************************************/

#pragma once

#include "Windows.h"
#include "BeebWin.h"
#include "Model.h"

extern char FDCDLL[MAX_PATH];

extern int    done;
extern Model  MachineType;
extern BeebWin *mainWin;
extern HINSTANCE hInst;
extern HWND      hCurrentDialog;
extern HACCEL    hCurrentAccelTable;

void Quit();
bool ToggleFullScreen();
void ShowingMenu();
void NoMenuShown();

static inline void SetActiveWindow(void *) {}
