#ifndef LGPluginAvailability_h
#define LGPluginAvailability_h

#if !defined(LIGHTGRAM_ARMV6) && (!defined(LIGHTGRAM_PLUGINS) || LIGHTGRAM_PLUGINS)
#define LG_PLUGINS_AVAILABLE 1
#else
#define LG_PLUGINS_AVAILABLE 0
#endif

#endif
