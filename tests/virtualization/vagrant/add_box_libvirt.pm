# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

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
    run_vagrant_cmd('init opensuse/Tumbleweed.' . get_required_var('ARCH'));

    run_vagrant_cmd('up', timeout => 1200);

    run_vagrant_cmd('ssh -c "[ $(cat testfile) = \"test\" ]"');
    run_vagrant_cmd('halt');
    run_vagrant_cmd('destroy -f');

    assert_script_run('rm -rf Vagrantfile testfile .vagrant');
}

sub post_fail_hook() {
    assert_script_run('rm -rf Vagrantfile testfile .vagrant');
}

1;
