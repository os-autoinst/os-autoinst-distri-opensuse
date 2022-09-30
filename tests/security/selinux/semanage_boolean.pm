# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test "#semanage boolean" command with options
#          "-l / -D / -m / -C..." can work
# Maintainer: QE Security <none@suse.de>
# Tags: poo#64728, tc#1741288

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
        "semanage boolean -l",
        sub {
            m/
            authlogin_.*(off.*,.*off).*
            daemons_.*(off.*,.*off).*
            domain_.*(off.*,.*off).*
            selinuxuser_.*(on.*,.*on).*/sx
        });

    # test option "-m": to set boolean value "off/on"
    assert_script_run("semanage boolean -m --off $test_boolean");
    validate_script_output("semanage boolean -l | grep $test_boolean", sub { m/${test_boolean}.*(off.*,.*off).*Allow.*to.*/ });
    assert_script_run("semanage boolean -m --on $test_boolean");
    validate_script_output("semanage boolean -l | grep $test_boolean", sub { m/${test_boolean}.*(on.*,.*on).*Allow.*to.*/ });

    # reboot and check again
    power_action("reboot", textmode => 1);
    reconnect_mgmt_console if is_pvm;
    $self->wait_boot(textmode => 1, ready_time => 600, bootloader_time => 300);
    $self->select_serial_terminal;

    validate_script_output("semanage boolean -l | grep $test_boolean", sub { m/${test_boolean}.*(on.*,.*on).*Allow.*to.*/ });

    # test option "-C": to list boolean local customizations
    validate_script_output(
        "semanage boolean -l -C",
        sub {
            m/(?=.*SELinux\s+boolean\s+State\s+Default\s+Description)(?=.*${test_boolean}\s+\(on\s+,\s+on\))(?=.*selinuxuser_execmod\s+\(on\s+,\s+on\))/s;
        });


    # test option "-D": to delete boolean local customizations
    assert_script_run("semanage boolean -D");

    # verify boolean of local customizations was/were deleted
    my $output = script_output("semanage boolean -l -C");
    if ($output) {
        $self->result('fail');
    }

    # clean up: restore the value for "selinuxuser_execmod"
    assert_script_run("semanage boolean --modify --on selinuxuser_execmod");
}

1;
