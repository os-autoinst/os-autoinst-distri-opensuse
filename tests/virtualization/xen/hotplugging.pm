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

    record_info "Virtual network", "Adding virtual network interface";
    assert_script_run "ssh root\@$_.$domain 'ip l'"                                                                  foreach (keys %xen::guests);
    assert_script_run "ssh root\@$hypervisor 'virsh attach-interface --domain $_ --type bridge --source br0 --live'" foreach (keys %xen::guests);
    assert_script_run "ssh root\@$hypervisor 'virsh domiflist $_'"                                                   foreach (keys %xen::guests);
    assert_script_run "ssh root\@$_.$domain 'ip l'"                                                                  foreach (keys %xen::guests);

    record_info "Disk", "Adding another raw disk";
    assert_script_run "ssh root\@$hypervisor 'mkdir -p /var/lib/libvirt/images/add/'";
    assert_script_run "ssh root\@$hypervisor 'qemu-img create -f raw /var/lib/libvirt/images/add/$_.raw 10G'" foreach (keys %xen::guests);
    assert_script_run "ssh root\@$hypervisor 'virsh attach-disk --domain $_ --source /var/lib/libvirt/images/add/$_.raw --target xvdb'" foreach (keys %xen::guests);
    assert_script_run "ssh root\@$hypervisor 'virsh domblklist $_'"       foreach (keys %xen::guests);
    assert_script_run "ssh root\@$_.$domain 'lsblk'"                      foreach (keys %xen::guests);
    assert_script_run "ssh root\@$hypervisor 'virsh detach-disk $_ xvdb'" foreach (keys %xen::guests);

    record_info "CPU", "Changing the number of CPUs available";
    assert_script_run "ssh root\@$hypervisor 'virsh vcpucount $_'"                          foreach (keys %xen::guests);
    assert_script_run "ssh root\@$_.$domain 'lscpu'"                                        foreach (keys %xen::guests);
    assert_script_run "ssh root\@$hypervisor 'virsh setvcpus --domain $_ --count 1 --live'" foreach (keys %xen::guests);
    assert_script_run "ssh root\@$hypervisor 'virsh vcpucount $_'"                          foreach (keys %xen::guests);
    assert_script_run "ssh root\@$_.$domain 'lscpu'"                                        foreach (keys %xen::guests);

    record_info "Memory", "Changing the amount of memory available";
    assert_script_run "ssh root\@$hypervisor 'xl list'"                                      foreach (keys %xen::guests);
    assert_script_run "ssh root\@$hypervisor 'virsh setmem --domain $_ --size 1024M --live'" foreach (keys %xen::guests);
    assert_script_run "ssh root\@$_.$domain 'free'"                                          foreach (keys %xen::guests);
    assert_script_run "ssh root\@$hypervisor 'xl list'"                                      foreach (keys %xen::guests);
}

sub test_flags {
    return {fatal => 1, milestone => 0};
}

1;

