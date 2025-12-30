# SUSE's openQA tests
#
# Copyright 2019-2025 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Initialize testing environment for Libvirt Virtual Networks
# included the following priorities 4 types:
# libvirt_host_bridge_virtual_network
# libvirt_nated_virtual_network
# libvirt_routed_virtual_network
# libvirt_isolated_virtual_network
#
# Maintainer: Leon Guo <xguo@suse.com>, qe-virt@suse.com

use virt_autotest::virtual_network_utils;
use virt_autotest::utils;
use base "virt_feature_test_base";
use virt_utils;
use testapi;
use utils;
use version_utils qw(is_sle);
use virt_autotest::utils qw(is_xen_host);

sub run_test {
    my ($self) = @_;

    if (is_xen_host) {
        #Ensure that there is enough free memory on xen host for virtual network test
        my $MEM = virt_autotest::virtual_network_utils::get_free_mem();
        record_info('Detect FREE MEM', $MEM . 'G');
        assert_script_run("test $MEM -ge 20", fail_message => "The SUT needs at least 20G FREE MEM for virtual network test");
    }

    #After deployed guest systems, ensure active pool have at least 40GiB(XEN)
    #or 20GiB(KVM) available disk space on vm host for virtual network test
    #From sle16, there are multiple active pools when multiple VMs created with storage file
    #in different sub-directories of /var/lib/libvirt/images, while on sle15, for such case,
    #there is only 1.
    #Good thing is that the pools are on the same partition that /var/lib/libvirt/images resides,
    #so the pools capacity and available space data is almost the same. Thus we can use the first pool info.
    #However, if someday we store VM disk files on different partitions, we will need to change the logic here.
    my ($ACTIVE_POOL_NAME, $AVAILABLE_POOL_SIZE) = virt_autotest::virtual_network_utils::get_active_pool_and_available_space();
    record_info('Detect Active POOL NAME:', $ACTIVE_POOL_NAME);
    record_info('Detect Available POOL SIZE:', $AVAILABLE_POOL_SIZE . 'GiB');
    my $expected_pool_size = get_var('VIRT_EXPECTED_POOLSIZE', (is_xen_host) ? '40' : '20');
    assert_script_run("test $AVAILABLE_POOL_SIZE -ge $expected_pool_size",
        fail_message => "The SUT needs at least " . $expected_pool_size . "GiB available space of active pool for virtual network test");

    # SLES16 has done this in earlier setup
    unless (is_sle('=16')) {
        #Enable libvirt debug log
        turn_on_libvirt_debugging_log;

        #VM HOST SSH SETUP
        virt_autotest::utils::ssh_setup();
    }

    #Backup file /etc/hosts before virtual network testing
    virt_autotest::virtual_network_utils::hosts_backup();

    #Install required packages
    zypper_call '-t in iproute2 iptables iputils bind-utils nmap';

    #Prepare Guests
    foreach my $guest (keys %virt_autotest::common::guests) {
        my $guest_bridge_source = virt_autotest::virtual_network_utils::get_guest_bridge_src($guest);
        record_info('GUEST_BRIDGE_SOURCE', "Found the $guest bridge source: " . $guest_bridge_source);
        #Archive deployed Guests
        #NOTE: Keep Archive deployed Guests for restore_guests func
        assert_script_run("virsh dumpxml $guest > /tmp/$guest.xml");
        upload_logs "/tmp/$guest.xml";
        #Used with attach-detach(hotplugging) interface to confirm all virtual network mode
        #NOTE: Required all guests keep running status
        #Ensures the SSH connection and ICMP PING responses is workable for given guest system
        validate_guest_status($guest);
        save_guest_ip($guest, name => "br123");
        virt_autotest::utils::ssh_copy_id($guest);

        # SLES16 guest uses networkmanager to control network, no /etc/sysconfig/network/ifcfg*
        next if ($guest =~ /sles-16/i);
        #enable guest wickedd debugging
        assert_script_run "ssh root\@$guest \"sed -i 's/^WICKED_DEBUG=.*/WICKED_DEBUG=\"all\"/g' /etc/sysconfig/network/config\"";
        assert_script_run "ssh root\@$guest 'grep 'WICKED_DEBUG' /etc/sysconfig/network/config'";
        assert_script_run "ssh root\@$guest \"sed -i 's/^WICKED_LOG_LEVEL=.*/WICKED_LOG_LEVEL=\"debug\"/g' /etc/sysconfig/network/config\"";
        assert_script_run "ssh root\@$guest 'grep 'WICKED_LOG_LEVEL' /etc/sysconfig/network/config'";
        if ($guest =~ m/sles-?11/i) {
            assert_script_run("ssh root\@$guest service network restart", 90);
            assert_script_run("ssh root\@$guest service wickedd restart", 90);
        } else {
            assert_script_run("time ssh -v root\@$guest systemctl restart network", 120);
            assert_script_run("time ssh -v root\@$guest systemctl restart wickedd", 120);
        }
    }
}

sub post_fail_hook {
    my ($self) = @_;

    $self->SUPER::post_fail_hook;

}

1;
