#include <errno.h>
#include <limits.h>
#include <mach-o/dyld.h>
#include <pwd.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#include "LGSystemApplication.h"

static bool LGFormatPath(char *buffer, const char *format, const char *first, const char *second)
{
    int length = snprintf(buffer, PATH_MAX, format, first, second);
    return length > 0 && length < PATH_MAX;
}

static bool LGCreateDirectoryTree(const char *path)
{
    char buffer[PATH_MAX];
    if (strlcpy(buffer, path, sizeof(buffer)) >= sizeof(buffer))
        return false;
    for (char *cursor = buffer + 1; *cursor != '\0'; cursor++)
    {
        if (*cursor != '/')
            continue;
        *cursor = '\0';
        if (mkdir(buffer, 0755) != 0 && errno != EEXIST)
            return false;
        *cursor = '/';
    }
    return mkdir(buffer, 0755) == 0 || errno == EEXIST;
}

static const char *LGUserHomePath(void)
{
    struct passwd *entry = getpwuid(getuid());
    if (entry != NULL && entry->pw_dir != NULL && entry->pw_dir[0] == '/')
        return entry->pw_dir;
    return LGSystemApplicationMobileHomePath;
}

int main(int argc, char *argv[])
{
    (void)argc;

    char executable[PATH_MAX];
    uint32_t executableSize = sizeof(executable);
    if (_NSGetExecutablePath(executable, &executableSize) != 0)
    {
        fprintf(stderr, "LightGram: executable path is too long\n");
        return EXIT_FAILURE;
    }

    char target[PATH_MAX];
    char home[PATH_MAX];
    char documents[PATH_MAX];
    char caches[PATH_MAX];
    char preferences[PATH_MAX];
    char temporary[PATH_MAX];
    if (!LGFormatPath(target, "%s%s", executable, LGSystemApplicationBinarySuffix) ||
        !LGFormatPath(home, "%s/%s", LGUserHomePath(), LGSystemApplicationHomeRelativePath) ||
        !LGFormatPath(documents, "%s/%s", home, "Documents") ||
        !LGFormatPath(caches, "%s/%s", home, "Library/Caches") ||
        !LGFormatPath(preferences, "%s/%s", home, "Library/Preferences") ||
        !LGFormatPath(temporary, "%s/%s", home, "tmp/"))
    {
        fprintf(stderr, "LightGram: application paths are too long\n");
        return EXIT_FAILURE;
    }

    const char *directories[] = { documents, caches, preferences, temporary };
    for (size_t index = 0; index < sizeof(directories) / sizeof(directories[0]); index++)
    {
        if (!LGCreateDirectoryTree(directories[index]))
        {
            fprintf(stderr, "LightGram: cannot create %s: %s\n", directories[index], strerror(errno));
            return EXIT_FAILURE;
        }
    }

    if (setenv("CFFIXED_USER_HOME", home, 1) != 0 || setenv("HOME", home, 1) != 0 || setenv("TMPDIR", temporary, 1) != 0)
    {
        fprintf(stderr, "LightGram: cannot configure environment: %s\n", strerror(errno));
        return EXIT_FAILURE;
    }

    argv[0] = target;
    execv(target, argv);
    fprintf(stderr, "LightGram: cannot execute %s: %s\n", target, strerror(errno));
    return EXIT_FAILURE;
}
