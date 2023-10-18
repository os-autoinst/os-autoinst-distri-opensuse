# SUSE's openQA tests
#
# Copyright 2016-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: yast2-vm
# Summary: Add virtualization hypervisor components to an installed system
# Maintainer: aginies <aginies@suse.com>

use base 'y2_module_guitest';
use strict;
use warnings;
use testapi;
use Utils::Architectures;
use utils;
use virt_autotest::utils qw(restart_libvirtd);

sub run {
    x11_start_program('xterm');
    send_key 'alt-f10';
    become_root;
    quit_packagekit;
    if (zypper_call('se yast2-vm', exitcode => [0, 104]) == 104) {
        record_soft_failure 'bsc#1083398 - YaST2-virtualization provides wrong components for SLED';
        zypper_call 'in yast2-vm';
    }
    y2_module_guitest::launch_yast2_module_x11('virtualization');
    # select everything
    if (is_x86_64) {
        send_key 'alt-x';    # XEN Server, only available on x86_64: bsc#1088175
        send_key 'alt-e';    # Xen tools
    }
    send_key 'alt-k';    # KVM Server
    send_key 'alt-v';    # KVM tools
    send_key 'alt-l';    # libvirt-lxc

    # launch the installation
    send_key 'alt-a';
    assert_screen([qw(yast_virtualization_installed yast_virtualization_bridge)], 800);
    if (match_has_tag('yast_virtualization_bridge')) {
        # select yes
        send_key 'alt-y';
        assert_screen 'yast_virtualization_installed', 60;
    }

    send_key 'alt-o';
    # close the xterm
    send_key 'alt-f4';
    # now need to start libvirtd
    x11_start_program('xterm');
    wait_screen_change { send_key 'alt-f10' };
    become_root;
    restart_libvirtd;
    wait_screen_change { send_key 'ret' };
    send_key 'ret';
    # close the xterm
    send_key 'alt-f4';
}

sub test_flags {
    return {milestone => 1};
}

1;
