# XEN regression tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: Virtual network and virtual block device hotplugging
# Maintainer: Jan Baier <jbaier@suse.cz>

use base "virt_feature_test_base";
use xen;
use strict;
use warnings;
use testapi;
use utils;
use virt_utils;
use version_utils;

sub run_test {
    my ($self) = @_;
    my $hypervisor = get_var('HYPERVISOR') // '127.0.0.1';
    my ($sles_running_version, $sles_running_sp) = get_sles_release;

    my %mac = ();
    record_info "Virtual network", "Adding virtual network interface";
    foreach my $guest (keys %xen::guests) {
        $mac{$guest} = '00:16:3f:32:' . (int(rand(89)) + 10) . ':' . (int(rand(89)) + 10);
        unless ($guest =~ m/hvm/i && is_sle('<=12-SP2') && check_var("XEN", "1")) {
            my $persistent_config_option = '';
            my $interface_model_option   = '';
            if (get_var('VIRT_AUTOTEST') && (get_var('XEN') || check_var('SYSTEM_ROLE', 'xen') || check_var('HOST_HYPERVISOR', 'xen'))) {
                record_soft_failure 'bsc#1168124 Bridge network interface hotplugging has to be performed at the beginning.';
                $self->{test_results}->{$guest}->{"bsc#1168124 Bridge network interface hotplugging has to be performed at the beginning"}->{status} = 'SOFTFAILED';
                $persistent_config_option = '--persistent' if ($sles_running_version eq '11' && $sles_running_sp eq '4');
                script_run "brctl addbr br0; ip link set dev br0 up", 60 if ($sles_running_version eq '11' && $sles_running_sp eq '4');
            }
            if (get_var('VIRT_AUTOTEST') && (check_var('SYSTEM_ROLE', 'kvm') || check_var('HOST_HYPERVISOR', 'kvm'))) {
                $interface_model_option = '--model virtio';
                script_run "brctl addbr br0; ip link set dev br0 up", 60 if ($sles_running_version eq '11' && $sles_running_sp eq '4');
                if ($guest =~ /^sles-11-sp4.*$/img) {
                    script_run "ssh root\@$guest modprobe acpiphp", 60;
                    record_info('Info: Manually loading acpiphp module in SLE 11-SP4 guest due to bsc#1167828 otherwise network interface hotplugging does not work');
                }
            }
            script_retry "ssh root\@$guest ip l | grep " . $xen::guests{$guest}->{macaddress}, delay => 60, retry => 3, timeout => 60;
            assert_script_run "virsh attach-interface --domain $guest --type bridge ${interface_model_option} --source br0 --mac " . $mac{$guest} . " --live " . ${persistent_config_option};
            assert_script_run "virsh domiflist $guest | grep br0";
            assert_script_run "ssh root\@$guest cat /proc/uptime | cut -d. -f1", 60;
            script_retry "ssh root\@$guest ip l | grep " . $mac{$guest}, delay => 60, retry => 3, timeout => 60;
            assert_script_run "virsh detach-interface $guest bridge --mac " . $mac{$guest};
        } else {
            record_soft_failure 'bsc#959325 - Live NIC attachment on <=12-SP2 Xen hypervisor with HVM guests does not work correctly.';
        }
    }

    # TODO:
    my $lsblk = 0;
    record_info "Disk", "Adding another raw disk";
    assert_script_run "mkdir -p /var/lib/libvirt/images/add/";
    assert_script_run "qemu-img create -f raw /var/lib/libvirt/images/add/$_.raw 10G" foreach (keys %xen::guests);
    my $domblk_target = '';
    if (check_var('XEN', '1')) {
        $domblk_target = 'xvdz';
    } else {
        $domblk_target = 'vdz';
    }
    script_run "virsh detach-disk $_ ${domblk_target}", 240 foreach (keys %xen::guests);
    assert_script_run "virsh attach-disk --domain $_ --source /var/lib/libvirt/images/add/$_.raw --target ${domblk_target}" foreach (keys %xen::guests);
    assert_script_run "virsh domblklist $_ | grep ${domblk_target}"                                                         foreach (keys %xen::guests);
    #Skip lsblk check for VIRT_AUTOTEST KVM test suites after attaching raw disk due to uncertainty
    if (!(get_var('VIRT_AUTOTEST') && (check_var('SYSTEM_ROLE', 'kvm') || check_var('HOST_HYPERVISOR', 'kvm')))) {
        foreach my $guest (keys %xen::guests) {
            $lsblk = script_run "ssh root\@$guest lsblk | grep ${domblk_target}", 60;
            record_soft_failure("lsblk failed - please check the output manually") if $lsblk != 0;
            $self->{test_results}->{$guest}->{"lsblk failed - please check the output manually (ssh root\@$guest lsblk | grep ${domblk_target})"}->{status} = 'SOFTFAILED' if (get_var('VIRT_AUTOTEST') && ($lsblk != 0));
        }
    }
    assert_script_run "ssh root\@$_ lsblk" foreach (keys %xen::guests);
    assert_script_run "virsh detach-disk $_ ${domblk_target}", 240 foreach (keys %xen::guests);

    # TODO:
    record_info "CPU", "Changing the number of CPUs available";
    foreach my $guest (keys %xen::guests) {
        if (get_var('VIRT_AUTOTEST') && (check_var('SYSTEM_ROLE', 'kvm') || check_var('HOST_HYPERVISOR', 'kvm')) && ($sles_running_version eq '11' && $sles_running_sp eq '4')) {
            record_info 'Skip vCPU hotplugging', 'bsc#1169065 vCPU hotplugging does no work on SLE 11-SP4 KVM host';
            next;
        }
        unless ($guest =~ m/hvm/i) {
            # The guest should have 2 CPUs after the installation
            assert_script_run "virsh vcpucount $guest | grep current | grep live", 90;
            assert_script_run "ssh root\@$guest nproc",                            60;
            # Add 1 CPU for everu guest
            assert_script_run "virsh setvcpus --domain $guest --count 3 --live";
            sleep 5;
            assert_script_run "virsh vcpucount $guest | grep current | grep live | grep 3";
            if (get_var('VIRT_AUTOTEST') && (check_var('SYSTEM_ROLE', 'kvm') || check_var('HOST_HYPERVISOR', 'kvm')) && ($sles_running_version eq '15' && $sles_running_sp eq '2')) {
                my $vcpu_nproc = script_retry "ssh root\@$guest nproc", delay => 60, retry => 3, timeout => 60, die => 0;
                record_soft_failure 'bsc#1170026 vCPU hotplugging damages this guest ' . $guest if ($vcpu_nproc != 0);
                $self->{test_results}->{$guest}->{"bsc#1170026 vCPU hotplugging damages this guest $guest"}->{status} = 'SOFTFAILED' if ($vcpu_nproc != 0);
            } else {
                script_retry "ssh root\@$guest nproc", delay => 60, retry => 3, timeout => 60;
            }
        }
    }

    # TODO:
    record_info "Memory", "Changing the amount of memory available";
    foreach my $guest (keys %xen::guests) {
        if (get_var('VIRT_AUTOTEST') && ($sles_running_version lt '12' or ($sles_running_version eq '12' and $sles_running_sp lt '3'))) {
            record_info('Skip memory hotplugging on outdated before-12-SP3 SLES product because immature memory handling situations');
            last;
        }
        unless ($guest =~ m/hvm/i) {
            assert_script_run "virsh dommemstat $guest";
            assert_script_run "ssh root\@$guest free", 60;
            #assert_script_run "ssh root\@$guest dmidecode --type 17 | grep Size", 60;
            assert_script_run "virsh setmem --domain $guest --size 3072M --live";
            sleep 5;
            assert_script_run "virsh dommemstat $guest";
            assert_script_run "ssh root\@$guest free", 60;
            #assert_script_run "ssh root\@$guest dmidecode --type 17 | grep Size", 60;
            assert_script_run "virsh setmem --domain $guest --size 2048M --live";
            sleep 5;
            assert_script_run "virsh dommemstat $guest";
            assert_script_run "ssh root\@$guest free", 60;
            #assert_script_run "ssh root\@$guest dmidecode --type 17 | grep Size", 60;
        }
    }

    #Workaround to drop all live provisions of all vm guests
    if (get_var('VIRT_AUTOTEST') && (check_var('SYSTEM_ROLE', 'kvm') || check_var('HOST_HYPERVISOR', 'kvm')) && (($sles_running_version eq '12' and $sles_running_sp eq '5') || ($sles_running_version eq '15' and $sles_running_sp eq '1'))) {
        record_info "Reboot All Guests", "Mis-handling of live and config provisions by other test modules may have negative impact on 12-SP5 and 15-SP1 KVM scenarios due to bsc#1171946. So here is the workaround to drop all live provisions by rebooting all vm guests.";
        perform_guest_restart;
    }
}

1;
