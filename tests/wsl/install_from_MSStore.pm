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
    my $winget_url = "https://github.com/microsoft/winget-cli/releases/download/$winget_version/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle";
    my $WSL_version = get_required_var "WSL_VERSION";
    assert_screen 'windows-desktop';
    $self->open_powershell_as_admin;
    # Enable Windows features WSL and VM platform
    $self->run_in_powershell(
        cmd => 'New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name AllowDevelopmentWithoutDevLicense -PropertyType DWORD -Value 1'
    );
    $self->run_in_powershell(
        cmd => "Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart",
        timeout => 300
    );
    $self->run_in_powershell(
        cmd => "Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart",
        timeout => 300
    );
    $self->run_in_powershell(
        cmd => 'Disable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-Hypervisor -NoRestart'
    ) if (get_var('WSL2'));

    # Reboot and wait for it
    $self->reboot_or_shutdown(1);
    $self->wait_boot_windows;
    $self->open_powershell_as_admin;

    if (get_var('WSL2')) {
        $self->install_wsl2_kernel;
    }
    else {
        $self->run_in_powershell(
            cmd => "wsl --set-default-version 1"
        ) if (check_var("WIN_VERSION", "11"));
    }


    # Download 'winget v1.3.1251-preview' for installing packages from the MS Store
    # with no need for credentials.
    $self->run_in_powershell(
        cmd => "Invoke-WebRequest -Uri \"$winget_url\" -OutFile \"C:\\winget.msixbundle\"",
        timeout => 300
    );
    # Install 'winget v1.3.1251-preview'
    $self->run_in_powershell(
        cmd => 'ii C:\\winget.msixbundle',
        code => sub {
            send_key 'alt-tab' if (check_var("WIN_VERSION", "11"));
            assert_screen [('install-winget-wsl', 'install-winget-background-wsl')];
            assert_and_click 'install-winget-background-wsl' if (match_has_tag('install-winget-background-wsl'));
            assert_and_click 'install-winget-wsl';
            # Winget installation sometimes gets stuck at 16% for a long time
            assert_screen 'install-winget-wsl-finish', timeout => 720;
            assert_screen(['background-winget-install', 'foreground-winget-install']);
            if (match_has_tag 'foreground-winget-install') {
                assert_and_click 'foreground-winget-install';
            } else {
                assert_and_click 'background-winget-install';
            }
            assert_and_click 'close-winget-install';
            send_key 'alt-tab';
        }
    );

    # Install required SUSE distro from the MS Store
    $self->run_in_powershell(
        cmd => 'winget install --source msstore --accept-package-agreements --accept-source-agreements "' . $WSL_version . '"',
        code => sub {
            assert_screen 'install-SUSE-WSL-finish', timeout => 720;
        }
    );

    # Reboot WSL to prevent error 0x80370109 that happens sometimes
    $self->run_in_powershell(
        cmd => 'wsl --shutdown',
    );

    record_info 'Port close', 'Closing serial port...';
    $self->run_in_powershell(
        cmd => q{$port.close()},
        code => sub { }
    );

    $self->use_search_feature(get_var('WSL_VERSION'));
    assert_and_click 'SUSE-wsl-search';
}

1;
