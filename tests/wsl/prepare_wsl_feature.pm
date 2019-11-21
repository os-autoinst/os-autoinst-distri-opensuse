# SUSE's openQA tests
#
# Copyright © 2012-2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Configure windows 10 to host WSL image
# Maintainer: Martin Loviska <mloviska@suse.com>

use base 'windowsbasetest';
use strict;
use warnings;
use testapi;

my $powershell_cmds = {
    enable_developer_mode =>
q{reg add `"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock`" /t REG_DWORD /f /v `"AllowDevelopmentWithoutDevLicense`" /d `"1`"},
    enable_wsl_feature => {
        wsl         => q{Enable-WindowsOptionalFeature -Online -FeatureName "Microsoft-Windows-Subsystem-Linux" -NoRestart},
        vm_platform => q{Enable-WindowsOptionalFeature -Online -FeatureName "VirtualMachinePlatform" -NoRestart}
    }
};

sub run {
    my ($self) = @_;
    my $wsl_appx_filename = get_required_var('ASSET_1');
    assert_screen 'windows-desktop';

    # 0) Enable developer mode
    $self->open_powershell_as_admin;
    $self->run_in_powershell($powershell_cmds->{enable_developer_mode});

    # 1) Enable WSL 1 or 2
    $self->run_in_powershell($powershell_cmds->{enable_wsl_feature}->{vm_platform}) if (get_var('some_future_var') =~ m/wsl/);
    $self->run_in_powershell($powershell_cmds->{enable_wsl_feature}->{wsl});

    # 2) Download the image
    $self->run_in_powershell('Invoke-WebRequest -Uri ' . data_url('ASSET_1') . ' -O C:\\' . $wsl_appx_filename . ' -UseBasicParsing');

    # 3) Open the image file in Explorer
    $self->run_in_powershell('ii C:\\');
    assert_and_click 'wsl-appx-file', timeout => 60, button => 'right';
    wait_still_screen stilltime => 3, timeout => 10;

    # 4) Reach certificate installation
    assert_and_click 'open-file-properties';
    assert_and_click 'digital-signatures';
    assert_and_click 'build-service-cert';
    wait_screen_change(sub { send_key 'alt-d' }, 10);
    assert_and_click 'view-certificate-details';
    assert_and_click 'install-certificate';
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
    # confirm selected certificate store
    wait_screen_change(sub { send_key 'ret' }, 10);
    # hit next
    wait_screen_change(sub { send_key 'ret' }, 10);
    for (1 .. 2) {
        assert_screen 'successful-certificate-import';
        wait_screen_change(sub { send_key 'ret' }, 10);
    }

    # close all opened windows, including powershell
    send_key_until_needlematch 'powershell-ready-prompt', 'alt-f4', 25, 2;
    # close
    type_string "exit", max_interval => 125;
    send_key 'ret';
    assert_screen 'windows-desktop';

    # 5) reboot the SUT
    $self->reboot_or_shutdown('reboot');
    $self->wait_boot_windows;

    # 6) Install Linux in WSL
    $self->open_powershell_as_admin;
    type_string "C:\\$wsl_appx_filename";
    wait_still_screen stilltime => 3, timeout => 10;
    send_key 'ret';
    wait_still_screen stilltime => 3, timeout => 10;
}

1;
