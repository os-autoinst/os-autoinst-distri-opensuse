# XEN regression tests
#
# Copyright © 2018 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Helper package for common xen operations
# Maintainer: Jan Baier <jbaier@suse.cz>

package xen;

use base 'consoletest';
use strict;
use testapi;
use utils;

# Supported guest configuration
#   * location of the installation tree
#   * autoyast profile
#   * extra parameters for virsh create / xl create
our %guests = (
    A_sles12_PV => {
        autoyast     => 'autoyast_xen/xen-SLES12-SP3-PV.xml',
        extra_params => '--paravirt',
        location     => 'http://mirror.suse.cz/install/SLP/SLE-12-SP3-Server-GM/x86_64/DVD1/',
    },
    A_sles12_HVM => {
        autoyast     => 'autoyast_xen/xen-SLES12-SP3-FV.xml',
        extra_params => '--hvm',
        location     => 'http://mirror.suse.cz/install/SLP/SLE-12-SP3-Server-GM/x86_64/DVD1/',
    },
    A_sles15_PV => {
        autoyast     => 'autoyast_xen/xen-SLES15-PV.xml',
        extra_params => '--paravirt',
        location     => 'http://mirror.suse.cz/install/SLP/SLE-15-Installer-LATEST/x86_64/DVD1/',
    },
    A_sles15_HVM => {
        autoyast     => 'autoyast_xen/xen-SLES15-FV.xml',
        extra_params => '--hvm',
        location     => 'http://mirror.suse.cz/install/SLP/SLE-15-Installer-LATEST/x86_64/DVD1/',
    },
);

sub create_guest {
    my $self = shift;
    my ($guest, $method) = @_;

    my $location     = $guests{$guest}->{location};
    my $autoyast     = $guests{$guest}->{autoyast};
    my $extra_params = $guests{$guest}->{extra_params} // "";

    if ($method eq 'virt-install') {
        # First undefine and destroy machine (we can't be sure if it exists)
        script_run "virsh undefine $guest && virsh destroy $guest || true";
        # Run unattended installation for selected guest
        assert_script_run "mkdir -p /var/lib/libvirt/images/xen/";
        assert_script_run "qemu-img create -f raw /var/lib/libvirt/images/xen/$guest.raw 10G";
        assert_script_run "virt-install --connect xen:/// --virt-type xen $extra_params --name $guest --memory 2048 --disk /var/lib/libvirt/images/xen/$guest.raw --network bridge=br0 --noautoconsole --vnc --autostart --location=$location --os-variant sles12 --wait -1 --extra-args 'autoyast=" . data_url($autoyast) . "'", timeout => 1800;
        # Wait for post-installation reboot as the previous command returns upon first reboot
        script_run 'sleep 30';
    }
}

1;
