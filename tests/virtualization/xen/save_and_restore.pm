# XEN regression tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Test if the guests can be saved and restored
# Maintainer: Jan Baier <jbaier@suse.cz>

use base 'xen';

use strict;
use testapi;
use utils;

sub run {
    my $self = shift;

    # Ensure virsh is installed
    zypper_call('-t in libvirt-client');

    assert_script_run "mkdir -p /var/lib/libvirt/images/saves/";
    # Save the machine states
    assert_script_run "virsh save $_ /var/lib/libvirt/images/saves/$_.vmsave" foreach (keys %xen::guests);
    # Check saved states
    assert_script_run "virsh list --all";
    assert_script_run "virsh list --all --with-managed-save";
    # Restore guests
    assert_script_run "virsh restore /var/lib/libvirt/images/saves/$_.vmsave" foreach (keys %xen::guests);
}

1;
