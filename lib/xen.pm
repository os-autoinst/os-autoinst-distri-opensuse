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
    'xen-sles15PV' => {
        autoyast     => 'autoyast_xen/xen-SLES15-PV.xml',
        extra_params => '--paravirt',
        macaddress   => '52:54:00:78:73:a3',
        location     => 'http://mirror.suse.cz/install/SLP/SLE-15-Installer-LATEST/x86_64/DVD1/',
    },
    'xen-sles15HVM' => {
        autoyast     => 'autoyast_xen/xen-SLES15-FV.xml',
        extra_params => '--hvm',
        macaddress   => '52:54:00:78:73:a4',
        location     => 'http://mirror.suse.cz/install/SLP/SLE-15-Installer-LATEST/x86_64/DVD1/',
    },
    'xen-sles11sp4PVx32' => {
        autoyast     => 'autoyast_xen/xen-SLES11-SP4-PV32.xml',
        extra_params => '--paravirt --arch i686',
        macaddress   => '52:54:00:78:73:a5',
        location     => 'http://mirror.suse.cz/install/SLP/SLES-11-SP4-LATEST/i386/DVD1/',
    },
    'xen-sles11sp4HVMx32' => {
        autoyast     => 'autoyast_xen/xen-SLES11-SP4-FV32.xml',
        extra_params => '--hvm --arch i686',
        macaddress   => '52:54:00:78:73:a6',
        location     => 'http://mirror.suse.cz/install/SLP/SLES-11-SP4-LATEST/i386/DVD1/',
    },
    'xen-sles11sp4PVx64' => {
        autoyast     => 'autoyast_xen/xen-SLES11-SP4-PV64.xml',
        extra_params => '--paravirt',
        macaddress   => '52:54:00:78:73:a7',
        location     => 'http://mirror.suse.cz/install/SLP/SLES-11-SP4-LATEST/x86_64/DVD1/',
    },
    'xen-sles11sp4HVMx64' => {
        autoyast     => 'autoyast_xen/xen-SLES11-SP4-FV64.xml',
        extra_params => '--hvm',
        macaddress   => '52:54:00:78:73:a8',
        location     => 'http://mirror.suse.cz/install/SLP/SLES-11-SP4-LATEST/x86_64/DVD1/',
    },
    'xen-sles12sp4PV' => {
        autoyast     => 'autoyast_xen/xen-SLES12-SP4-PV.xml',
        extra_params => '--paravirt',
        macaddress   => '52:54:00:78:73:a9',
        location     => 'http://mirror.suse.cz/install/SLP/SLE-12-SP4-Server-GM/x86_64/DVD1/',
    },
    'xen-sles12sp4HVM' => {
        autoyast     => 'autoyast_xen/xen-SLES12-SP4-FV.xml',
        extra_params => '--hvm',
        macaddress   => '52:54:00:78:73:aa',
        location     => 'http://mirror.suse.cz/install/SLP/SLE-12-SP4-Server-GM/x86_64/DVD1/',
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
        record_info "$guest", "Going to create $guest guest";
        # Run unattended installation for selected guest
        assert_script_run "qemu-img create -f raw /var/lib/libvirt/images/xen/$guest.raw 10G";
        script_run "( virt-install --connect xen:/// --virt-type xen $extra_params --name $guest --memory 2048 --disk /var/lib/libvirt/images/xen/$guest.raw --network bridge=br0,mac=$macaddress --noautoconsole --vnc --autostart --location=$location --os-variant sles12 --wait -1 --extra-args 'autoyast=" . data_url($autoyast) . "' & )";
    }
}

