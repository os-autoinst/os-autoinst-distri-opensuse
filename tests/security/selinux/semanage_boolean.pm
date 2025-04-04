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
use serial_terminal 'select_serial_terminal';
use utils;
use Utils::Backends 'is_pvm';

sub run {
    my ($self) = @_;
    my $test_boolean = "fips_mode";

    select_serial_terminal;

    # list and verify some (not all as it changes often) boolean(s)
    my $booleans = script_output("semanage boolean -l");
    for my $prefix (qw(authlogin_ daemons_ domain_)) {
        die "Missing boolean ${prefix}*" unless $booleans =~ m/^${prefix}.*\(off.*,.*off\)/m;
    }

    # Save boolean state
    assert_script_run("semanage boolean -E > ~/oldbooleans");

    # test option "-m": to set boolean value "off/on"
    assert_script_run("semanage boolean -m --off $test_boolean");
    validate_script_output("semanage boolean -l | grep $test_boolean", sub { m/${test_boolean}.*(off.*,.*off).*Allow.*to.*/ });
    assert_script_run("semanage boolean -m --on $test_boolean");
    validate_script_output("semanage boolean -l | grep $test_boolean", sub { m/${test_boolean}.*(on.*,.*on).*Allow.*to.*/ });

    # reboot and check again
    my $prev_console = current_console();
    power_action("reboot", textmode => 1);
    reconnect_mgmt_console if is_pvm;
    $self->wait_boot(textmode => 1, ready_time => 600, bootloader_time => 300);
    select_console($prev_console);

    validate_script_output("semanage boolean -l | grep $test_boolean", sub { m/${test_boolean}.*(on.*,.*on).*Allow.*to.*/ });

    # test option "-C": to list boolean local customizations
    my $local_booleans = script_output("semanage boolean -l -C");

    # Enabled above
    die "${test_boolean} missing" unless $local_booleans =~ m/${test_boolean}\s+\(on\s+,\s+on\)/;
    if (script_run('rpm -q container-selinux') == 0) {
        die "container booleans missing" unless $local_booleans =~ m/virt_sandbox_use_all_caps\s+\(on\s+,\s+on\).*virt_use_nfs\s+\(on\s+,\s+on\)/s;
    }

    # test option "-D": to delete boolean local customizations
    assert_script_run("semanage boolean -D");

    # verify boolean of local customizations was/were deleted
    my $output = script_output("semanage boolean -l -C");
    if ($output) {
        $self->result('fail');
    }

    # clean up: restore previous boolean values
    assert_script_run("semanage import -f ~/oldbooleans && rm ~/oldbooleans");
}

1;
