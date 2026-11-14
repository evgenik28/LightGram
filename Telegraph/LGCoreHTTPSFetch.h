#ifndef LG_CORE_HTTPS_FETCH_H
#define LG_CORE_HTTPS_FETCH_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    LGCoreFetchStatusOK = 0,
    LGCoreFetchStatusInvalidArgument,
    LGCoreFetchStatusResolve,
    LGCoreFetchStatusConnect,
    LGCoreFetchStatusTLS,
    LGCoreFetchStatusCertificate,
    LGCoreFetchStatusIO,
    LGCoreFetchStatusProtocol,
    LGCoreFetchStatusTooLarge,
    LGCoreFetchStatusTimeout,
    LGCoreFetchStatusCancelled,
    LGCoreFetchStatusRejected
} LGCoreFetchStatus;

enum {
    LGCoreFetchLocationCapacity = 4096
};

typedef struct {
    int statusCode;
    int64_t contentLength;
    char location[LGCoreFetchLocationCapacity];
} LGCoreFetchHead;

typedef struct {
    const char *host;
    uint16_t port;
    const char *path;
    const char *const *headers;
    int idleTimeoutSeconds;
    uint64_t maximumBodyLength;
    int (*isCancelled)(void *context);
    int (*receiveBody)(void *context, const uint8_t *bytes, size_t length, int64_t expectedLength);
    void *context;
} LGCoreFetchRequest;

LGCoreFetchStatus LGCoreHTTPSFetch(const LGCoreFetchRequest *request, LGCoreFetchHead *head);

#ifdef __cplusplus
}
#endif

#endif
