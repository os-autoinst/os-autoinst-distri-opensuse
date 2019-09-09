# Copyright (C) 2019 SUSE LLC
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
# Summary: Check system info like `/etc/issue` or `/etc/os-release`.
# Maintainer: Alynx Zhou <alynx.zhou@suse.com>

use base "basetest";
use strict;
use warnings;
use testapi;
use utils;

sub run {
    select_console('root-console');

    script_output("SUSEConnect --list");
    script_output("SUSEConnect --status-text");

    if (!get_var('MILESTONE_VERSION')) {
        assert_script_run('cat /etc/issue');
    } else {
        my $milestone_version = get_var('MILESTONE_VERSION');
        assert_script_run("grep $milestone_version /etc/issue");
    }
    assert_script_run('cat /etc/os-release');
}

sub test_flags {
    return {fatal => 0};
}

1;
