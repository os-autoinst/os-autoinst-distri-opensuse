# SUSE's openQA tests
#
# Copyright 2016-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Windows 11 installation test module
#    modified (only win10 drivers) iso from https://fedoraproject.org/wiki/Windows_Virtio_Drivers is needed
#    Works only with CDMODEL=ide-cd and QEMUCPU=host or core2duo (maybe other but not qemu64)
# Maintainer: qa-c <qa-c@suse.de>

use base "windowsbasetest";
use testapi;

sub run {

    my $self = shift;

    # Press 'spacebar' continuously until installation appears
    send_key_until_needlematch('windows-unattend-starting', '.', 60, 1);
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

    # Verify that WSL has been properly installed during OS deployment
    $self->open_powershell_as_admin;
    $self->run_in_powershell(
        cmd => '$port.WriteLine($(wsl --version))',
        code => sub {
            my $serial_output = wait_serial(
                qr/WSL version: \d+\.\d+\.\d+\.\d+/,
                expect_not_found => 1
            );
            if ($serial_output == undef) {
                record_info("WSL installed", "WSL has been deployed properly!");
            } elsif ($serial_output =~ qr/The Windows Subsystem for Linux is not installed./) {
                die("WSL has not been installed during OS deployment...");
            } else {
                die("WSL unexpected error", "Unexpected error installing WSL:\n\n$serial_output");
            }
        }
    );
    $self->close_powershell;
}

1;
