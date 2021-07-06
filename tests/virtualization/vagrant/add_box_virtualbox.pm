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

# Package: vagrant
# Summary: Test for vagrant
# Maintainer: dancermak <dcermak@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use vagrant;

sub run() {
    setup_vagrant_virtualbox();

    select_console('user-console');
    assert_script_run('echo "test" > testfile');

    run_vagrant_cmd('init centos/7');
    run_vagrant_cmd('up --provider virtualbox', timeout => 1200);

    run_vagrant_cmd('ssh -c "[ $(cat testfile) = \"test\" ]"');
    run_vagrant_cmd('halt');
    run_vagrant_cmd('destroy -f');

    assert_script_run('rm -rf Vagrantfile testfile .vagrant');
}

sub post_fail_hook() {
    assert_script_run('rm -rf Vagrantfile testfile .vagrant');
}

1;
