# SUSE's openjdk fips tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: FIPS: openjdk
#          Jira feature: SLE-21206
#          FIPS 140-3: make OpenJDK be able to use the NSS certified crypto
#          Test case GET "Supported Cipher Suites and list all crypto providers
# Tags: poo#112034
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base "opensusebasetest";
use testapi;
use utils;
use openjdktest;
use registration qw(add_suseconnect_product);
use version_utils qw(is_sle is_sled is_rt is_sles4sap);

sub get_java_versions {
    # on newer version we need legacy module for openjdk 11, but is not available
    # on SLERT/SLED, can't test openjdk 11. On 15-SP7 17 is also in legacy module
    return '21' if (is_rt || is_sled) && is_sle('>=15-SP7');
    return '11 17 21' if (is_sle '>=15-SP6');
    return '17 21' if ((is_rt || is_sled) && is_sle('>=15-SP6'));
    return '11 17';
}

sub run {
    my $self = @_;

    my @java_versions = split(' ', get_java_versions);

    # SLED and SLERT do not have legacy module; SLE4SAP needs Development tools for jsch
    add_suseconnect_product 'sle-module-legacy' unless (is_sle('>=15-SP6') && (is_rt || is_sled));
    add_suseconnect_product 'sle-module-development-tools' if is_sles4sap;

    foreach my $version (@java_versions) {
        configure_java_version $version;
        record_info "INFO: running crypto test for OpenJDK $version";
        run_crypto_test $version;
        record_info "INFO: running SSH test for OpenJDK $version";
        run_ssh_test $version;
    }
}

sub test_flags {
    return {no_rollback => 1};
}

1;
