# XEN regression tests
#
# Copyright © 2019-2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Package: bridge-utils libvirt-client openssh qemu-tools util-linux
# Summary: Virtual network and virtual block device hotplugging
# Maintainer: Pavel Dostal <pdostal@suse.cz>, Felix Niederwanger <felix.niederwanger@suse.de>, Jan Baier <jbaier@suse.cz>

use base "virt_feature_test_base";
use virt_autotest::common;
use virt_autotest::utils;
use strict;
use warnings;
use testapi;
use utils;
use virt_utils;
use version_utils;

# Magic MAC prefix for temporary devices. Must be of the format 'XX:XX:XX:XX'
my $MAC_PREFIX = '00:16:3f:32';

# Try to attach a NIC or disk device and check for bsc1175218
sub try_attach {
    my $cmd = shift;
    if (script_run($cmd) != 0) {
        # Check for https://bugzilla.suse.com/show_bug.cgi?id=1175218
        if (script_run($cmd . " 2>&1 | grep 'No more available PCI slots'") == 0) {
            record_soft_failure("bsc#1175218 No more available PCI slots when attaching network interface");
            return 0;
        } else {
            die "virsh attach failed";
        }
    }
    return 1;
}


# Add a virtual network interface for the given guest and return the determined MAC address
sub add_virtual_network_interface {
    my $self  = shift;
    my $guest = shift;
    my ($sles_running_version, $sles_running_sp) = get_os_release;

    my $mac = "$MAC_PREFIX:" . (int(rand(89)) + 10) . ':' . (int(rand(89)) + 10);
    unless ($guest =~ m/hvm/i && is_sle('<=12-SP2') && is_xen_host) {
        my $persistent_config_option = '';
        my $interface_model_option   = '';
        if (get_var('VIRT_AUTOTEST') && is_xen_host) {
            record_soft_failure 'bsc#1168124 Bridge network interface hotplugging has to be performed at the beginning.';
            $self->{test_results}->{$guest}->{"bsc#1168124 Bridge network interface hotplugging has to be performed at the beginning"}->{status} = 'SOFTFAILED';
            $persistent_config_option = '--persistent' if ($sles_running_version eq '11' && $sles_running_sp eq '4');
            script_run "brctl addbr br0; ip link set dev br0 up", 60 if ($sles_running_version eq '11' && $sles_running_sp eq '4');
        }
        if (get_var('VIRT_AUTOTEST') && is_kvm_host) {
            $interface_model_option = '--model virtio';
            script_run "brctl addbr br0; ip link set dev br0 up", 60 if ($sles_running_version eq '11' && $sles_running_sp eq '4');
            if ($guest =~ /^sles-11-sp4.*$/img) {
                script_run "ssh root\@$guest modprobe acpiphp", 60;
                record_info('Info: Manually loading acpiphp module in SLE 11-SP4 guest due to bsc#1167828 otherwise network interface hotplugging does not work');
            }
        }
        script_retry("ssh root\@$guest ip l | grep " . $virt_autotest::common::guests{$guest}->{macaddress}, delay => 60, retry => 3, timeout => 60);
        assert_script_run("virsh domiflist $guest", 90);
        if (try_attach("virsh attach-interface --domain $guest --type bridge ${interface_model_option} --source br0 --mac " . $mac . " --live " . ${persistent_config_option})) {
            assert_script_run("virsh domiflist $guest | grep br0");
            assert_script_run("ssh root\@$guest cat /proc/uptime | cut -d. -f1", 60);
            script_retry("ssh root\@$guest ip l | grep " . $mac, delay => 60, retry => 3, timeout => 60);
            assert_script_run("virsh detach-interface $guest bridge --mac " . $mac);
        }
    } else {
        record_soft_failure 'bsc#959325 - Live NIC attachment on <=12-SP2 Xen hypervisor with HVM guests does not work correctly.';
    }
    return $mac;
}

