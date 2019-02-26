# SUSE's openQA tests
#
# Copyright © 2017-2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: system containers images test setup, installing libvirt-lxc
# Maintainer: Cédric Bosdonnat <cbosdonnat@suse.de>

use base "basetest";
use testapi;
use utils;
use strict;
use warnings;

sub run() {
    select_console 'root-console';

    # Install libvirt's lxc driver
    zypper_call('--gpg-auto-import-keys ref');
    zypper_call('in libvirt-daemon-lxc libvirt-client libvirt-daemon-config-network');

    # Make sure libvirtd is up and running with default network
    systemctl 'restart libvirtd';
    assert_script_run('virsh net-start default');
}

sub test_flags() {
    return {milestone => 1, fatal => 1};
}

1;
