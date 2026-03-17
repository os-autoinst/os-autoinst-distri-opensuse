# Copyright 2025-2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Boot Elemental3 OS image.
# Maintainer: unified-core@suse.com, ldevulder@suse.com

use base qw(opensusebasetest);
use testapi;
use lockapi;
use mm_network qw(configure_hostname setup_static_mm_network);
use serial_terminal qw(select_serial_terminal);
use power_action_utils qw(power_action);

sub run {
    my ($self) = @_;

    # Set default root password
    $testapi::password = get_required_var('TEST_PASSWORD');

    # 'install' command directly install the OS image without the installer step
    unless (check_var('TESTED_CMD', 'install')) {
        # Wait for OS installer boot
        assert_screen('grub-unifiedcore_installer', timeout => 120);
        wait_still_screen;
    }

    # OS installation is done automatically as well as the reboot after installation
    # We just have to wait for the VM to reboot
    $self->wait_grub(bootloader_time => bmwqemu::scale_timeout(300));

    # No GUI, easier and quicker to use the serial console
    select_serial_terminal();

    # OS deployment done
    record_info('OS deployment', 'Successfully installed!');

    # Check the installed OS
    assert_script_run('cat /etc/os-release');

    # Record boot
    my $cmdline = script_output('cat /proc/cmdline');
    record_info('OS boot', "Successfully booted! /proc/cmdline='$cmdline'");

    # Test if FIPS is activated
    if (check_var('CRYPTO_POLICY', 'fips')) {
        assert_script_run('dmesg | grep -iq "fips mode: enabled"');
        assert_script_run('grep -iq "fips=1" /proc/cmdline');
        record_info('FIPS', 'FIPS mode enabled!');
    }

    # Wait for system to be in running state
    unless (get_var('PARALLEL_WITH')) {
        my $sys_state = script_output('systemctl is-system-running --wait', timeout => 240, proceed_on_failure => 1);
        die("Wrong OS state: $sys_state") unless ($sys_state =~ m/running/);
    }

    # Test reboot in recovery mode
    if (check_var('TESTED_CMD', 'customize_recovery')) {
        power_action('reboot', keepconsole => 1, textmode => 1);

        # Select SUT for bootloader
        select_console('sut');

        # Wait for GRUB
        $self->wait_grub();

        # Choose entry to test
        send_key_until_needlematch('elemental3-bootmenu-recovery', 'down');
        send_key('ret', wait_screen_change => 1);
        wait_still_screen(timeout => 120);

        # In recovery mode we have auto-login configured on tty1
        console('root-console')->set_tty(1);
        select_console('root-console');

        # Check for recovery boot option
        assert_script_run('grep -q recovery /proc/cmdline');
        record_info('RECOVERY', 'Booted in recovery mode!');
    }
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
