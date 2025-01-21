# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Helper package for common virt operations
# Maintainer: qe-virt <qe-virt@suse.de>

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
# By default, our guests will be installed via `virt-install`. If "method => 'import'" is set, the virtual machine will
# be imported instead of installed.
my $guest_version = "";
if (get_var("VERSION")) {
    $guest_version = get_var("VERSION");
    $guest_version =~ s/-//;
    $guest_version =~ y/SP/sp/;
}
our %guests = ();
if (get_var("REGRESSION", '') =~ /xen/) {
    %guests = (
        sles15sp2HVM => {
            name => 'sles15sp2HVM',
            autoyast => 'autoyast_xen/sles15sp2HVM_PRG.xml',
            extra_params => '--connect xen:/// --virt-type xen --hvm --os-variant sle15sp1',    # sle15sp2 is unknown on 12.3
            distro => 'SLE_15',
            location => 'http://mirror.suse.cz/install/SLP/SLE-15-SP2-Full-GM/x86_64/DVD1/',
        },
        sles15sp2PV => {
            name => 'sles15sp2PV',
            autoyast => 'autoyast_xen/sles15sp2PV_PRG.xml',
            extra_params => '--connect xen:/// --virt-type xen --paravirt --os-variant sle15sp1',    # sle15sp2 is unknown on 12.3
            distro => 'SLE_15',
            location => 'http://mirror.suse.cz/install/SLP/SLE-15-SP2-Full-GM/x86_64/DVD1/',
        },
        sles15sp3PV => {
            name => 'sles15sp3PV',
            autoyast => 'autoyast_xen/sles15sp3PV_PRG.xml',
            extra_params => '--os-variant sle15-unknown',
            distro => 'SLE_15',
            location => 'http://mirror.suse.cz/install/SLP/SLE-15-SP3-Full-LATEST/x86_64/DVD1/',
        },
        sles15sp3HVM => {
            name => 'sles15sp3HVM',
            autoyast => 'autoyast_xen/sles15sp3HVM_PRG.xml',
            extra_params => '--os-variant sle15-unknown',
            distro => 'SLE_15',
            location => 'http://mirror.suse.cz/install/SLP/SLE-15-SP3-Full-LATEST/x86_64/DVD1/',
        },
        sles12sp5HVM => {
            name => 'sles12sp5HVM',
            autoyast => 'autoyast_xen/sles12sp5HVM_PRG.xml',
            extra_params => '--connect xen:/// --virt-type xen --hvm --os-variant sles12sp4',    # old system compatibility
            distro => 'SLE_12_SP5',
            location => 'http://mirror.suse.cz/install/SLP/SLE-12-SP5-Server-LATEST/x86_64/DVD1/',
        },
        sles12sp5PV => {
            name => 'sles12sp5PV',
            autoyast => 'autoyast_xen/sles12sp5PV_PRG.xml',
            extra_params => '--connect xen:/// --virt-type xen --paravirt --os-variant sles12sp4',    # old system compatibility
            distro => 'SLE_12_SP5',
            location => 'http://mirror.suse.cz/install/SLP/SLE-12-SP5-Server-LATEST/x86_64/DVD1/',
        },
        sles15sp4PV => {
            name => 'sles15sp4PV',
            extra_params => '--os-variant sle15-unknown',    # problems after kernel upgrade
            distro => 'SLE_15_SP4',
            location => 'http://mirror.suse.cz/install/SLP/SLE-15-SP4-Full-LATEST/x86_64/DVD1/',
        },
        sles15sp4HVM => {
            name => 'sles15sp4HVM',
            extra_params => '--os-variant sle15-unknown',    # problems after kernel upgrade
            distro => 'SLE_15_SP4',
            location => 'http://mirror.suse.cz/install/SLP/SLE-15-SP4-Full-LATEST/x86_64/DVD1/',
        },
        sles15sp5PV => {
            name => 'sles15sp5PV',
            extra_params => '--os-variant sle15-unknown',    # problems after kernel upgrade
            distro => 'SLE_15_SP5',
            location => 'http://mirror.suse.cz/install/SLP/SLE-15-SP5-Full-LATEST/x86_64/DVD1/',
        },
        sles15sp5HVM => {
            name => 'sles15sp5HVM',
            extra_params => '--os-variant sle15-unknown',    # problems after kernel upgrade
            distro => 'SLE_15_SP5',
            location => 'http://mirror.suse.cz/install/SLP/SLE-15-SP5-Full-LATEST/x86_64/DVD1/',
        },
        sles15sp6PV => {
            name => 'sles15sp6PV',
            extra_params => '--os-variant sle15-unknown',
            distro => 'SLE_15',
            location => 'http://mirror.suse.cz/install/SLP/SLE-15-SP6-Full-GM/x86_64/DVD1/',
        },
        sles15sp6HVM => {
            name => 'sles15sp6HVM',
            extra_params => '--os-variant sle15-unknown',
            distro => 'SLE_15',
            location => 'http://mirror.suse.cz/install/SLP/SLE-15-SP6-Full-GM/x86_64/DVD1/',
        }
    );
    # Filter out guests not allowed for the detected SLE version
    if (is_sle('=12-SP5')) {
        my @allowed_guests = qw(sles12sp5HVM sles12sp5PV sles15sp5HVM sles15sp5PV sles15sp6HVM sles15sp6PV);
        foreach my $guest (keys %guests) {
            delete $guests{$guest} unless grep { $_ eq $guest } @allowed_guests;
        }
    } elsif (is_sle('=15-SP2')) {
        my @allowed_guests = qw(sles15sp2HVM sles15sp2PV sles15sp3HVM sles15sp3PV);
        foreach my $guest (keys %guests) {
            delete $guests{$guest} unless grep { $_ eq $guest } @allowed_guests;
        }
    } elsif (is_sle('=15-SP3')) {
        my @allowed_guests = qw(sles15sp3HVM sles15sp3PV sles15sp4HVM sles15sp4PV);
        foreach my $guest (keys %guests) {
            delete $guests{$guest} unless grep { $_ eq $guest } @allowed_guests;
        }
    } elsif (is_sle('=15-SP4')) {
        my @allowed_guests = qw(sles15sp4HVM sles15sp4PV sles15sp5HVM sles15sp5PV);
        foreach my $guest (keys %guests) {
            delete $guests{$guest} unless grep { $_ eq $guest } @allowed_guests;
        }
    } elsif (is_sle('=15-SP5')) {
        my @allowed_guests = qw(sles12sp5HVM sles12sp5PV sles15sp5HVM sles15sp5PV sles15sp6HVM sles15sp6PV);
        foreach my $guest (keys %guests) {
            delete $guests{$guest} unless grep { $_ eq $guest } @allowed_guests;
        }
    } elsif (is_sle('=15-SP6')) {
        my @allowed_guests = qw(sles12sp5HVM sles12sp5PV sles15sp6HVM sles15sp6PV);
        foreach my $guest (keys %guests) {
            delete $guests{$guest} unless grep { $_ eq $guest } @allowed_guests;
        }
    } else {
        %guests = ();
    }
    %guests = %guests{"sles${guest_version}PV", "sles${guest_version}HVM"} if (get_var('TERADATA'));

} elsif (get_var("REGRESSION", '') =~ /kvm|qemu/) {
    %guests = (
        sles12sp3 => {
            name => 'sles12sp3',
            autoyast => 'autoyast_kvm/sles12sp3_PRG.xml',
            extra_params => '--os-variant sles12sp3',
            distro => 'SLE_12_SP3',
            location => 'http://mirror.suse.cz/install/SLP/SLE-12-SP3-Server-GM/x86_64/DVD1/',
        },
        sles15sp2 => {
            name => 'sles15sp2',
            autoyast => 'autoyast_kvm/sles15sp2_PRG.xml',
            extra_params => '--os-variant sle15-unknown',    # problems after kernel upgrade (originally sle15sp2)
            distro => 'SLE_15',
            location => 'http://mirror.suse.cz/install/SLP/SLE-15-SP2-Full-GM/x86_64/DVD1/',
        },
        sles15sp3 => {
            name => 'sles15sp3',
            autoyast => 'autoyast_kvm/sles15sp3_PRG.xml',
            extra_params => '--os-variant sle15-unknown',
            distro => 'SLE_15',
            location => 'http://mirror.suse.cz/install/SLP/SLE-15-SP3-Full-LATEST/x86_64/DVD1/',
        },
        sles12sp5 => {
            name => 'sles12sp5',
            autoyast => 'autoyast_kvm/sles12sp5_PRG.xml',
            extra_params => '--os-variant sles12sp4',    # old system compatibility
            distro => 'SLE_12_SP5',
            location => 'http://mirror.suse.cz/install/SLP/SLE-12-SP5-Server-LATEST/x86_64/DVD1/',
        },
        sles15sp4 => {
            name => 'sles15sp4',
            extra_params => '--os-variant sle15-unknown',    # problems after kernel upgrade
            distro => 'SLE_15',
            location => 'http://mirror.suse.cz/install/SLP/SLE-15-SP4-Full-LATEST/x86_64/DVD1/',
        },
        sles15sp5 => {
            name => 'sles15sp5',
            extra_params => '--os-variant sle15-unknown',    # problems after kernel upgrade
            distro => 'SLE_15',
            location => 'http://mirror.suse.cz/install/SLP/SLE-15-SP5-Full-LATEST/x86_64/DVD1/',
        },
        sles15sp6 => {
            name => 'sles15sp6',
            extra_params => '--os-variant sle15-unknown',
            distro => 'SLE_15',
            location => 'http://mirror.suse.cz/install/SLP/SLE-15-SP6-Full-GM/x86_64/DVD1/',
        }
    );
    # Filter out guests not allowed for the detected SLE version
    if (is_sle('=12-SP3')) {
        my @allowed_guests = qw(sles12sp3);
        foreach my $guest (keys %guests) {
            delete $guests{$guest} unless grep { $_ eq $guest } @allowed_guests;
        }
    } elsif (is_sle('=12-SP5')) {
        my @allowed_guests = qw(sles12sp5 sles15sp5 sles15sp6);
        foreach my $guest (keys %guests) {
            delete $guests{$guest} unless grep { $_ eq $guest } @allowed_guests;
        }
    } elsif (is_sle('=15-SP2')) {
        my @allowed_guests = qw(sles15sp2 sles15sp3);
        foreach my $guest (keys %guests) {
            delete $guests{$guest} unless grep { $_ eq $guest } @allowed_guests;
        }
    } elsif (is_sle('=15-SP3')) {
        my @allowed_guests = qw(sles15sp3 sles15sp4);
        foreach my $guest (keys %guests) {
            delete $guests{$guest} unless grep { $_ eq $guest } @allowed_guests;
        }
    } elsif (is_sle('=15-SP4')) {
        my @allowed_guests = qw(sles15sp4 sles15sp5);
        foreach my $guest (keys %guests) {
            delete $guests{$guest} unless grep { $_ eq $guest } @allowed_guests;
        }
    } elsif (is_sle('=15-SP5')) {
        my @allowed_guests = qw(sles12sp5 sles15sp5 sles15sp6);
        foreach my $guest (keys %guests) {
            delete $guests{$guest} unless grep { $_ eq $guest } @allowed_guests;
        }
    } elsif (is_sle('=15-SP6')) {
        my @allowed_guests = qw(sles12sp5 sles15sp6);
        foreach my $guest (keys %guests) {
            delete $guests{$guest} unless grep { $_ eq $guest } @allowed_guests;
        }
    } else {
        %guests = ();
    }
    %guests = %guests{"sles$guest_version"} if (get_var('TERADATA'));

} elsif (get_var("REGRESSION", '') =~ /vmware/) {
    %guests = (
        sles12sp3 => {
            name => 'sles12sp3',
        },
        sles12sp5 => {
            name => 'sles12sp5',
        },
        sles12sp5ES => {
            name => 'sles12sp5ES',
        },
        sles15sp2TD => {
            name => 'sles15sp2TD',
        },
        sles15sp3 => {
            name => 'sles15sp3',
        },
        sles15sp4 => {
            name => 'sles15sp4',
        },
        sles15sp4TD => {
            name => 'sles15sp4TD',
        },
        sles15sp5 => {
            name => 'sles15sp5',
        },
        sles15sp6 => {
            name => 'sles15sp6',
        },
    );
    %guests = get_var('TERADATA') ? %guests{"sles${guest_version}TD"} : (get_var('INCIDENT_REPO') =~ /LTSS-Extended-Security/) ? %guests{"sles${guest_version}ES"} : %guests{"sles${guest_version}"};

} elsif (get_var("REGRESSION", '') =~ /hyperv/) {
    %guests = (
        sles12sp3 => {
            vm_name => 'sles-12.3_openQA-virtualization-maintenance',
        },
        sles12sp5 => {
            vm_name => 'sles-12.5_openQA-virtualization-maintenance',
        },
        sles12sp5ES => {
            vm_name => 'sles-12.5_openQA-virtualization-maintenance-ES',
        },
        sles15sp2TD => {
            vm_name => 'sles-15.2_openQA-virtualization-maintenance',
        },
        sles15sp3 => {
            vm_name => 'sles-15.3_openQA-virtualization-maintenance',
        },
        sles15sp4 => {
            vm_name => 'sles-15.4_openQA-virtualization-maintenance',
        },
        sles15sp4TD => {
            vm_name => 'sles-15.4_openQA-virtualization-maintenance-TD',
        },
        sles15sp5 => {
            vm_name => 'sles-15.5_openQA-virtualization-maintenance',
        },
        sles15sp6 => {
            vm_name => 'sles-15.6_openQA-virtualization-maintenance',
        },
    );
    %guests = get_var('TERADATA') ? %guests{"sles${guest_version}TD"} : (get_var('INCIDENT_REPO') =~ /LTSS-Extended-Security/) ? %guests{"sles${guest_version}ES"} : %guests{"sles${guest_version}"};
}

