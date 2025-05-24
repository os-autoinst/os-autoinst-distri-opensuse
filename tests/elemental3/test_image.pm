# Copyright 2023-2025 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Test installation and boot of Elemental ISO
# Maintainer: unified-core@suse.com, ldevulder@suse.com

use base 'opensusebasetest';
use strict;
use warnings;

use testapi;
use power_action_utils qw(power_action);
use serial_terminal qw(select_serial_terminal);
use Utils::Architectures;

sub run {
    my ($self) = @_;
    my $rootpwd = get_required_var('TEST_PASSWORD');
    $testapi::password = $rootpwd;    # Set default root password

    # For HDD image boot
    if (check_var('IMAGE_TYPE', 'disk')) {
        # Wait for GRUB and select default entry
        $self->wait_grub(bootloader_time => 300);
        send_key('ret', wait_screen_change => 1);
        wait_still_screen(timeout => 120);
        save_screenshot();
    }

    # No GUI, easier and quicker to use the serial console
    select_serial_terminal();

    # Record boot
    record_info('OS boot', 'Successfully booted!');

    # Check RKE2 status
    script_run('kubectl get pod -A');
    sleep(120);    # dirty but only for debugging purpose for now!
    my $rke2_status = script_output('kubectl get pod -A');

    # kubectl get pod -A 2>&1 | egrep -iv 'status.*restarts|running|completed'

    # Record RKE2 status
    record_info('RKE2 status', "$rke2_status");
}

sub test_flags {
    return {fatal => 1};
}

1;
