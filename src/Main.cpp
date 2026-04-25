/****************************************************************
BeebEm - BBC Micro and Master 128 Emulator
Copyright (C) 1994  David Alan Gilbert
Copyright (C) 1994  Nigel Magnay
Copyright (C) 1997  Mike Wyatt

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

/* Mike Wyatt and NRM's port to win32 - 7/6/97 */

#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>

#include <SDL.h>

#ifdef WITH_UNIX_EXTRAS
#	include <sys/types.h>
#	include <dirent.h>
#	include <pwd.h>
#endif

#include <iostream>
#include <fstream>

#include "Windows.h"

#include "gui/gui.h"

#include "6502core.h"
#include "BeebEmPages.h"
#include "BeebMem.h"
#include "BeebWin.h"
#include "FileUtils.h"
#include "SysVia.h"
#include "UserVia.h"

#include "line.h"	// SDL Stuff
#include "log.h"
#include "Sdl.h"

#ifdef MULTITHREAD
#undef MULTITHREAD
#endif

// Make global reference to command line args
int __argc = 0;
char **__argv = nullptr;

/****************************************************************************/

Model MachineType;
BeebWin *mainWin = nullptr;
HINSTANCE hInst;
HWND hCurrentDialog = nullptr;
HACCEL hCurrentAccelTable = nullptr;

/****************************************************************************/

bool done = false;
bool showing_menu = false;
EG_Window *displayed_window_ptr = NULL;

void SetActiveWindow(EG_Window *window_ptr)
{
	displayed_window_ptr = window_ptr;
}

bool ToggleFullScreen()
{
	mainWin->SetFullScreenToggle(!mainWin->IsFullScreen());

	SetFullScreenTickbox(mainWin->IsFullScreen());

	Destroy_Screen();

	if (!Create_Screen())
	{
		qFATAL("Could not recreate SDL window!\n");
		exit(10);
	}

	// Update GUI here so it's not missed anywhere - this is
	// turning into such a bloody MESS...
	ClearWindowsBackgroundCacheAndResetSurface();
	ClearVideoWindow();

//	if (SDL_WM_ToggleFullScreen(screen_ptr) != 1)
//		EG_Log(EG_LOG_WARNING, dL"Could not toggle full-screen mode.", dR);

	return mainWin->IsFullScreen();
}

void UnfullscreenBeforeExit(void)
{
	// Hopefully this will fix that annoying bug where the mouse pointer
	// vanishes on exit. Is that me, or is it SDL?
	if (mainWin->IsFullScreen())
	{
		ToggleFullScreen();
	}
}

void ShowingMenu(void)
{
	showing_menu = true;
}

void NoMenuShown(void)
{
	showing_menu = false;
}

void Quit(void)
{
	done = true;
}

