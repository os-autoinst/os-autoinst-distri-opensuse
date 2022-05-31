# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for Device Type Dialog in
# YaST2 lan module dialog.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YaST::NetworkSettings::NetworkCardSetup::DeviceTypeDialog;
use strict;
use warnings;
use testapi;
use parent 'YaST::NetworkSettings::NetworkCardSetup::NetworkCardSetupWizard';

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
    record_soft_failure('bsc#1191112 - Resizing window as workaround for YaST content not loading');
    send_key_until_needlematch(DEVICE_TYPE_DIALOG, 'alt-f10', 9, 2);
    send_key $shortcut->{$device};
}

sub press_next {
    my ($self) = @_;
    $self->SUPER::press_next(DEVICE_TYPE_DIALOG);
}


1;
