# Copyright 2025-2026 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Boot Elemental3 OS image.
# Maintainer: unified-core@suse.com, ldevulder@suse.com

use Mojo::Base 'opensusebasetest';
use testapi;
use lockapi;
use mm_network qw(configure_hostname setup_static_mm_network);
use power_action_utils qw(power_action);
use serial_terminal qw(select_serial_terminal);
use utils qw(script_retry validate_script_output_retry);

# Wait for a pattern on the serial0 output (kernel console ttyS0), and stop
# if emergency mode shows on the screen. This reads serial0 only while the
# current console is not a serial terminal (for example 'sut').
# The serial buffer is cleared at module start and a failed wait does not move
# the read offset, so output printed before the call is still found.
sub wait_serial_or_emergency {
    my ($regexp, $what, $deadline) = @_;
    while (1) {
        return if wait_serial($regexp, timeout => 10, quiet => 1);
        die "Emergency mode detected while waiting for $what" if check_screen([qw(emergency-mode emergency-shell)], 1);
        die "Timeout waiting for $what" if time > $deadline;
    }
}

# Wait until the installed OS is running. The installer root password is not
# TEST_PASSWORD, so a serial login on the installer fails with 'Login incorrect'.
# Wait for the installer to reboot and for the login prompt of the installed OS,
# then log in and check the tag file written by the customization script.
sub wait_os_installed {
    my $deadline = time + bmwqemu::scale_timeout(900);
    wait_serial_or_emergency(qr/reboot: Restarting system/, 'the installer to reboot', $deadline);
    wait_serial_or_emergency(qr/login:/, 'the installed OS login prompt', $deadline);

    select_serial_terminal();
    script_retry('test -f /run/os-installed.tag', retry => 30, delay => 10, fail_message => 'Tag /run/os-installed.tag not found');
}

sub run {
    my ($self) = @_;

    # Set default root password
    $testapi::password = get_required_var('TEST_PASSWORD');

    if (check_var('TESTED_CMD', 'extract_iso')) {
        # This ISO image does not install anything, it is just the basic container
        # that should be used with 'customize' command, validating the OS boot is enough
        $self->wait_boot_past_bootloader(ready_time => 120, textmode => 1, nologin => 1);
        wait_still_screen;
        record_info('ISO', 'ISO image booted!');
        return;
    } elsif (check_var('TESTED_CMD', 'install')) {
        # 'install' command directly installed the OS image previously without
        # the installer step
        $self->wait_boot(bootloader_time => bmwqemu::scale_timeout(300), textmode => 1, nologin => 1);
        wait_still_screen;
    } else {
        # Wait for OS installer boot
        assert_screen('grub-unifiedcore_installer', timeout => 120);
        wait_still_screen();

        # OS installation is done automatically as well as the reboot after installation.
        # The installer and the installed OS show the same login screen, so the screen
        # cannot tell them apart: wait for the installed OS tag instead
        wait_os_installed();
    }

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
    # NOTE: a lot of things are done through systemd at firstboot,
    #       so this is why we have to wait quite a long time.
    validate_script_output_retry(
        'systemctl is-system-running',
        sub { m/running/ },
        retry => 15,
        delay => 60,
        die => 1,
        fail_message => 'systemd not in running state!'
    ) unless (get_var('PARALLEL_WITH', ''));

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
        assert_screen('text-logged-in-root', timeout => 120);
        wait_still_screen();

        # In recovery mode we have auto-login configured on tty1, so we are
        # already at the root shell prompt on the active SUT console
        # Check for recovery boot option
        assert_script_run('grep -q recovery /proc/cmdline');
        record_info('RECOVERY', 'Booted in recovery mode!');
    }
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