int main(int argc, char *argv[])
{
	int X11_CapsLock_Down;
	Uint32 ticks = SDL_GetTicks();

	std::string Error = GetSystemError();

	printf("\"%s\"\n", Error.c_str());

	// Create global reference to command line args (like windows does)
	__argc = argc;
	__argv = (char**)argv;

	// Initialise debugging subsystem.
	Log_Init();

	// Initialize SDL resources.
	if (!InitialiseSDL())
	{
		qFATAL("Unable to initialise SDL library!");
		return 1;
	}

	// Initialize GUI API
	if (!EG_Initialize())
	{
		qFATAL("EG failed to initialize! Quiting.");
		return 1;
	}

	// Build menus
	if (!InitializeBeebEmGUI(screen_ptr))
	{
		return 1;
	}

	// Create instance of Emulator core:
	mainWin = new(std::nothrow) BeebWin();

	if (!mainWin->Initialise())
	{
		return 1;
	}

	// Clear SDL event queue
	EG_Draw_FlushEventQueue();

	// Main loop converted to SDL:
	X11_CapsLock_Down = 0;	// =0 not down, used to emulate a key release in X11 (caps has no release event).

/* THIS WILL EVENTUALLY MOVE INTO beebwin.cpp when the MFC event loop is faked
 * (until then the rest of this file will be a mess):
 * -------------------------------------------
 */

	done = 0;

	do
	{
		/* As X11 sucks, we need to release the Caps Lock key ourselves, an event will not happen.
		 * The X11_CapsLock_Down var basically counts down once per pass of the emulator core, when
		 * it's 1, we assume enough time has passed to pass the core a release of the Beebs Caps Lock
		 * key.
		 */
		if (X11_CapsLock_Down > 0)
		{
			X11_CapsLock_Down--;

			if (X11_CapsLock_Down == 0)
			{
				BeebKeyUp(4, 0);
			}
		}

		// Toggle processing of either events to the emulator core, or events to the menu.
		SDL_Event event;

		if (!showing_menu)
		{
			// Execute emulator:
			if (!mainWin->IsFrozen())
			{
				Exec6502Instruction();
			}

			// If the mouse cursor should be hidden (set on GUI),
			// then make sure it is hidden after a suitable delay.
			// (Delay is set in the menu event code below)
			if (mainWin->CursorShouldBeHidden() &&
			    SDL_ShowCursor(SDL_QUERY) == SDL_ENABLE &&
			    EG_Draw_CalcTimePassed(ticks, SDL_GetTicks()) >= 2500)
			{
				SDL_ShowCursor(SDL_DISABLE);
			}

			while (SDL_PollEvent(&event))
			{
				switch (event.type)
				{
					case SDL_QUIT:
						done = true;
						break;

					case SDL_MOUSEMOTION:
						if (mainWin)
						{
							mainWin->ScaleMousestick(event.motion.x,
							                         event.motion.y);

							mainWin->SetAMXPosition(event.motion.x,
							                        event.motion.y);

							// Experiment: show menu in full screen when cursor moved to top of window
							//-- if (HideMenuEnabled)
							//-- {
							//-- 	if (HIWORD(lParam) <= 2)
							//-- 		mainWin->ShowMenu(true);
							//-- 	else
							//-- 		mainWin->ShowMenu(false);
							//-- }
						}
						break;

					case SDL_MOUSEBUTTONDOWN:
						if (event.button.button == SDL_BUTTON_LEFT)
						{
							// printf("left button down\n");
							//-- if (mainWin) mainWin->SetMousestickButton(TRUE);
							AMXButtons |= AMX_LEFT_BUTTON;
						}
						else if (event.button.button == SDL_BUTTON_MIDDLE)
						{
							// printf("middle button down\n");
							AMXButtons |= AMX_MIDDLE_BUTTON;
						}
						else if (event.button.button == SDL_BUTTON_RIGHT)
						{
							// printf("right button down\n");
							AMXButtons |= AMX_RIGHT_BUTTON;
						}
						break;

					case SDL_MOUSEBUTTONUP:
						if (event.button.button == SDL_BUTTON_LEFT)
						{
							// printf("left button up\n");
							//-- if (mainWin) mainWin->SetMousestickButton(FALSE);
							AMXButtons &= ~AMX_LEFT_BUTTON;
						}
						else if (event.button.button == SDL_BUTTON_MIDDLE)
						{
							// printf("middle button up\n");
							AMXButtons &= ~AMX_MIDDLE_BUTTON;
						}
						else if (event.button.button == SDL_BUTTON_RIGHT)
						{
							// printf("right button up\n");
							AMXButtons &= ~AMX_RIGHT_BUTTON;
						}
						break;

					case SDL_KEYDOWN:
					case SDL_KEYUP: {
						if (event.key.keysym.sym == SDLK_F12 ||
						    event.key.keysym.sym == SDLK_MENU)
						{
							Show_Main();
						}

						// Handle shift booting:
						if (mainWin->m_ShiftBooted)
						{
							mainWin->m_ShiftBooted = false;
							BeebKeyUp(0, 0);
						}

						// Convert SDL key press into BBC key press:
						int col = 0, row = 0;

						if (ConvertSDLKeyToBBCKey(event.key.keysym /*, &pressed */, &col, &row))
						{
							/* If X11 and Caps Lock then release automatically after 20
							* passes to the emulator core (doesn't X11 suck)..
							*
							* We'll only ever receive a pressed event for Caps Lock, so
							* emulate a release after x amount of time passes within the
							* emulator core.
							*
							* (For games we can use another key, defaults to Windows Left
							*  key for the moment).
							*/
							if (event.key.keysym.sym == SDLK_CAPSLOCK && cfg_HaveX11)
							{
								BeebKeyDown(4, 0);
								X11_CapsLock_Down = 20;
							}
							else
							{
								// Process key in emulator core:
								if (event.type == SDL_KEYDOWN)
								{
									BeebKeyDown(row, col);
								}
								else
								{
									BeebKeyUp(row, col);
								}
							}

//							// Release Caps lock for X11 after a short delay.
//							if (event.key.keysym.sym == SDLK_CAPSLOCK && cfg_HaveX11){
//								printf("Need to release Caps\n");
//								//SDL_Delay(1000);
//								X11_CapsLock_Down = 10;
//							}

							// Handle reset:
							if (row == -2)
							{
								mainWin->Break();
							}
						}
						break;
					}
				}
			}
		}
		else
		{
			// Make sure mouse pointer is shown when menu is displayed
			if (SDL_ShowCursor(SDL_QUERY) != SDL_ENABLE)
				SDL_ShowCursor(SDL_ENABLE);

			// Process window manager signals:
			while (SDL_PollEvent(&event))
			{
				switch (event.type)
				{
					case SDL_QUIT:
						done = true;
						break;

					#ifdef WITH_DEBUG_OUTPUT

					// For now allow exit with ESCAPE.
					case SDL_KEYDOWN:
						// if(event.key.keysym.sym == SDLK_ESCAPE)
						// 	done=1;
						break;

					#endif
				}

				// Send event to GUI:
				EG_Window_ProcessEvent(displayed_window_ptr, &event, 0, 0);
			}

			// printf("Menu mode.\n");
			SDL_Delay(10);
			EG_Window_ProcessEvent(displayed_window_ptr, NULL, 0, 0);

			// Record time so we can hide the mouse cursor after a small delay.
			ticks = SDL_GetTicks();
		}
	} while (!done);

	// Sometimes the mouse pointer vanishes on exit.
	// It seems to only happen when fullscreened, so make sure
	// we unfullscreen before destroying everything.
	UnfullscreenBeforeExit();

	delete mainWin;

	// Cleanly free SDL and logging.
	DestroyBeebEmGUI();
	UninitialiseSDL();
	Log_UnInit();

	return 0;
}
