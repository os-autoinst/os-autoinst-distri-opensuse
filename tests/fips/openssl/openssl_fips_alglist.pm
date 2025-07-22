# SUSE's openQA tests
# openssl FIPS test
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: openssl
# Summary: openssl should only list FIPS approved cryptographic functions
#          while system is working in FIPS mode
#
# Maintainer: QE Security <none@suse.de>
# Tags: poo#44831, poo#65375, poo#101932, poo#111818

use base "consoletest";
use testapi;
use serial_terminal 'select_serial_terminal';
use version_utils qw(is_sle is_sle_micro is_transactional);
use security::openssl_misc_utils;

sub check_algos {
    my ($openssl_binary, $list_command, $valid_algos_ref, $pattern) = @_;
    my @valid_algos = @$valid_algos_ref;

    my $is_openssl3 = get_openssl_x_y_version($openssl_binary) >= 3.0 ? 1 : 0;

    my @openssl_output = split /\n/, script_output("$openssl_binary $list_command");

    foreach my $line (@openssl_output) {
        chomp $line;
        next unless ($is_openssl3 && $line =~ /$pattern->{fips}/) || ($is_openssl3 == 0 && $line =~ /$pattern->{name}/);

        my $invalid_algo_found = 1;
        foreach my $valid_algo (@valid_algos) {
            if ($line =~ /$valid_algo/) {
                $invalid_algo_found = 0;
                last;
            }
        }
        die "Error: Invalid algorithm found - $line\n" if ($invalid_algo_found == 1);
    }
}

sub check_pk_algos {
    my ($openssl_binary) = @_;

    my @valid_algos = qw(RSA rsa DSA dsa EC DH HMAC CMAC);
    push(@valid_algos, 'ED', 'ML') unless is_sle('<16');
    push(@valid_algos, 'HKDF', 'TLS1-PRF') if has_default_openssl3;
    my %pattern = (
        fips => '\@ fips',
        name => 'Name:',
    );

    check_algos($openssl_binary, 'list -public-key-algorithms', \@valid_algos, \%pattern);
}

sub check_hash_algos {
    my ($openssl_binary) = @_;

    my @valid_algos = qw(SHA1 SHA224 SHA256 SHA384 SHA512 DSA SHA3-224 SHA3-256 SHA3-384 SHA3-512 SHAKE128 SHAKE256);
    push(@valid_algos, 'KECCAK') if has_default_openssl3;
    my %pattern = (
        fips => '\@ fips',
        name => undef,
    );

    check_algos($openssl_binary, 'list -digest-algorithms', \@valid_algos, \%pattern);
}

sub run_alglist_fips_tests {
    my $openssl_binary = shift // "openssl";
    record_info('Testing public key algorithms');
    check_pk_algos "$openssl_binary";
    record_info('Testing digest algorithms');
    check_hash_algos "$openssl_binary";
}

sub run {
    select_serial_terminal;
    install_openssl;
    my $ver = get_openssl_full_version;
    record_info("Testing OpenSSL $ver");
    run_alglist_fips_tests;
    if (is_sle('>=15-SP6') && is_sle('<16')) {
        $ver = get_openssl_full_version(OPENSSL1_BINARY);
        record_info("Testing OpenSSL $ver");
        run_alglist_fips_tests(OPENSSL1_BINARY);
    }
}

sub test_flags {
    return {
        #poo160197 workaround since rollback seems not working with swTPM
        no_rollback => is_transactional ? 1 : 0,
        fatal => 1
    };
}

1;
