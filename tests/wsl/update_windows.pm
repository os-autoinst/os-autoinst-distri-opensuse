# SUSE's openQA tests
#
# Copyright 2012-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Update Windows base image
# Maintainer: qa-c <qa-c@suse.de>

use Mojo::Base qw(windowsbasetest);
use testapi qw(assert_and_click assert_screen check_screen match_has_tag click_lastmatch);

sub run {
    my $self = shift;
    $self->windows_run('control update');

    assert_screen 'windows-update', timeout => 30;
    # Sometimes there's need to press the "Check for updates" button manually
    click_lastmatch if (check_screen 'windows-no-updates-available');
    while (defined(check_screen(['windows-updates-available', 'windows-checking-updates'], 60))) {
        # Windows 11 sometimes fails some update and there's need to push a
        # button to install the rest
        click_lastmatch if (check_screen 'windows11-updates-available-to-install');
        bmwqemu::diag("Updating windows base image file...");
        sleep 60;
    }

    assert_screen([qw(windows-updates-required-restart windows-up-to-date)]);

    # A reboot for finishing updating...
    $self->reboot_or_shutdown(1);
    while (defined(check_screen('windows-updating', 60))) {
        bmwqemu::diag("Applying updates while shutting down the machine...");
    }
    $self->wait_boot_windows;

    # Shutdown
    $self->reboot_or_shutdown;
}

1;
