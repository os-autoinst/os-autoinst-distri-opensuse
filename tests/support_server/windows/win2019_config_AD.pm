# SUSE's openQA tests
#
# Copyright 2012-2020 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Boot and configure one Active Directory on Windows server 2019
#    Used this how-to:
#           https://docs.microsoft.com/pt-br/powershell/module/addsdeployment/install-addsforest?view=win10-ps
#           https://social.technet.microsoft.com/wiki/contents/articles/52765.windows-server-2019-step-by-step-setup-active-directory-environment-using-powershell.aspx
#
# Maintainer: mmartins <mmartins@suse.com>

use base 'windowsbasetest';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my $self = shift;

    #Configure Ip address to Multimachine setup
    $self->run_in_powershell(cmd => 'ipconfig', tags => 'win-ad-powershell');
    $self->run_in_powershell(cmd => 'Get-NetIPAddress', tags => 'win-ad-powershell');
    $self->run_in_powershell(cmd => 'New-NetIPAddress -InterfaceAlias Ethernet -IPAddress 10.0.2.101 -PrefixLength 24 -DefaultGateway 10.0.2.101', tags => 'win-ad-powershell');
    $self->run_in_powershell(cmd => 'Set-DnsClientServerAddress -InterfaceAlias Ethernet -ServerAddresses ("10.0.2.101","127.0.0.1")', tags => 'win-ad-powershell');

    $self->run_in_powershell(cmd => 'Get-NetIPAddress', tags => 'win-ad-powershell');

    #Install and configure Active Directory Services
    $self->run_in_powershell(cmd => 'Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools', tags => 'win-ad-powershell');
    assert_screen("AD_2019_installed", timeout => 90);
    $self->run_in_powershell(cmd => "Install-ADDSForest -DomainName 'geeko.com' -CreateDnsDelegation:\$false -DatabasePath 'C:\\Windows\\NTDS' -DomainMode '7' -DomainNetbiosName 'geeko' -ForestMode '7' -InstallDns:\$true -LogPath 'C:\\Windows\\NTDS' -NoRebootOnCompletion:\$True -SysvolPath 'C:\\Windows\\SYSVOL' -Force:\$true", tags => 'win-ad-powershell');

    assert_screen("InstallAD-pwd");
    type_string_slow "N0tS3cr3t@";
    send_key "ret";
    assert_screen "InstallAD-pwd-confirm";
    type_string_slow "N0tS3cr3t@";
    send_key "ret";
    assert_screen("windows_ad_installed", timeout => 300);
    #It is a windows, need restart baby.
    $self->reboot_or_shutdown('reboot');

    assert_screen "windows-installed-ok", timeout => 400;
    send_key "ctrl-alt-delete";
    assert_screen "windows_server_login", timeout => 60;
    type_string "N0tS3cr3t@";
    send_key "ret";
    #some times server_manager windows slow to open, fix waiting few seconds more...
    assert_screen "wint_manage_server", timeout => 45;
    $self->open_powershell_as_admin;

    #Check if AD is running, and create one user test with Unix attributes:
    $self->run_in_powershell(cmd => 'ipconfig', tags => 'win-ad-powershell');
    $self->run_in_powershell(cmd => 'Start-Service adws,kdc,Netlogon', tags => 'win-ad-powershell');
    $self->run_in_powershell(cmd => 'Get-Service adws,kdc,Netlogon', tags => 'win-ad-powershell');
    $self->run_in_powershell(cmd => 'Get-ADDomain geeko.com', tags => 'win-ad-powershell');
    $self->run_in_powershell(cmd => 'Get-ADForest geeko.com', tags => 'win-ad-powershell');
    $self->run_in_powershell(cmd => 'New-ADUser -Name "geekouser" -GivenName GeekoUser -Surname Test -SamAccountName geekouser -UserPrincipalName geekouser@geeko.com', tags => 'win-ad-powershell');

    $self->run_in_powershell(cmd => 'Get-ADUser geekouser', tags => 'win-ad-powershell');
    $self->run_in_powershell(cmd => 'Set-ADAccountPassword "CN=geekouser,CN=users,DC=geeko,DC=com" -Reset -NewPassword (ConvertTo-SecureString -AsPlainText "Test@123" -Force)', tags => 'win-ad-powershell');
    $self->run_in_powershell(cmd => 'Enable-ADAccount -Identity geekouser', tags => 'win-ad-powershell');
    $self->run_in_powershell(cmd => 'Add-AdGroupMember "Domain Admins" geekouser ', tags => 'win-ad-powershell');

    #Open Users and Groups
    $self->run_in_powershell(cmd => 'dsa.msc', tags => 'win-ad-powershell');
    #Enable Advanced View
    assert_and_click("mmc-geeko-domain", button => 'left', dclick => 1);
    hold_key 'alt';
    send_key 'v';
    send_key 'v';
    release_key 'alt';
    #Select usertest on Users
    assert_and_click("mmc-geeko-users", button => 'left', dclick => 1);
    assert_and_click("mmc-geekouser-open", button => 'left', dclick => 1);
    #select Attribute Editor tab, and got to Unix attribts:
    assert_and_click("mmc-geeko-select-attribute");
    send_key 'shift-end';
    send_key 'pgup';
    send_key 'pgup';
    send_key 'up';
    send_key 'up';
    send_key 'up';
    send_key 'up';
    send_key 'up';
    assert_and_click("mmc-geeko-unix-userid", button => 'left', dclick => 1);
    wait_screen_change { type_string "1001"; };
    send_key 'ret';
    assert_and_click("mmc-geeko-unix-gid-ok");
    wait_screen_change { send_key 'g'; };
    send_key 'g';
    send_key 'down';
    send_key 'down';
    assert_and_click("mmc-geeko-unix-gid", button => 'left', dclick => 1);
    type_string "1001";
    send_key 'ret';
    send_key 'h';
    assert_and_click("mmc-geeko-unix-home", button => 'left', dclick => 1);
    type_string "/home/usertest";
    send_key 'ret';
    save_screenshot;
    wait_screen_change { send_key 'ret'; };

    #Configuration done. shutdown machine.
    $self->reboot_or_shutdown();
    check_shutdown;

}

1;