our %imports = ();    # imports are virtual machines that we don't install but just import. We test those separately.
if (get_var("REGRESSION", '') =~ /xen/) {
    %imports = (
        win2k19 => {
            name => 'win2k19',
            extra_params => '--connect xen:/// --hvm --os-type windows --os-variant win2k16',    # --os-variant win2k19 not supported in older versions
            disk => '/var/lib/libvirt/images/win2k19.raw',
            source => '/mnt/virt_images/xen/win2k19.raw',
            macaddress => '52:54:00:78:73:66',
            version => 'Microsoft Windows Server 2019',
            memory => 4096,
            vcpus => 4,
            network_model => "e1000",
        },
    );
} elsif (get_var("REGRESSION", '') =~ /kvm|qemu/) {
    %imports = (
        win2k19 => {
            name => 'win2k19',
            extra_params => '--os-type windows --os-variant win2k16',    # --os-variant win2k19 not supported in older versions
            disk => '/var/lib/libvirt/images/win2k19.raw',
            source => '/mnt/virt_images/kvm/win2k19.raw',
            macaddress => '52:54:00:78:73:66',
            version => 'Microsoft Windows Server 2019',
            memory => 4096,
            vcpus => 4,
            network_model => "e1000",
        },
    );
} else {
    %imports = ();
}

1;
