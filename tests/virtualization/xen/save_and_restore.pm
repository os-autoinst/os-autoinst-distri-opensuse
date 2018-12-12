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

use base "x11test";
use xen;
use strict;
use testapi;
use utils;

sub run {
    my ($self) = @_;
    select_console 'x11';
    my $hypervisor = get_required_var('QAM_XEN_HYPERVISOR');

    x11_start_program('xterm');
    send_key 'super-up';

    # Ensure virsh is installed
    assert_script_run "ssh root\@$hypervisor 'zypper -n in libvirt-client'";
    assert_script_run "ssh root\@$hypervisor 'mkdir -p /var/lib/libvirt/images/saves/'";

    foreach my $guest (keys %xen::guests) {
        record_info "$guest", "Processing $guest now";

        # Remove previous attempt (if there was any)
        script_run "ssh root\@$hypervisor 'rm /var/lib/libvirt/images/saves/$guest.vmsave' || true";

        # Save the machine states
        assert_script_run "ssh root\@$hypervisor 'virsh save $guest /var/lib/libvirt/images/saves/$guest.vmsave'", 300;
        sleep 15;

        # Check saved states
        assert_script_run "ssh root\@$hypervisor 'virsh list --all'";

        # Restore guests
        assert_script_run "ssh root\@$hypervisor 'virsh restore /var/lib/libvirt/images/saves/$guest.vmsave'", 300;

        clear_console;
    }

    wait_screen_change { send_key 'alt-f4'; };
}

sub test_flags {
    return {fatal => 1, milestone => 0};
}

1;
