# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Package: vagrant-sshfs vagrant-sshfs-testsuite rpm
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
    # vagrant-sshfs' testsuite wants to mount certain folders as the wheel group
    # => must be present on the system
    zypper_call("in vagrant-sshfs vagrant-sshfs-testsuite system-group-wheel");

    select_console('user-console');

    # check that the plugin is correctly installed
    assert_script_run('vagrant plugin list|grep sshfs|grep -q system');

    #
    # Do some crude testing of the synchronization capabilities of sshfs:
    # - create a testfile with the contents "Foo" => verify that the vagrant VM sees Foo
    # - write "Bar" into the testfile in the VM => check that that propagates to the host
    #
    assert_script_run('echo "Foo" > testfile');

    run_vagrant_cmd('init opensuse/Tumbleweed.' . get_required_var('ARCH'));

    assert_script_run('sed -i \'s/# config\.vm\.synced_folder .*$/config\.vm\.synced_folder "\.", "\/vagrant", type: "sshfs"/\' Vagrantfile');

    run_vagrant_cmd('up', timeout => 1200);

    assert_script_run('[[ $(vagrant ssh -- cat /vagrant/testfile) = "Foo" ]]');
    assert_script_run('vagrant ssh -- "echo \"Bar\" > /vagrant/testfile"');
    assert_script_run('[[ $(cat testfile) = "Bar" ]]');

    run_vagrant_cmd('halt');
    run_vagrant_cmd('destroy -f');
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
