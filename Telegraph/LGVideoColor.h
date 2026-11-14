#ifndef LG_VIDEO_COLOR_H
#define LG_VIDEO_COLOR_H

#include <stddef.h>
#include <stdint.h>

typedef struct
{
    const uint8_t *planes[3];
    int strides[3];
    unsigned int width;
    unsigned int height;
} LGVideoI420;

int LGVideoConvertBGRA(const LGVideoI420 *color, const LGVideoI420 *alpha, uint8_t *output, unsigned int width, unsigned int height);

#endif
