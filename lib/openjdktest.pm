# Copyright 2023 SUSE LLC
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

our @EXPORT = qw(
  remove_any_installed_java
  run_ssh_test
);

sub remove_any_installed_java {
    my @output = grep /java-\d+-openjdk/, split(/\n/, script_output "rpm -qa 'java-*'");
    return unless scalar @output;    # nothing to remove
    my $pkgs = join ' ', @output;
    zypper_call "rm ${pkgs}";
}

sub run_ssh_test {
    assert_script_run("javac -cp jsch-0.1.55.jar:. Shell.java");
    script_run("java -cp jsch-0.1.55.jar:. Shell", timeout => 0);
    assert_screen "openjdk-hostname";
    for (1 .. 30) { send_key "backspace"; }
    type_string get_var("OPENJDK_HN", 'bernhard@localhost');
    save_screenshot;
    send_key 'ret';
    wait_still_screen 3;
    send_key 'ret';
    save_screenshot;
    wait_still_screen 3;
    send_key 'ret' if (check_screen("auth-key-connect", 10));
    wait_still_screen 3;
    record_info("FAIL", "java.security.ProviderException: Could not derive key", result => 'fail') if (check_screen("shell-not-derive-key", 10));
    send_key 'ret';
    save_screenshot;
    wait_still_screen 3;
    send_key 'alt-f4';
}
