# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: apparmor-utils nscd
# Summary: Test with "usr.sbin.nscd" is in "enforce" mode and AppArmor is
#          "enabled && active", stop and start the nscd service have no error.
# - Install nscd
# - Run "aa-enforce usr.sbin.nscd", checks output for enforce mode confirmation
# - Stop, start, restart and check status on nscd service
# - Check audit.log for errors related to nscd
# Maintainer: QE Security <none@suse.de>
# Tags: poo#44993, tc#1695951

use base "apparmortest";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = shift;
    my $log_file = $apparmortest::audit_log;

    zypper_call("in nscd");

    # set the AppArmor security profile to enforce mode
    my $profile_name = "usr.sbin.nscd";
    validate_script_output("aa-enforce $profile_name", sub { m/Setting .*$profile_name to enforce mode./ });

    # cleanup audit log
    assert_script_run("echo > $log_file");

    # verify "nscd" service
    assert_script_run("systemctl stop nscd.service");
    assert_script_run("systemctl start nscd.service");
    assert_script_run("systemctl restart nscd.service");
    assert_script_run("systemctl status --no-pager nscd.service", sub { m/Active: active (running)./ });

    # verify audit log contains no related error
    my $script_output = script_output "cat $log_file";
    if ($script_output =~ m/type=AVC .*apparmor=.*DENIED.* profile=.*nscd.* comm=.*nscd.*/sx) {
        record_info("ERROR", "There are errors found in $log_file", result => 'fail');
        $self->result('fail');
    }
}

1;
