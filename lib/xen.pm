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
    'xen-sles12PV' => {
        autoyast     => 'autoyast_xen/xen-SLES12-SP3-PV.xml',
        extra_params => '--paravirt',
        macaddress   => '52:54:00:78:73:a1',
        location     => 'http://mirror.suse.cz/install/SLP/SLE-12-SP3-Server-GM/x86_64/DVD1/',
    },
    'xen-sles12HVM' => {
        autoyast     => 'autoyast_xen/xen-SLES12-SP3-FV.xml',
        extra_params => '--hvm',
        macaddress   => '52:54:00:78:73:a2',
        location     => 'http://mirror.suse.cz/install/SLP/SLE-12-SP3-Server-GM/x86_64/DVD1/',
    },
);

sub create_guest {
    my $self = shift;
    my ($guest, $method) = @_;

    my $location     = $guests{$guest}->{location};
    my $autoyast     = $guests{$guest}->{autoyast};
    my $macaddress   = $guests{$guest}->{macaddress};
    my $extra_params = $guests{$guest}->{extra_params} // "";

    if ($method eq 'virt-install') {
        # First undefine and destroy machine (we can't be sure if it exists)
        script_run "virsh undefine $guest && virsh destroy $guest || true";
        # Run unattended installation for selected guest
        assert_script_run "mkdir -p /var/lib/libvirt/images/xen/";
        assert_script_run "qemu-img create -f raw /var/lib/libvirt/images/xen/$guest.raw 10G";
        assert_script_run "virt-install --connect xen:/// --virt-type xen $extra_params --name $guest --memory 2048 --disk /var/lib/libvirt/images/xen/$guest.raw --network bridge=br0,mac=$macaddress --noautoconsole --vnc --autostart --location=$location --os-variant sles12 --wait -1 --extra-args 'autoyast=" . data_url($autoyast) . "'", timeout => 1800;
        # Wait for post-installation reboot as the previous command returns upon first reboot
        sleep 90;
    }
}

1;
