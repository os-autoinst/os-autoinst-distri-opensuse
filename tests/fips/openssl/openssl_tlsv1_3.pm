# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: openssl
# Summary: openssl 1.1.1 supports and negotiates by default the new TLS 1.3 protocol.
#          Applications that leave everything to the openssl library will automatically
#          start to negotiate the TLS 1.3 protocol. However, many packages have their
#          own settings which override the library defaults and these either have to be
#          recompiled against openssl 1.1.1 or might even need extra patching.
# Maintainer: QE Security <none@suse.de>
# Tags: poo#64992, tc#1744100

use base "consoletest";
use testapi;
use serial_terminal 'select_serial_terminal';
use apachetest;
use version_utils qw (is_sle is_sle_micro is_transactional package_version_cmp);
use security::openssl_misc_utils;

sub run_fips_tls1_3_tests {
    my $openssl_binary = shift // "openssl";

    setup_apache2(mode => 'SSL');

    # List the supported ciphers and make sure TLSV1.3 is there
    validate_script_output "$openssl_binary ciphers -v", sub { m/TLSv1\.3.*/xg };

    # Establish a transparent connection to apache server to check the TLS protocol
    validate_script_output "echo | $openssl_binary s_client -connect localhost:443 2>&1", sub { m/TLSv1\.3.*/xg };

    # Transfer a URL to check the TLS protocol
    validate_script_output 'curl -Ivvv  https://www.google.com 2>&1', sub { m/TLSv1\.3.*/xg };
}

sub run {
    select_serial_terminal;
    install_openssl;
    my $ver = get_openssl_full_version;
    record_info("Testing OpenSSL $ver");
    run_fips_tls1_3_tests;
    if (is_sle('>=15-SP6') && is_sle('<16')) {
        $ver = get_openssl_full_version(OPENSSL1_BINARY);
        record_info("Testing OpenSSL $ver");
        run_fips_tls1_3_tests();
    }
}

sub test_flags {
    return {
        #poo160197 workaround since rollback seems not working with swTPM
        no_rollback => is_transactional ? 1 : 0,
        fatal => 0
    };
}

1;
