#import "LGCrashSections.h"

#include <unistd.h>

static LGCrashSectionWriter volatile LGCrashSectionPythonWriter = NULL;

void LGCrashSectionsSetPythonWriter(LGCrashSectionWriter writer)
{
    LGCrashSectionPythonWriter = writer;
    __sync_synchronize();
}

void LGCrashSectionsWrite(int fd)
{
    LGCrashSectionWriter writer = LGCrashSectionPythonWriter;
    if (writer == NULL)
        return;
    static const char begin[] = "CRASH python-begin\n";
    static const char end[] = "\nCRASH python-end\n";
    write(fd, begin, sizeof(begin) - 1);
    writer(fd);
    write(fd, end, sizeof(end) - 1);
}
