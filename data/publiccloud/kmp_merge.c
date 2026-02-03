/*
 * kmp_merge.c
 *
 * Byte-level merge of two files using KMP overlap at the VERY END of A:
 *   output = A + (B without duplicated prefix)
 *
 * Optional injection text when there is NO overlap:
 *   output = A + INJECT + B   (only if overlap == 0 and INJECT provided)
 *
 * Binary-safe for files A/B.
 * INJECT is taken from argv as a literal string (no escape processing).
 */

#include <err.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

static unsigned char *read_file(const char *path, size_t *len)
{
    FILE *f = fopen(path, "rb");
    if (!f)
        err(1, "%s", path);

    struct stat st;
    if (fstat(fileno(f), &st) != 0)
        err(1, "fstat");

    if (st.st_size < 0)
        errx(1, "negative file size");

    size_t size = (size_t)st.st_size;
    unsigned char *buf = NULL;

    if (size > 0) {
        buf = malloc(size);
        if (!buf)
            err(1, "malloc");
        if (fread(buf, 1, size, f) != size)
            err(1, "fread");
    }

    fclose(f);
    *len = size;
    return buf;
}

/*
 * Prefix function:
 * pi[i] = length of longest proper prefix of pattern[0..i]
 *         that is also a suffix ending at i
 */
static size_t *compute_prefix_function(const unsigned char *pattern, size_t psize)
{
    if (psize == 0)
        return NULL;

    size_t *pi = malloc(sizeof(size_t) * psize);
    if (!pi)
        return NULL;

    pi[0] = 0;
    for (size_t i = 1; i < psize; i++) {
        size_t k = pi[i - 1];
        while (k > 0 && pattern[i] != pattern[k])
            k = pi[k - 1];
        if (pattern[i] == pattern[k])
            k++;
        pi[i] = k;
    }

    return pi;
}

/* Returns length of longest suffix(target) matching prefix(pattern). */
static size_t kmp_overlap_end(
    const unsigned char *target, size_t tsize,
    const unsigned char *pattern, size_t psize
)
{
    if (tsize == 0 || psize == 0)
        return 0;

    size_t window = (tsize < psize) ? tsize : psize;
    const unsigned char *t = target + (tsize - window);

    size_t *pi = compute_prefix_function(pattern, psize);
    if (!pi)
        return 0;

    size_t k = 0;
    for (size_t i = 0; i < window; i++) {
        while (k > 0 && t[i] != pattern[k])
            k = pi[k - 1];
        if (t[i] == pattern[k])
            k++;
    }

    free(pi);
    return k;
}

int main(int argc, char **argv)
{
    if (argc != 3 && argc != 4) {
        fprintf(stderr, "usage: %s A B [INJECT]\n", argv[0]);
        return 1;
    }

    if (argc == 4 && strlen(argv[3]) > 65536)
        errx(1, "INJECT too large; use file/stdin");

    const unsigned char *inject = NULL;
    size_t inject_len = 0;
    if (argc == 4) {
        inject = (const unsigned char *)argv[3];
        inject_len = strlen(argv[3]); /* text-only by design */
    }

    size_t lenA = 0, lenB = 0;
    unsigned char *A = read_file(argv[1], &lenA);
    unsigned char *B = read_file(argv[2], &lenB);

    size_t overlap = kmp_overlap_end(A, lenA, B, lenB);

    if (lenA)
        fwrite(A, 1, lenA, stdout);

    if (overlap == 0 && inject && inject_len)
        fwrite(inject, 1, inject_len, stdout);

    if (lenB)
        fwrite(B + overlap, 1, lenB - overlap, stdout);

    free(A);
    free(B);
    return 0;
}
