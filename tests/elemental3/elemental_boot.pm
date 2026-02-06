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

    # Wait for OS installer boot
    assert_screen('grub-unifiedcore_installer', timeout => 120);
    wait_still_screen;

    # OS installation is done automatically as well as the reboot after installation
    # We just have to wait for the VM to reboot
    $self->wait_grub(bootloader_time => bmwqemu::scale_timeout(300));

    # OS deployment done
    record_info('OS deployment', 'Successfully installed!');

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
