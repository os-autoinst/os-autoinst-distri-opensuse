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

    #Need to reset up environemt - br123 for virt_atuo test due to after
    #finished guest installation to trigger cleanup step on sles11sp4 vm hosts
    virt_autotest::virtual_network_utils::restore_standalone() if (is_sle('=11-sp4'));

    #Enable libvirt debug log
    virt_autotest::virtual_network_utils::enable_libvirt_log();

    #VM HOST SSH SETUP
    virt_autotest::virtual_network_utils::ssh_setup();

    #Backup file /etc/hosts before virtual network testing
    virt_autotest::virtual_network_utils::hosts_backup();

    #Install required packages
    zypper_call '-t in iproute2 iptables iputils bind-utils sshpass nmap';

    #Check with Guest status before libvirt virtual network tests
    virt_autotest::virtual_network_utils::check_guest_status();

    #Prepare Guests
    foreach my $guest (keys %xen::guests) {
        #Archive deployed Guests
        #NOTE: Keep Archive deployed Guests for restore_guests func
        assert_script_run("virsh dumpxml $guest > /tmp/$guest.xml");
        upload_logs "/tmp/$guest.xml";
        #Start installed Guests
        assert_script_run("virsh start $guest", 60);
        #Wait for forceful boot up guests
        sleep 60;
        save_guest_ip($guest, name => "br123");
        my $mode = is_sle('=11-sp4') ? '' : '-f';
        exec_and_insert_password("ssh-copy-id -o StrictHostKeyChecking=no $mode root\@$guest");
        #Prepare the new guest network interface files for libvirt virtual network
        assert_script_run("ssh root\@$guest 'cd /etc/sysconfig/network/; cp ifcfg-eth0 ifcfg-eth1; cp ifcfg-eth0 ifcfg-eth2; cp ifcfg-eth0 ifcfg-eth3; cp ifcfg-eth0 ifcfg-eth4; cp ifcfg-eth0 ifcfg-eth5; cp ifcfg-eth0 ifcfg-eth6'");
        assert_script_run("ssh root\@$guest 'rcnetwork restart'", 60);
    }

    #Skip restart network service due to bsc#1166570
    #Restart network service
    #virt_autotest::virtual_network_utils::restart_network();
}

sub post_fail_hook {
    my ($self) = @_;

    #Restart libvirtd service
    virt_autotest::virtual_network_utils::restart_libvirtd();

    #Destroy created virtual networks
    virt_autotest::virtual_network_utils::destroy_vir_network();

    #Restore br123 for virt_autotest
    virt_autotest::virtual_network_utils::restore_standalone();

    #Restore Guest systems
    virt_autotest::virtual_network_utils::restore_guests();

    #Upload debug log
    virt_autotest::virtual_network_utils::upload_debug_log();
}

1;
