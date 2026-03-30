# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: Test '# setenforce/getenforce' commands work
#          # setenforce - modify the mode SELinux is running in
#          #   - usage:  setenforce [ Enforcing | Permissive | 1 | 0 ]
#          # getenforce - reports whether SELinux is enforcing, permissive, or disabled
# Maintainer: QE Security <none@suse.de>
# Tags: poo#105202, tc#1769801, poo#195890

use Mojo::Base 'opensusebasetest';
use power_action_utils 'power_action';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;
use Utils::Backends 'is_pvm';

sub set_and_verify_mode {
    my ($mode) = @_;
    record_info('SELinux Mode', "Switching to $mode");
    assert_script_run("setenforce $mode");
    validate_script_output('getenforce', sub { m/^$mode$/ });
}

sub reboot_and_check {
    my ($self, $expected_mode) = @_;
    record_info('Reboot', "Expecting mode after reboot: $expected_mode");
    power_action('reboot', textmode => 1);
    reconnect_mgmt_console if is_pvm;
    $self->wait_boot(textmode => 1, ready_time => 600, bootloader_time => 300);
    select_serial_terminal;
    validate_script_output('getenforce', sub { m/^$expected_mode$/ });
}

sub run {
    my ($self) = @_;
    select_serial_terminal;
    my $mode_original = script_output('getenforce');
    record_info('Initial mode', $mode_original);
    set_and_verify_mode('Permissive');
    reboot_and_check($self, $mode_original);
    set_and_verify_mode('Enforcing');
    reboot_and_check($self, $mode_original);
}

1;
