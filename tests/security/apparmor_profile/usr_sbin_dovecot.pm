# Copyright (C) 2018 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.
#
# Summary: Test with "usr.sbin.dovecot" is in "enforce" mode and AppArmor is
#          "enabled && active", stop and start the dovecot service have no error.
# Maintainer: llzhao <llzhao@suse.com>
# Tags: poo#44999, tc#1695949

use base "apparmortest";
use strict;
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
