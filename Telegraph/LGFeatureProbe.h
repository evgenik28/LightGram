#import <Foundation/Foundation.h>
#import <stdarg.h>

#ifndef LG_COMPAT_FEATURE_PROBE_ENABLED
#define LG_COMPAT_FEATURE_PROBE_ENABLED 0
#endif

static inline void LGFeatureProbe(NSString *format, ...) __attribute__((format(__NSString__, 1, 2)));

static inline void LGFeatureProbe(NSString *format, ...)
{
#if LG_COMPAT_FEATURE_PROBE_ENABLED
    if (format != nil)
    {
        va_list arguments;
        va_start(arguments, format);
        NSString *message = [[NSString alloc] initWithFormat:format arguments:arguments];
        va_end(arguments);
    }
#else
    (void)format;
#endif
}
