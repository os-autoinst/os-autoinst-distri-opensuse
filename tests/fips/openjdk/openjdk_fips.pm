# SUSE's openjdk fips tests
#
# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: FIPS: openjdk
#          Jira feature: SLE-21206
#          FIPS 140-3: make OpenJDK be able to use the NSS certified crypto
#          Test case GET "Supported Cipher Suites and list all crypto providers
# Tags: poo#112034
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use utils;
use openjdktest;
use version_utils qw(is_sle is_leap is_tumbleweed);

sub run {
    my $self = @_;

    my @java_versions = (17);
    if (is_sle('<=15-SP5') || is_leap('<=15.5')) {
        push @java_versions, 11;
    } elsif (is_sle('>=15-SP6') || is_leap('<=15.6') || is_tumbleweed) {
        push @java_versions, 21;
    } else {
        die "Unsupported SLE/openSUSE version for this test.";
    }

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
