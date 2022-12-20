# SUSE's openQA tests
#
# Copyright 2019-2020 SUSE LLC
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
use set_config_as_glue;
use strict;
use warnings;
use testapi;
use utils;
use version_utils 'is_sle';
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
    my ($ACTIVE_POOL_NAME, $AVAILABLE_POOL_SIZE) = virt_autotest::virtual_network_utils::get_active_pool_and_available_space();
    record_info('Detect Active POOL NAME:', $ACTIVE_POOL_NAME);
    record_info('Detect Available POOL SIZE:', $AVAILABLE_POOL_SIZE . 'GiB');
    my $expected_pool_size = get_var('VIRT_EXPECTED_POOLSIZE', (is_xen_host) ? '40' : '20');
    assert_script_run("test $AVAILABLE_POOL_SIZE -ge $expected_pool_size",
        fail_message => "The SUT needs at least " . $expected_pool_size . "GiB available space of active pool for virtual network test");

    #Need to reset up environment - br123 for virt_atuo test due to after
    #finished guest installation to trigger cleanup step on sles11sp4 vm hosts
    virt_autotest::virtual_network_utils::restore_standalone() if (is_sle('=11-sp4'));

    #Enable libvirt debug log
    virt_autotest::virtual_network_utils::enable_libvirt_log();

    #VM HOST SSH SETUP
    virt_autotest::utils::ssh_setup();

    #Backup file /etc/hosts before virtual network testing
    virt_autotest::virtual_network_utils::hosts_backup();

    #Install required packages
    zypper_call '-t in iproute2 iptables iputils bind-utils sshpass nmap';

    #Prepare Guests
    foreach my $guest (keys %virt_autotest::common::guests) {
        #Archive deployed Guests
        #NOTE: Keep Archive deployed Guests for restore_guests func
        assert_script_run("virsh dumpxml $guest > /tmp/$guest.xml");
        upload_logs "/tmp/$guest.xml";
        #Used with attach-detach(hotplugging) interface to confirm all virtual network mode
        #NOTE: Required all guests keep running status
        #Check that all guests are still running before virtual network tests
        script_retry("nmap $guest -PN -p ssh | grep open", delay => 30, retry => 6, timeout => 180);
        save_guest_ip($guest, name => "br123");
        virt_autotest::utils::ssh_copy_id($guest);
        check_guest_health($guest);
        #Prepare the new guest network interface files for libvirt virtual network
        #for some guests, interfaces are named eth0, eth1, eth2, ...
        #for TW kvm guest, they are enp1s0, enp2s0, enp3s0, ...
        my $primary_nic = script_output("ssh root\@$guest \"ip a|awk -F': ' '/state UP/ {print \\\$2}'|head -n1\"");
        $primary_nic =~ /([a-zA-Z]*)(\d)(\w*)/;
        for (my $i = 1; $i <= 6; $i++) {
            my $nic = $1 . (int($2) + $i) . $3;
            assert_script_run("ssh root\@$guest 'cp /etc/sysconfig/network/ifcfg-$primary_nic /etc/sysconfig/network/ifcfg-$nic'");
        }
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

    #Skip restart network service due to bsc#1166570
    #Restart network service
    #virt_autotest::virtual_network_utils::restart_network();
}

sub post_fail_hook {
    my ($self) = @_;

    $self->SUPER::post_fail_hook;

    #Restart libvirtd service
    virt_autotest::utils::restart_libvirtd();

    #Destroy created virtual networks
    virt_autotest::virtual_network_utils::destroy_vir_network();

    #Restore br123 for virt_autotest
    virt_autotest::virtual_network_utils::restore_standalone();

    #Restore Guest systems
    virt_autotest::virtual_network_utils::restore_guests();
}

1;
