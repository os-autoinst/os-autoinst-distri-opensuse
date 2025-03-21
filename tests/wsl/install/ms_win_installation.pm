# SUSE's openQA tests
#
# Copyright 2016-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Windows 10 installation test module
#    modiffied (only win10 drivers) iso from https://fedoraproject.org/wiki/Windows_Virtio_Drivers is needed
#    Works only with CDMODEL=ide-cd and QEMUCPU=host or core2duo (maybe other but not qemu64)
# Maintainer: Jozef Pupava <jpupava@suse.com>

use base "windowsbasetest";
use strict;
use warnings;

use testapi;

sub run {

    my $self = shift;

    # Press 'spacebar' continuously until installation appears
    send_key_until_needlematch('windows-unattend-starting', 'spc', 60, 1);
    record_info('Windows firstboot', 'Starting Windows for the first time');
    wait_still_screen stilltime => 60, timeout => 300;

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
}

1;
