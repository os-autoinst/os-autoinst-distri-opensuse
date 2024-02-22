# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: perl-Bootloader
# Summary: Basic functional test for pbl package
# Maintainer: QE Core <qe-core@suse.de>

use base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use strict;
use warnings;
use utils 'zypper_call';
use power_action_utils 'power_action';
use version_utils qw(is_tumbleweed is_sle check_version);

sub run {
    my ($self) = @_;
    select_serial_terminal;

    if (script_run 'rpm -q perl-Bootloader') {
        zypper_call 'in perl-Bootloader';
    }

    # version older than 1.1 does not support option default-settings
    my $pbl_version = script_output("rpm -q --qf '%{version}' perl-Bootloader");
    my $new_pbl = check_version('>=1.1', $pbl_version);

    # pbl --loader is not available on <15-SP3
    unless (is_sle("<15-SP3")) {
        if (get_var('UEFI')) {
            assert_script_run 'pbl --loader grub2-efi';
            validate_script_output 'cat /etc/sysconfig/bootloader', qr/LOADER_TYPE="grub2-efi"/;
        }
        else {
            assert_script_run 'pbl --loader grub2';
            validate_script_output 'cat /etc/sysconfig/bootloader', qr/LOADER_TYPE="grub2"/;
        }
    }
    assert_script_run 'pbl --install';
    assert_script_run 'pbl --config';
    power_action('reboot', textmode => 1);
    $self->wait_boot;
    select_serial_terminal;

    # Add new option and check if it exists
    assert_script_run 'pbl --add-option TEST_OPTION="test_value"';
    validate_script_output 'cat /etc/default/grub', qr/test_value/;

    # Delete option and check if it was deleted
    assert_script_run 'pbl --del-option "TEST_OPTION"';
    assert_script_run('! grep -q "TEST_OPTION" /etc/default/grub');

    # Add new option and check if it's logged in new log file
    assert_script_run 'pbl --log /var/log/pbl-test.log --add-option LOG_OPTION="log_value"';
    validate_script_output 'cat /var/log/pbl-test.log', qr/log_value/;

    if ($new_pbl) {
        validate_script_output 'pbl --default-settings', qr/kernel|initrd|append/;
    }
    power_action('reboot', textmode => 1);
    $self->wait_boot;

}

sub post_fail_hook {
    my ($self) = @_;
    $self->SUPER::post_fail_hook;
    upload_logs('/var/log/pbl.log');
}

1;
