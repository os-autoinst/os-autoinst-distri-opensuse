# SUSE's openQA tests
#
# Copyright © 2019 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.

# Summary: The class introduces all accessing methods for Device Type Dialog in
# YaST2 lan module dialog.
# Maintainer: Oleksandr Orlov <oorlov@suse.de>

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
        bond   => 'alt-o',
        vlan   => 'alt-v'
    };
    assert_screen(DEVICE_TYPE_DIALOG);
    send_key $shortcut->{$device};
}

sub press_next {
    my ($self) = @_;
    $self->SUPER::press_next(DEVICE_TYPE_DIALOG);
}


1;
