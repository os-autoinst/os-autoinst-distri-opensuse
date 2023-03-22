# Copyright 2017-2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Base module for openjdk test cases
# Maintainer: QE Security <none@suse.de>

package openjdktest;

use base Exporter;
use Exporter;

use consoletest;
use strict;
use warnings;
use testapi;
use utils;

our @EXPORT = qw(
  $jdk11_done_file
  prepare_test
  run_crypto_test
  run_tcheck_test
  remove_any_installed_java
);

our $jdk11_done_file = "/tmp/openjdk11_done";

sub prepare_test {
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

    zypper_call("in mozilla-nss-tools git-core");

    # Configure nssdb
    assert_script_run("mkdir /etc/pki/nssdb");
    script_run_interactive("certutil -d /etc/pki/nssdb -N", $interactive_str, 30);
    assert_script_run("chmod og+r /etc/pki/nssdb/*");
}

sub run_crypto_test {
    script_run("cd ~; rm -rf JavaCryptoTest");
    assert_script_run("cd ~; rm -rf JavaCryptoTest ; git clone -q https://github.com/ecki/JavaCryptoTest");
    script_run("cd ~/JavaCryptoTest/src/main/java/");
    script_run("javac net/eckenfels/test/jce/JCEProviderInfo.java");
    return script_output("java -cp ~/JavaCryptoTest/src/main/java/ net.eckenfels.test.jce.JCEProviderInfo");
}

sub run_tcheck_test {
    my ($JDK_TCHECK) = @_;
    script_run('cd ~ && find . -name "*Tcheck*" -delete');
    assert_script_run("wget --quiet --no-check-certificate $JDK_TCHECK");
    assert_script_run("chmod 777 Tcheck.java");
    assert_script_run("javac Tcheck.java");
    assert_script_run("java Tcheck > result.txt");
    my $EX_TCHECK = get_var("EX_TCHECK", "https://gitlab.suse.de/qe-security/testing/-/raw/main/data/openjdk/Tcheck.txt");
    assert_script_run("wget --quiet --no-check-certificate $EX_TCHECK");
    return script_output("diff -a Tcheck.txt result.txt");
}

sub remove_any_installed_java {
    my @output = grep /java-\d+-openjdk/, split(/\n/, script_output "rpm -qa 'java-*'");
    return unless scalar @output;    # nothing to remove
    my $pkgs = join ' ', @output;
    zypper_call "rm ${pkgs}";
}


1;
