# SUSE's openQA tests
#
# Copyright 2018-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Remote Login: Windows access openSUSE/SLE over RDP
# Maintainer: GraceWang <gwang@suse.com>
# Tags: tc#1610388

use Mojo::Base qw(windowsbasetest);
use testapi;

sub approve_network_popup {
    # if there is the networks popup that ask's if it's ok to be discoverable, approve it
    wait_still_screen stilltime => 5, timeout => 10;
    assert_screen([qw(networks-popup-be-discoverable no-network-discover-popup)], 60);
    if (match_has_tag 'networks-popup-be-discoverable') {
        assert_and_click 'network-discover-yes';
        wait_screen_change(sub { send_key 'ret' }, 10);
    }
    # We may miss some characters due to type command too fast after network popup
    # so wait several seconds as a workaround
    # See poo#109091
    wait_still_screen 3;
}

sub run {
    my $self = shift;

    assert_screen 'windows-desktop';
    $self->open_powershell_as_admin;
    $self->run_in_powershell(cmd => 'Get-NetIPAddress', tags => 'win-remote-desktop');
    $self->run_in_powershell(cmd => '$a = Get-NetAdapter -Name "Ethernet*" ; echo $a.name', tags => 'win-remote-desktop');
    $self->run_in_powershell(cmd => 'Set-NetIPInterface -InterfaceAlias $a.name -Dhcp Disabled', tags => 'win-remote-desktop');
    approve_network_popup;
    $self->run_in_powershell(cmd => 'Get-NetIPAddress -InterfaceAlias $a.name', tags => 'win-remote-desktop');
    $self->run_in_powershell(cmd => 'New-NetIPAddress -InterfaceAlias $a.name -IPAddress 10.0.2.18 -PrefixLength 24 -DefaultGateway 10.0.2.2 -Confirm:$false', tags => 'win-remote-desktop');
    approve_network_popup;
    $self->run_in_powershell(cmd => 'Set-DnsClientServerAddress -InterfaceAlias $a.name -ServerAddresses ("10.67.0.2") -Confirm:$false', tags => 'win-remote-desktop');
    enter_cmd('exit');
    assert_screen 'windows-desktop';
}

1;
