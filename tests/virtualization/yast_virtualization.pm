# SUSE's openQA tests
#
# Copyright © 2016-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Add virtualization hypervisor components to an installed system
# Maintainer: aginies <aginies@suse.com>

use base 'y2_module_guitest';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = @_;
    x11_start_program('xterm');
    send_key 'alt-f10';
    become_root;
    pkcon_quit;
    if (script_run('zypper se -i yast2-vm') == 104) {
        record_soft_failure 'bsc#1083398 - YaST2-virtualization provides wrong components for SLED';
        zypper_call 'in yast2-vm';
    }
    $self->launch_yast2_module_x11('virtualization');
    # select everything
    if (check_var('ARCH', 'x86_64')) {
        send_key 'alt-x';    # XEN Server, only available on x86_64: bsc#1088175
        send_key 'alt-e';    # Xen tools
    }
    send_key 'alt-k';        # KVM Server
    send_key 'alt-v';        # KVM tools
    send_key 'alt-l';        # libvirt-lxc

    # launch the installation
    send_key 'alt-a';
    assert_screen([qw(yast_virtualization_installed yast_virtualization_bridge)], 600);
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
    systemctl 'start libvirtd', timeout => 60;
    wait_screen_change { send_key 'ret' };
    systemctl 'status libvirtd', timeout => 60;
    # manually start the 'default' network if it is not active
    if (script_run("virsh net-info default |& grep '^Active.*no'") == 0) {
        record_soft_failure 'bsc#1123699';
        record_info("start default network", "libvirtd did not start the network by default");
        assert_script_run("virsh net-start default");
    }
    send_key 'ret';
    # close the xterm
    send_key 'alt-f4';
}

sub test_flags {
    return {milestone => 1};
}

1;
