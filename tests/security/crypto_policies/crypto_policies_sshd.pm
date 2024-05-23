# Copyright 2024 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Switch crypto-policies, reboot and verify sshd is running
# Maintainer: QE Security <none@suse.de>

use base 'opensusebasetest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use power_action_utils 'power_action';
use Utils::Backends 'is_pvm';
use Utils::Architectures;

sub run {
    my ($self) = @_;
    select_serial_terminal;
    systemctl 'enable --now sshd.service';
    for my $policy ('LEGACY', 'BSI', 'FUTURE', 'DEFAULT') {
        $self->set_policy($policy);
        # check the service is running after policy change
        validate_script_output 'systemctl status sshd.service', sub { m/active \(running\)/ };
    }
}

sub set_policy {
    my ($self, $policy) = @_;
    assert_script_run "update-crypto-policies --set $policy";
    power_action('reboot', textmode => 1);
    reconnect_mgmt_console if is_pvm();
    $self->wait_boot(textmode => 1, ready_time => 600, bootloader_time => 300);
    select_serial_terminal;
    # ensure the current policy has been applied
    validate_script_output 'update-crypto-policies --show', sub { m/$policy/ };
}

sub test_flags {
    return {milestone => 1, fatal => 1};
}

1;
