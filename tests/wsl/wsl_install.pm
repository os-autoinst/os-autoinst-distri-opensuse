# SUSE's openQA tests
#
# Copyright 2012-2019 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Configure windows to host WSL image
# THIS WHOLE MODULE IS KEPT UNTIL THE INSTALLATION OF WINDOWS ARM64 CAN BE
# AUTOMATED. IT WILL BE RAN ONLY IN AARCH64 MACHINES.
# Maintainer: qa-c <qa-c@suse.de>

use Mojo::Base qw(windowsbasetest);
use Utils::Architectures qw(is_aarch64);
use testapi;
use version_utils qw(is_sle is_opensuse);

sub run {
    my ($self) = @_;

    $self->open_powershell_as_admin;

    # WSL2 platform must be enabled from the MSstore from now on
    $self->run_in_powershell(
        cmd => "wsl --install --no-distribution",
        code => sub {
            assert_screen("windows-wsl-cli-install-finished", timeout => 900);
        }
    );

    $self->reboot_or_shutdown(is_reboot => 1);
    $self->wait_boot_windows;
}

1;