sub get_disk_image_name {
    my $guest       = shift;
    my $disk_format = shift // get_var("QEMU_DISK_FORMAT");
    $disk_format //= "raw";    # Fallback in case nor function argument not QEMU_DISK_FORMAT setting is set
    my $disk_image = "/var/lib/libvirt/images/add/$guest.$disk_format";
    return $disk_image;
}

# Add a virtual disk to the given guest
sub test_add_virtual_disk {
    my $guest       = shift;
    my $disk_format = get_var("QEMU_DISK_FORMAT") // "raw";
    my $disk_image  = get_disk_image_name($guest, $disk_format);

    assert_script_run("rm -f $disk_image");
    assert_script_run "qemu-img create -f $disk_format $disk_image 10G";
    my $domblk_target = 'vdz';
    $domblk_target = 'xvdz' if (is_xen_host);
    script_run("virsh detach-disk $guest ${domblk_target}", 240);
    if (try_attach("virsh attach-disk --domain $_ --source $disk_image --target ${domblk_target}")) {
        assert_script_run "virsh domblklist $guest | grep ${domblk_target}";
        # Skip lsblk check for VIRT_AUTOTEST KVM test suites after attaching raw disk due to uncertainty
        if (!get_var('VIRT_AUTOTEST')) {
            if (is_kvm_host) {
                my $lsblk = script_run("ssh root\@$guest lsblk | grep 'vd[b-z]'", 60);
                record_soft_failure("lsblk failed - please check the output manually") if $lsblk != 0;
            } elsif (is_xen_host) {
                my $lsblk = script_run("ssh root\@$guest lsblk | grep 'xvd[b-z]'", 60);
                record_soft_failure("lsblk failed - please check the output manually") if $lsblk != 0;
            } else {
                my $msg = "Unknown virtualization hosts";
                record_soft_failure($msg);
            }
        }
        assert_script_run("ssh root\@$guest lsblk");
        assert_script_run("virsh detach-disk $guest ${domblk_target}", 240);
    }
    assert_script_run("rm -f $disk_image");
}

# Set and check the number of vcpus for the given guest
sub set_vcpus {
    my ($guest, $vcpus) = @_;
    assert_script_run("virsh setvcpus --domain $guest --count $vcpus --live");
    return script_run("virsh vcpucount $guest | grep current | grep live | grep $vcpus") == 0;
}

# Add a virtual CPU to the given guest
sub test_add_vcpu {
    my $guest = shift;
    my ($sles_running_version, $sles_running_sp) = get_os_release;

    if (get_var('VIRT_AUTOTEST') && is_kvm_host && ($sles_running_version eq '11' && $sles_running_sp eq '4')) {
        record_info 'Skip vCPU hotplugging', 'bsc#1169065 vCPU hotplugging does no work on SLE 11-SP4 KVM host';
        return;
    }
    return if (is_xen_host && $guest =~ m/hvm/i);    # not supported on HVM guest

    # Ensure guest CPU count is 2
    die "Setting vcpus failed" unless (set_vcpus($guest, 2));
    assert_script_run("ssh root\@$guest nproc | grep 2", 60);
    # Add 1 CPU
    if ($sles_running_version eq '15' && $sles_running_sp eq '4' && is_xen_host && is_fv_guest($guest)) {
        record_soft_failure('bsc#1188898 Failed to set live vcpu count on fv guest on 15-SP4 Xen host');
    }
    elsif ($sles_running_version eq '15' && $sles_running_sp eq '3' && is_xen_host && is_fv_guest($guest)) {
        record_soft_failure('bsc#1180350 Failed to set live vcpu count on fv guest on 15-SP3 Xen host');
    }
    else {
        die "Increasing vcpus failed" unless (set_vcpus($guest, 3));
        if (get_var('VIRT_AUTOTEST') && is_kvm_host && ($sles_running_version eq '15' && $sles_running_sp eq '2')) {
            record_soft_failure 'bsc#1170026 vCPU hotplugging damages ' . $guest if (script_retry("ssh root\@$guest nproc", delay => 60, retry => 3, timeout => 60, die => 0) != 0);
            #$self->{test_results}->{$guest}->{"bsc#1170026 vCPU hotplugging damages this guest $guest"}->{status} = 'SOFTFAILED' if ($vcpu_nproc != 0);
        } else {
            script_retry("ssh root\@$guest nproc | grep 3", delay => 60, retry => 3, timeout => 60);
        }
        # Reset CPU count to two
        die "Resetting vcpus failed" unless (set_vcpus($guest, 2));

        ## Check for bsc#1187341. This whole section can be removed once bsc#1187341 is fixed
        if ($guest eq 'sles12sp3PV') {
            sleep(60);    # Bug needs some time to actually be triggered
            if (script_run("virsh list --all | grep $guest | grep running") != 0) {
                record_soft_failure("bsc#1187341", "$guest changing number of vspus crashes $guest");
                script_run("xl dump-core > xl_coredump_$guest.log");
                upload_logs("xl_coredump_$guest.log");
                script_run("virsh start $guest");
                ensure_online("$guest");
            }
        }
    }
}

