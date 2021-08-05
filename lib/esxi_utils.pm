# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Utilities for running ESXi commands
# Maintainer: Nan Zhang <nan.zhang@suse.com>

package esxi_utils;

use base 'opensusebasetest';

use strict;
use warnings;

sub esxi_vm_get_vmid {
    my ($self, $esxi_host, $login_user, $login_passwd, $guest_name) = @_;
    my $vim_cmd = "vim-cmd vmsvc/getallvms";
    return script_output("sshpass -p $login_passwd ssh -l $login_user $esxi_host $vim_cmd | grep -i $guest_name | awk -F' ' '{print $2}'");
}

sub esxi_vm_power_getstate {
    my ($self, $esxi_host, $login_user, $login_passwd, $guest_name) = @_;
    my $vmid = $self->esxi_vm_get_vmid($esxi_host, $login_user, $login_passwd, $guest_name);
    my $vim_cmd = "vim-cmd vmsvc/power.getstate";
    return script_output("sshpass -p $login_passwd ssh -l $login_user $esxi_host $vim_cmd $vmid");
}

sub esxi_vm_power_off {
    my ($self, $esxi_host, $login_user, $login_passwd, $guest_name) = @_;
    my $vmid = $self->esxi_vm_get_vmid($esxi_host, $login_user, $login_passwd, $guest_name);
    my $vim_cmd = "vim-cmd vmsvc/power.off";
    assert_script_run("sshpass -p $login_passwd ssh -l $login_user $esxi_host $vim_cmd $vmid");
}

sub esxi_vm_power_on {
    my ($self, $esxi_host, $login_user, $login_passwd, $guest_name) = @_;
    my $vmid = $self->esxi_vm_get_vmid($esxi_host, $login_user, $login_passwd, $guest_name);
    my $vim_cmd = "vim-cmd vmsvc/power.on";
    assert_script_run("sshpass -p $login_passwd ssh -l $login_user $esxi_host $vim_cmd $vmid");
}

sub esxi_vm_power_reboot {
    my ($self, $esxi_host, $login_user, $login_passwd, $guest_name) = @_;
    my $vmid = $self->esxi_vm_get_vmid($esxi_host, $login_user, $login_passwd, $guest_name);
    my $vim_cmd = "vim-cmd vmsvc/power.reboot";
    assert_script_run("sshpass -p $login_passwd ssh -l $login_user $esxi_host $vim_cmd $vmid");
}

sub esxi_vm_power_reset {
    my ($self, $esxi_host, $login_user, $login_passwd, $guest_name) = @_;
    my $vmid = $self->esxi_vm_get_vmid($esxi_host, $login_user, $login_passwd, $guest_name);
    my $vim_cmd = "vim-cmd vmsvc/power.reset";
    assert_script_run("sshpass -p $login_passwd ssh -l $login_user $esxi_host $vim_cmd $vmid");
}

sub esxi_vm_power_shutdown {
    my ($self, $esxi_host, $login_user, $login_passwd, $guest_name) = @_;
    my $vmid = $self->esxi_vm_get_vmid($esxi_host, $login_user, $login_passwd, $guest_name);
    my $vim_cmd = "vim-cmd vmsvc/power.shutdown";
    assert_script_run("sshpass -p $login_passwd ssh -l $login_user $esxi_host $vim_cmd $vmid");
}

sub esxi_vm_network_binding {
    my ($self, $esxi_host, $login_user, $login_passwd, $guest_name) = @_;
    my $vim_cmd = "vim-cmd vmsvc/getallvms | grep -i $guest_name | cut -d ' ' -f 1 | xargs vim-cmd vmsvc/get.environment | grep vswitch | sed -n 1p | cut -d '\"' -f 2";
    return script_output("sshpass -p $login_passwd ssh -l $login_user $esxi_host $vim_cmd");
}

sub esxi_vm_public_ip {
    my ($self, $esxi_host, $login_user, $login_passwd, $guest_name) = @_;
    my $vim_cmd = "vim-cmd vmsvc/getallvms | grep -i $guest_name | cut -d ' ' -f 1 | xargs vim-cmd vmsvc/get.guest | grep ipAddress | sed -n 1p | cut -d '\"' -f 2";
    return script_output("sshpass -p $login_passwd ssh -l $login_user $esxi_host $vim_cmd");
}

sub get_host_timestamp {
    my ($self, $esxi_host, $login_user, $login_passwd) = @_;
    return script_output("sshpass -p $login_passwd ssh -l $login_user $esxi_host date -u +'\%Y-\%m-\%d \%H:\%M:\%S'");
}

sub disable_all_clock_synchronization {
    my ($self, $esxi_host, $login_user, $login_passwd, $guest_name) = @_;
    my $vmx_file = "/vmfs/volumes/datastore1/$guest_name/$guest_name.vmx";

    # Set all time synchronization properties to FALSE
    assert_script_run("sshpass -p $login_passwd ssh -l $login_user $esxi_host sed -ie 's/tools.syncTime.*/tools.syncTime=\"FALSE\"/' $vmx_file");
    assert_script_run("sshpass -p $login_passwd ssh -l $login_user $esxi_host echo time.synchronize.continue=\"FALSE\" >> $vmx_file");
    assert_script_run("sshpass -p $login_passwd ssh -l $login_user $esxi_host echo time.synchronize.restore=\"FALSE\" >> $vmx_file");
    assert_script_run("sshpass -p $login_passwd ssh -l $login_user $esxi_host echo time.synchronize.resume.disk=\"FALSE\" >> $vmx_file");
    assert_script_run("sshpass -p $login_passwd ssh -l $login_user $esxi_host echo time.synchronize.shrink=\"FALSE\" >> $vmx_file");
    assert_script_run("sshpass -p $login_passwd ssh -l $login_user $esxi_host echo time.synchronize.tools.startup=\"FALSE\" >> $vmx_file");
    assert_script_run("sshpass -p $login_passwd ssh -l $login_user $esxi_host echo time.synchronize.resume.host=\"FALSE\" >> $vmx_file");
}

1;
