/****************************************************************
BeebEm - BBC Micro and Master 128 Emulator
CoreAudio backend — pulls from the SDL-compatible ring buffer
and outputs via AVAudioEngine + AVAudioSourceNode.
****************************************************************/

#pragma once

#ifdef __cplusplus
#include <cstddef>

// Initialise CoreAudio output at the given sample rate (8-bit unsigned mono).
// Call once after the ring buffer is ready.
bool CoreAudioInit(int sampleRate);

// Stop and tear down the CoreAudio engine.
void CoreAudioFree();

#endif // __cplusplus
