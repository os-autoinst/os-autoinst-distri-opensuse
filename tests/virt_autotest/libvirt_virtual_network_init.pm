# SUSE's openQA tests
#
# Copyright (C) 2019-2020 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.
#
# Summary: Initialize testing environment for Libvirt Virtual Networks
# included the following priorities 4 types:
# libvirt_host_bridge_virtual_network
# libvirt_nated_virtual_network
# libvirt_routed_virtual_network
# libvirt_isolated_virtual_network
#
# Maintainer: Leon Guo <xguo@suse.com>

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

sub run_test {
    my ($self) = @_;

    if (is_xen_host) {
        #Ensure that there is enough free memory on xen host for virtual network test
        my $MEM = $self->get_free_mem();
        record_info('Detect FREE MEM', $MEM . 'G');
        assert_script_run("test $MEM -ge 20", fail_message => "The SUT needs at least 20G FREE MEM for virtual network test");
    }

    #After deployed guest systems, ensure active pool have at least
    #60GiB available disk space on vm host for virtual network test
    my ($ACTIVE_POOL_NAME, $AVAILABLE_POOL_SIZE) = $self->get_active_pool_and_available_space();
    record_info('Detect Active POOL NAME:',    $ACTIVE_POOL_NAME);
    record_info('Detect Available POOL SIZE:', $AVAILABLE_POOL_SIZE . 'GiB');
    assert_script_run("test $AVAILABLE_POOL_SIZE -ge 60", fail_message => "The SUT needs at least 60GiB available space of active pool for virtual network test");

    #Need to reset up environemt - br123 for virt_atuo test due to after
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
        #Prepare the new guest network interface files for libvirt virtual network
        assert_script_run("ssh root\@$guest 'cd /etc/sysconfig/network/; cp ifcfg-eth0 ifcfg-eth1; cp ifcfg-eth0 ifcfg-eth2; cp ifcfg-eth0 ifcfg-eth3; cp ifcfg-eth0 ifcfg-eth4; cp ifcfg-eth0 ifcfg-eth5; cp ifcfg-eth0 ifcfg-eth6'");
        if ($guest =~ m/sles-?11/i) {
            assert_script_run("ssh root\@$guest service network restart", 90);
        } else {
            assert_script_run("time ssh -v root\@$guest systemctl restart network", 120);
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
