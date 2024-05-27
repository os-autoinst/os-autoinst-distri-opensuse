# SUSE's openQA tests
#
# Copyright 2019 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: libvirt-daemon openssh
# Summary: Import and test Windows guest
# Maintainer: QE-Virtualization <qe-virt@suse.de>

use base "consoletest";
use virt_autotest::common;
use virt_autotest::utils;
use strict;
use warnings;
use testapi;
use utils;

sub remove_guest {
    my $guest = shift;

    if (script_run("virsh list --all | grep '$guest'", 90) == 0) {
        assert_script_run "virsh destroy $guest";
        assert_script_run "virsh undefine $guest";
    }
}

sub run {
    my $self = shift;
    my $username = 'Administrator';

    # Remove already existing guests to ensure a fresh start (needed for restarting jobs)
    remove_guest $_ foreach (keys %virt_autotest::common::imports);
    #    shutdown_guests();    # Shutdown SLES guests as they are not needed here

    import_guest $_, 'virt-install' foreach (values %virt_autotest::common::imports);

    # Wait for Win2k19 boot, get IP via nmap, and add to hosts
    sleep 60;
    foreach (values %virt_autotest::common::imports) {
        my $cmd = "nmap -sn 192.168.122.0/24 | grep $_->{macaddress} -B2 | head -1 | grep -oE '[0-9]+.[0-9]+.[0-9]+.[0-9]+'";
        my $ip_address = script_output_retry $cmd, delay => 10, retry => 10;
        add_guest_to_hosts $_->{name}, $ip_address;
    }

    # Check if SSH is open because of that means that the guest is installed
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
