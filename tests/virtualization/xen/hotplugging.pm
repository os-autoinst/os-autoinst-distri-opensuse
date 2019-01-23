# XEN regression tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Virtual network and virtual block device hotplugging
# Maintainer: Jan Baier <jbaier@suse.cz>

use base "x11test";
use xen;
use strict;
use testapi;
use utils;

sub run {
    my ($self) = @_;
    select_console 'x11';
    my $hypervisor = get_required_var('QAM_XEN_HYPERVISOR');
    my $domain     = get_required_var('QAM_XEN_DOMAIN');

    x11_start_program('xterm');
    send_key 'super-up';

    # Ensure virsh is installed
    assert_script_run "ssh root\@$hypervisor 'zypper -n in libvirt-client'", 180;

    foreach my $guest (keys %xen::guests) {
        record_info "$guest", "Processing $guest now";

        # Virtual network
        assert_script_run "ssh root\@$hypervisor 'virsh attach-interface --domain $guest --type bridge --source br0 --live'";
        assert_script_run "ssh root\@$hypervisor 'virsh domiflist $guest'";
        assert_script_run "ssh root\@$guest.$domain 'ip l'";

        # Disk
        assert_script_run "ssh root\@$hypervisor 'mkdir -p /var/lib/libvirt/images/add/'";
        assert_script_run "ssh root\@$hypervisor 'qemu-img create -f raw /var/lib/libvirt/images/add/$guest.raw 10G'";
        assert_script_run "ssh root\@$hypervisor 'virsh attach-disk --domain $guest --source /var/lib/libvirt/images/add/$guest.raw --target xvdb'";
        assert_script_run "ssh root\@$hypervisor 'virsh domblklist $guest'";
        assert_script_run "ssh root\@$guest.$domain 'lsblk'";
        assert_script_run "ssh root\@$hypervisor 'virsh detach-disk $guest xvdb'";

        # CPU
        assert_script_run "ssh root\@$hypervisor 'virsh vcpucount $guest'";
        assert_script_run "ssh root\@$hypervisor 'virsh setvcpus --domain $guest --count 1 --live'";
        assert_script_run "ssh root\@$guest.$domain 'lscpu'";
        assert_script_run "ssh root\@$hypervisor 'virsh vcpucount $guest'";

        # Memory
        assert_script_run "ssh root\@$hypervisor 'xl list'";
        assert_script_run "ssh root\@$hypervisor 'virsh setmem --domain $guest --size 1024M --live'";
        assert_script_run "ssh root\@$guest.$domain 'free'";
        assert_script_run "ssh root\@$hypervisor 'xl list'";
        clear_console;
    }

    wait_screen_change { send_key 'alt-f4'; };
}

sub test_flags {
    return {fatal => 1, milestone => 0};
}

1;

