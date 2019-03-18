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
# Summary: Test with "usr.sbin.traceroute" is in "enforce" mode and AppArmor is
#          "enabled && active", the "/usr/sbin/traceroute" can work as usual.
# Maintainer: llzhao <llzhao@suse.com>
# Tags: poo#44996, tc#1682587

use base "apparmortest";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = shift;
    my $log_file = $apparmortest::audit_log;

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
