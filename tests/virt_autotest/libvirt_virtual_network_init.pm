# SUSE's openQA tests
#
# Copyright (C) 2019 SUSE LLC
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

sub run_test {
    my ($self) = @_;

    #Enable libvirt debug log
    virt_autotest::virtual_network_utils::enable_libvirt_log();

    #VM HOST SSH SETUP
    virt_autotest::virtual_network_utils::ssh_setup();

    #Install required packages
    zypper_call '-t in iproute2 iptables iputils bind-utils sshpass';

    #Check with Guest status before libvirt virtual network tests
    virt_autotest::virtual_network_utils::check_guest_status();

    #Prepare Guests
    foreach my $guest (keys %xen::guests) {
        #Archive deployed Guests
        assert_script_run("virsh dumpxml $guest > /tmp/$guest.xml");
        upload_logs "/tmp/$guest.xml";
        #Start installed Guests
        assert_script_run("virsh start $guest", 60);
        #Wait for forceful boot up guests
        sleep 60;
        #Get the Guest IP Address for bootup guest
        my $mac_guest = script_output("virsh domiflist $guest | grep br123 | grep -oE \"[[:xdigit:]]{2}(:[[:xdigit:]]{2}){5}\"");
        script_retry "journalctl --no-pager | grep DHCPACK | grep $mac_guest | grep -oE \"([0-9]{1,3}[\.]){3}[0-9]{1,3}\"", delay => 90, retry => 9, timeout => 90;
        my $gi_guest = script_output("journalctl --no-pager | grep DHCPACK | grep $mac_guest | tail -1 | grep -oE \"([0-9]{1,3}[\.]){3}[0-9]{1,3}\"");
        #Copy the VM host SSH Key to guest systems
        exec_and_insert_password("ssh-copy-id -o StrictHostKeyChecking=no -f root\@$gi_guest");
        #Prepare the new guest network interface files for libvirt virtual network
        assert_script_run("ssh root\@$gi_guest 'cd /etc/sysconfig/network/; cp ifcfg-eth0 ifcfg-eth1; cp ifcfg-eth0 ifcfg-eth2'");
        assert_script_run("ssh root\@$gi_guest 'rcnetwork restart'", 60);
        #REDEFINE GUEST NETWORK INTERFACE
        assert_script_run("virsh detach-interface $guest bridge --mac $mac_guest");
        assert_script_run("virsh dumpxml $guest > $guest.redefine");
        upload_logs "$guest.redefine";
        assert_script_run("rm -rf $guest.redefine");
    }

    #Destroy existed br123 network interface
    virt_autotest::virtual_network_utils::destroy_standalone();

    #Restart libvirtd service
    virt_autotest::virtual_network_utils::restart_libvirtd();

    #Restart network service
    virt_autotest::virtual_network_utils::restart_network();

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
