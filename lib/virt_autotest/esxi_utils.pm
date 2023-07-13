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
use Utils::Backends qw(is_qemu is_svirt);

our @EXPORT = qw(
  esxi_vm_get_vmid
  esxi_vm_power_getstate
  esxi_vm_power_ops
  esxi_vm_network_binding
  esxi_vm_public_ip
  get_host_timestamp
  disable_vm_time_synchronization
  revert_vm_timesync_setting
);

my $hypervisor = get_var('HYPERVISOR') // 'esxi7.qa.suse.cz';

sub esxi_vm_get_vmid {
    my $vm_name = shift;
    my $vim_cmd = "vim-cmd vmsvc/getallvms | grep -iw $vm_name | cut -d' ' -f1";
    my $vmid;

    if (is_svirt) {
        (undef, $vmid) = console('svirt')->run_cmd($vim_cmd, domain => 'sshVMwareServer', wantarray => 1);
    }
    elsif (is_qemu) {
        $vmid = script_output(qq(ssh -o StrictHostKeyChecking=no root\@$hypervisor "$vim_cmd"));
    }
    chomp($vmid);
    return $vmid;
}

sub esxi_vm_power_getstate {
    my $vmid = shift;
    my $vim_cmd = "vim-cmd vmsvc/power.getstate";
    my $power_state;

    if (is_svirt) {
        (undef, $power_state) = console('svirt')->run_cmd("$vim_cmd $vmid", domain => 'sshVMwareServer', wantarray => 1);
    }
    elsif (is_qemu) {
        $power_state = script_output(qq(ssh -o StrictHostKeyChecking=no root\@$hypervisor "$vim_cmd $vmid"));
    }
    return $power_state;
}

sub esxi_vm_power_ops {
    my ($vmid, $powerops) = @_;
    my $vim_cmd = "vim-cmd vmsvc/$powerops";

    if (is_svirt) {
        return console('svirt')->run_cmd("$vim_cmd $vmid", domain => 'sshVMwareServer', wantarray => 1);
    }
    elsif (is_qemu) {
        return script_run(qq(ssh -o StrictHostKeyChecking=no root\@$hypervisor "$vim_cmd $vmid"));
    }
}

sub esxi_vm_network_binding {
    my $vmid = shift;
    my $vim_cmd;
    my $vswitch;

    if (is_svirt) {
        $vim_cmd = qq(vim-cmd vmsvc/get.environment $vmid | grep vswitch | sed -n 1p | cut -d'\"' -f2);
        (undef, $vswitch) = console('svirt')->run_cmd($vim_cmd, domain => 'sshVMwareServer', wantarray => 1);
    }
    elsif (is_qemu) {
        $vim_cmd = qq(vim-cmd vmsvc/get.environment $vmid | grep vswitch | sed -n 1p | cut -d'\\"' -f2);
        $vswitch = script_output(qq(ssh -o StrictHostKeyChecking=no root\@$hypervisor "$vim_cmd"));
    }
    return $vswitch;
}

sub esxi_vm_public_ip {
    my $vmid = shift;
    my $vim_cmd;
    my $vm_ip;

    if (is_svirt) {
        $vim_cmd = qq(vim-cmd vmsvc/get.guest $vmid | grep ipAddress | sed -n 1p | cut -d'\"' -f2);
        (undef, $vm_ip) = console('svirt')->run_cmd($vim_cmd, domain => 'sshVMwareServer', wantarray => 1);
    }
    elsif (is_qemu) {
        $vim_cmd = qq(vim-cmd vmsvc/get.guest $vmid | grep ipAddress | sed -n 1p | cut -d'\\"' -f2);
        $vm_ip = script_output(qq(ssh -o StrictHostKeyChecking=no root\@$hypervisor "$vim_cmd"));
    }
    return $vm_ip;
}

sub get_host_timestamp {
    my $date_cmd = shift // "date -u +'\%F \%T'";    # Default to get UTC time
    my $host_time;

    if (is_svirt) {
        (undef, $host_time) = console('svirt')->run_cmd($date_cmd, domain => 'sshVMwareServer', wantarray => 1);
    }
    elsif (is_qemu) {
        $host_time = script_output(qq(ssh -o StrictHostKeyChecking=no root\@$hypervisor "$date_cmd"));
    }
    return $host_time;
}

1;
