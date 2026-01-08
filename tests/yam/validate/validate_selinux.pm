# SUSE's openQA tests
#
# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Validate selinux in default installation
# Maintainer: QE Installation and Migration (QE Iam) <none@suse.de>

use base "consoletest";
use scheduler 'get_test_suite_data';
use testapi;

sub run {
    select_console 'root-console';

    my $selinux = get_test_suite_data()->{selinux};
    assert_script_run("sestatus");
    assert_script_run("sestatus | grep \"SELinux status.*.$selinux->{status}\"");
    assert_script_run("sestatus | grep \"Current mode.*.$selinux->{mode}\"");
}

1;
