# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for Device Type Dialog in
# YaST2 lan module dialog.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package YaST::NetworkSettings::NetworkCardSetup::DeviceTypeDialog;
use strict;
use warnings;
use testapi;
use parent 'YaST::NetworkSettings::NetworkCardSetup::NetworkCardSetupWizard';
use YaST::workarounds;
use version_utils qw(is_sle);

use constant {
    DEVICE_TYPE_DIALOG => 'yast2_lan_device_type_dialog'
};

sub select_device_type {
    my ($self, $device) = @_;
    # Specify device type shortcut, depending on device name provided with
    # $device method parameter.
    my $shortcut = {
        bridge => 'alt-b',
        bond => 'alt-o',
        vlan => 'alt-v'
    };
    apply_workaround_bsc1204176(DEVICE_TYPE_DIALOG) if (is_sle('>=15-SP4'));
    assert_screen(DEVICE_TYPE_DIALOG);
    send_key $shortcut->{$device};
}

sub press_next {
    my ($self) = @_;
    $self->SUPER::press_next(DEVICE_TYPE_DIALOG);
}


1;
