/*
 * This utility verifies libgcrypt public-key operations at runtime.
 * It validates:
 * 1. KEY GENERATION: Successful creation of cryptographic keypairs.
 * 2. SIGNING: Ability to generate valid digital signatures.
 * 3. VERIFICATION: Correct validation of generated signatures.
 *
 * Algorithms covered:
 * - RSA     (baseline, must always work)
 * - ECDSA   (FIPS-approved, must work in FIPS mode)
 * - ML-DSA  (post-quantum, optional / may be disabled in FIPS)
 *
 * Output format:
 *   RSA: OK / FAIL
 *   ECDSA: OK / FAIL
 *   ML-DSA: OK / FAIL / SKIPPED
 *
 * Purpose:
 * Ensures that libgcrypt correctly performs real cryptographic
 * operations under current system policy (FIPS or non-FIPS).
 */

#include <gcrypt.h>
#include <stdio.h>

/* Helper: generate key, sign data, verify signature */
static int test_algo(const char *genkey_expr) {
    gcry_sexp_t key = NULL;
    gcry_sexp_t parms = NULL;
    gcry_sexp_t data = NULL;
    gcry_sexp_t sig = NULL;
    int rc;

    /* Key generation parameters */
    rc = gcry_sexp_new(&parms, genkey_expr, 0, 1);
    if (rc)
        return -1;

    /* Generate keypair */
    rc = gcry_pk_genkey(&key, parms);
    gcry_sexp_release(parms);
    if (rc)
        return -1;

    /* Prepare data */
    rc = gcry_sexp_new(&data,
        "(data (flags raw) (value \"openqa-test\"))",
        0, 1);
    if (rc) {
        gcry_sexp_release(key);
        return -1;
    }

    /* Sign */
    rc = gcry_pk_sign(&sig, data, key);
    if (rc) {
        gcry_sexp_release(data);
        gcry_sexp_release(key);
        return -1;
    }

    /* Verify */
    rc = gcry_pk_verify(sig, data, key);

    /* Cleanup */
    gcry_sexp_release(sig);
    gcry_sexp_release(data);
    gcry_sexp_release(key);

    return rc ? -1 : 0;
}

int main(void) {
    const char *ver;

    ver = gcry_check_version(NULL);
    if (!ver) {
        printf("INIT: FAIL\n");
        return 1;
    }

    gcry_control(GCRYCTL_INITIALIZATION_FINISHED, 0);

    printf("# libgcrypt: %s\n", ver);

    /* RSA */
    if (test_algo("(genkey (rsa (nbits 4:2048)))") == 0)
        printf("RSA: OK\n");
    else
        printf("RSA: FAIL\n");

    /* ECDSA */
    if (test_algo("(genkey (ecdsa (curve \"NIST P-256\")))") == 0)
        printf("ECDSA: OK\n");
    else
        printf("ECDSA: FAIL\n");

#ifdef GCRY_PK_MLDSA
    /* ML-DSA (PQC) */
    if (test_algo("(genkey (ml-dsa))") == 0)
        printf("ML-DSA: OK\n");
    else
        printf("ML-DSA: FAIL\n");
#else
    printf("ML-DSA: SKIPPED\n");
#endif

    return 0;
}
