# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: libvirt-daemon openssh
# Summary: Import and test Windows guest
# Maintainer: QE-Virtualization <qe-virt@suse.de>

use Mojo::Base 'consoletest';
use virt_autotest::common;
use virt_autotest::utils;
use testapi;
use utils;

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

    # Remove already existing guests to ensure a fresh start (needed for restarting jobs)
    remove_guest $_ foreach (keys %virt_autotest::common::imports);
    #    shutdown_guests();    # Shutdown SLES guests as they are not needed here

    import_guest $_, 'virt-install' foreach (values %virt_autotest::common::imports);

    # Wait for Windows boot, get IP via nmap, and add to hosts
    sleep 60;

    my $scan_subnet = '192.168.122.0/24';

    # Xen Windows guests may take longer to boot due to HVM overhead
    my $nmap_delay = is_xen_host() ? 15 : 10;
    my $nmap_retry = is_xen_host() ? 15 : 10;

    foreach (values %virt_autotest::common::imports) {
        my $mac = $_->{macaddress};
        my $cmd = "nmap -sn $scan_subnet | grep -i '$mac' -B2 | grep 'Nmap scan report' | grep -oE '([0-9]{1,3}\\.){3}[0-9]{1,3}'";
        my $ip_address = script_output_retry $cmd, delay => $nmap_delay, retry => $nmap_retry;
        record_info("Guest IP", "Guest $_->{name} has IP: $ip_address");
        add_guest_to_hosts $_->{name}, $ip_address;
    }

    # Check if SSH is open because that means that the guest is installed
    ensure_online $_, skip_ssh => 1 foreach (keys %virt_autotest::common::imports);

    ssh_copy_id $_, username => $username, authorized_keys => 'C:\ProgramData\ssh\administrators_authorized_keys', scp => 1 foreach (keys %virt_autotest::common::imports);

    # Print system info, upload it and check the OS version
    assert_script_run "ssh $username\@$_ 'systeminfo' | tee /tmp/$_-systeminfo.txt" foreach (keys %virt_autotest::common::imports);
    upload_logs "/tmp/$_-systeminfo.txt" foreach (keys %virt_autotest::common::imports);
    assert_script_run "ssh $username\@$_ 'systeminfo' | grep '$virt_autotest::common::imports{$_}->{version}'" foreach (keys %virt_autotest::common::imports);
}

sub post_fail_hook {
    my $self = shift;
    # Note: Don't cleanup guests on test failure, so their state is preserved for debugging purposes!
    $self->SUPER::post_fail_hook;
}

sub post_run_hook {
    #    my $self = shift;
    remove_guest $_ foreach (keys %virt_autotest::common::imports);
    #    $self->SUPER::post_run_hook;
}

1;
