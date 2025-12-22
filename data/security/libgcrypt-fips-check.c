/*
 * This utility verifies that libgcrypt enforces FIPS boundaries at runtime.
 * It validates:
 * 1. HARD ENFORCEMENT: Blocking of unapproved primitives (e.g., RSA-1024).
 * 2. SOFT ENFORCEMENT: Success with a NON_COMPLIANT service indicator (e.g., MD5).
 * 3. COMPLIANCE: Success with a COMPLIANT indicator for approved algorithms.
 *
 * Output format: TAP v13 (Standard for OpenQA, Kselftest, and CI/CD).
 */

#include <gcrypt.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdbool.h>

/* Handle API drift between upstream (1.11+) and backports (1.10.x) */
#if !defined(GCRYCTL_FIPS_SERVICE_INDICATOR_MD) && defined(GCRYCTL_FIPS_SERVICE_INDICATOR_HASH)
#define GCRYCTL_FIPS_SERVICE_INDICATOR_MD GCRYCTL_FIPS_SERVICE_INDICATOR_HASH
#endif

typedef struct {
    const char *tag;  /* Human-readable algorithm name */
    int algo;         /* libgcrypt ID or RSA bit length */
    bool approved;    /* FIPS 140-3 approved status */
    bool is_rsa;      /* Type discriminator */
} test_case_t;

static const char *si_label(gcry_error_t si) {
    if (si == 0) return "COMPLIANT";
    if (gpg_err_code(si) == GPG_ERR_NOT_SUPPORTED) return "NON_COMPLIANT";
    if (gpg_err_code(si) == GPG_ERR_INV_OP) return "NOT_IMPLEMENTED";
    return "UNKNOWN";
}

static bool do_hash(int algo) {
    gcry_md_hd_t hd;
    if (gcry_md_open(&hd, algo, 0)) return false;
    gcry_md_write(hd, "probe", 5);
    bool ok = (gcry_md_read(hd, algo) != NULL);
    gcry_md_close(hd);
    return ok;
}

static bool do_rsa_gen(int nbits) {
    gcry_sexp_t p, k;
    char s[64];
    snprintf(s, sizeof(s), "(genkey (rsa (nbits 4:%d)))", nbits);

    if (gcry_sexp_new(&p, s, 0, 1)) return false;
    gcry_error_t rc = gcry_pk_genkey(&k, p);
    gcry_sexp_release(p);

    if (rc == 0) gcry_sexp_release(k);
    return rc == 0;
}

int main(void) {
    const char *v = gcry_check_version(NULL);
    if (!v) {
        fprintf(stderr, "libgcrypt version check failed\n");
        return 1;
    }

    if (gcry_control(GCRYCTL_INITIALIZATION_FINISHED, 0)) {
        fprintf(stderr, "libgcrypt initialization failed\n");
        return 1;
    }

    int active = (gcry_fips_mode_active() == 1);

    static const test_case_t suite[] = {
        {"HASH_MD5",    GCRY_MD_MD5,    false, false},
        {"HASH_SHA1",   GCRY_MD_SHA1,   false, false},
        {"HASH_SHA256", GCRY_MD_SHA256, true,  false},
        {"HASH_SHA384", GCRY_MD_SHA384, true,  false},
        {"HASH_SHA512", GCRY_MD_SHA512, true,  false},
        {"RSA_1024",    1024,           false, true},
        {"RSA_4096",    4096,           true,  true},
    };

    int num_tests = sizeof(suite) / sizeof(suite[0]);
    int failures = 0;

    /* 3. TAP Header and Plan */
    printf("TAP version 13\n");
    printf("# Libgcrypt: %s\n", v);
    printf("# FIPS Mode: %s\n", active ? "Enabled" : "Disabled");
    printf("1..%d\n", num_tests);

    /* 4. Execution Loop */
    for (int i = 0; i < num_tests; i++) {
        const test_case_t *t = &suite[i];

        /* Run the actual crypto operation */
        bool op_ok = t->is_rsa ? do_rsa_gen(t->algo) : do_hash(t->algo);

        /* Retrieve Dynamic Service Indicator (post-operation) */
        gcry_error_t si = op_ok ? gcry_get_fips_service_indicator() : 0;

        bool passed = false;
        const char *reason = "";

        if (!active) {
            /* In Non-FIPS mode, everything must work */
            passed = op_ok;
            reason = op_ok ? "Allowed in Non-FIPS" : "Unexpected block in Non-FIPS";
        } else {
            /* FIPS Validation Path */
            if (t->approved) {
                /* Approved algos MUST work AND be COMPLIANT */
                passed = (op_ok && si == 0);
                reason = passed ? "Compliant" : "Approved algo failed/flagged";
            } else {
                /* Forbidden algos MUST be BLOCKED OR flagged as NON_COMPLIANT */
                if (!op_ok) {
                    passed = true;
                    reason = "Correctly Blocked";
                } else {
                    passed = (gpg_err_code(si) == GPG_ERR_NOT_SUPPORTED);
                    reason = passed ? "Correctly Flagged Non-Compliant" : "Security Violation";
                }
            }
        }

        if (!passed) failures++;

        /* TAP Test Result Line */
        printf("%s %d - %s # op:%s si:%s (%s)\n",
               passed ? "ok" : "not ok",
               i + 1,
               t->tag,
               op_ok ? "OK" : "ERR",
               si_label(si),
               reason);
    }

    return failures ? 1 : 0;
}
