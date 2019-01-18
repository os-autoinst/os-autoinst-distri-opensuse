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

use base "consoletest";
use xen;
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self)     = @_;
    my $hypervisor = get_required_var('QAM_XEN_HYPERVISOR');
    my $domain     = get_required_var('QAM_XEN_DOMAIN');

    foreach my $guest (keys %xen::guests) {
        record_info "$guest", "Processing $guest now";

        # Virtual network
        assert_script_run "ssh root\@$hypervisor 'virsh attach-interface --domain $guest --type bridge --source br0 --live'";
        assert_script_run "ssh root\@$hypervisor 'virsh domiflist $guest'";
        for (my $i = 0; $i <= 120; $i++) {
            if (script_run("ssh root\@$guest.$domain 'ip l'") == 0) {
                last;
            }
            sleep 3;
        }

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
    }
}

sub test_flags {
    return {fatal => 1, milestone => 0};
}

1;

