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
use warnings;
use testapi;
use utils;

sub run {
    my $hypervisor = get_var('HYPERVISOR') // '127.0.0.1';

    assert_script_run "mkdir -p /var/lib/libvirt/images/saves/";

    record_info "Remove", "Remove previous saves (if there were any)";
    script_run "rm /var/lib/libvirt/images/saves/$_.vmsave || true" foreach (keys %xen::guests);

    record_info "Save", "Save the machine states";
    assert_script_run("virsh save $_ /var/lib/libvirt/images/saves/$_.vmsave", 300) foreach (keys %xen::guests);

    record_info "Check", "Check saved states";
    assert_script_run "virsh list --all | grep $_ | grep shut" foreach (keys %xen::guests);

    record_info "Restore", "Restore guests";
    assert_script_run("virsh restore /var/lib/libvirt/images/saves/$_.vmsave", 300) foreach (keys %xen::guests);

    record_info "Check", "Check restored states";
    assert_script_run "virsh list --all | grep $_ | grep running" foreach (keys %xen::guests);

    record_info "SSH", "Check hosts are listening on SSH";
    script_retry "nmap $_ -PN -p ssh | grep open", delay => 3, retry => 60 foreach (keys %xen::guests);
}

1;

