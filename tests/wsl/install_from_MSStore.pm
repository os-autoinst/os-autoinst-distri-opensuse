# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Install SUSE or openSUSE WSL images from the MS Store directly
# Maintainer: qa-c  <qa-c@suse.de>

use Mojo::Base "windowsbasetest";
use testapi;
use version_utils "is_sle";

sub run {
    my ($self) = @_;
    my $winget_version = 'v.1.3.1611';
    my $winget_url = 'https://github.com/microsoft/winget-cli/releases/download/' . $winget_version . '/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle';
    my $WSL_version = get_required_var "VERSION";
    assert_screen 'windows-desktop';
    $self->open_powershell_as_admin;
    # Enable Windows features WSL and VM platform
    $self->run_in_powershell(
        cmd => "Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart",
        timeout => 300
    );
    $self->run_in_powershell(
        cmd => "Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart",
        timeout => 300
    );

    # Reboot and wait for it
    $self->reboot_or_shutdown(1);
    $self->wait_boot_windows;
    $self->open_powershell_as_admin;

    # $self->install_wsl2_kernel;

    # Download 'winget v1.3.1251-preview' for installing packages from the MS Store
    # with no need for credentials.
    $self->run_in_powershell(
        cmd => "Invoke-WebRequest -Uri '" . $winget_url . "' -OutFile 'C:\\winget.msixbundle'",
        timeout => 300
    );
    # Install 'winget v1.3.1251-preview'
    $self->run_in_powershell(
        cmd => 'ii C:\\winget.msixbundle',
        code => sub {
            assert_and_click 'install-winget-wsl';
            assert_screen 'install-winget-wsl-finish', timeout => 600;
            assert_and_click 'foreground-winget-install';
            assert_and_click 'close-winget-install';
            send_key 'alt-tab';
        }
    );

    # Install required SUSE distro from the MS Store
    $self->run_in_powershell(
        cmd => 'winget install --accept-package-agreements --accept-source-agreements "' . $WSL_version . '"',
        code => sub {
            assert_and_click 'install-SUSE-WSL-finish', timeout => 600;
        }
    );

    record_info 'Port close', 'Closing serial port...';
    $self->run_in_powershell(
        cmd => q{$port.close()},
        code => sub { }
    );

    assert_and_click 'foreground-SUSE-WSL';
}

1;
