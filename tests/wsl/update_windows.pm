# SUSE's openQA tests
#
# Copyright 2012-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Update Windows base image
# Maintainer: qa-c <qa-c@suse.de>

use Mojo::Base qw(windowsbasetest);
use testapi qw(assert_and_click assert_screen check_screen match_has_tag type_string record_info);

sub run {
    my $self = shift;
    $self->open_powershell_as_admin;

    # There's need to disable the execution policy
    $self->run_in_powershell(
        cmd => 'Set-ExecutionPolicy -Force Unrestricted'
    );

    # Now the module PSWindowsUpdate will be installed and imported
    $self->run_in_powershell(
        cmd => 'Install-Module -Force PSWindowsUpdate',
        code => sub {
            check_screen('powershell-prompt', timeout => 30);
            type_string('Y', lf => 1) if (match_has_tag('powershell-prompt'));
        }
    );
    $self->run_in_powershell(
        cmd => 'Import-Module PSWindowsUpdate'
    );

    # The module now can be used to retrieve and install all the updates available
    $self->run_in_powershell(
        cmd => 'Get-WindowsUpdate'
    );
    assert_screen(['available-updates', 'no-available-updates'], timeout => 120);
    if (match_has_tag('available-updates')) {
        $self->run_in_powershell(
            cmd => 'Install-WindowsUpdate',
            code => sub {
                assert_screen('powershell-prompt');
                type_string('A', lf => 1);
                assert_screen(['updates-finished', 'reboot-required'], timeout => 1200);
                if (match_has_tag('reboot-required')) {
                    type_string('Y', lf => 1);
                    $self->wait_boot_windows;
                }
            }
        );
        record_info('System updated', 'All the updates were installed. Windows is up-to-date');
    } else {
        record_info('No updates found', 'No updates were found. Windows is up-to-date');
    }
    $self->reboot_or_shutdown();
}

1;
