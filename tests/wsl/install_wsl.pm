# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Install SUSE or openSUSE WSL images from the MS Store directly
# Maintainer: qa-c  <qa-c@suse.de>

use Mojo::Base "windowsbasetest";
use testapi;
use version_utils;
use Utils::Architectures 'is_aarch64';

sub install_certificates {
    my ($self) = @_;
    my $certs = {
        opensuse => 'wsl/openSUSE-UEFI-CA-Certificate.crt',
        sle => 'wsl/SLES-UEFI-CA-Certificate.crt'
    };
    my $ms_cert_store = 'cert:\\LocalMachine\\Root';
    my $cert_file_path = 'C:\Users\Public\image-ca.cert';
    # The certificates should be downloaded from the web
    $self->run_in_powershell(
        cmd => 'Invoke-WebRequest -Uri "' . data_url($certs->{get_required_var('DISTRI')}) . '" -O "' . $cert_file_path . '" -UseBasicParsing',
    );
    $self->run_in_powershell(
        cmd => 'Import-Certificate -FilePath "' . $cert_file_path . '" -CertStoreLocation ' . $ms_cert_store . ' -Verbose',
        timeout => 120
    );
}

sub run {
    my ($self) = @_;
    assert_screen 'windows-desktop';

    $self->open_powershell_as_admin;
    # Set the version for WSL1
    $self->run_in_powershell(
        cmd => 'wsl --set-default-version 1',
        timeout => 30
    ) unless (get_var('WSL2'));

    my $WSL_version = '';
    if (is_sle('<=15-sp4')) {
        $WSL_version = "SUSE-Linux-Enterprise-Server-" . get_required_var("VERSION");
    } elsif (is_sle('>=15-sp5')) {
        $WSL_version = "SUSE-Linux-Enterprise-" . get_required_var("VERSION");
    } elsif (is_leap) {
        $WSL_version = "openSUSE-Leap-" . get_required_var("VERSION");
    } else {
        $WSL_version = "openSUSE-Tumbleweed";
    }
    my $install_from = get_required_var('WSL_INSTALL_FROM');
    if ($install_from eq 'build') {
        my $wsl_appx_filename = (split /\//, get_required_var('ASSET_1'))[-1];
        my $wsl_appx_uri = "\\\\10.0.2.4\\qemu\\$wsl_appx_filename";
        # Enable the 'developer mode' in Windows
        $self->run_in_powershell(
            cmd => 'New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name AllowDevelopmentWithoutDevLicense -PropertyType DWORD -Value 1'
        );
        # On Win 11 for Arm Build 25931, smb transfers don't work (poo#126083)
        $wsl_appx_uri = data_url('ASSET_1') if is_aarch64;
        $self->run_in_powershell(
            cmd => "Start-BitsTransfer -Source $wsl_appx_uri -Destination C:\\\\$wsl_appx_filename",
            timeout => 60
        );

        $self->install_certificates;

        $self->run_in_powershell(
            cmd => "Add-AppxPackage -Path C:\\$wsl_appx_filename",
            timeout => 60
        );
        record_info 'Port close', 'Closing serial port...';
        $self->run_in_powershell(cmd => '$port.close()', code => sub { });
        $self->run_in_powershell(cmd => 'exit', code => sub { });
        $self->use_search_feature($WSL_version =~ s/\-/\ /gr);
        assert_and_click 'wsl-suse-startup-search';
    } elsif ($install_from eq 'msstore') {
        # Install required SUSE distro from the MS Store
        $self->run_in_powershell(
            cmd => "wsl --install --distribution $WSL_version",
            code => sub {
                assert_screen("yast2-wsl-firstboot-welcome", timeout => 300);
            }
        );
    } else {
        die("The value entered for WSL_INSTALL_FROM is not 'build' neither 'msstore'");
    }
}

1;
