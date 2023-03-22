# SUSE's openjdk fips tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: openjdk expect
#
# Summary: FIPS: openjdk
#          Jira feature: SLE-21206
#          FIPS 140-3: make OpenJDK be able to use the NSS certified crypto
#          Test case GET "Supported Cipher Suites and list all crypto providers
# Tags: poo#112034
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use openjdktest;

sub run {
    my $self = @_;

    select_console "root-console";

    # If file from previous test doesn't exist, then setup test from scratch
    if (script_run("test -f $jdk11_done_file") != 0) {
        prepare_test();
    }

    remove_any_installed_java();

    zypper_call("in java-17-openjdk java-17-openjdk-devel");

    my $crypto = run_crypto_test();
    record_info("FAIL", "Cannot list all crypto providers", result => 'fail') if ($crypto !~ /Listing all JCA Security Providers/);

    my $JDK_TCHECK = get_var("JDK_TCHECK", "https://gitlab.suse.de/qe-security/testing/-/raw/main/data/openjdk/Tcheck.java");
    my $out = run_tcheck_test($JDK_TCHECK);
    record_info("FAIL", "Actually result VS Expected result: $out", result => 'fail') if ($out ne '');
}

sub test_flags {
    return {no_rollback => 1};
}

1;
