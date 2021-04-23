# VIRTUAL MACHINE UEFI FEATURES VERIFICATION MODULE
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.
#
# Summary: This module tests virtual machine with UEFI/Secureboot by
# using efibootmgr -v and mokutil --sb-state.And also performs power
# management operations,including suspend to memory,disk and hybrid
# on each virtual machine.
#
# Maintainer: Wayne Chen <wchen@suse.com>
package uefi_guest_verification;

use base 'virt_feature_test_base';
use strict;
use warnings;
use POSIX 'strftime';
use File::Basename;
use testapi;
use IPC::Run;
use utils;
use virt_utils;
use virt_autotest::common;
use virt_autotest::utils;

sub run_test {
    my $self = shift;

    $self->check_guest_bootloader($_)  foreach (keys %virt_autotest::common::guests);
    $self->check_guest_bootcurrent($_) foreach (keys %virt_autotest::common::guests);
    if (is_kvm_host) {
        record_soft_failure("In order to implement pm features, current kvm virtual machine uses uefi firmware that does not support PXE/HTTP boot and secureboot. bsc#1182886 UEFI virtual machine boots with trouble");
        #$self->check_guest_uefi_boot($_) foreach (keys %virt_autotest::common::guests);
        #$self->check_guest_secure_boot($_) foreach (keys %virt_autotest::common::guests);
    }
    else {
        record_soft_failure("UEFI implementation for xen fullvirt uefi virtual machine is incomplete. bsc#1184936 Xen fullvirt lacks of complete support for UEFI");
    }
    $self->check_guest_pmsuspend_enabled;
    return $self;
}

sub check_guest_bootloader {
    my ($self, $guest_name) = @_;

    my $ssh_command_prefix = "ssh -vvv -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no";
    script_retry("$ssh_command_prefix root\@$guest_name efibootmgr -v");
    script_retry("$ssh_command_prefix root\@$guest_name mokutil --sb-state");
    return $self;
}

sub check_guest_bootcurrent {
    my ($self, $guest_name) = @_;

    my $ssh_command_prefix = "ssh -vvv -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no";
    my $current_boot_entry = script_output("$ssh_command_prefix root\@$guest_name efibootmgr -v | grep -i BootCurrent | grep -oE [[:digit:]]+");
    assert_script_run("$ssh_command_prefix root\@$guest_name efibootmgr -v | grep -i \"BootOrder: $current_boot_entry\"");
    assert_script_run("$ssh_command_prefix root\@$guest_name efibootmgr -v | grep -i Boot$current_boot_entry.*sles") if (script_output("$ssh_command_prefix root\@$guest_name cat /etc/issue | grep -io \"SUSE Linux Enterprise Server.*\"", proceed_on_failure => 1) ne '');
    return $self;
}

sub check_guest_uefi_boot {
    my ($self, $guest_name) = @_;

    my $ssh_command_prefix = "timeout 30 ssh -vvv -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no";
    assert_script_run("$ssh_command_prefix root\@$guest_name efibootmgr -v | grep -iE \"uefi.*pxev6\"");
    assert_script_run("$ssh_command_prefix root\@$guest_name efibootmgr -v | grep -iE \"uefi.*HTTPv6\"");
    return $self;
}

sub check_guest_secure_boot {
    my ($self, $guest_name) = @_;

    my $ssh_command_prefix = "timeout 30 ssh -vvv -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no";
    assert_script_run("$ssh_command_prefix root\@$guest_name mokutil --sb-state | grep -iE \"secureboot.*enabled\"");
    return $self;
}

sub check_guest_pmsuspend_enabled {
    my $self = shift;

    $self->do_guest_pmsuspend($_, 'mem') foreach (keys %virt_autotest::common::guests);
    if (is_kvm_host) {
        $self->do_guest_pmsuspend($_, 'hybrid') foreach (keys %virt_autotest::common::guests);
        $self->do_guest_pmsuspend($_, 'disk')   foreach (keys %virt_autotest::common::guests);
    }
    else {
        record_soft_failure("UEFI implementation for xen fullvirt uefi virtual machine is incomplete. bsc#1184936 Xen fullvirt lacks of complete support for UEFI");
    }
    return $self;
}

sub do_guest_pmsuspend {
    my ($self, $suspend_domain, $suspend_target, $suspend_duration) = @_;
    carp("Guest domain name must be given before performing dompmsuspend.") if (!(defined $suspend_domain) or ($suspend_domain eq ''));
    $suspend_target   //= 'mem';
    $suspend_duration //= 0;

    my $guest_state_after_suspend = 'pmsuspended';
    $guest_state_after_suspend = 'shut off' if ($suspend_target eq 'disk');
    assert_script_run("virsh dompmsuspend --domain $suspend_domain --target $suspend_target");
    script_retry("virsh list --all  | grep -i $suspend_domain | grep -i \"$guest_state_after_suspend\"", delay => 10, retry => 5);
    if ($suspend_target eq 'disk') {
        assert_script_run("virsh start --domain $suspend_domain");
    }
    else {
        assert_script_run("virsh dompmwakeup --domain $suspend_domain");
    }
    assert_script_run("virsh list --all  | grep -i $suspend_domain | grep -i running");
    script_retry("ssh -vvv -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root\@$_ efibootmgr -v", delay => 60, retry => 3);
    return $self;
}

sub post_fail_hook {
    my $self = shift;

    $self->SUPER::post_fail_hook;
    return $self;
}

1;

