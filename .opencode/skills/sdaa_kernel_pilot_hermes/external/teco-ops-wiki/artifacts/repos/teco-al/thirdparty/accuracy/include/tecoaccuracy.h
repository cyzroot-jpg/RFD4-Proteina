#ifndef INCLUDE_TECOACCURACY_H_
#define INCLUDE_TECOACCURACY_H_

#ifndef TECOACCURACYWINAPI
#ifdef _WIN32
#define TECOACCURACYWINAPI __stdcall
#else
#define TECOACCURACYWINAPI
#endif
#endif

#define TECOACCURACY_MAJOR 1
#define TECOACCURACY_MINOR 0
#define TECOACCURACY_PATCHLEVEL 0

#define TECOACCURACY_VERSION \
    (TECOACCURACY_MAJOR * 10000 + TECOACCURACY_MINOR * 100 + TECOACCURACY_PATCHLEVEL)

#include <stdlib.h>

#if defined(__cplusplus)
extern "C" {
#endif

struct tecoaccuracyContext;
typedef struct tecoaccuracyContext *tecoaccuracyHandle_t;

typedef enum {
    TECOACCURACY_STATUS_SUCCESS = 0,
    TECOACCURACY_STATUS_VERSION_MISMATCH = 1,
    TECOACCURACY_STATUS_NOT_INITIALIZED = 2,
    TECOACCURACY_STATUS_ALLOCATION_FAILED = 3,
    TECOACCURACY_STATUS_TYPE_ERROR = 4,
    TECOACCURACY_STATUS_OUT_OF_RANGE = 5,
    TECOACCURACY_STATUS_LENGTH_NOT_MULTIPLE = 6,
    TECOACCURACY_STATUS_REINITIALIZED = 7,
    TECOACCURACY_STATUS_NOT_IMPLEMENT = 8,
    TECOACCURACY_STATUS_INITIALIZATION_FAILED = 9,
    TECOACCURACY_STATUS_ARCH_MISMATCH = 10,
    TECOACCURACY_STATUS_INTERNAL_ERROR = 11,
    TECOACCURACY_STATUS_UNKNOW_ERROR  = 12
} tecoaccuracyStatus_t;

typedef enum {
    TECOACCURACY_DATA_CHAR = 0,
    TECOACCURACY_DATA_INT16 = 1,
    TECOACCURACY_DATA_INT32 = 2,
    TECOACCURACY_DATA_INT64 = 3,
    TECOACCURACY_DATA_UCHAR = 4,
    TECOACCURACY_DATA_UINT16 = 5,
    TECOACCURACY_DATA_UINT32 = 6,
    TECOACCURACY_DATA_UINT64 = 7,
    TECOACCURACY_DATA_HALF = 8,
    TECOACCURACY_DATA_BFLOAT16 = 9,
    TECOACCURACY_DATA_FLOAT = 10,
    TECOACCURACY_DATA_DOUBLE = 11,
} tecoaccuracyDataType_t;

typedef enum {
    TECOACCURACY_JSON = 0,
    TECOACCURACY_LOG_INFO = 1,
} tecoaccuracyReportForm_t;

typedef struct {
    unsigned version;
    unsigned time_sec;      /* epoch time in seconds */
    unsigned time_usec;     /* microseconds part of epoch time */
    unsigned time_delta;    /* time since start in seconds */
    unsigned long long pid; /* process ID */
    unsigned long long tid; /* thread ID */
    bool is_passed;
    bool is_exception;
    int reserved[64];       /* reserved for future use */
} tecoaccuracyReport_t;

typedef void (*tecoaccuracyCallback_t)(void *udata,
    const tecoaccuracyReport_t *dbg, const char *msg);

typedef struct {
    tecoaccuracyReportForm_t form;
    int reserved[64];       /* reserved for future use */
} tecoaccuracyAttribute_t;


size_t TECOACCURACYWINAPI tecoaccuracyGetVersion(void);

tecoaccuracyStatus_t TECOACCURACYWINAPI tecoaccuracyCreate(tecoaccuracyHandle_t *handle);
tecoaccuracyStatus_t TECOACCURACYWINAPI tecoaccuracyDestroy(tecoaccuracyHandle_t handle);

tecoaccuracyStatus_t TECOACCURACYWINAPI tecoaccuracySetAttribute(
        tecoaccuracyHandle_t handle, tecoaccuracyAttribute_t att);
tecoaccuracyStatus_t TECOACCURACYWINAPI tecoaccuracyGetattribute(
        tecoaccuracyHandle_t handle, tecoaccuracyAttribute_t *att);

tecoaccuracyStatus_t TECOACCURACYWINAPI tecoaccuracySetCallback(
        tecoaccuracyHandle_t handle, void *udata, tecoaccuracyCallback_t fptr);

tecoaccuracyStatus_t TECOACCURACYWINAPI tecoaccuracyGetCallback(
        tecoaccuracyHandle_t handle, void **udata, tecoaccuracyCallback_t *fptr);

tecoaccuracyStatus_t TECOACCURACYWINAPI tecoaccuracyTwoSideValidate(
    tecoaccuracyHandle_t handle, void* tecorigin, void* compare,
    tecoaccuracyDataType_t compare_type, size_t num);

#if defined(__cplusplus)
}
#endif

#endif  // INCLUDE_TECOACCURACY_H_