# Returns the guest memory in MB
sub get_guest_memory {
    my $guest        = shift;
    my $kernelmemory = 200000;    # We account to kernel memory to measures which omit it by adding this amount to the measured value

    my $memory = 0;
    $memory = script_output("ssh $guest cat /proc/meminfo | grep MemTotal | awk '{print \$2}'", proceed_on_failure => 1);
    return ($memory + $kernelmemory) / 1024 if (defined($memory) && $memory > 0);

    # Fallback to use `free`
    $memory = script_output("ssh $guest free | grep Mem | awk '{print \$2}'", proceed_on_failure => 1) + $kernelmemory;
    return ($memory + $kernelmemory) / 1024 if (defined($memory) && $memory > 0);

    return 0;
}

# Set memory of the given guest to the given size in MB
sub set_guest_memory {
    my $guest      = shift;
    my $memory     = shift;
    my $min_memory = shift // 0.9 * $memory;    # acceptance range for memory check
    my $max_memory = shift // 1.1 * $memory;    # acceptance range for memory check

    assert_script_run("virsh setmem --domain $guest --size $memory" . "M --live");
    assert_script_run("virsh dommemstat $guest");
    assert_script_run("ssh root\@$guest free", 60);
    sleep 5;                                    # give the VM some time to adjust
    my $guestmemory = get_guest_memory($guest);
    # Memory reposts are not precise, we allow for a +/-10% acceptance range
    my $within_tolerance = ($min_memory <= $guestmemory) && ($guestmemory <= $max_memory);
    record_soft_failure("Set live memory failed - expected $memory but got $guestmemory") unless ($within_tolerance);
}

sub test_vmem_change {
    my $guest = shift;
    if (is_sle) {
        my ($sles_running_version, $sles_running_sp) = get_os_release;
        if (get_var('VIRT_AUTOTEST') && ($sles_running_version lt '12' or ($sles_running_version eq '12' and $sles_running_sp lt '3'))) {
            record_info('Skip memory hotplugging on outdated before-12-SP3 SLES product because immature memory handling situations');
            return;
        }
    }
    return if (is_xen_host && $guest =~ m/hvm/i);    # memory change not supported on HVM guest
    set_guest_memory($guest, 2048, 1500, 2252);      # Lower memory limit is set to 80%, which is enough to distinguish between 2G and 3G
    set_guest_memory($guest, 3072, 2457, 3379);
    set_guest_memory($guest, 2048, 1500, 2252);
}

sub increase_max_memory {
    my $guest          = shift;
    my $increase       = shift // 2048;
    my $guest_instance = $virt_autotest::common::guests{$guest};
    my $maxmemory      = $guest_instance->{maxmemory} // "4096";
    $maxmemory += $increase;
    assert_script_run("virsh setmaxmem $guest $maxmemory" . "M --config");
}

