# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for Hardware Dialog in
# YaST2 lan module dialog.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package YaST::NetworkSettings::NetworkCardSetup::HardwareDialog;
use strict;
use warnings;
use testapi;
use parent 'YaST::NetworkSettings::NetworkCardSetup::NetworkCardSetupWizard';

use constant {
    HARDWARE_DIALOG => 'yast2_lan_hardware_dialog',
    BRIDGE_DEVICE_IN_DROPDOWN => 'yast2_lan_device_type_bridge',
    BOND_DEVICE_IN_DROPDOWN => 'yast2_lan_device_type_bond',
    VLAN_DEVICE_IN_DROPDOWN => 'yast2_lan_device_type_VLAN'
};

sub select_device_type {
    my ($self, $device) = @_;
    assert_screen(HARDWARE_DIALOG);
    send_key 'alt-d';    # Select 'Device Type' dropdown
    send_key 'home';    # Jump to beginning of list
    my $device_needle;
    if ($device eq 'bridge') {
        $device_needle = BRIDGE_DEVICE_IN_DROPDOWN;
    }
    elsif ($device eq 'bond') {
        $device_needle = BOND_DEVICE_IN_DROPDOWN;
    }
    elsif ($device eq 'vlan') {
        $device_needle = VLAN_DEVICE_IN_DROPDOWN;
    }
    else {
        die "\"$device\" device is not known.";
    }
    send_key_until_needlematch $device_needle, 'down';
}

sub press_next {
    my ($self) = @_;
    $self->SUPER::press_next(HARDWARE_DIALOG);
}

1;
