#ifndef LGTransferPolicy_h
#define LGTransferPolicy_h

#include <stdbool.h>
#include <stdint.h>
#include <string.h>
#include <float.h>

typedef struct {
    int partSize;
    int maximumRequests;
    int64_t maximumInFlightBytes;
    uint32_t generation;
} LGTransferParameters;

typedef struct {
    int level;
    int stableWindows;
    int successes;
    int64_t bytes;
    double windowStart;
    double lastSample;
    double cooldownUntil;
    double rate;
    double duration;
} LGTransferDirection;

typedef struct {
    uint32_t generation;
    int networkClass;
    bool constrained;
    LGTransferDirection directions[2];
} LGTransferPolicy;

static inline int LGTransferDownloadPartSize(int preferredSize, int offset)
{
    while (preferredSize > 4096 && offset % preferredSize != 0)
        preferredSize /= 2;
    return preferredSize;
}

static inline void LGTransferDirectionReset(LGTransferDirection *direction, int networkClass, double now)
{
    memset(direction, 0, sizeof(*direction));
    direction->level = networkClass >= 2 ? 1 : 0;
    direction->windowStart = now;
    direction->lastSample = now;
}

static inline void LGTransferPolicyReset(LGTransferPolicy *policy, int networkClass, bool constrained, double now)
{
    policy->generation++;
    policy->networkClass = networkClass;
    policy->constrained = constrained;
    for (int i = 0; i < 2; i++)
        LGTransferDirectionReset(&policy->directions[i], networkClass, now);
}

static inline LGTransferParameters LGTransferPolicyParameters(LGTransferPolicy *policy, bool upload, double now)
{
    LGTransferDirection *direction = &policy->directions[upload ? 1 : 0];
    if (now - direction->lastSample > 30.0)
        LGTransferDirectionReset(direction, policy->networkClass, now);
    int level = direction->level;
    if (policy->constrained && level > 1)
        level = 1;
    if (policy->networkClass <= 1 && level > 1)
        level = 1;
    static const int sizes[2][4] = {{131072, 131072, 262144, 262144}, {65536, 131072, 262144, 524288}};
    static const int counts[2][4] = {{2, 4, 6, 8}, {2, 3, 4, 4}};
    LGTransferParameters result;
    result.partSize = sizes[upload ? 1 : 0][level];
    result.maximumRequests = counts[upload ? 1 : 0][level];
    if (policy->constrained && result.maximumRequests > 3)
        result.maximumRequests = 3;
    result.maximumInFlightBytes = (int64_t)result.partSize * result.maximumRequests;
    result.generation = policy->generation;
    return result;
}

static inline void LGTransferPolicyRecordFailure(LGTransferPolicy *policy, bool upload, uint32_t generation, double now)
{
    if (generation != policy->generation)
        return;
    LGTransferDirection *direction = &policy->directions[upload ? 1 : 0];
    if (direction->level > 0)
        direction->level--;
    direction->stableWindows = 0;
    direction->successes = 0;
    direction->bytes = 0;
    direction->windowStart = now;
    direction->lastSample = now;
    direction->cooldownUntil = now + 30.0;
}

static inline void LGTransferPolicyRecordSuccess(LGTransferPolicy *policy, bool upload, uint32_t generation, int64_t bytes, double started, double now)
{
    double duration = now - started;
    if (generation != policy->generation || bytes <= 0 || !(duration > 0.0 && duration <= DBL_MAX && now >= -DBL_MAX && now <= DBL_MAX))
        return;
    LGTransferDirection *direction = &policy->directions[upload ? 1 : 0];
    if (duration >= 8.0)
    {
        LGTransferPolicyRecordFailure(policy, upload, generation, now);
        return;
    }
    if (direction->successes != 0 && started - direction->lastSample > 1.0)
    {
        direction->bytes = 0;
        direction->successes = 0;
    }
    if (direction->successes == 0)
        direction->windowStart = started;
    else if (started < direction->windowStart)
        direction->windowStart = started;
    direction->lastSample = now;
    direction->bytes += bytes;
    direction->successes++;
    direction->duration = direction->duration == 0.0 ? duration : direction->duration * 0.8 + duration * 0.2;
    double elapsed = now - direction->windowStart;
    if (elapsed < 0.1 || direction->bytes < 256 * 1024 ||
        (direction->successes < 2 && direction->bytes < 512 * 1024))
        return;
    double rate = direction->bytes / elapsed;
    direction->rate = direction->rate == 0.0 ? rate : direction->rate * 0.7 + rate * 0.3;
    static const double thresholds[3] = {180.0 * 1024, 650.0 * 1024, 1536.0 * 1024};
    int maximumLevel = policy->constrained || policy->networkClass <= 1 ? 1 : 3;
    if (now >= direction->cooldownUntil && direction->level < maximumLevel && direction->rate >= thresholds[direction->level] && direction->duration < 3.0)
    {
        if (++direction->stableWindows >= 2)
        {
            direction->level++;
            direction->stableWindows = 0;
            direction->cooldownUntil = now + 3.0;
        }
    }
    else
    {
        direction->stableWindows = 0;
        if (direction->level > 0 && elapsed >= 2.0 && direction->rate < thresholds[direction->level - 1] / 3.0)
        {
            direction->level--;
            direction->cooldownUntil = now + 15.0;
        }
    }
    direction->windowStart = now;
    direction->bytes = 0;
    direction->successes = 0;
}

#endif