sub run_test {
    my ($self) = @_;
    my ($sles_running_version, $sles_running_sp) = get_os_release;

    if ($sles_running_version eq '15' && get_var("VIRT_AUTOTEST") && !get_var("VIRT_UNIFIED_GUEST_INSTALL")) {
        record_info("DNS Setup", "SLE 15+ host may have more strict rules on dhcp assigned ip conflict prevention, so guest ip may change");
        my $dns_bash_script_url = data_url("virt_autotest/setup_dns_service.sh");
        script_output("curl -s -o ~/setup_dns_service.sh $dns_bash_script_url", 180, type_command => 0, proceed_on_failure => 0);
        script_output("chmod +x ~/setup_dns_service.sh && ~/setup_dns_service.sh -f testvirt.net -r 123.168.192 -s 192.168.123.1", 180, type_command => 0, proceed_on_failure => 0);
        upload_logs("/var/log/virt_dns_setup.log");
        save_screenshot;
    }

    ## 0. Guest preparation
    shutdown_guests();
    # Increase maximum memory for this test run
    increase_max_memory($_) foreach (keys %virt_autotest::common::guests);
    start_guests();

    # 1. Add network interfaces
    my %mac = ();
    record_info "Virtual network", "Adding virtual network interface";
    $mac{$_} = add_virtual_network_interface($self, $_) foreach (keys %virt_autotest::common::guests);

    # 2. Hotplug HDD
    my $lsblk       = 0;
    my $disk_format = get_var("QEMU_DISK_FORMAT") // "raw";
    record_info "Disk", "Adding another raw disk";
    assert_script_run "mkdir -p /var/lib/libvirt/images/add/";
    test_add_virtual_disk($_) foreach (keys %virt_autotest::common::guests);

    # 3. Hotplugging of vCPUs
    record_info("CPU", "Changing the number of CPUs available");
    test_add_vcpu($_) foreach (keys %virt_autotest::common::guests);

    # 4. Live memory change of guests
    record_info "Memory", "Changing the amount of memory available";
    test_vmem_change($_) foreach (keys %virt_autotest::common::guests);

    # Workaround to drop all live provisions of all vm guests
    if (get_var('VIRT_AUTOTEST') && is_kvm_host && (($sles_running_version eq '12' and $sles_running_sp eq '5') || ($sles_running_version eq '15' and $sles_running_sp eq '1'))) {
        record_info "Reboot All Guests", "Mis-handling of live and config provisions by other test modules may have negative impact on 12-SP5 and 15-SP1 KVM scenarios due to bsc#1171946. So here is the workaround to drop all live provisions by rebooting all vm guests.";
        perform_guest_restart;
    }

    ## 5. Cleanup
    shutdown_guests();
    reset_guest($_) foreach (keys %virt_autotest::common::guests);
}

sub reset_guest {
    my $guest = shift;
    return if $guest == "";
    my $guest_instance = $virt_autotest::common::guests{$guest};

    ## Network
    # Remove temporary NIC devices, those are identified by a MAC starting with "$MAC_PREFIX"
    remove_additional_nic($guest, $MAC_PREFIX);
    ## Disk cleanup
    my $disk_image = get_disk_image_name($guest);
    remove_additional_disks($guest);
    script_run("rm -f $disk_image");
    ## CPU and memory
    set_vcpus($guest, 2);
    my $memory = $guest_instance->{memory} // "2048";
    set_guest_memory($guest, $memory);
    # max memory
    my $maxmemory = $guest_instance->{maxmemory} // "4096";
    script_run("virsh setmaxmem $_ $maxmemory" . "M --config") foreach (keys %virt_autotest::common::guests);
}

sub post_fail_hook {
    my ($self) = @_;

    # Call parent post_fail_hook to collect logs on failure
    $self->SUPER::post_fail_hook;
    # Ensure guests remain in a consistent state also on failure
    reset_guest($_) foreach (keys %virt_autotest::common::guests);
}

1;
