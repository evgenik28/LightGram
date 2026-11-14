#ifndef LGDiagnostics_h
#define LGDiagnostics_h

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    LGDiagnosticsComponentLightGram = 0,
    LGDiagnosticsComponentHelper = 1
} LGDiagnosticsComponent;

extern bool LGDiagnosticsActive;

static inline bool LGDiagnosticsEnabled(void)
{
    return LGDiagnosticsActive;
}

bool LGDiagnosticsOverride(LGDiagnosticsComponent component, bool *value);
bool LGDiagnosticsSetOverride(LGDiagnosticsComponent component, bool value);
bool LGDiagnosticsResolve(LGDiagnosticsComponent component, bool buildDefault);
void LGDiagnosticsActivate(LGDiagnosticsComponent component, bool buildDefault);

#ifdef __cplusplus
}
#endif

#endif
