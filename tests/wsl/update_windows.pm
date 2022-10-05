# SUSE's openQA tests
#
# Copyright 2012-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Update Windows base image
# Maintainer: qa-c <qa-c@suse.de>

use Mojo::Base qw(windowsbasetest);
use testapi;

sub run {
    my $self = shift;

    $self->open_powershell_as_admin;

    # There's need to disable the execution policy
    $self->run_in_powershell(
        cmd => 'Set-ExecutionPolicy -Force Unrestricted'
    );

    # Now the module PSWindowsUpdate will be installed and imported
    $self->run_in_powershell(
        cmd => 'Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force'
    );
    $self->run_in_powershell(
        cmd => 'Install-Module -Name PSWindowsUpdate -Force'
    );
    $self->run_in_powershell(
        cmd => 'Import-Module PSWindowsUpdate'
    );

    # The module now can be used to retrieve and install all the updates available
    $self->run_in_powershell(cmd => '$output = Get-WindowsUpdate', timeout => 300);
    $self->run_in_powershell(cmd => '$port.WriteLine($output.KB)', code => sub { });
    if (wait_serial('.*KB.*', timeout => 60)) {
        $self->run_in_powershell(
            cmd => '$output = Install-WindowsUpdate -AcceptAll -Install -IgnoreReboot',
            timeout => 1200    # Would 20min be enough for Windows installing updates?
        );
        $self->run_in_powershell(cmd => '$port.WriteLine($output.Result)', code => sub { });
        if (wait_serial('.*Failed.*', timeout => 60, quiet => 1)) {
            force_soft_failure("Some of the updates have failed");
        } else {
            record_info "Updated", "System has been updated";
        }
        $self->reboot_or_shutdown(1);
        $self->wait_boot_windows();
    } else {
        record_info "No updates", "No updates available, system is updated";
    }

    $self->reboot_or_shutdown();
}

1;
