# Copyright (C) 2020 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.
#
# Summary: Test "# ls/id/ps -Z" prints any security context of each
#          file/dir/user/process.
# Maintainer: llzhao <llzhao@suse.com>
# Tags: poo#61783, tc#1741282

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my $testfile = "foo";

    select_console "root-console";

    # print security context of file/dir
    assert_script_run("touch $testfile");
    validate_script_output("ls -Z $testfile", sub { m/.*_u:.*_r:.*_t:.*\ .*$testfile/sx });
    assert_script_run("rm -f $testfile");
    validate_script_output("ls -Zd /root", sub { m/.*_u:.*_r:.*_t:.*\ \/root/sx });

    # print security context of current user
    validate_script_output("id -Z", sub { m/.*_u:.*_r:.*_t:.*/sx });

    # print security context of process
    validate_script_output("ps -Z", sub { m/.*_u:.*_r:.*_t:.*\ .*bash/sx });
}

1;
