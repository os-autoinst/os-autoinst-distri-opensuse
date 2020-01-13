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

# Summary: virtual_network_utils:
#          This file provides fundamental utilities for virtual network.
# Maintainer: Leon Guo <xguo@suse.com>

package virt_autotest::virtual_network_utils;

use base Exporter;
use Exporter;

use utils;
use strict;
use warnings;
use File::Basename;
use testapi;
use Data::Dumper;
use XML::Writer;
use IO::File;
use proxymode;
use version_utils 'is_sle';
use virt_autotest_base;
use virt_utils;

our @EXPORT
  = qw(download_network_cfg prepare_network restore_standalone destroy_standalone restart_libvirtd restart_network restore_guests restore_network destroy_vir_network restore_libvirt_default enable_libvirt_log ssh_setup upload_debug_log check_guest_status);

sub download_network_cfg {
    #Download required libvird virtual network configuration file
    my $vnet_cfg_name       = shift;
    my $wait_script         = "180";
    my $vnet_cfg_url        = data_url("virt_autotest/$vnet_cfg_name");
    my $download_cfg_script = "curl -s -o ~/$vnet_cfg_name $vnet_cfg_url";
    script_output($download_cfg_script, $wait_script, type_command => 0, proceed_on_failure => 0);
}

sub prepare_network {
    #Confirm the host bridge configuration file
    my $virt_host_bridge = shift;
    my $config_path      = "/etc/sysconfig/network/ifcfg-$virt_host_bridge";
    if (script_run("[[ -f $config_path ]]") != 0) {
        assert_script_run("ip link add name $virt_host_bridge type bridge");
        assert_script_run("ip link set dev $virt_host_bridge up");
        my $wait_script          = "180";
        my $bash_script_name     = "vm_host_bridge_init.sh";
        my $bash_script_url      = data_url("virt_autotest/$bash_script_name");
        my $download_bash_script = "curl -s -o ~/$bash_script_name $bash_script_url";
        script_output($download_bash_script, $wait_script, type_command => 0, proceed_on_failure => 0);
        my $execute_bash_script = "chmod +x ~/$bash_script_name && ~/$bash_script_name $virt_host_bridge";
        script_output($execute_bash_script, $wait_script, type_command => 0, proceed_on_failure => 0);
    }
}

sub restore_network {
    my $virt_host_bridge = shift;
    my $network_mark     = "/etc/sysconfig/network/ifcfg-$virt_host_bridge.new";
    if (script_run("[[ -f $network_mark ]]") == 0) {
        assert_script_run("ip link set dev $virt_host_bridge down",       60);
        assert_script_run("ip link delete $virt_host_bridge type bridge", 60);
        my $wait_script          = "180";
        my $bash_script_name     = "vm_host_bridge_final.sh";
        my $bash_script_url      = data_url("virt_autotest/$bash_script_name");
        my $download_bash_script = "curl -s -o ~/$bash_script_name $bash_script_url";
        script_output($download_bash_script, $wait_script, type_command => 0, proceed_on_failure => 0);
        my $execute_bash_script = "chmod +x ~/$bash_script_name && ~/$bash_script_name $virt_host_bridge";
        script_output($execute_bash_script, $wait_script, type_command => 0, proceed_on_failure => 0);
    }
}

sub restore_standalone {
    #File standalone was installed from qa_test_virtualization package
    my $standalone_path = "/usr/share/qa/qa_test_virtualization/shared/standalone";
    assert_script_run("source $standalone_path", 60) if (script_run("[[ -f $standalone_path ]]") == 0);
}

sub destroy_standalone {
    #File cleanup was installed from qa_test_virtualization package
    my $cleanup_path = "/usr/share/qa/qa_test_virtualization/cleanup";
    assert_script_run("source $cleanup_path", 60) if (script_run("[[ -f $cleanup_path ]]") == 0);
}

sub restart_libvirtd {
    is_sle('>11') ? systemctl 'restart libvirtd' : script_run("service libvirtd restart");
}

sub restart_network {
    is_sle('>11') ? systemctl 'restart network' : script_run("service network restart");
}

sub restore_guests {
    my $get_vm_hostnames   = "virsh list  --all | grep sles | awk \'{print \$2}\'";
    my $vm_hostnames       = script_output($get_vm_hostnames, 30, type_command => 0, proceed_on_failure => 0);
    my @vm_hostnames_array = split(/\n+/, $vm_hostnames);
    foreach (@vm_hostnames_array)
    {
        script_run("virsh destroy $_");
        script_run("virsh undefine $_");
        script_run("virsh define /tmp/$_.xml");
        script_run("rm -rf /tmp/$_.xml");
    }
}

sub destroy_vir_network {
    #Get the created virtual network name
    my $get_vnet_name   = "virsh net-list --all| grep vnet | head -1 | awk \'{print \$1}\'";
    my $vnet_name       = script_output($get_vnet_name, 30, type_command => 0, proceed_on_failure => 0);
    my @vnet_name_array = split(/\n+/, $vnet_name);
    foreach (@vnet_name_array) { script_run("virsh net-destroy $_"); }
}

sub restore_libvirt_default {
    my $default_path = "/root/libvirt_default.xml";
    if (script_run("[[ -f $default_path ]]") == 0) {
        assert_script_run("virsh net-define $default_path", 60);
        assert_script_run("rm -rf $default_path");
    }
}

sub enable_libvirt_log {
    assert_script_run qq(echo 'log_level = 1
    log_filters="3:remote 4:event 3:json 3:rpc"
    log_outputs="1:file:/var/log/libvirt/libvirtd.log"' >> /etc/libvirt/libvirtd.conf);
    is_sle('>11') ? systemctl 'restart libvirtd' : script_run("service libvirtd restart");
}

sub ssh_setup {
    # Remove existing SSH public keys and create new one
    script_run("rm -f ~/.ssh/id_*; ssh-keygen -t rsa -f ~/.ssh/id_rsa -P ''", 0);
}

sub upload_debug_log {
    script_run("dmesg > /tmp/dmesg.log");
    virt_autotest_base::upload_virt_logs("/tmp/dmesg.log /var/log/libvirt /var/log/messages", "libvirt-virtual-network-debug-logs");
    if (get_var("XEN") || check_var("HOST_HYPERVISOR", "xen")) {
        script_run("xl dmesg > /tmp/xl-dmesg.log");
        virt_autotest_base::upload_virt_logs("/tmp/dmesg.log /var/log/libvirt /var/log/messages /var/log/xen /var/lib/xen/dump /tmp/xl-dmesg.log", "libvirt-virtual-network-debug-logs");
    }
    virt_utils::upload_supportconfig_log;
}

sub check_guest_status {
    my $wait_script        = "30";
    my $vm_types           = "sles";
    my $get_vm_hostnames   = "virsh list  --all | grep $vm_types | awk \'{print \$2}\'";
    my $vm_hostnames       = script_output($get_vm_hostnames, $wait_script, type_command => 0, proceed_on_failure => 0);
    my @vm_hostnames_array = split(/\n+/, $vm_hostnames);
    foreach (@vm_hostnames_array) {
        if (script_run("virsh list --all | grep $_ | grep shut") != 0) { script_run "virsh destroy $_", 90;
            #Wait for forceful shutdown of active guests
            sleep 20;
        }
    }

}

1;
