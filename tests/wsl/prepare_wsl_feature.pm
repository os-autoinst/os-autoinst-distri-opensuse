# SUSE's openQA tests
#
# Copyright © 2012-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Configure windows 10 to host WSL image
# Currently we have self signed images as sle12sp5 and leap
# tumbleweed and sle15sp2 or higher contain a chain of certificates
# In case of chain certificates, store only CA certificate
# 1) Download the image and CA cert if any
# 2) Enable developer mode Import certificates
# 3) Import downloaded or embedded certificate
# 4) Enable WSL feature
# 5) Reboot
# 6) Install WSL image
# Maintainer: qa-c <qa-c@suse.de>

use Mojo::Base qw(windowsbasetest);
use testapi;
use version_utils qw(is_sle is_opensuse);

my $powershell_cmds = {
    enable_developer_mode =>
q{New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name AllowDevelopmentWithoutDevLicense -PropertyType DWORD -Value 1},
    enable_wsl_feature => {
        wsl         => q{Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart},
        vm_platform => q{Enable-WindowsOptionalFeature -Online -FeatureName "VirtualMachinePlatform" -NoRestart}
    }
};

my $ms_kernel_link = 'https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi';

sub run {
    my ($self)            = @_;
    my $wsl_appx_filename = (split /\//, get_required_var('ASSET_1'))[-1];
    my $certs             = {
        opensuse => '/wsl/openSUSE-UEFI-CA-Certificate.crt',
        sle      => '/wsl/SLES-UEFI-CA-Certificate.crt'
    };
    my $ms_cert_store  = 'cert:\\LocalMachine\\Root';
    my $cert_file_path = 'C:\Users\Public\image-ca.cert';

    assert_screen 'windows-desktop';
    $self->open_powershell_as_admin;
    $self->run_in_powershell(
        cmd     => 'Invoke-WebRequest -Uri ' . autoinst_url("/assets/other/$wsl_appx_filename") . ' -O C:\\' . $wsl_appx_filename . ' -UseBasicParsing',
        timeout => 750
    );
    $self->run_in_powershell(cmd => $powershell_cmds->{enable_developer_mode});

    if (is_sle('>=15-sp2') || is_opensuse) {
        $self->run_in_powershell(
            cmd => 'Invoke-WebRequest -Uri ' . data_url($certs->{get_required_var('DISTRI')}) . ' -O ' . $cert_file_path . ' -UseBasicParsing',
        );
        $self->run_in_powershell(
            cmd => 'Import-Certificate -FilePath ' . $cert_file_path . ' -CertStoreLocation ' . $ms_cert_store . ' -Verbose',
        );
    } else {
        # a) Open the image file in Explorer
        $self->run_in_powershell(cmd => q{ii C:\\});
        assert_and_click 'wsl-appx-file', timeout => 60, button => 'right';
        wait_still_screen stilltime => 3, timeout => 10;
        # b) Reach certificate installation
        assert_and_click 'open-file-properties';
        assert_and_click 'digital-signatures', timeout => 60;
        assert_and_click 'build-service-cert';
        assert_and_click 'cert-details';
        assert_and_click 'view-certificate-details';
        assert_and_click 'install-certificate', timeout => 60;
        wait_still_screen stilltime => 3, timeout => 10;
        assert_and_click 'install-certificate-to-local-machine';
        wait_screen_change(sub { send_key 'ret' }, 10);
        assert_screen 'user-acount-ctl-allow-make-changes', 20;
        assert_and_click 'user-acount-ctl-yes';
        wait_still_screen stilltime => 3, timeout => 10;
        assert_and_click 'select-custom-store', timeout => 120;
        wait_still_screen stilltime => 1, timeout => 5;
        assert_and_click 'browse';
        assert_and_click 'select-store-trusted-roots';
        # confirm selected certificate store and then
        # hit next
        wait_screen_change(sub { send_key 'ret' }, 10) for (1 .. 2);
        assert_screen 'completing-cert-import';
        assert_and_click 'finish-button-in-win10';
        assert_screen 'successful-certificate-import';
        # close all opened windows, including powershell
        send_key_until_needlematch 'powershell-ready-prompt', 'alt-f4', 25, 2;
    }

    # enable WSL & VM platform (WSL2) features
    # reboot the SUT
    $self->run_in_powershell(
        cmd     => $powershell_cmds->{enable_wsl_feature}->{wsl},
        timeout => 120
    );

    if (get_var('WSL2')) {
        $self->run_in_powershell(
            cmd     => $powershell_cmds->{enable_wsl_feature}->{vm_platform},
            timeout => 120
        );
        $self->run_in_powershell(
            cmd     => "Invoke-WebRequest -Uri $ms_kernel_link -O C:\\kernel.msi  -UseBasicParsing",
            timeout => 300
        );
    }

    $self->reboot_or_shutdown(1);
    $self->wait_boot_windows;

    # 5) Install Linux in WSL
    if (get_var('WSL2')) {
        $self->open_powershell_as_admin;
        $self->run_in_powershell(
            cmd  => q{ii C:\\kernel.msi},
            code => sub {
                assert_screen 'wsl2-install-kernel-start';
                send_key 'ret';
                assert_screen 'wsl2-install-kernel-finished';
                send_key 'ret';
            }
        );
        $self->run_in_powershell(
            cmd => q{wsl --set-default-version 2}
        );
        $self->run_in_powershell(
            cmd  => q{$port.close()},
            code => sub { }
        );
    } else {
        $self->open_powershell_as_admin(no_serial => 1);
    }

    $self->run_in_powershell(
        cmd  => qq{ii C:\\$wsl_appx_filename},
        code => sub {
            assert_and_click 'install-linux-in-wsl', timeout => 120;
        }
    );
}

1;
