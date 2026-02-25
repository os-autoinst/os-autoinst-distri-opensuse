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
use utils qw(enter_cmd_slow);

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
        # We can use WSL_CUSTOM_IMAGE var to provide a custom URL to download a
        # different image from the ASSET_1 provided via IBS
        my $wsl_image_uri = get_var('WSL_CUSTOM_IMAGE', data_url('ASSET_1'));
        my $wsl_image_filename = (split /\//, $wsl_image_uri)[-1];
        my $wsl_image_ext = (split /\./, $wsl_image_filename)[-1];
        die("The image provided is not in .appx neither .tar.xz format.\nImage extension: $wsl_image_ext")
          unless ($wsl_image_ext =~ /^(appx|xz)$/);
        # Enable the 'developer mode' in Windows
        $self->run_in_powershell(
            cmd => 'Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name AllowDevelopmentWithoutDevLicense -Type DWORD -Value 1'
        );

        $self->install_certificates;

        $self->run_in_powershell(
            cmd => "Start-BitsTransfer -Source $wsl_image_uri -Destination C:\\\\$wsl_image_filename",
            timeout => 60
        );
        # Select the installation method based on the file extension
        if ($wsl_image_ext eq 'appx') {
            $self->run_in_powershell(
                cmd => "Add-AppxPackage -Path C:\\$wsl_image_filename",
                timeout => 60
            );
        } elsif ($wsl_image_ext eq 'xz') {
            $self->run_in_powershell(cmd => "mkdir C:\\$WSL_version");
            $self->run_in_powershell(
                cmd => "wsl --import $WSL_version C:\\$WSL_version C:\\$wsl_image_filename",
                timeout => 60
            );
        }
        $self->close_powershell;
        $self->use_search_feature($WSL_version =~ s/\-/\ /gr);
        assert_and_click 'wsl-suse-startup-search';
        if (check_var('DISTRI', 'sle') || is_aarch64) {
            assert_and_click("welcome_to_wsl", timeout => 120);
            send_key "alt-f4";
        }
    } elsif ($install_from eq 'msstore') {
        # Install required SUSE distro from the MS Store, legacy or modern.
        if (check_var('WSL_FIRSTBOOT', 'yast')) {
            # Install required SUSE distro from the MS Store
            $self->run_in_powershell(
                cmd => "wsl --install --legacy --distribution $WSL_version",
                timeout => 300,
                code => sub {
                    assert_screen("yast2-wsl-firstboot-welcome", timeout => 300);
                }
            );
        }
        else {
            $self->run_in_powershell(
                cmd => "wsl --install --web-download --distribution $WSL_version",
                timeout => 300,
                code => sub {
                    # change to jeos-wsl-firstboot-welcome
                    assert_screen("jeos-wsl-firstboot-welcome", timeout => 300);
                }
            );
        }
        if (check_var('DISTRI', 'sle')) {
            assert_and_click("welcome_to_wsl", timeout => 120);
            send_key "alt-f4";
        }

    } else {
        die("The value entered for WSL_INSTALL_FROM is not 'build' neither 'msstore'");
    }
}

1;
