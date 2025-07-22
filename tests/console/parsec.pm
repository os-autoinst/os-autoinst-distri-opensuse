# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: parsec parsec-tool
# Summary: Test parsec service with parsec-tool
# Maintainer: Guillaume Gardet <guillaume@opensuse.org>

use base "consoletest";
use testapi;
use utils;

sub run {
    my $self = shift;
    # Install requirements
    select_console 'root-console';
    my $pkg_list = "parsec parsec-tool";
    zypper_call("in $pkg_list");
    systemctl 'start parsec';

    # Add user to 'parsec-clients' group
    assert_script_run("usermod -a -G parsec-clients $testapi::username");
    select_console('user-console');
    # Use newgrp to get 'parsec-clients' group membership
    enter_cmd("newgrp parsec-clients");

    # Run tests as user with 'parsec-clients' permissions, with default config
    record_info('ping');
    assert_script_run 'parsec-tool ping';
    save_screenshot;

    record_info('list-opcodes');
    assert_script_run 'parsec-tool list-opcodes --provider 1';
    save_screenshot;

    record_info('list-providers');
    assert_script_run 'parsec-tool list-providers';
    save_screenshot;

    record_info('list-keys');
    assert_script_run 'parsec-tool list-keys';
    save_screenshot;

    # exit from newgrp session
    enter_cmd("exit");

    # Clean-up
    select_console 'root-console';
    systemctl 'stop parsec';
    zypper_call("rm -u $pkg_list");
}

1;
