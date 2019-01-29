# XEN regression tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Test if the guests can be saved and restored
# Maintainer: Jan Baier <jbaier@suse.cz>

use base "consoletest";
use xen;
use strict;
use testapi;
use utils;

sub run {
    my ($self) = @_;
    my $hypervisor = get_required_var('QAM_XEN_HYPERVISOR');

    assert_script_run "ssh root\@$hypervisor 'zypper -n in libvirt-client'";
    assert_script_run "ssh root\@$hypervisor 'mkdir -p /var/lib/libvirt/images/saves/'";

    record_info "Remove", "Remove previous saves (if there were any)";
    script_run "ssh root\@$hypervisor 'rm /var/lib/libvirt/images/saves/$_.vmsave' || true" foreach (keys %xen::guests);

    record_info "Save", "Save the machine states";
    assert_script_run("ssh root\@$hypervisor 'virsh save $_ /var/lib/libvirt/images/saves/$_.vmsave'", 300) foreach (keys %xen::guests);

    record_info "Check", "Check saved states";
    assert_script_run "ssh root\@$hypervisor 'virsh list --all | grep $_ | grep shut'" foreach (keys %xen::guests);

    record_info "Restore", "Restore guests";
    assert_script_run("ssh root\@$hypervisor 'virsh restore /var/lib/libvirt/images/saves/$_.vmsave'", 300) foreach (keys %xen::guests);

    record_info "Check", "Check restored states";
    assert_script_run "ssh root\@$hypervisor 'virsh list --all | grep $_ | grep running'" foreach (keys %xen::guests);
}

sub test_flags {
    return {fatal => 1, milestone => 0};
}

1;
