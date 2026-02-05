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

    my $vbs_url = data_url("wsl/UpdateInstall.ps1");
    my $opensuse_url = data_url("wsl/openSUSE-UEFI-CA-Certificate.crt");
    my $suse_url = data_url("wsl/SLES-UEFI-CA-Certificate.crt");
    $self->open_powershell_as_admin;
    # download certificates
    $self->run_in_powershell(cmd => qq{Invoke-WebRequest -Uri "$opensuse_url" -OutFile "\$env:TEMP\\openSUSE-UEFI-CA-Certificate.crt"});
    $self->run_in_powershell(cmd => qq{Invoke-WebRequest -Uri "$suse_url" -OutFile "\$env:TEMP\\SLES-UEFI-CA-Certificate.crt"});
    # enable developer mode
    $self->run_in_powershell(cmd => 'New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name AllowDevelopmentWithoutDevLicense -PropertyType DWORD -Value 1');
    # install certificates
    $self->run_in_powershell(cmd => 'Import-Certificate -FilePath $env:TEMP\SLES-UEFI-CA-Certificate.crt -CertStoreLocation cert:\\LocalMachine\\Root -Verbose');
    $self->run_in_powershell(cmd => 'Import-Certificate -FilePath $env:TEMP\openSUSE-UEFI-CA-Certificate.crt -CertStoreLocation cert:\\LocalMachine\\Root -Verbose');
    # continue with update
    $self->run_in_powershell(cmd => qq{Invoke-WebRequest -Uri "$vbs_url" -OutFile "\$env:TEMP\\UpdateInstall.ps1"});
    $self->run_in_powershell(cmd => "Set-ExecutionPolicy Bypass -Scope CurrentUser -Force");
    $self->run_in_powershell(
        cmd => "cd \$env:TEMP; .\\UpdateInstall.ps1",
        code => sub {
            die("Update script finished unespectedly or timed out...")
              unless wait_serial('0', timeout => 3600);
        }
    );
    save_screenshot;

    # The script autoreboot fails, so there's need to reboot manually
    $self->reboot_or_shutdown(1);
    while (defined(check_screen('windows-updating', 60))) {
        bmwqemu::diag("Applying updates while shutting down the machine...");
    }
    $self->wait_boot_windows;

    # Shutdown
    $self->reboot_or_shutdown;
}

1;
