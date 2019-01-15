# XEN regression tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Installation of HVM and PV guests
# Maintainer: Jan Baier <jbaier@suse.cz>

use base 'xen';

use strict;
use testapi;
use utils;

sub run {
    my $self = shift;

    assert_script_run qq(echo 'log_level = 1
    log_filters="3:remote 4:event 3:json 3:rpc"
    log_outputs="1:file:/var/log/libvirt/libvirtd.log"' >> /etc/libvirt/libvirtd.conf);
    systemctl 'restart libvirtd';

    # Ensure additional package is installed
    zypper_call '-t in libvirt-client';

    # Show all guests
    assert_script_run 'xl list';
    save_screenshot;

    # Install every defined guest
    # TODO: It will be nice to run this in parallel
    foreach my $guest (keys %xen::guests) {
        $self->create_guest($guest, 'virt-install');
        # Show guest details
        assert_script_run "xl list $guest";
    }

    # All guests should be now installed, show them
    assert_script_run 'xl list';
    save_screenshot;
}

1;
