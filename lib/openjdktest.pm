# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Base module for openJDK test cases
# Maintainer: QE Security <none@suse.de>

package openjdktest;

use base Exporter;
use Exporter;

use consoletest;
use strict;
use warnings;
use testapi;
use utils;
use serial_terminal qw(select_user_serial_terminal select_serial_terminal);
use package_utils 'install_package';
use version_utils qw(is_transactional is_sle);
use transactional 'trup_call';

our @EXPORT = qw(
  remove_any_installed_java
  run_crypto_test
  download_and_set_permissions
  prepare_java_ssh_test
  configure_java_version
  run_ssh_test
);

sub remove_any_installed_java {
    my @output = grep /java-\d+-openjdk/, split(/\n/, script_output "rpm -qa 'java-*'");
    return unless scalar @output;    # nothing to remove
    my $pkgs = join ' ', @output;
    is_transactional ? trup_call("pkg remove ${pkgs}") : zypper_call("rm ${pkgs}");
}

sub configure_java_version {
    my ($version) = @_;
    select_serial_terminal;

    remove_any_installed_java();

    install_package("java-$version-openjdk java-$version-openjdk-devel", trup_continue => 1);

    my $permission = ($version > 15) ? "og+rw" : "og+r";
    assert_script_run("chmod $permission /etc/pki/nssdb/*");

    select_user_serial_terminal();
    my $vers_file = "/tmp/java_versions_$version.txt";
    script_output("java -version &> $vers_file; javac -version &>> $vers_file");
    validate_script_output("cat $vers_file", sub { m/openjdk version "$version\..*/ });
    validate_script_output("cat $vers_file", sub { m/javac $version\..*/ });
    script_output("rm $vers_file");
}

sub run_crypto_test {
    my ($version) = @_;

    assert_script_run 'curl -O ' . data_url('security/openjdk/GetJCEProviderInfo.java');
    script_run("javac GetJCEProviderInfo.java");
    my $crypto = script_output("java GetJCEProviderInfo");
    record_info("FAIL", "Cannot list all crypto providers", result => 'fail') if ($crypto !~ /Listing all JCA Security Providers/);

    #moved from https://gitlab.suse.de/qe-security/testing/-/raw/main/data/openjdk/Tcheck.java
    my $JDK_TCHECK = get_var("JDK_TCHECK", data_url('security/openjdk/Tcheck.java'));
    assert_script_run("cd ~; test -f Tcheck.java || wget --quiet --no-check-certificate $JDK_TCHECK");
    assert_script_run("javac Tcheck.java");
    # Provider #1 must be the NSS-FIPS one. On 15.x and 16.1 it's 'SunPKCS11-NSS-FIPS using library null' (poo#125654).
    # On 16.0 the FIPS update is already in and it's 'SunPKCS11-FIPS using library .../libnssadapter.so';
    # 16.1 will switch to that variant once the update lands, so accept either on 16+ (poo#199250).
    my $null = qr{SunPKCS11-NSS-FIPS using library null};
    my $adapter = qr{SunPKCS11-FIPS using library \S+/libnssadapter\.so};
    my $expected = is_sle('>=16') ? qr{ 1\. (?:$null|$adapter)} : qr{ 1\. $null};
    validate_script_output("java Tcheck", sub { m/$expected/ });
}

sub run_ssh_test {
    my ($version) = @_;

    select_serial_terminal;

    install_package("jsch", trup_continue => 1);

    select_user_serial_terminal();
    my $java_src = "Shell.java";
    my $url = get_var("TEST_JAVA", data_url("security/openjdk/$java_src"));
    my $cp = script_output('rpm -ql jsch |grep jsch.jar') . ':.';

    assert_script_run("wget --quiet --no-check-certificate -O $java_src $url");
    assert_script_run("javac -cp $cp Shell.java");

    my $output = script_output(
        "java -cp $cp Shell '$testapi::username\@localhost' '$testapi::password' 2>&1 || true",
        timeout => 60,
    );
    return if $output =~ /\Q$testapi::username\E/;
    return record_soft_failure("bsc#1266034 - java-11-openjdk DH KeyAgreement fails in FIPS mode (CKR_ATTRIBUTE_SENSITIVE)")
      if $version eq '11' && $output =~ /Could not derive key/;
    return record_info("FAIL", "java.security.ProviderException: Could not derive key", result => 'fail')
      if $output =~ /Could not derive key/;
    die "openjdk SSH test failed unexpectedly: $output";
}
