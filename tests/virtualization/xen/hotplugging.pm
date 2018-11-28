# XEN regression tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Virtual network and virtual block device hotplugging
# Maintainer: Jan Baier <jbaier@suse.cz>

use base 'xen';

use strict;
use testapi;
use utils;

sub run {
    my $self = shift;

    # Ensure virsh is installed
    zypper_call('-t in libvirt-client');

    foreach my $guest (keys %xen::guests) {
        # Virtual network
        assert_script_run "virsh attach-interface --domain $guest --type bridge --source br0 --live";
        assert_script_run "virsh domiflist $guest";
        ## TODO: Check "ip l" inside the guest

        # Disk
        assert_script_run 'mkdir -p /var/lib/libvirt/images/add/';
        assert_script_run "qemu-img create -f raw /var/lib/libvirt/images/add/$guest.raw 10G";
        assert_script_run "virsh attach-disk --domain $guest --source /var/lib/libvirt/images/add/$guest.raw --target xvdb";
        assert_script_run "virsh domblklist $guest";
        ## TODO: Check "lsblk" inside the guest
        assert_script_run "virsh detach-disk $guest xvdb";

        # CPU
        assert_script_run "virsh vcpucount $guest";
        assert_script_run "virsh setvcpus --domain $guest --count 1 --live";
        ## TODO: Check "lscpu" inside the guest
        assert_script_run "virsh vcpucount $guest";

        # Memory
        assert_script_run 'xl list';
        assert_script_run "virsh setmem --domain $guest --size 1024M --live";
        ## TODO: Check "free" inside the guest
        assert_script_run 'xl list';
    }
}

1;
