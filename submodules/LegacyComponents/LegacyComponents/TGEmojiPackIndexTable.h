#ifndef TGEmojiPackIndexTable_h
#define TGEmojiPackIndexTable_h

#include <stdint.h>

typedef struct
{
    uint32_t codepointsOffset;
    uint32_t codepointsCount;
    uint32_t packOffset;
    uint32_t packLength;
} TGEmojiPackIndexTableEntry;

static const uint64_t TGEmojiPackIndexTablePackSize = 0ULL;
static const uint32_t TGEmojiPackIndexTableMaxCodepoints = 1;
static const uint32_t TGEmojiPackIndexTableCount = 0;

static const uint32_t TGEmojiPackIndexTableCodepoints[] = { 0 };

static const TGEmojiPackIndexTableEntry TGEmojiPackIndexTableEntries[] = { {0, 0, 0, 0} };

#endif
