# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Helper package for common virt operations
# Maintainer: Pavel Dostal <pdostal@suse.cz>

package virt_autotest::common;

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_sle';

# Supported guest configuration
#   * location of the installation tree
#   * autoyast profile
#   * extra parameters for virsh create / xl create

our %guests = ();
if (get_var("REGRESSION", '') =~ /xen/) {
    %guests = (
        sles12sp3PV => {
            name         => 'sles12sp3PV',
            autoyast     => 'autoyast_xen/sles12sp3PV_PRG.xml',
            extra_params => '--connect xen:/// --virt-type xen --paravirt --os-variant sles12sp3',
            macaddress   => '52:54:00:78:73:a1',
            ip           => '192.168.122.106',
            distro       => 'SLE_12_SP3',
            location     => 'http://mirror.suse.cz/install/SLP/SLE-12-SP3-Server-GM/x86_64/DVD1/',
        },
        sles12sp3HVM => {
            name         => 'sles12sp3HVM',
            autoyast     => 'autoyast_xen/sles12sp3HVM_PRG.xml',
            extra_params => '--connect xen:/// --virt-type xen --hvm --os-variant sles12sp3',
            macaddress   => '52:54:00:78:73:a2',
            ip           => '192.168.122.105',
            distro       => 'SLE_12_SP3',
            location     => 'http://mirror.suse.cz/install/SLP/SLE-12-SP3-Server-GM/x86_64/DVD1/',
        },
        sles15PV => {
            name         => 'sles15PV',
            autoyast     => 'autoyast_xen/sles15PV_PRG.xml',
            extra_params => '--connect xen:/// --virt-type xen --paravirt --os-variant sle15',
            macaddress   => '52:54:00:78:73:a3',
            ip           => '192.168.122.102',
            distro       => 'SLE_15',
            location     => 'http://mirror.suse.cz/install/SLP/SLE-15-Installer-LATEST/x86_64/DVD1/',
        },
        sles15HVM => {
            name         => 'sles15HVM',
            autoyast     => 'autoyast_xen/sles15HVM_PRG.xml',
            extra_params => '--connect xen:/// --virt-type xen --hvm --os-variant sle15',
            macaddress   => '52:54:00:78:73:a4',
            ip           => '192.168.122.101',
            distro       => 'SLE_15',
            location     => 'http://mirror.suse.cz/install/SLP/SLE-15-Installer-LATEST/x86_64/DVD1/',
        },
        sles11sp4PVx32 => {
            name         => 'sles11sp4PVx32',
            autoyast     => 'autoyast_xen/sles11sp4PVx32_PRG.xml',
            extra_params => '--connect xen:/// --virt-type xen --paravirt --arch i686 --os-variant sles11sp4',
            macaddress   => '52:54:00:78:73:a5',
            ip           => '192.168.122.110',
            distro       => 'SLE_11_SP4',
            location     => 'http://mirror.suse.cz/install/SLP/SLES-11-SP4-LATEST/i386/DVD1/',
        },
        sles11sp4HVMx32 => {
            name         => 'sles11sp4HVMx32',
            autoyast     => 'autoyast_xen/sles11sp4HVMx32_PRG.xml',
            extra_params => '--connect xen:/// --virt-type xen --hvm --arch i686 --os-variant sles11sp4',
            macaddress   => '52:54:00:78:73:a6',
            ip           => '192.168.122.108',
            distro       => 'SLE_11_SP4',
            location     => 'http://mirror.suse.cz/install/SLP/SLES-11-SP4-LATEST/i386/DVD1/',
        },
        sles11sp4PVx64 => {
            name         => 'sles11sp4PVx64',
            autoyast     => 'autoyast_xen/sles11sp4PVx64_PRG.xml',
            extra_params => '--connect xen:/// --virt-type xen --paravirt --os-variant sles11sp4',
            macaddress   => '52:54:00:78:73:a7',
            ip           => '192.168.122.109',
            distro       => 'SLE_11_SP4',
            location     => 'http://mirror.suse.cz/install/SLP/SLES-11-SP4-LATEST/x86_64/DVD1/',
        },
        sles11sp4HVMx64 => {
            name         => 'sles11sp4HVMx64',
            autoyast     => 'autoyast_xen/sles11sp4HVMx64_PRG.xml',
            extra_params => '--connect xen:/// --virt-type xen --hvm --os-variant sles11sp4',
            macaddress   => '52:54:00:78:73:a8',
            ip           => '192.168.122.107',
            distro       => 'SLE_11_SP4',
            location     => 'http://mirror.suse.cz/install/SLP/SLES-11-SP4-LATEST/x86_64/DVD1/',
        },
        sles12sp4PV => {
            name         => 'sles12sp4PV',
            autoyast     => 'autoyast_xen/sles12sp4PV_PRG.xml',
            extra_params => '--connect xen:/// --virt-type xen --paravirt --os-variant sles12sp4',
            macaddress   => '52:54:00:78:73:a9',
            ip           => '192.168.122.104',
            distro       => 'SLE_12_SP4',
            location     => 'http://mirror.suse.cz/install/SLP/SLE-12-SP4-Server-GM/x86_64/DVD1/',
        },
        sles12sp4HVM => {
            name         => 'sles12sp4HVM',
            autoyast     => 'autoyast_xen/sles12sp4HVM_PRG.xml',
            extra_params => '--connect xen:/// --virt-type xen --hvm --os-variant sles12sp4',
            macaddress   => '52:54:00:78:73:aa',
            ip           => '192.168.122.103',
            distro       => 'SLE_12_SP4',
            location     => 'http://mirror.suse.cz/install/SLP/SLE-12-SP4-Server-GM/x86_64/DVD1/',
        },
        sles15sp1HVM => {
            name         => 'sles15sp1HVM',
            autoyast     => 'autoyast_xen/sles15sp1HVM_PRG.xml',
            extra_params => '--connect xen:/// --virt-type xen --hvm --os-variant sle15sp1',
            macaddress   => '52:54:00:78:73:ab',
            ip           => '192.168.122.111',
            distro       => 'SLE_15',
            location     => 'http://mirror.suse.cz/install/SLP/SLE-15-SP1-Installer-GM/x86_64/DVD1/',
        },
        sles15sp1PV => {
            name         => 'sles15sp1PV',
            autoyast     => 'autoyast_xen/sles15sp1PV_PRG.xml',
            extra_params => '--connect xen:/// --virt-type xen --paravirt --os-variant sle15sp1',
            macaddress   => '52:54:00:78:73:ac',
            ip           => '192.168.122.112',
            distro       => 'SLE_15',
            location     => 'http://mirror.suse.cz/install/SLP/SLE-15-SP1-Installer-GM/x86_64/DVD1/',
        },
        sles15sp2HVM => {
            name         => 'sles15sp2HVM',
            autoyast     => 'autoyast_xen/sles15sp2HVM_PRG.xml',
            extra_params => '--connect xen:/// --virt-type xen --hvm --os-variant sle15sp1',       # sle15sp2 is unknown on 12.3
            macaddress   => '52:54:00:78:73:b0',
            ip           => '192.168.122.116',
            distro       => 'SLE_15',
            location     => 'http://mirror.suse.cz/install/SLP/SLE-15-SP2-Full-GM/x86_64/DVD1/',
        },
        sles15sp2PV => {
            name         => 'sles15sp2PV',
            autoyast     => 'autoyast_xen/sles15sp2PV_PRG.xml',
            extra_params => '--connect xen:/// --virt-type xen --paravirt --os-variant sle15sp1',    # sle15sp2 is unknown on 12.3
            macaddress   => '52:54:00:78:73:af',
            ip           => '192.168.122.115',
            distro       => 'SLE_15',
            location     => 'http://mirror.suse.cz/install/SLP/SLE-15-SP2-Full-GM/x86_64/DVD1/',
        },
        sles12sp5HVM => {
            name         => 'sles12sp5HVM',
            autoyast     => 'autoyast_xen/sles12sp5HVM_PRG.xml',
            extra_params => '--connect xen:/// --virt-type xen --hvm --os-variant sles12sp4',            # old system compatibility
            macaddress   => '52:54:00:78:73:ad',
            ip           => '192.168.122.113',
            distro       => 'SLE_12_SP5',
            location     => 'http://mirror.suse.cz/install/SLP/SLE-12-SP5-Server-LATEST/x86_64/DVD1/',
        },
        sles12sp5PV => {
            name         => 'sles12sp5PV',
            autoyast     => 'autoyast_xen/sles12sp5PV_PRG.xml',
            extra_params => '--connect xen:/// --virt-type xen --paravirt --os-variant sles12sp4',       # old system compatibility
            macaddress   => '52:54:00:78:73:ae',
            ip           => '192.168.122.114',
            distro       => 'SLE_12_SP5',
            location     => 'http://mirror.suse.cz/install/SLP/SLE-12-SP5-Server-LATEST/x86_64/DVD1/',
        },
    );

    delete($guests{sles11sp4PVx32});
    delete($guests{sles11sp4HVMx64});
    delete($guests{sles12sp3HVM}) if (!is_sle('=12-SP3'));
    delete($guests{sles12sp4PV})  if (!is_sle('=12-SP4'));
    delete($guests{sles12sp5HVM}) if (!is_sle('=12-SP5'));
    delete($guests{sles15PV})     if (!is_sle('=15'));
    delete($guests{sles15sp1HVM}) if (!is_sle('=15-SP1'));
} elsif (get_var("REGRESSION", '') =~ /kvm|qemu/) {
    %guests = (
        sles12sp3 => {
            name         => 'sles12sp3',
            autoyast     => 'autoyast_kvm/sles12sp3_PRG.xml',
            extra_params => '--os-variant sles12sp3',
            macaddress   => '52:54:00:78:73:a2',
            ip           => '192.168.122.102',
            distro       => 'SLE_12_SP3',
            location     => 'http://mirror.suse.cz/install/SLP/SLE-12-SP3-Server-GM/x86_64/DVD1/',
        },
        sles12sp4 => {
            name         => 'sles12sp4',
            autoyast     => 'autoyast_kvm/sles12sp4_PRG.xml',
            extra_params => '--os-variant sles12sp4',
            macaddress   => '52:54:00:78:73:aa',
            ip           => '192.168.122.103',
            distro       => 'SLE_12_SP4',
            location     => 'http://mirror.suse.cz/install/SLP/SLE-12-SP4-Server-GM/x86_64/DVD1/',
        },
        sles15 => {
            name         => 'sles15',
            autoyast     => 'autoyast_kvm/sles15_PRG.xml',
            extra_params => '--os-variant sle15',
            macaddress   => '52:54:00:78:73:a4',
            ip           => '192.168.122.101',
            distro       => 'SLE_15',
            location     => 'http://mirror.suse.cz/install/SLP/SLE-15-Installer-LATEST/x86_64/DVD1/',
        },
        sles15sp1 => {
            name         => 'sles15sp1',
            autoyast     => 'autoyast_kvm/sles15sp1_PRG.xml',
            extra_params => '--os-variant sles12',                                                      # problems after kernel upgrade
            macaddress   => '52:54:00:78:73:ab',
            ip           => '192.168.122.111',
            distro       => 'SLE_15',
            location     => 'http://mirror.suse.cz/install/SLP/SLE-15-SP1-Installer-GM/x86_64/DVD1/',
        },
        sles15sp2 => {
            name         => 'sles15sp2',
            autoyast     => 'autoyast_kvm/sles15sp2_PRG.xml',
            extra_params => '--os-variant sles12',                                                      # problems after kernel upgrade (originally sle15sp2)
            macaddress   => '52:54:00:78:73:af',
            ip           => '192.168.122.115',
            distro       => 'SLE_15',
            location     => 'http://mirror.suse.cz/install/SLP/SLE-15-SP2-Full-GM/x86_64/DVD1/',
        },
        sles12sp5 => {
            name         => 'sles12sp5',
            autoyast     => 'autoyast_kvm/sles12sp5_PRG.xml',
            extra_params => '--os-variant sles12sp4',                                                    # old system compatibility
            macaddress   => '52:54:00:78:73:ad',
            ip           => '192.168.122.113',
            distro       => 'SLE_12_SP5',
            location     => 'http://mirror.suse.cz/install/SLP/SLE-12-SP5-Server-LATEST/x86_64/DVD1/',
        },
    );
} elsif (get_var("REGRESSION", '') =~ /vmware/) {
    %guests = (
        sles11sp4x64 => {
            name => 'sles11sp4x64',
            ip   => 'd125.qam.suse.de',
        },
        sles11sp4x32 => {
            name => 'sles11sp4x32',
            ip   => 'd11.qam.suse.de',
        },
        sles12sp2 => {
            name => 'sles12sp2',
            ip   => 'vm-sle12-sp2-a60.qam.suse.de',
        },
        sles12sp3 => {
            name => 'sles12sp3',
            ip   => 'd153.qam.suse.de',
        },
        sles12sp4 => {
            name => 'sles12sp4',
            ip   => 'd370.qam.suse.de',
        },
        sles12sp5 => {
            name => 'sles12sp5',
            ip   => 'd388.qam.suse.de',
        },
        sles15 => {
            name => 'sles15',
            ip   => 'd294.qam.suse.de',
        },
        sles15sp1 => {
            name => 'sles15sp1',
            ip   => 'd208.qam.suse.de',
        },
        sles15sp2 => {
            name => 'sles15sp2',
            ip   => 'd192.qam.suse.de',
        },
    );

    delete($guests{sles11sp4x32}) if (!is_sle('=11-SP4'));
    delete($guests{sles11sp4x64}) if (!is_sle('=11-SP4'));
    delete($guests{sles12sp2})    if (!is_sle('=12-SP2'));
    delete($guests{sles12sp3})    if (!is_sle('=12-SP3'));
    delete($guests{sles12sp4})    if (!is_sle('=12-SP4'));
    delete($guests{sles12sp5})    if (!is_sle('=12-SP5'));
    delete($guests{sles15})       if (!is_sle('=15'));
    delete($guests{sles15sp1})    if (!is_sle('=15-SP1'));
    delete($guests{sles15sp2})    if (!is_sle('=15-SP2'));
} elsif (get_var("REGRESSION", '') =~ /hyperv/) {
    %guests = (
        sles11sp4x32 => {
            name => 'sles11sp4x32',
            ip   => 'borg-11.qam.suse.de',
        },
        sles11sp4x64 => {
            name => 'sles11sp4x64',
            ip   => 'borg-10.qam.suse.de',
        },
        sles12sp3 => {
            name => 'sles12sp3',
            ip   => 'borg-14.qam.suse.de',
        },
        sles12sp2 => {
            name => 'sles12sp2',
            ip   => 'borg-13.qam.suse.de',
        },
        sles12sp4 => {
            name => 'sles12sp4',
            ip   => 'd112.qam.suse.de',
        },
        sles12sp5 => {
            name => 'sles12sp5',
            ip   => 'd387.qam.suse.de',
        },
        sles15 => {
            name => 'sles15',
            ip   => 'd67.qam.suse.de',
        },
        sles15sp1 => {
            name => 'sles15sp1',
            ip   => 'd402.qam.suse.de',
        },
        sles15sp2 => {
            name => 'sles15sp2',
            ip   => 'd196.qam.suse.de',
        },
    );

    delete($guests{sles11sp4x32}) if (!is_sle('=11-SP4'));
    delete($guests{sles11sp4x64}) if (!is_sle('=11-SP4'));
    delete($guests{sles12sp2})    if (!is_sle('=12-SP2'));
    delete($guests{sles12sp3})    if (!is_sle('=12-SP3'));
    delete($guests{sles12sp4})    if (!is_sle('=12-SP4'));
    delete($guests{sles12sp5})    if (!is_sle('=12-SP5'));
    delete($guests{sles15})       if (!is_sle('=15'));
    delete($guests{sles15sp1})    if (!is_sle('=15-SP1'));
    delete($guests{sles15sp2})    if (!is_sle('=15-SP2'));
} else {
    %guests = ();
}

our %imports = ();    # imports are virtual machines that we don't install but just import. We test those separately.
if (get_var("REGRESSION", '') =~ /xen/) {
    %imports = (
        win2k19 => {
            name         => 'win2k19',
            extra_params => '--connect xen:/// --hvm --os-type windows --os-variant win2k8',    # --os-variant win2k19 not supported in older versions
            disk         => '/var/lib/libvirt/images/win2k19.raw',
            source       => '/mnt/virt_images/xen/win2k19.raw',
            macaddress   => '52:54:00:78:73:66',
            ip           => '192.168.122.66',
            version      => 'Microsoft Windows Server 2019',
        },
    );
} elsif (get_var("REGRESSION", '') =~ /kvm|qemu/) {
    %imports = (
        win2k19 => {
            name         => 'win2k19',
            extra_params => '--os-type windows --os-variant win2k8',                            # --os-variant win2k19 not supported in older versions
            disk         => '/var/lib/libvirt/images/win2k19.raw',
            source       => '/mnt/virt_images/kvm/win2k19.raw',
            macaddress   => '52:54:00:78:73:66',
            ip           => '192.168.122.66',
            version      => 'Microsoft Windows Server 2019',
        },
    );
} else {
    %imports = ();
}

1;
