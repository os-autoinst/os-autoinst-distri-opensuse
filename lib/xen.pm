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
use warnings;
use testapi;
use utils;

# Supported guest configuration
#   * location of the installation tree
#   * autoyast profile
#   * extra parameters for virsh create / xl create

our %guests = ();
if (check_var("REGRESSION", "xen-hypervisor") || check_var("REGRESSION", "xen-client")) {
    %guests = (
        sles12sp3PV => {
            autoyast     => 'autoyast_xen/sles12sp3PV.xml',
            extra_params => '--connect xen:/// --virt-type xen --paravirt',
            macaddress   => '52:54:00:78:73:a1',
            ip           => '192.168.122.106',
            distro       => 'SLE_12_SP3',
            location     => 'http://mirror.suse.cz/install/SLP/SLE-12-SP3-Server-GM/x86_64/DVD1/',
        },
        sles12sp3HVM => {
            autoyast     => 'autoyast_xen/sles12sp3HVM.xml',
            extra_params => '--connect xen:/// --virt-type xen --hvm',
            macaddress   => '52:54:00:78:73:a2',
            ip           => '192.168.122.105',
            distro       => 'SLE_12_SP3',
            location     => 'http://mirror.suse.cz/install/SLP/SLE-12-SP3-Server-GM/x86_64/DVD1/',
        },
        sles15PV => {
            autoyast     => 'autoyast_xen/sles15PV.xml',
            extra_params => '--connect xen:/// --virt-type xen --paravirt',
            macaddress   => '52:54:00:78:73:a3',
            ip           => '192.168.122.102',
            distro       => 'SLE_15',
            location     => 'http://mirror.suse.cz/install/SLP/SLE-15-Installer-LATEST/x86_64/DVD1/',
        },
        sles15HVM => {
            autoyast     => 'autoyast_xen/sles15HVM.xml',
            extra_params => '--connect xen:/// --virt-type xen --hvm',
            macaddress   => '52:54:00:78:73:a4',
            ip           => '192.168.122.101',
            distro       => 'SLE_15',
            location     => 'http://mirror.suse.cz/install/SLP/SLE-15-Installer-LATEST/x86_64/DVD1/',
        },
        sles11sp4PVx32 => {
            autoyast     => 'autoyast_xen/sles11sp4PVx32.xml',
            extra_params => '--connect xen:/// --virt-type xen --paravirt --arch i686',
            macaddress   => '52:54:00:78:73:a5',
            ip           => '192.168.122.110',
            distro       => 'SLE_11_SP4',
            location     => 'http://mirror.suse.cz/install/SLP/SLES-11-SP4-LATEST/i386/DVD1/',
        },
        sles11sp4HVMx32 => {
            autoyast     => 'autoyast_xen/sles11sp4HVMx32.xml',
            extra_params => '--connect xen:/// --virt-type xen --hvm --arch i686',
            macaddress   => '52:54:00:78:73:a6',
            ip           => '192.168.122.108',
            distro       => 'SLE_11_SP4',
            location     => 'http://mirror.suse.cz/install/SLP/SLES-11-SP4-LATEST/i386/DVD1/',
        },
        sles11sp4PVx64 => {
            autoyast     => 'autoyast_xen/sles11sp4PVx64.xml',
            extra_params => '--connect xen:/// --virt-type xen --paravirt',
            macaddress   => '52:54:00:78:73:a7',
            ip           => '192.168.122.109',
            distro       => 'SLE_11_SP4',
            location     => 'http://mirror.suse.cz/install/SLP/SLES-11-SP4-LATEST/x86_64/DVD1/',
        },
        sles11sp4HVMx64 => {
            autoyast     => 'autoyast_xen/sles11sp4HVMx64.xml',
            extra_params => '--connect xen:/// --virt-type xen --hvm',
            macaddress   => '52:54:00:78:73:a8',
            ip           => '192.168.122.107',
            distro       => 'SLE_11_SP4',
            location     => 'http://mirror.suse.cz/install/SLP/SLES-11-SP4-LATEST/x86_64/DVD1/',
        },
        sles12sp4PV => {
            autoyast     => 'autoyast_xen/sles12sp4PV.xml',
            extra_params => '--connect xen:/// --virt-type xen --paravirt',
            macaddress   => '52:54:00:78:73:a9',
            ip           => '192.168.122.104',
            distro       => 'SLE_12_SP4',
            location     => 'http://mirror.suse.cz/install/SLP/SLE-12-SP4-Server-GM/x86_64/DVD1/',
        },
        sles12sp4HVM => {
            autoyast     => 'autoyast_xen/sles12sp4HVM.xml',
            extra_params => '--connect xen:/// --virt-type xen --hvm',
            macaddress   => '52:54:00:78:73:aa',
            ip           => '192.168.122.103',
            distro       => 'SLE_12_SP4',
            location     => 'http://mirror.suse.cz/install/SLP/SLE-12-SP4-Server-GM/x86_64/DVD1/',
        },
        sles15sp1HVM => {
            autoyast     => 'autoyast_xen/sles15sp1HVM.xml',
            extra_params => '--connect xen:/// --virt-type xen --hvm',
            macaddress   => '52:54:00:78:73:ab',
            ip           => '192.168.122.111',
            distro       => 'SLE_15',
            location     => 'http://mirror.suse.cz/install/SLP/SLE-15-SP1-Installer-LATEST/x86_64/DVD1/',
        },
        sles15sp1PV => {
            autoyast     => 'autoyast_xen/sles15sp1PV.xml',
            extra_params => '--connect xen:/// --virt-type xen --paravirt',
            macaddress   => '52:54:00:78:73:ac',
            ip           => '192.168.122.112',
            distro       => 'SLE_15',
            location     => 'http://mirror.suse.cz/install/SLP/SLE-15-SP1-Installer-LATEST/x86_64/DVD1/',
        },
    );
} elsif (check_var("REGRESSION", "qemu-hypervisor") || check_var("REGRESSION", "qemu-client")) {
    %guests = (
        sles12sp3 => {
            autoyast     => 'autoyast_kvm/sles12sp3.xml',
            extra_params => '',
            macaddress   => '52:54:00:78:73:a2',
            ip           => '192.168.122.102',
            distro       => 'SLE_12_SP3',
            location     => 'http://mirror.suse.cz/install/SLP/SLE-12-SP3-Server-GM/x86_64/DVD1/',
        },
        sles12sp4 => {
            autoyast     => 'autoyast_kvm/sles12sp4.xml',
            extra_params => '',
            macaddress   => '52:54:00:78:73:aa',
            ip           => '192.168.122.103',
            distro       => 'SLE_12_SP4',
            location     => 'http://mirror.suse.cz/install/SLP/SLE-12-SP4-Server-GM/x86_64/DVD1/',
        },
        sles15 => {
            autoyast     => 'autoyast_kvm/sles15.xml',
            extra_params => '',
            macaddress   => '52:54:00:78:73:a4',
            ip           => '192.168.122.101',
            distro       => 'SLE_15',
            location     => 'http://mirror.suse.cz/install/SLP/SLE-15-Installer-LATEST/x86_64/DVD1/',
        },
        sles15sp1 => {
            autoyast     => 'autoyast_kvm/sles15sp1.xml',
            extra_params => '',
            macaddress   => '52:54:00:78:73:ab',
            ip           => '192.168.122.111',
            distro       => 'SLE_15',
            location     => 'http://mirror.suse.cz/install/SLP/SLE-15-SP1-Installer-LATEST/x86_64/DVD1/',
        },
    );
} else {
    %guests = ();
}

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
        assert_script_run "qemu-img create -f raw /var/lib/libvirt/images/xen/$guest.raw 20G";
        script_run "( virt-install $extra_params --name $guest --vcpus=2,maxvcpus=4 --memory 4096 --disk /var/lib/libvirt/images/xen/$guest.raw --network network=default,mac=$macaddress --noautoconsole --vnc --autostart --location=$location --os-variant sles12 --wait -1 --extra-args 'autoyast=" . data_url($autoyast) . "' >> virt-install_$guest.txt 2>&1 & )";
    }
}

1;
