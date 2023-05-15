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
    zypper_call("in mozilla-nss-tools git-core");

    # ensure there ain't newer JDK before installing jdk11
    remove_any_installed_java();

    zypper_call("in java-17-openjdk java-17-openjdk-devel");

    my $vers_file = "/tmp/java_versions.txt";
    script_output("java -version &> $vers_file; javac -version &>> $vers_file");
    validate_script_output("cat $vers_file", sub { m/openjdk version "17\..*/ });
    validate_script_output("cat $vers_file", sub { m/javac 17\..*/ });
    script_output("rm $vers_file");

    # Simple java crypto test
    script_run("cd ~/JavaCryptoTest/src/main/java/");
    script_run("javac net/eckenfels/test/jce/JCEProviderInfo.java");
    my $crypto = script_output("java -cp ~/JavaCryptoTest/src/main/java/ net.eckenfels.test.jce.JCEProviderInfo");
    record_info("FAIL", "Cannot list all crypto providers", result => 'fail') if ($crypto !~ /Listing all JCA Security Providers/);

    my $JDK_TCHECK = get_var("JDK_TCHECK", "https://gitlab.suse.de/qe-security/testing/-/raw/main/data/openjdk/Tcheck.java");
    assert_script_run("cd ~;wget --quiet --no-check-certificate $JDK_TCHECK");
    assert_script_run("javac Tcheck.java");
    # poo125654: we only need to check that '1. SunPKCS11-NSS-FIPS using library null' is present and at the first place
    validate_script_output("java Tcheck", sub { m/.* 1\. SunPKCS11-NSS-FIPS using library null.*/ });
}

sub test_flags {
    return {no_rollback => 1};
}

1;
