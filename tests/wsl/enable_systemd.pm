# SUSE's openQA tests
#
# Copyright 2012-2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Configure WSL users
# Maintainer: qa-c  <qa-c@suse.de>

use Mojo::Base qw(windowsbasetest);
use testapi;
use utils qw(enter_cmd_slow);

sub run {
    my $self = shift;

    $self->open_powershell_as_admin();
    $self->run_in_powershell(cmd => q(wsl /bin/bash -c "echo -e '[boot]\nsystemd=true' > /etc/wsl.conf"), timeout => 60);
    $self->run_in_powershell(cmd => q(wsl --shutdown));
    $self->run_in_powershell(cmd => q(wsl -c systemctl list-unit-files --type=service));
    $self->run_in_powershell(cmd => q(wsl -c shutdown -h now));
}
