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
    my ($self) = @_;
    my $hypervisor = get_var('HYPERVISOR') // '127.0.0.1';

    # TODO:
    my $lsblk = 0;
    record_info "Disk", "Adding another raw disk";
    assert_script_run "mkdir -p /var/lib/libvirt/images/add/";
    assert_script_run "qemu-img create -f raw /var/lib/libvirt/images/add/$_.raw 10G" foreach (keys %xen::guests);
    if (check_var('XEN', '1')) {
        script_run "virsh detach-disk $_ xvdz", 120 foreach (keys %xen::guests);
        assert_script_run "virsh attach-disk --domain $_ --source /var/lib/libvirt/images/add/$_.raw --target xvdz" foreach (keys %xen::guests);
        assert_script_run "virsh domblklist $_ | grep xvdz"                                                         foreach (keys %xen::guests);
        foreach my $guest (keys %xen::guests) {
            $lsblk = script_run "ssh root\@$guest lsblk | grep xvdz", 60;
            record_soft_failure("lsblk failed - please check the output manually") if $lsblk != 0;
        }
        assert_script_run "ssh root\@$_ lsblk" foreach (keys %xen::guests);
        assert_script_run "virsh detach-disk $_ xvdz", 120 foreach (keys %xen::guests);
    } else {
        script_run "virsh detach-disk $_ vdz", 120 foreach (keys %xen::guests);
        assert_script_run "virsh attach-disk --domain $_ --source /var/lib/libvirt/images/add/$_.raw --target vdz" foreach (keys %xen::guests);
        assert_script_run "virsh domblklist $_ | grep vdz"                                                         foreach (keys %xen::guests);
        foreach my $guest (keys %xen::guests) {
            $lsblk = script_run "ssh root\@$guest lsblk | grep vdz", 60;
            record_soft_failure("lsblk failed - please check the output manually") if $lsblk != 0;
        }
        assert_script_run "ssh root\@$_ lsblk" foreach (keys %xen::guests);
        assert_script_run "virsh detach-disk $_ vdz", 120 foreach (keys %xen::guests);
    }

    # TODO:
    record_info "CPU", "Changing the number of CPUs available";
    foreach my $guest (keys %xen::guests) {
        unless ($guest =~ m/hvm/i) {
            # The guest should have 2 CPUs after the installation
            assert_script_run "virsh vcpucount $guest | grep current | grep live";
            assert_script_run "ssh root\@$guest nproc", 60;
            # Add 1 CPU for everu guest
            assert_script_run "virsh setvcpus --domain $guest --count 3 --live";
            sleep 5;
            assert_script_run "virsh vcpucount $guest | grep current | grep live | grep 3";
            script_retry "ssh root\@$guest nproc", delay => 60, retry => 3, timeout => 60;
        }
    }

    # TODO:
    record_info "Memory", "Changing the amount of memory available";
    foreach my $guest (keys %xen::guests) {
        unless ($guest =~ m/hvm/i) {
            assert_script_run "virsh dommemstat $guest";
            assert_script_run "ssh root\@$guest free", 60;
            #assert_script_run "ssh root\@$guest dmidecode --type 17 | grep Size", 60;
            assert_script_run "virsh setmem --domain $guest --size 3072M --live";
            sleep 5;
            assert_script_run "virsh dommemstat $guest";
            assert_script_run "ssh root\@$guest free", 60;
            #assert_script_run "ssh root\@$guest dmidecode --type 17 | grep Size", 60;
            assert_script_run "virsh setmem --domain $guest --size 2048M --live";
            sleep 5;
            assert_script_run "virsh dommemstat $guest";
            assert_script_run "ssh root\@$guest free", 60;
            #assert_script_run "ssh root\@$guest dmidecode --type 17 | grep Size", 60;
        }
    }

    my %mac = ();
    foreach my $guest (keys %xen::guests) {
        $mac{$guest} = '00:16:3f:32:' . (int(rand(89)) + 10) . ':' . (int(rand(89)) + 10);
    }

    record_info "Virtual network", "Adding virtual network interface";
    script_retry "ssh root\@$_ ip l | grep " . $xen::guests{$_}->{macaddress}, delay => 60, retry => 3, timeout => 60 foreach (keys %xen::guests);
    assert_script_run "virsh attach-interface --domain $_ --type bridge --source br0 --mac " . $mac{$_} . " --live" foreach (keys %xen::guests);
    assert_script_run "virsh domiflist $_ | grep br0" foreach (keys %xen::guests);
    assert_script_run "ssh root\@$_ cat /proc/uptime | cut -d. -f1", 60 foreach (keys %xen::guests);
    script_retry "ssh root\@$_ ip l | grep " . $mac{$_}, delay => 60, retry => 3, timeout => 60 foreach (keys %xen::guests);
    assert_script_run "virsh detach-interface $_ bridge --mac " . $mac{$_} foreach (keys %xen::guests);
}

1;

