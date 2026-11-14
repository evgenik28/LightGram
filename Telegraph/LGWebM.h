#ifndef LG_WEBM_H
#define LG_WEBM_H

#include <stddef.h>
#include <stdint.h>

typedef struct
{
    size_t offset;
    size_t length;
    size_t alphaOffset;
    size_t alphaLength;
    uint64_t timestampNs;
} LGWebMFrame;

typedef struct
{
    uint32_t width;
    uint32_t height;
    uint32_t alphaMode;
    uint32_t frameCount;
    uint64_t durationNs;
    LGWebMFrame *frames;
} LGWebM;

int LGWebMParse(const uint8_t *data, size_t length, LGWebM *result);
void LGWebMFree(LGWebM *webm);

#endif
