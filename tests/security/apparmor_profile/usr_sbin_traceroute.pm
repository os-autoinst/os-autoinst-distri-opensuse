# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: apparmor-utils
# Summary: Test with "usr.sbin.traceroute" is in "enforce" mode and AppArmor is
#          "enabled && active", the "/usr/sbin/traceroute" can work as usual.
# - Run "aa-enforce usr.sbin.traceroute", check output for enforce mode set
# - Clean "/var/log/audit/audit.log"
# - Run "traceroute www.baidu.com"
# - Log (audit.log) should not contain no errors related to traceroute
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

    # set the AppArmor security profile to enforce mode
    my $profile_name = "usr.sbin.traceroute";
    validate_script_output("aa-enforce $profile_name", sub { m/Setting .*$profile_name to enforce mode./ });

    # cleanup audit log
    assert_script_run("echo > $log_file");

    # verify "/usr/sbin/traceroute" can work
    assert_script_run("traceroute www.baidu.com");

    # verify audit log contains no related error
    my $script_output = script_output "cat $log_file";
    if ($script_output =~ m/type=AVC .*apparmor=.*DENIED.* profile=.*traceroute.* comm=.*traceroute.*/sx) {
        record_info("ERROR", "There are errors found in $log_file", result => 'fail');
        $self->result('fail');
    }
}

1;
