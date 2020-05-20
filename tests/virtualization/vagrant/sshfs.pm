# Copyright (C) 2020 SUSE LLC
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

# Summary: Test for the vagrant-sshfs plugin
# Maintainer: dancermak <dcermak@suse.com>

use base "consoletest";
use strict;
use warnings;
use testapi;
use utils;
use vagrant;

sub run() {
    setup_vagrant_libvirt();

    select_console('root-console');
    zypper_call("in vagrant-sshfs vagrant-sshfs-testsuite");

    select_console('user-console');

    # check that the plugin is correctly installed
    assert_script_run('vagrant plugin list|grep sshfs|grep -q system');

    #
    # Do some crude testing of the synchronization capabilities of sshfs:
    # - create a testfile with the contents "Foo" => verify that the vagrant VM sees Foo
    # - write "Bar" into the testfile in the VM => check that that propagates to the host
    #
    assert_script_run('echo "Foo" > testfile');

    assert_script_run('vagrant init opensuse/Tumbleweed.' . get_required_var('ARCH'));

    assert_script_run('sed -i \'s/# config\.vm\.synced_folder .*$/config\.vm\.synced_folder "\.", "\/vagrant", type: "sshfs"/\' Vagrantfile');

    assert_script_run('vagrant up', timeout => 1200);

    assert_script_run('[[ $(vagrant ssh -- cat /vagrant/testfile) = "Foo" ]]');
    assert_script_run('vagrant ssh -- "echo \"Bar\" > /vagrant/testfile"');
    assert_script_run('[[ $(cat testfile) = "Bar" ]]');

    assert_script_run('vagrant halt');
    assert_script_run('vagrant destroy -f');
    assert_script_run('rm -rf Vagrantfile testfile .vagrant');

    #
    # Run the actual upstream testsuite
    # (get the script path from rpm, as the version of sshfs is present in the path)
    #
    assert_script_run('cp $(dirname $(rpm -ql vagrant-sshfs-testsuite|grep testsuite.sh))/Vagrantfile .');
    assert_script_run('$(rpm -ql vagrant-sshfs-testsuite|grep testsuite.sh)', timeout => 1200);

    # cleanup
    assert_script_run('rm -rf Vagrantfile .vagrant');
}

sub post_fail_hook() {
    assert_script_run('rm -rf Vagrantfile .vagrant');
}

1;
