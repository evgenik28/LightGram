#ifndef LGCrashSections_h
#define LGCrashSections_h

typedef void (*LGCrashSectionWriter)(int fd);

#ifdef __cplusplus
extern "C" {
#endif

void LGCrashSectionsSetPythonWriter(LGCrashSectionWriter writer);
void LGCrashSectionsWrite(int fd);

#ifdef __cplusplus
}
#endif

#endif
