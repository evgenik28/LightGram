#import "LGRemoteClock.h"

#include <math.h>
#include <pthread.h>

static NSString *const LGRemoteClockDifferenceKey = @"LGRemoteClockDifference";
static const NSTimeInterval LGRemoteClockPersistenceThreshold = 1.0;

static pthread_mutex_t LGRemoteClockLock = PTHREAD_MUTEX_INITIALIZER;
static NSTimeInterval LGRemoteClockCurrentDifference = 0.0;
static NSTimeInterval LGRemoteClockPersistedDifference = 0.0;
static BOOL LGRemoteClockLoaded = NO;

static void LGRemoteClockLoadLocked(void)
{
    if (LGRemoteClockLoaded)
        return;
    LGRemoteClockLoaded = YES;
    LGRemoteClockCurrentDifference = [[NSUserDefaults standardUserDefaults] doubleForKey:LGRemoteClockDifferenceKey];
    LGRemoteClockPersistedDifference = LGRemoteClockCurrentDifference;
}

NSTimeInterval LGRemoteClockDifference(void)
{
    pthread_mutex_lock(&LGRemoteClockLock);
    LGRemoteClockLoadLocked();
    NSTimeInterval difference = LGRemoteClockCurrentDifference;
    pthread_mutex_unlock(&LGRemoteClockLock);
    return difference;
}

NSTimeInterval LGRemoteClockTime(void)
{
    return CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970 + LGRemoteClockDifference();
}

void LGRemoteClockSetDifference(NSTimeInterval difference)
{
    if (isnan(difference) || isinf(difference))
        return;

    pthread_mutex_lock(&LGRemoteClockLock);
    LGRemoteClockLoadLocked();
    LGRemoteClockCurrentDifference = difference;
    BOOL persist = fabs(difference - LGRemoteClockPersistedDifference) >= LGRemoteClockPersistenceThreshold;
    if (persist)
        LGRemoteClockPersistedDifference = difference;
    pthread_mutex_unlock(&LGRemoteClockLock);

    if (persist)
        [[NSUserDefaults standardUserDefaults] setDouble:difference forKey:LGRemoteClockDifferenceKey];
}
