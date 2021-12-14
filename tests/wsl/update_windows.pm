# SUSE's openQA tests
#
# Copyright 2012-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Update Windows base image
# Maintainer: qa-c <qa-c@suse.de>

use Mojo::Base qw(windowsbasetest);
use testapi qw(assert_and_click assert_screen check_screen match_has_tag);

sub run {
    my $self = shift;
    $self->windows_run('control update');

    assert_screen 'windows-update';
    while (defined(check_screen('windows-updates-available', 60))) {
        bmwqemu::diag("Updating windows base image file...");
        sleep 30;
    }

    assert_screen([qw(windows-updates-required-restart windows-up-to-date)]);

    $self->windows_run('shutdown -s -t 0');
    while (defined(check_screen('windows-updating', 60))) {
        bmwqemu::diag("Applying updates while shutting down the machine...");
    }
}

1;
