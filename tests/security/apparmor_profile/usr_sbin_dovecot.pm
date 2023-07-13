# Copyright 2018 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Package: apparmor-parser apparmor-utils dovecot
# Summary: Test with "usr.sbin.dovecot" is in "enforce" mode and AppArmor is
#          "enabled && active", stop and start the dovecot service have no error.
# - Install dovecot
# - Run "aa-enforce usr.sbin.dovecot" and check output for enforce mode enabled
# - Stop, start, restart and check status for dovecot service
# - Check audit.log for errors related to dovecot
# Maintainer: QE Security <none@suse.de>
# Tags: poo#44999, tc#1695949

use base "apparmortest";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = shift;
    my $log_file = $apparmortest::audit_log;

    zypper_call("in dovecot");

    # set the AppArmor security profile to enforce mode
    my $profile_name = "usr.sbin.dovecot";
    validate_script_output("aa-enforce $profile_name", sub { m/Setting .*$profile_name to enforce mode./ });

    # cleanup audit log
    assert_script_run("echo > $log_file");

    # verify "dovecot" service
    assert_script_run("systemctl stop dovecot.service");
    assert_script_run("systemctl start dovecot.service");
    assert_script_run("systemctl restart dovecot.service");
    assert_script_run("systemctl status --no-pager dovecot.service", sub { m/Active: active (running)./ });

    # verify audit log contains no related error
    my $script_output = script_output "cat $log_file";
    if ($script_output =~ m/type=AVC .*apparmor=.*DENIED.* profile=.*dovecot.* comm=.*dovecot.*/sx) {
        record_info("ERROR", "There are errors found in $log_file", result => 'fail');
        $self->result('fail');
    }
}

1;
