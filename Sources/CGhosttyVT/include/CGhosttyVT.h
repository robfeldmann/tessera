#ifndef C_GHOSTTY_VT_H
#define C_GHOSTTY_VT_H

// On Windows, Tessera links the static ghostty-vt-static.lib (no runtime DLL
// discovery). GHOSTTY_STATIC makes the header's GHOSTTY_API macro a no-op so
// symbols are not declared __declspec(dllimport); see ghostty/vt/types.h.
#if defined(_WIN32) || defined(_WIN64)
#define GHOSTTY_STATIC 1
#endif

// The ghostty/ directory next to this header holds the pinned revision's headers,
// committed; scripts/build-libghostty-vt.sh / .ps1 check them against the build.
#include "ghostty/vt.h"

#endif
