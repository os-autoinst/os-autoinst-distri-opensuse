# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test "# setsebool" command with options "-P / -N" can work
# Maintainer: QE Security <none@suse.de>
# Tags: poo#63751, tc#1741287

use base 'opensusebasetest';
use power_action_utils "power_action";
use strict;
use warnings;
use testapi;
use utils;
use Utils::Backends 'is_pvm';

sub run {
    my ($self) = @_;
    my $test_boolean = "fips_mode";

    $self->select_serial_terminal;

    # list and verify some (not all as it changes often) boolean(s)
    validate_script_output(
        "getsebool -a",
        sub {
            m/
            authlogin_.*\ -->\ off.*
            daemons_.*\ -->\ off.*
            domain_.*\ -->\ on.*
            selinuxuser_.*\ -->\ off.*
            selinuxuser_.*\ -->\ on.*/sx
        });

    # test option "-P": to set boolean value "off/on"
    assert_script_run("setsebool -P $test_boolean 0");
    validate_script_output("getsebool $test_boolean", sub { m/${test_boolean}\ -->\ off/ });
    assert_script_run("setsebool -P $test_boolean 1");
    validate_script_output("getsebool $test_boolean", sub { m/${test_boolean}\ -->\ on/ });

    # reboot and check again
    power_action("reboot", textmode => 1);
    reconnect_mgmt_console if is_pvm;
    $self->wait_boot(textmode => 1, ready_time => 600, bootloader_time => 300);
    $self->select_serial_terminal;

    validate_script_output("getsebool $test_boolean", sub { m/${test_boolean}\ -->\ on/ });

    # test option "-N": to set boolean value "off/on"
    assert_script_run("setsebool -N $test_boolean 0");
    validate_script_output("getsebool $test_boolean", sub { m/${test_boolean}\ -->\ off/ });

    # reboot and check again
    power_action("reboot", textmode => 1);
    reconnect_mgmt_console if is_pvm;
    $self->wait_boot(textmode => 1, ready_time => 600, bootloader_time => 300);
    $self->select_serial_terminal;

    validate_script_output("getsebool $test_boolean", sub { m/${test_boolean}\ -->\ on/ });
}

1;
