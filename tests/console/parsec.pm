# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test parsec service with parsec-tool
# Maintainer: Guillaume Gardet <guillaume@opensuse.org>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my $self = shift;
    # Install requirements
    select_console 'root-console';
    my $pkg_list = "parsec parsec-tool";
    zypper_call("in $pkg_list");
    systemctl 'start parsec';

    # Add user to 'parsec-clients' group and force relogin
    assert_script_run("usermod -a -G parsec-clients $testapi::username");
    select_console('user-console');
    type_string("exit\n");
    # Exit from serial_terminal before reseting consoles, as a workaround until https://github.com/os-autoinst/os-autoinst-distri-opensuse/pull/11405 get merged
    $self->select_serial_terminal;
    type_string("exit\n");
    reset_consoles;
    select_console('user-console', ensure_tty_selected => 0, skip_setterm => 1);

    # Run tests as user with 'parsec-clients' permissions, with default config
    record_info('ping');
    assert_script_run 'parsec-tool ping';
    save_screenshot;

    record_info('list-opcodes');
    assert_script_run 'parsec-tool list-opcodes';
    save_screenshot;

    record_info('list-providers');
    assert_script_run 'parsec-tool list-providers';
    save_screenshot;

    record_info('list-keys');
    assert_script_run 'parsec-tool list-keys';
    save_screenshot;

    # Clean-up
    select_console 'root-console';
    systemctl 'stop parsec';
    zypper_call("rm -u $pkg_list");
}

1;
