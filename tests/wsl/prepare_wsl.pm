# SUSE's openQA tests
#
# Copyright 2012-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP
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
use Utils::Architectures qw(is_aarch64);
use testapi;
use version_utils qw(is_sle is_opensuse);

sub run {
    my ($self) = @_;

    $self->open_powershell_as_admin;

    $self->power_configuration if (is_aarch64);

    if (get_var('WSL2')) {
        # WSL2 platform must be enabled from the MSstore from now on
        $self->run_in_powershell(
            cmd => "wsl --install --no-distribution",
            code => sub {
                unless (is_aarch64) {
                    assert_screen(["windows-user-account-ctl-hidden", "windows-user-acount-ctl-allow-make-changes"], 240);
                    assert_and_click "windows-user-account-ctl-hidden" if match_has_tag("windows-user-account-ctl-hidden");
                    assert_and_click "windows-user-acount-ctl-yes";
                }
                assert_screen("windows-wsl-cli-install-finished", timeout => 900);
            }
        );
        # Disable HyperV in WSL2
        $self->run_in_powershell(
            cmd => 'Disable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-Hypervisor -NoRestart',
            timeout => 60
        );
    } else {
        # WSL1 will still be enabled in the legacy mode
        $self->run_in_powershell(
            cmd => 'Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart',
            timeout => 300
        );
    }

    $self->reboot_or_shutdown(is_reboot => 1);
    $self->wait_boot_windows;
}

1;
