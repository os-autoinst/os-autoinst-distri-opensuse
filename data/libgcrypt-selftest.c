#include <stdio.h>
#include <gcrypt.h>

int main(void) {
    if (!gcry_check_version (GCRYPT_VERSION)) {
        fputs ("libgcrypt version mismatch\n", stderr);
        exit (1);
    }

    gcry_control (GCRYCTL_DISABLE_SECMEM);

    gcry_control (GCRYCTL_INITIALIZATION_FINISHED);

    if (gcry_control (GCRYCTL_SELFTEST, 0)) {
        fputs ("libgcrypt selftest failed\n", stderr);
        exit (1);
    } else {
        fputs ("libgcrypt selftest successful\n", stdout);
    }

    return 0;
}
