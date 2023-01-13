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

sub remove_any_installed_java {
    my @output = grep /java-\d+-openjdk/, split(/\n/, script_output "rpm -qa 'java-*'");
    return unless scalar @output;    # nothing to remove
    my $pkgs = join ' ', @output;
    zypper_call "rm ${pkgs}";
}


sub run {
    my $self = @_;

    my $interactive_str = [
        {
            prompt => qr/Enter new password/m,
            key => 'ret',
        },
        {
            prompt => qr/Re-enter password/m,
            key => 'ret',
        },
    ];

    select_console "root-console";
    zypper_call("in mozilla-nss-tools git-core");

    # Configure nssdb
    assert_script_run("mkdir /etc/pki/nssdb");
    script_run_interactive("certutil -d /etc/pki/nssdb -N", $interactive_str, 30);
    assert_script_run("chmod og+r /etc/pki/nssdb/*");

    # ensure there ain't newer JDK before installing jdk11
    remove_any_installed_java();

    # Install openJDK 11
    zypper_call("in java-11-openjdk java-11-openjdk-devel");

    # Simple java crypto test
    assert_script_run("cd ~;git clone -q https://github.com/ecki/JavaCryptoTest");
    script_run("cd ~/JavaCryptoTest/src/main/java/");
    script_run("javac net/eckenfels/test/jce/JCEProviderInfo.java");
    my $crypto = script_output("java -cp ~/JavaCryptoTest/src/main/java/ net.eckenfels.test.jce.JCEProviderInfo");
    record_info("FAIL", "Cannot list all crypto providers", result => 'fail') if ($crypto !~ /Listing all JCA Security Providers/);

    # Prepare testing data
    my $JDK_TCHECK = get_var("JDK_TCHECK", "https://gitlab.suse.de/qe-security/testing/-/raw/main/data/openjdk/Tcheck.java");
    assert_script_run("cd ~;wget --quiet --no-check-certificate $JDK_TCHECK");
    assert_script_run("chmod 777 Tcheck.java");
    assert_script_run("javac Tcheck.java");
    assert_script_run("java Tcheck > result.txt");
    my $EX_TCHECK = get_var("EX_TCHECK", "https://gitlab.suse.de/qe-security/testing/-/raw/main/data/openjdk/Tcheck.txt");
    assert_script_run("wget --quiet --no-check-certificate $EX_TCHECK");
    my $out = script_output("diff -a Tcheck.txt result.txt");
    record_info("FAIL", "Actually result VS Expected result: $out", result => 'fail') if ($out ne '');
}

sub test_flags {
    return {no_rollback => 1};
}

1;
