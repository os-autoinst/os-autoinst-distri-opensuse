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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static unsigned char *read_file(const char *path, size_t *len)
{
    FILE *f = fopen(path, "rb");
    if (!f) { perror(path); exit(1); }

    if (fseek(f, 0, SEEK_END) != 0) { perror("fseek"); exit(1); }
    long size = ftell(f);
    if (size < 0) { perror("ftell"); exit(1); }
    rewind(f);

    unsigned char *buf = NULL;
    if (size > 0) {
        buf = (unsigned char *)malloc((size_t)size);
        if (!buf) { perror("malloc"); exit(1); }
        if (fread(buf, 1, (size_t)size, f) != (size_t)size) {
            perror("fread");
            exit(1);
        }
    }

    fclose(f);
    *len = (size_t)size;
    return buf;
}

static int *compute_prefix_function(const unsigned char *pattern, int psize)
{
    if (psize <= 0) return NULL;

    int *pi = (int *)malloc(sizeof(int) * (size_t)psize);
    if (!pi) return NULL;

    int k = -1;
    pi[0] = -1;

    for (int i = 1; i < psize; i++) {
        while (k > -1 && pattern[k + 1] != pattern[i])
            k = pi[k];
        if (pattern[i] == pattern[k + 1])
            k++;
        pi[i] = k;
    }
    return pi;
}

/* Returns length of longest suffix(target) that equals prefix(pattern). */
static size_t kmp_overlap_end(
    const unsigned char *target, size_t tsize,
    const unsigned char *pattern, size_t psize
)
{
    if (tsize == 0 || psize == 0) return 0;

    /* Only the last min(tsize, psize) bytes can participate in an end-overlap. */
    size_t window = (tsize < psize) ? tsize : psize;
    const unsigned char *t = target + (tsize - window);

    int *pi = compute_prefix_function(pattern, (int)psize);
    if (!pi) return 0;

    int k = -1;
    for (size_t i = 0; i < window; i++) {
        while (k > -1 && pattern[k + 1] != t[i])
            k = pi[k];
        if (pattern[k + 1] == t[i])
            k++;
        /* do NOT reset k on full match. */
    }

    free(pi);
    return (size_t)(k + 1);
}

int main(int argc, char **argv)
{
    if (argc != 3 && argc != 4) {
        fprintf(stderr, "usage: %s A B [INJECT]\n", argv[0]);
        return 1;
    }

    const unsigned char *inject = NULL;
    size_t inject_len = 0;
    if (argc == 4) {
        inject = (const unsigned char *)argv[3];
        inject_len = strlen(argv[3]);
    }

    size_t lenA = 0, lenB = 0;
    unsigned char *A = read_file(argv[1], &lenA);
    unsigned char *B = read_file(argv[2], &lenB);

    size_t overlap = kmp_overlap_end(A, lenA, B, lenB);

    /* Always print whole A */
    if (lenA) fwrite(A, 1, lenA, stdout);

    /* If no overlap, optionally inject text */
    if (overlap == 0 && inject && inject_len)
        fwrite(inject, 1, inject_len, stdout);

    /* Then print B without duplicated prefix */
    if (lenB) fwrite(B + overlap, 1, lenB - overlap, stdout);

    free(A);
    free(B);
    return 0;
}