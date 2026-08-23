#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include <stdint.h>
#include <unistd.h>
#include <sys/stat.h>
#include "moonbit.h"

/* Maximum file size: 1GB to prevent OOM on large files */
#define HYDRO_MAX_FILE_SIZE (1024L * 1024L * 1024L)

MOONBIT_FFI_EXPORT
int32_t hydro_write_file(
    moonbit_bytes_t path,
    moonbit_bytes_t content,
    int32_t content_len
) {
    /* Defense against negative content_len (P3-2) */
    if (content_len < 0) return -1;

    FILE *f = fopen((const char *)path, "wb");
    if (!f) return -1;
    size_t written = fwrite(content, 1, (size_t)content_len, f);
    fchmod(fileno(f), 0640);
    fsync(fileno(f));
    int close_err = fclose(f);
    if (close_err != 0) return -1;
    return (int32_t)(written == (size_t)content_len ? 0 : -1);
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t hydro_read_file(moonbit_bytes_t path) {
    FILE *f = fopen((const char *)path, "rb");
    if (!f) return moonbit_make_bytes(0, 0);

    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    if (size < 0) {
        fclose(f);
        return moonbit_make_bytes(0, 0);
    }

    /* P1-1: Check for integer overflow — size must fit in int32_t */
    if (size > INT32_MAX) {
        fclose(f);
        return moonbit_make_bytes(0, 0);
    }

    /* P2-1: Check for excessive file size to prevent OOM */
    if (size > HYDRO_MAX_FILE_SIZE) {
        fclose(f);
        return moonbit_make_bytes(0, 0);
    }

    fseek(f, 0, SEEK_SET);

    /* P2-2: size == 0 is valid — return empty bytes (not an error) */
    if (size == 0) {
        fclose(f);
        return moonbit_make_bytes(0, 0);
    }

    moonbit_bytes_t result = moonbit_make_bytes_raw((int32_t)size);
    size_t read = fread(result, 1, (size_t)size, f);
    fclose(f);

    if (read != (size_t)size) {
        return moonbit_make_bytes(0, 0);
    }
    return result;
}

/* P2-3: Dedicated file existence check — distinguishes empty files from missing files */
MOONBIT_FFI_EXPORT
int32_t hydro_file_exists(moonbit_bytes_t path) {
    FILE *f = fopen((const char *)path, "rb");
    if (!f) return 0;
    fclose(f);
    return 1;
}

/* P2-4: Delete file — used for test cleanup */
MOONBIT_FFI_EXPORT
int32_t hydro_delete_file(moonbit_bytes_t path) {
    int err = remove((const char *)path);
    return (int32_t)(err == 0 ? 0 : -1);
}

/* Get file size: returns size in bytes, or -1 on error */
MOONBIT_FFI_EXPORT
int32_t hydro_file_size(moonbit_bytes_t path) {
    struct stat st;
    if (stat((const char *)path, &st) != 0) return -1;
    if (st.st_size > INT32_MAX) return -1;
    return (int32_t)st.st_size;
}
