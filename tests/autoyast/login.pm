# Copyright 2015-2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Log into system installed with autoyast
# - Check if system is at login screen in console
# - Run "cat /proc/cmdline"
# - Save screenshot
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

use strict;
use warnings;
use base 'y2_installbase';
use testapi;
use Utils::Backends;

sub run {
    my $self = shift;
    assert_screen("autoyast-system-login-console", 20);
    # default result
    $self->result('fail');

    # TODO: is_remote_backend could be a better fit here, but not
    # too sure if it would make sense for svirt or s390 for example
    if (is_ipmi) {
        #use console based on ssh to avoid unstable ipmi
        use_ssh_serial_console;
    }
    assert_script_run 'echo "checking serial port"';
    enter_cmd "cat /proc/cmdline";
    save_screenshot;
    $self->result('ok');
}

sub test_flags {
    return {fatal => 1};
}

1;

