# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Check RPi bluetooth: Do a scan and check if we see
#          the openQA-worker device.
# Maintainer: qe-core team <qe-core@suse.de>

use base "opensusebasetest";
use strict;
use warnings;
use testapi;
use utils;

# This requires a discoverable bluetooth device in range:
#===========================
#/etc/bluetooth/main.conf:
#[Policy]
#AutoEnable=true
#[General]
#DiscoverableTimeout = 0
#Name = openQA-worker
#===========================

sub run {
    my ($self) = @_;

    zypper_call 'in bluez';
    systemctl 'start bluetooth';
    systemctl 'status bluetooth';
    assert_script_run 'rfkill list';
    assert_script_run 'bluetoothctl show';
    assert_script_run '(echo "power on"; sleep 5; echo "scan on"; sleep 30; echo "devices") | bluetoothctl | tee /dev/stderr | grep openQA-worker';
    assert_script_run 'bluetoothctl show';
}

sub post_fail_hook {
    my ($self) = @_;
    $self->save_and_upload_log('dmesg', 'dmesg.log');
    $self->save_and_upload_log('journalctl -b', 'journal.log');
}

1;
