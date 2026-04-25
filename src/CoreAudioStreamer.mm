/****************************************************************
BeebEm - BBC Micro and Master 128 Emulator
CoreAudio backend — AVAudioEngine + AVAudioSourceNode.

Pulls 8-bit unsigned mono samples from the MacPlatform ring buffer
and converts them to Float32 for CoreAudio output.
****************************************************************/

#import <AVFoundation/AVFoundation.h>
#include "CoreAudioStreamer.h"
#include "macos/MacPlatform.h"

static AVAudioEngine       *s_engine    = nil;
static AVAudioSourceNode   *s_srcNode   = nil;
static int                  s_sampleRate = 44100;

bool CoreAudioInit(int sampleRate)
{
    s_sampleRate = sampleRate;
    s_engine = [[AVAudioEngine alloc] init];

    // Output format: Float32, mono, at the requested rate.
    AVAudioFormat *fmt = [[AVAudioFormat alloc]
        initWithCommonFormat:AVAudioPCMFormatFloat32
                  sampleRate:sampleRate
                    channels:1
                 interleaved:NO];

    s_srcNode = [[AVAudioSourceNode alloc]
        initWithFormat:fmt
           renderBlock:^OSStatus(BOOL         *isSilence,
                                 const AudioTimeStamp *timestamp,
                                 AVAudioFrameCount     frameCount,
                                 AudioBufferList      *outputData)
    {
        (void)timestamp;
        AudioBuffer *buf = &outputData->mBuffers[0];
        float *out = (float *)buf->mData;
        AVAudioFrameCount frames = frameCount;

        uint8_t tmp[8192];
        int got = 0;
        if (frames <= sizeof(tmp)) {
            got = GetBytesFromSDLSoundBuffer((int)frames, tmp);
        }

        // Convert uint8 → float32 (0..255 → -1..+1)
        for (AVAudioFrameCount i = 0; i < frames; ++i) {
            out[i] = (i < (AVAudioFrameCount)got)
                   ? ((float)tmp[i] / 128.0f) - 1.0f
                   : 0.0f;
        }

        *isSilence = (got == 0);
        return noErr;
    }];

    [s_engine attachNode:s_srcNode];
    [s_engine connect:s_srcNode
                   to:s_engine.mainMixerNode
               format:fmt];

    NSError *err = nil;
    if (![s_engine startAndReturnError:&err]) {
        NSLog(@"CoreAudioInit: AVAudioEngine start failed: %@", err);
        s_engine  = nil;
        s_srcNode = nil;
        return false;
    }

    return true;
}

void CoreAudioFree()
{
    if (s_engine) {
        [s_engine stop];
        s_engine  = nil;
        s_srcNode = nil;
    }
}
