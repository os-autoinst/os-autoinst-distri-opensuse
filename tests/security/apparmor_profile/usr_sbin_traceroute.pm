# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: apparmor-utils
# Summary: Test traceroute with usr.sbin.traceroute in enforce mode and
#          with AppArmor enabled and active.
# Maintainer: QE Security <none@suse.de>
# Tags: poo#44996, tc#1682587

use base "apparmortest";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = shift;
    my $log_file = $apparmortest::audit_log;

    # Install traceroute if not present
    if (script_run("which traceroute")) {
        zypper_call("in traceroute");
    }

    # Set the AppArmor security profile to enforce mode
    validate_script_output("aa-enforce usr.sbin.traceroute", sub { m/Setting .*usr\.sbin\.traceroute to enforce mode\./ });

    # Clean audit log
    assert_script_run("echo > $log_file");

    # Verify /usr/sbin/traceroute works
    assert_script_run("traceroute suse.com");

    # Verify audit log contains no related errors
    my $script_output = script_output "cat $log_file";
    if ($script_output =~ m/type=AVC .*apparmor=.*DENIED.* profile=.*traceroute.* comm=.*traceroute.*/sx) {
        record_info("ERROR", "There are errors found in $log_file", result => 'fail');
        $self->result('fail');
    }
}

1;
