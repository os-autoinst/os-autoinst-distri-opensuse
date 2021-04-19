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

# Package: vagrant vagrant-libvirt
# Summary: Test for vagrant with the libvirt plugin
# Maintainer: dancermak <dcermak@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use vagrant;

sub run() {
    setup_vagrant_libvirt();

    select_console('user-console');

    # expect the output to contain the line if vagrant-libvirt has been
    # correctly installed via the RPM:
    # vagrant-libvirt (0.0.45, system)
    assert_script_run('vagrant plugin list|grep libvirt|grep -q system');

    assert_script_run('echo "test" > testfile');

    # Available from https://app.vagrantup.com/opensuse
    assert_script_run("vagrant init opensuse/Tumbleweed." . get_required_var('ARCH'));

    assert_script_run('vagrant up', timeout => 1200);

    assert_script_run('vagrant ssh -c "[ $(cat testfile) = \"test\" ]"');
    assert_script_run('vagrant halt');
    assert_script_run('vagrant destroy -f');

    assert_script_run('rm -rf Vagrantfile testfile .vagrant');
}

sub post_fail_hook() {
    assert_script_run('rm -rf Vagrantfile testfile .vagrant');
}

1;
