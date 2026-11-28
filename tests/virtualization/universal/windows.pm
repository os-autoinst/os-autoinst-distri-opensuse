# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: libvirt-daemon openssh
# Summary: Import and test Windows guest
# Maintainer: QE-Virtualization <qe-virt@suse.de>

use Mojo::Base 'consoletest';
use virt_autotest::domain_management_utils qw(check_guest_state shutdown_guest);
use virt_autotest::common;
use virt_autotest::utils;
use testapi;
use utils;
use serial_terminal 'select_serial_terminal';

sub remove_guest {
    my $guest = shift;

    if (is_xen_host()) {
        script_run "virsh --connect xen:/// destroy $guest", 60;
        script_run "virsh --connect xen:/// undefine $guest --nvram", 60;
        script_run "xl destroy $guest 2>/dev/null", 30;
    } else {
        if (script_run("virsh list --all | grep '$guest'", 90) == 0) {
            script_run "virsh destroy $guest", 60;
            script_run "virsh undefine $guest --nvram", 60;
        }
    }
}

sub run {
    my $self = shift;
    my $username = 'Administrator';

    # Ensure we have a working serial console, previous virt-manager GUI tests
    # may leave the console in an unreliable state (bsc#1172356, bsc#1221917)
    select_serial_terminal;

    # Remove already existing guests to ensure a fresh start (needed for restarting jobs)
    remove_guest $_ foreach (keys %virt_autotest::common::imports);
    my @sles_guests = grep {
        my $state = check_guest_state(guest => $_);
        $state && $state ne 'shutoff';
    } keys %virt_autotest::common::guests;
    # Save the state before shutdown so a partial failure can still be recovered.
    $self->{sles_guests_to_restore} = \@sles_guests;
    shutdown_guest(guest => join(' ', @sles_guests), die => 1) if @sles_guests;

    import_guest $_, 'virt-install' foreach (values %virt_autotest::common::imports);

    # Wait for Windows boot, get IP via nmap, and add to hosts
    sleep 60;

    my $scan_subnet = '192.168.122.0/24';

    # Xen Windows guests take longer to boot due to HVM overhead
    my $nmap_delay = is_xen_host() ? 30 : 15;
    my $nmap_retry = is_xen_host() ? 30 : 15;

    foreach (values %virt_autotest::common::imports) {
        my $mac = $_->{macaddress};
        my $cmd = "nmap -sn $scan_subnet | grep -i '$mac' -B2 | grep 'Nmap scan report' | grep -oE '([0-9]{1,3}\\.){3}[0-9]{1,3}'";
        my $ip_address = script_output_retry $cmd, delay => $nmap_delay, retry => $nmap_retry, timeout => 60;
        record_info("Guest IP", "Guest $_->{name} has IP: $ip_address");
        add_guest_to_hosts $_->{name}, $ip_address;
    }

    # Check if SSH is open because that means that the guest is installed
    ensure_online $_, skip_ssh => 1 foreach (keys %virt_autotest::common::imports);

    ssh_copy_id $_, username => $username, authorized_keys => 'C:\ProgramData\ssh\administrators_authorized_keys', scp => 1 foreach (keys %virt_autotest::common::imports);

    # Print system info, upload it and check the OS version
    # Windows systeminfo can be very slow on freshly booted Xen HVM guests
    assert_script_run "ssh $username\@$_ 'systeminfo' | tee /tmp/$_-systeminfo.txt", 480 foreach (keys %virt_autotest::common::imports);
    upload_logs "/tmp/$_-systeminfo.txt" foreach (keys %virt_autotest::common::imports);
    assert_script_run "grep '$virt_autotest::common::imports{$_}->{version}' /tmp/$_-systeminfo.txt" foreach (keys %virt_autotest::common::imports);
}

# Keep Windows guest definitions and disks on both outcomes while releasing host memory.
sub post_fail_hook {
    my $self = shift;
    $self->SUPER::post_fail_hook;
    $self->post_run_hook;
}

sub post_run_hook {
    my $self = shift;
    my @sles_guests = @{delete $self->{sles_guests_to_restore} // []};
    my @windows_guests = grep { check_guest_state(guest => $_) } keys %virt_autotest::common::imports;
    shutdown_guest(guest => join(' ', @windows_guests), die => 1) if @windows_guests;
    ensure_online($_, skip_network => 1) foreach @sles_guests;
}

1;
