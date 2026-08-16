#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "moonbit.h"

MOONBIT_FFI_EXPORT
int32_t hydro_write_file(
    moonbit_bytes_t path,
    moonbit_bytes_t content,
    int32_t content_len
) {
    FILE *f = fopen((const char *)path, "wb");
    if (!f) return -1;
    size_t written = fwrite(content, 1, (size_t)content_len, f);
    fclose(f);
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
    fseek(f, 0, SEEK_SET);

    moonbit_bytes_t result = moonbit_make_bytes_raw((int32_t)size);
    size_t read = fread(result, 1, (size_t)size, f);
    fclose(f);

    if (read != (size_t)size) {
        return moonbit_make_bytes(0, 0);
    }
    return result;
}
