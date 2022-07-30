#include <windows.h>
#include <stdio.h>

////////////////////////////////////////////////////////////////////////////////
//
//   This simple C++ program shows how the CasEngine DLL can be easily
//   imported and used in your application. 
//
//   1. Put CasEngine.dll in the same folder as this code.
//   2. Put ffmpeg executable in a folder called ffmpeg.
//   3. Run the app with command line passing the filename of the audio as
//      an argument.
//   4. Press Pause to stop playing and close the application.
//
//   Creation: 30/07/2022 by A. H. Junior
//
////////////////////////////////////////////////////////////////////////////////


int main(int argc, char** argv)
{
    char* filename; 

    if (argc != 2)
        printf("Must provide one audio file.\n");
    else { 
        filename = argv[1];
        HMODULE lib = LoadLibrary("CasEngine.dll");

        // Define function pointers
        typedef int (__stdcall *ce_0)();
        typedef int (__stdcall *ce_1)(const char *);
        typedef int (__stdcall *ce_2)(int);
        typedef int (__stdcall *ce_3)(float);
        typedef bool (__stdcall *ce_4)();

        // Import functions
        ce_0 ce_init = (ce_0) GetProcAddress(lib, "ce_init");
        ce_0 ce_free = (ce_0) GetProcAddress(lib, "ce_free");
        ce_0 ce_play = (ce_0) GetProcAddress(lib, "ce_play");
        ce_0 ce_pause = (ce_0) GetProcAddress(lib, "ce_pause");
        ce_0 ce_stop = (ce_0) GetProcAddress(lib, "ce_stop");
        ce_0 ce_loadDirectSound = (ce_0) GetProcAddress(lib, "ce_loadDirectSound");
        ce_1 ce_loadFileIntoTrack = (ce_1) GetProcAddress(lib, "ce_loadFileIntoTrack");
        ce_2 ce_addTrackToPlaylist = (ce_2) GetProcAddress(lib, "ce_addTrackToPlaylist");   
        ce_3 ce_changeSpeed = (ce_3) GetProcAddress(lib, "ce_changeSpeed");
        ce_4 ce_isPlaying = (ce_4) GetProcAddress(lib, "ce_isPlaying");

        // Load the engine
        if (ce_init() == 0) printf("CasEngine successfully loaded.\n");

        // Load driver
        ce_loadDirectSound();

        // Load a track using a audio file
        int trackId = ce_loadFileIntoTrack(filename);

        // If ID is positive, loading was successful
        if (trackId >= 0) {
            ce_addTrackToPlaylist(trackId);
            
            // Start playing
            ce_play();
            printf("Now playing. Press PAUSE to stop.\n");

            // Plays audio until user presses Pause
            while(ce_isPlaying()) {
                Sleep(10);
                if (GetAsyncKeyState(VK_SPACE) & 0x01)
                    ce_stop();
            }
        }
        else {
            printf("File \"%s\" not found.", filename);
        }

        // Frees the objects
        ce_free();
    }

    return 0;
}