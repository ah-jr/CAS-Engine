#include <windows.h>
#include <stdio.h>
#include <math.h>

////////////////////////////////////////////////////////////////////////////////
//
//   This simple C++ program shows how the CasEngine DLL can be easily
//   imported and used in your application. 
//
//   1. Put CasEngine.dll in the same folder as this code.
//   2. Put ffmpeg executable in a folder called ffmpeg.
//   3. Run the app with command line passing the filename of the audio as
//      an argument.
//   4. Press up/down keys to change volume.
//   5. Press left/right keys to change speed, or backspace to reset it.
//   6. Press Pause to stop playing and close the application.
//
//   Creation: 30/07/2022 by A. H. Junior
//
////////////////////////////////////////////////////////////////////////////////

// Define function pointers
typedef int (__stdcall *ce_0)();
typedef int (__stdcall *ce_1)(const char *);
typedef int (__stdcall *ce_2)(int);
typedef int (__stdcall *ce_3)(double);
typedef bool (__stdcall *ce_4)();
typedef int (__stdcall *ce_5)(ce_0);
typedef double (__stdcall *ce_6)();

// Import functions
HMODULE lib = LoadLibrary("CasEngine.dll");

ce_0 ce_init = (ce_0) GetProcAddress(lib, "ce_init");
ce_0 ce_free = (ce_0) GetProcAddress(lib, "ce_free");
ce_0 ce_play = (ce_0) GetProcAddress(lib, "ce_play");
ce_0 ce_pause = (ce_0) GetProcAddress(lib, "ce_pause");
ce_0 ce_stop = (ce_0) GetProcAddress(lib, "ce_stop");
ce_0 ce_loadDirectSound = (ce_0) GetProcAddress(lib, "ce_loadDirectSound");
ce_1 ce_loadFileIntoTrack = (ce_1) GetProcAddress(lib, "ce_loadFileIntoTrack");
ce_2 ce_addTrackToPlaylist = (ce_2) GetProcAddress(lib, "ce_addTrackToPlaylist");   
ce_3 ce_setSpeed = (ce_3) GetProcAddress(lib, "ce_setSpeed");
ce_3 ce_setLevel = (ce_3) GetProcAddress(lib, "ce_setLevel");
ce_4 ce_isPlaying = (ce_4) GetProcAddress(lib, "ce_isPlaying");
ce_5 ce_setCallback = (ce_5) GetProcAddress(lib, "ce_setCallback");
ce_6 ce_getProgress = (ce_6) GetProcAddress(lib, "ce_getProgress"); 

// Callback function: put here operations that need to happen
// once the buffer gets filled with new samples. Be careful not
// to overload this method with too many slow function calls and
// operations, or else you could lose buffers and get distortion 
// in the output. 
int callback(void)
{
    printf("\b\b\b");
    printf("%02.0f%%", 100*ce_getProgress());

    return 1;
}

int main(int argc, char** argv)
{
    char* filename; 
    double level = 0.5;
    double speed = 1.0;

    if (argc != 2)
        printf("Must provide one audio file.\n");
    else { 
        filename = argv[1];

        printf("Press ENTER to start playing");
        getchar();

        // Load the engine
        if (ce_init() == 0) printf("CasEngine successfully loaded.\n");

        // Load driver
        ce_loadDirectSound();

        // Set callback function
        ce_setCallback((ce_0) callback);

        // Load a track using a audio file
        int trackId = ce_loadFileIntoTrack(filename);
 
        // If ID is positive, loading was successful
        if (trackId >= 0) {
            ce_addTrackToPlaylist(trackId);
            
            // Start playing
            ce_setLevel(level);
            ce_setSpeed(speed);
            ce_play();
        
            printf("Now playing. Press SPACE to stop.\n");

            // Plays audio until user presses Pause
            while(ce_isPlaying()) {
                Sleep(10);
                if (GetAsyncKeyState(VK_SPACE) & 0x8000)
                    ce_stop();

                if (GetAsyncKeyState(VK_UP) & 0x8000){
                    level = fmin(level + 0.01, 1);
                    ce_setLevel(level);
                }
                if (GetAsyncKeyState(VK_DOWN) & 0x8000){
                    level = fmax(level - 0.01, 0);
                    ce_setLevel(level);
                }
                if (GetAsyncKeyState(VK_RIGHT) & 0x8000){
                    speed = fmin(speed + 0.01, 2);
                    ce_setSpeed(speed);
                }
                if (GetAsyncKeyState(VK_LEFT) & 0x8000){
                    speed = fmax(speed - 0.01, 0.1);
                    ce_setSpeed(speed);
                }
                if (GetAsyncKeyState(VK_BACK) & 0x8000){
                    speed = 1.0;
                    ce_setSpeed(speed);
                }
            }
        }
        else {
            printf("File \"%s\" not found.", filename);
        }

        // Free the objects
        ce_free();
    }

    return 0;
}