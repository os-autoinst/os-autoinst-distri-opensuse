# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Utilities for running ESXi commands
# Maintainer: Nan Zhang <nan.zhang@suse.com>

package virt_autotest::esxi_utils;

use base Exporter;
use Exporter;

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use utils;

our @EXPORT = qw(
  esxi_vm_get_vmid
  esxi_vm_power_getstate
  esxi_vm_power_ops
  esxi_vm_network_binding
  esxi_vm_public_ip
  get_host_timestamp
  disable_vm_time_synchronization
);

sub esxi_vm_get_vmid {
    my $vm_name = shift;
    my $vim_cmd = "vim-cmd vmsvc/getallvms | grep -i $vm_name | awk -F' ' '{print \$1}'";
    my (undef, $vmid) = console('svirt')->run_cmd($vim_cmd, domain => 'sshVMwareServer', wantarray => 1);
    chomp($vmid);
    return $vmid;
}

sub esxi_vm_power_getstate {
    my $vmid = shift;
    my $vim_cmd = "vim-cmd vmsvc/power.getstate";
    my (undef, $power_state) = console('svirt')->run_cmd("$vim_cmd $vmid", domain => 'sshVMwareServer', wantarray => 1);
    return $power_state;
}

sub esxi_vm_power_ops {
    my ($vmid, $powerops) = @_;
    my $vim_cmd = "vim-cmd vmsvc/$powerops";
    return console('svirt')->run_cmd("$vim_cmd $vmid", domain => 'sshVMwareServer', wantarray => 1);
}

sub esxi_vm_network_binding {
    my $vmid = shift;
    my $vim_cmd = "vim-cmd vmsvc/get.environment $vmid | grep vswitch | sed -n 1p | cut -d'\"' -f2";
    my (undef, $vswitch) = console('svirt')->run_cmd($vim_cmd, domain => 'sshVMwareServer', wantarray => 1);
    return $vswitch;
}

sub esxi_vm_public_ip {
    my $vmid = shift;
    my $vim_cmd = "vim-cmd vmsvc/get.guest $vmid | grep ipAddress | sed -n 1p | cut -d'\"' -f2";
    my (undef, $vm_ip) = console('svirt')->run_cmd($vim_cmd, domain => 'sshVMwareServer', wantarray => 1);
    return $vm_ip;
}

sub get_host_timestamp {
    my $date_cmd = shift // "date -u +'\%F \%T'";    # Default to get UTC time
    my (undef, $host_time) = console('svirt')->run_cmd($date_cmd, domain => 'sshVMwareServer', wantarray => 1);
    return $host_time;
}

sub disable_vm_time_synchronization {
    my $vm_name = shift;
    my $vmx_file = "/vmfs/volumes/" . get_required_var('VMWARE_DATASTORE') . "/openQA/$vm_name.vmx";

    # Set all time synchronization properties to FALSE
    console('svirt')->run_cmd("sed -ie 's/tools.syncTime.*/tools.syncTime=\"FALSE\"/' $vmx_file", domain => 'sshVMwareServer', wantarray => 1);
    console('svirt')->run_cmd("echo time.synchronize.continue=\"FALSE\" >> $vmx_file", domain => 'sshVMwareServer', wantarray => 1);
    console('svirt')->run_cmd("echo time.synchronize.restore=\"FALSE\" >> $vmx_file", domain => 'sshVMwareServer', wantarray => 1);
    console('svirt')->run_cmd("echo time.synchronize.resume.disk=\"FALSE\" >> $vmx_file", domain => 'sshVMwareServer', wantarray => 1);
    console('svirt')->run_cmd("echo time.synchronize.shrink=\"FALSE\" >> $vmx_file", domain => 'sshVMwareServer', wantarray => 1);
    console('svirt')->run_cmd("echo time.synchronize.tools.startup=\"FALSE\" >> $vmx_file", domain => 'sshVMwareServer', wantarray => 1);
    console('svirt')->run_cmd("echo time.synchronize.resume.host=\"FALSE\" >> $vmx_file", domain => 'sshVMwareServer', wantarray => 1);
}

1;
