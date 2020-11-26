# SUSE's openQA tests
#
# Copyright © 2012-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Validate WSL image from host
# Maintainer: qa-c <qa-c@suse.de>

use Mojo::Base qw(windowsbasetest);
use testapi qw(assert_and_click type_string get_var);
use version_utils qw(is_sle is_opensuse);
use wsl qw(is_sut_reg);

my %expected = (
    provider => get_var('WSL2') ? 'microsoft' : '(wsl|kvm)',
    mount    => '/mnt/c'
);

sub run {
    my $self = shift;

    assert_and_click 'powershell-as-admin-window';
    type_string "exit\n";
    $self->open_powershell_as_admin();
    $self->run_in_powershell(cmd => 'wsl --list --verbose',                                                     timeout => 60);
    $self->run_in_powershell(cmd => "wsl mount | Select-String -Pattern $expected{mount}",                      timeout => 60);
    $self->run_in_powershell(cmd => qq{wsl ls $expected{mount}},                                                timeout => 60);
    $self->run_in_powershell(cmd => qq/wsl systemd-detect-virt | Select-String -Pattern "$expected{provider}"/, timeout => 60);
    $self->run_in_powershell(cmd => 'wsl /bin/bash -c "dmesg | head -n 20"');
    $self->run_in_powershell(cmd => 'wsl env');
    $self->run_in_powershell(cmd => 'wsl locale');
    $self->run_in_powershell(cmd => 'wsl date');
    if (is_opensuse || (is_sle && is_sut_reg)) {
        $self->run_in_powershell(cmd => 'wsl -u root zypper -q -n in python3', timeout => 120);
        $self->run_in_powershell(cmd => q{wsl python3 -c "print('Hello from Python living in WSL')"});
    }
    $self->run_in_powershell(cmd => 'wsl --shutdown',       timeout => 60);
    $self->run_in_powershell(cmd => 'wsl --list --verbose', timeout => 60);
}

1;
