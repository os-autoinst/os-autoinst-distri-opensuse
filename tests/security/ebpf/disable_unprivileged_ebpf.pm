# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test 'Unprivileged eBPF usage has been disabled,
#          the setting can be changed by the `root` user':
#          '# Verify the eBPF should be disabled unprivileged eBPF by default'
#          '# Verify re-enable unprivileged eBPF temporarily using "systemctl"'
#          '# Verify re-enable unprivileged eBPF temporarily using status file'
#          '# Verify re-enable unprivileged eBPF persistently using config file'
# Maintainer: QE Security <none@suse.de>
# Tags: poo#103932, tc#1769831, poo#108302

use base 'opensusebasetest';
use power_action_utils "power_action";
use strict;
use warnings;
use testapi;
use utils;
use Utils::Backends 'is_pvm';

sub reboot_and_check {
    my ($self, $status) = @_;
    my $f_unpriv_bpf_disabled = '/proc/sys/kernel/unprivileged_bpf_disabled';

    # Reboot and verify the eBPF status
    power_action('reboot', textmode => 1);
    reconnect_mgmt_console if is_pvm;
    $self->wait_boot(textmode => 1, ready_time => 600, bootloader_time => 300);
    select_console 'root-console';
    validate_script_output("cat $f_unpriv_bpf_disabled", sub { m/$status/ });
}

sub privileged_bpf_check {
    my ($self) = @_;
    my $f_unpriv_bpf_disabled = '/proc/sys/kernel/unprivileged_bpf_disabled';

    # Verify the eBPF status: should be enabled privileged eBPF
    validate_script_output("cat $f_unpriv_bpf_disabled", sub { m/1/ });
    # The value of 'unprivileged_bpf_disabled' can not changed since it was set to 1
    script_run("echo -n 0 > $f_unpriv_bpf_disabled");
    validate_script_output("cat $f_unpriv_bpf_disabled", sub { m/1/ });
    script_run("echo -n 2 > $f_unpriv_bpf_disabled");
    validate_script_output("cat $f_unpriv_bpf_disabled", sub { m/1/ });
}

sub run {
    my ($self) = @_;
    my $f_unpriv_bpf_disabled = '/proc/sys/kernel/unprivileged_bpf_disabled';
    my $sysctl_conf = '/etc/sysctl.conf';

    select_console 'root-console';

    # Verify the eBPF status: OS should be disabled unprivileged eBPF by default
    validate_script_output("cat $f_unpriv_bpf_disabled", sub { m/2/ });

    # Re-enable unprivileged eBPF temporarily using 'sysctl'
    validate_script_output('sysctl kernel.unprivileged_bpf_disabled=0', sub { m/kernel.unprivileged_bpf_disabled = 0/ });
    # Verify the eBPF status: should be enabled unprivileged eBPF
    validate_script_output("cat $f_unpriv_bpf_disabled", sub { m/0/ });

    # Reboot, verify the eBPF status: should be disabled unprivileged eBPF again
    $self->reboot_and_check('2');

    # Re-enable unprivileged eBPF temporarily using "$f_unpriv_bpf_disabled"
    assert_script_run("echo -n 0 > $f_unpriv_bpf_disabled");
    # Verify the eBPF status: should be enabled unprivileged eBPF
    validate_script_output("cat $f_unpriv_bpf_disabled", sub { m/0/ });

    # Reboot, verify the eBPF status: should be disabled unprivileged eBPF again
    $self->reboot_and_check('2');

    # Set 'unprivileged_bpf_disabled' value to 1 by using 'sysctl'
    validate_script_output('sysctl kernel.unprivileged_bpf_disabled=1', sub { m/kernel.unprivileged_bpf_disabled = 1/ });
    $self->privileged_bpf_check;

    # Reboot, verify the eBPF status: should be disabled unprivileged eBPF again
    $self->reboot_and_check('2');

    # Set 'unprivileged_bpf_disabled' value to 1 by using "$f_unpriv_bpf_disabled"
    assert_script_run("echo -n 1 > $f_unpriv_bpf_disabled");
    $self->privileged_bpf_check;

    # Reboot, verify the eBPF status: should be disabled again
    $self->reboot_and_check('2');

    # Re-enable unprivileged eBPF persistently
    assert_script_run("echo 'kernel.unprivileged_bpf_disabled = 0' >> $sysctl_conf");
    # Verify the eBPF status: should be disabled unprivileged eBPF
    validate_script_output("cat $f_unpriv_bpf_disabled", sub { m/2/ });

    # Reboot, verify the eBPF status: should be enabled unprivileged eBPF
    $self->reboot_and_check('0');
}

sub test_flags {
    return {always_rollback => 1};
}

1;
