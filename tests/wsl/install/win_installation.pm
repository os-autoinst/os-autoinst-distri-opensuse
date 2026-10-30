# SUSE's openQA tests
#
# Copyright 2016-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Windows 11 installation test module
#    modified (only win10 drivers) iso from https://fedoraproject.org/wiki/Windows_Virtio_Drivers is needed
#    Works only with CDMODEL=ide-cd and QEMUCPU=host or core2duo (maybe other but not qemu64)
# Maintainer: qa-c <qa-c@suse.de>

use Mojo::Base 'windowsbasetest';
use testapi;

sub run {

    my $self = shift;

    # Press 'spacebar' continuously until installation appears
    send_key_until_needlematch('windows-unattend-running', '.', 60, 1);
    record_info('Windows firstboot', 'Starting Windows for the first time');
    assert_screen('windows-login-screen', 3600);    # Wait for Windows to complete installation

    $self->windows_login;

    # When starting Windows for the first time, several screens or pop-ups may
    # appear in a different order. We'll try to handle them until the desktop is
    # shown
    assert_screen(['windows-edge-welcome', 'windows-desktop', 'windows-edge-decline', 'networks-popup-be-discoverable', 'windows-start-menu', 'windows-qemu-drivers', 'windows-setup-browser', 'windows-user-acount-ctl-yes'], timeout => 120);
    while (not match_has_tag('windows-desktop')) {
        assert_and_click "windows-user-acount-ctl-yes" if (match_has_tag 'windows-user-acount-ctl-yes');
        assert_and_click 'windows-edge-welcome' if (match_has_tag 'windows-edge-welcome');
        assert_and_click 'windows-setup-browser' if (match_has_tag 'windows-setup-browser');
        assert_and_click 'network-discover-yes' if (match_has_tag 'networks-popup-be-discoverable');
        assert_and_click 'windows-edge-decline' if (match_has_tag 'windows-edge-decline');
        assert_and_click 'windows-start-menu' if (match_has_tag 'windows-start-menu');
        assert_and_click 'windows-qemu-drivers' if (match_has_tag 'windows-qemu-drivers');
        wait_still_screen stilltime => 15, timeout => 30;
        assert_screen(['windows-edge-welcome', 'windows-desktop', 'windows-edge-decline', 'networks-popup-be-discoverable', 'windows-start-menu', 'windows-qemu-drivers', 'windows-setup-browser', 'windows-user-acount-ctl-yes'], timeout => 30);
    }

    # Install WSL from the GitHub release page. "wsl --install" and "wsl --update" use the GitHub API,
    # which fails with 403 when the rate limit of the IP address of the workers is used up.
    $self->open_powershell_as_admin;
    my $tag_option = get_var('WSL_RELEASE_TAG') ? ' -Tag ' . get_var('WSL_RELEASE_TAG') : '';
    $self->run_in_powershell(cmd => 'Invoke-WebRequest -Uri "' . data_url('wsl/install_wsl.ps1') . '" -OutFile "$env:TEMP\\install_wsl.ps1" -UseBasicParsing');
    $self->run_in_powershell(cmd => 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:TEMP\\install_wsl.ps1"' . $tag_option, timeout => 900);

    # Verify that WSL has been properly installed during OS deployment
    $self->run_in_powershell(
        cmd => '$port.WriteLine($(wsl --version)); $port.WriteLine("WSL-CHECK-END")',
        code => sub {
            # wsl.exe prints UTF-16, so PowerShell can add NUL bytes between the characters
            my $serial_output = wait_serial(qr/WSL-CHECK-END/, timeout => 120) // die("No answer from 'wsl --version' on the serial port");
            $serial_output =~ s/\0//g;
            die("WSL has not been installed during OS deployment...\n\n$serial_output") unless $serial_output =~ qr/WSL version: \d+\.\d+\.\d+\.\d+/;
            record_info("WSL installed", "WSL has been deployed properly!");
        }
    );
    $self->run_in_powershell(
        cmd => '$port.WriteLine($(Get-LocalUser | Where-Object { $_.Enabled } | Select Name,PasswordExpires))',
        code => sub {
            wait_serial("Name=Bernhard.*PasswordExpires=(?>)}") || die "Failed to disable max password age";
        }
    );
    $self->close_powershell;
}

sub test_flags {
    return {fatal => 1};
}
1;
