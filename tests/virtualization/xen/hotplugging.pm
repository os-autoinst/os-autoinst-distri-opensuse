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
    record_info "Disk", "Adding another raw disk";
    assert_script_run "mkdir -p /var/lib/libvirt/images/add/";
    assert_script_run "qemu-img create -f raw /var/lib/libvirt/images/add/$_.raw 10G" foreach (keys %xen::guests);
    if (check_var('XEN', '1')) {
        assert_script_run "virsh attach-disk --domain $_ --source /var/lib/libvirt/images/add/$_.raw --target xvdb" foreach (keys %xen::guests);
        assert_script_run "virsh domblklist $_ | grep xvdb"                                                         foreach (keys %xen::guests);
        assert_script_run "ssh root\@$_ lsblk | grep xvdb"                                                          foreach (keys %xen::guests);
        assert_script_run "virsh detach-disk $_ xvdb"                                                               foreach (keys %xen::guests);
    } else {
        assert_script_run "virsh attach-disk --domain $_ --source /var/lib/libvirt/images/add/$_.raw --target vdb" foreach (keys %xen::guests);
        assert_script_run "virsh domblklist $_ | grep vdb"                                                         foreach (keys %xen::guests);
        assert_script_run "ssh root\@$_ lsblk | grep vdb"                                                          foreach (keys %xen::guests);
        assert_script_run "virsh detach-disk $_ vdb"                                                               foreach (keys %xen::guests);
    }

    # TODO:
    record_info "CPU", "Changing the number of CPUs available";
    assert_script_run "virsh vcpucount $_ | grep current | grep live | grep 2" foreach (keys %xen::guests);
    assert_script_run "ssh root\@$_ nproc"                                     foreach (keys %xen::guests);
    assert_script_run "virsh setvcpus --domain $_ --count 3 --live"            foreach (keys %xen::guests);
    assert_script_run "virsh vcpucount $_ | grep current | grep live | grep 3" foreach (keys %xen::guests);
    script_retry "ssh root\@$_ nproc", delay => 15, retry => 6 foreach (keys %xen::guests);
    assert_script_run "virsh setvcpus --domain $_ --count 2 --live"            foreach (keys %xen::guests);
    assert_script_run "virsh vcpucount $_ | grep current | grep live | grep 2" foreach (keys %xen::guests);
    script_retry "ssh root\@$_ nproc", delay => 15, retry => 6 foreach (keys %xen::guests);

    # TODO:
    record_info "Memory", "Changing the amount of memory available";
    assert_script_run "virsh dommemstat $_"                          foreach (keys %xen::guests);
    assert_script_run "ssh root\@$_ free"                            foreach (keys %xen::guests);
    assert_script_run "virsh setmem --domain $_ --size 2048M --live" foreach (keys %xen::guests);
    assert_script_run "virsh dommemstat $_"                          foreach (keys %xen::guests);
    assert_script_run "ssh root\@$_ free"                            foreach (keys %xen::guests);
    assert_script_run "virsh setmem --domain $_ --size 4096M --live" foreach (keys %xen::guests);
    assert_script_run "virsh dommemstat $_"                          foreach (keys %xen::guests);
    assert_script_run "ssh root\@$_ free"                            foreach (keys %xen::guests);

    my %mac = ();
    foreach my $guest (keys %xen::guests) {
        $mac{$guest} = '00:16:3f:32:' . (int(rand(89)) + 10) . ':' . (int(rand(89)) + 10);
    }

    record_info "Virtual network", "Adding virtual network interface";
    script_retry "ssh root\@$_ ip l | grep " . $xen::guests{$_}->{macaddress}, delay => 15, retry => 3 foreach (keys %xen::guests);
    assert_script_run "virsh attach-interface --domain $_ --type bridge --source br0 --mac " . $mac{$_} . " --live" foreach (keys %xen::guests);
    assert_script_run "virsh domiflist $_ | grep br0"                                                               foreach (keys %xen::guests);
    assert_script_run "ssh root\@$_ cat /proc/uptime | cut -d. -f1"                                                 foreach (keys %xen::guests);
    script_retry "ssh root\@$_ ip l | grep " . $mac{$_}, delay => 15, retry => 3 foreach (keys %xen::guests);
    assert_script_run "virsh detach-interface $_ bridge --mac " . $mac{$_} foreach (keys %xen::guests);
}

1;

