# openssl fips test
#
# Copyright © 2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Test variables: OPENSSL_FIPS and OPENSSL_FORCE_FIPS_MODE
# OPENSSL_FIPS=1: put the openssl CLI into FIPS mode
# OPENSSL_FORCE_FIPS_MODE=1: put the openssl library into FIPS mode
# Maintainer: Qingming Su <qingming.su@suse.com>

use base "consoletest";
use testapi;
use strict;

sub validate_fips {
    validate_script_output "openssl dgst -md5 /tmp/hello.txt 2>&1 || true", sub { m/disabled for fips|unknown option/ };
}

sub run {
    select_console 'root-console';

    # Prepare temp file for testing
    assert_script_run "echo Hello > /tmp/hello.txt";

    # Verify variable OPENSSL_FIPS
    type_string "export OPENSSL_FIPS=1\n";
    validate_fips;

    # Verify variable OPENSSL_FORCE_FIPS_MODE
    type_string "unset OPENSSL_FIPS; export OPENSSL_FORCE_FIPS_MODE=1\n";
    validate_fips;

    script_run 'rm -f /tmp/hello.txt';
}

1;
# vim: set sw=4 et:
