# SUSE's openQA tests
#
# Copyright 2017-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: libvirt-daemon-lxc libvirt-client libvirt-daemon-config-network
# Summary: system containers images test setup, installing libvirt-lxc
# Maintainer: Cédric Bosdonnat <cbosdonnat@suse.de>

use base "basetest";
use testapi;
use utils;

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
