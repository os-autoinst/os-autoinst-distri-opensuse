# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Boot Elemental3 OS image.
# Maintainer: unified-core@suse.com, ldevulder@suse.com

use base qw(opensusebasetest);
use testapi;
use lockapi;
use mm_network qw(configure_hostname setup_static_mm_network);
use serial_terminal qw(select_serial_terminal);

sub run {
    my ($self) = @_;

    # Set default root password
    $testapi::password = get_required_var('TEST_PASSWORD');

    # For raw OS image boot
    if (check_var('IMAGE_TYPE', 'disk')) {
        # Wait for GRUB and select default entry
        $self->wait_grub(bootloader_time => 300);
        send_key('ret', wait_screen_change => 1);
        wait_still_screen(timeout => 120);
        save_screenshot();
    }

    # For iso OS image boot: the OS needs to be installed first!
    if (check_var('IMAGE_TYPE', 'iso')) {
        # Wait for boot
        # Bypass Grub on aarch64 as it can take too long to match the first grub2 needle
        if (is_aarch64) {
            $self->wait_boot_past_bootloader(textmode => 1);
            sleep bmwqemu::scale_timeout(30);
        } else {
            $self->wait_boot(textmode => 1);
        }

        # OS installation is done automatically as well as the reboot after installation
        # We just have to wait for the VM to reboot

        # Select SUT for bootloader
        select_console('sut');

        # Wait for GRUB
        $self->wait_grub();

        # Choose entry to test
        # send_key_until_needlematch($state->{tag}, 'down');
        send_key('ret', wait_screen_change => 1);
        wait_still_screen(timeout => 120);
        save_screenshot();
    }

    # No GUI, easier and quicker to use the serial console
    select_serial_terminal();

    # Check the installed OS
    assert_script_run('cat /etc/os-release');

    # Record boot
    record_info('OS boot', 'Successfully booted!');
}

sub test_flags {
    return {fatal => 1, milestone => 0};
}

1;
