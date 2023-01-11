# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for Bridged Devices Tab in
#  YaST2 lan module dialog.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package YaST::NetworkSettings::NetworkCardSetup::BridgedDevicesTab;
use strict;
use warnings;
use testapi;
use parent 'YaST::NetworkSettings::NetworkCardSetup::NetworkCardSetupWizard';
use YaST::workarounds;
use version_utils qw(is_sle);

use constant {
    NETWORK_CARD_SETUP => 'yast2_lan_network_card_setup',
    BRIDGED_DEVICES_TAB => 'yast2_lan_bridged_devices_tab_selected',
    ALREADY_CONFIGURED_DEVICE_POPUP => 'yast2_lan_select_already_configured_device',
    BRIDGED_DEVICE_CHECKBOX_UNCHECKED => 'yast2_lan_checkbox_unchecked'
};

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        tab_shortcut => $args->{tab_shortcut},
        bridged_devices_shortcut => $args->{bridged_devices_shortcut}
    }, $class;
}

sub select_tab {
    my ($self) = @_;
    assert_screen(NETWORK_CARD_SETUP);
    send_key($self->{tab_shortcut});
}

sub select_bridged_device_in_list {
    assert_screen(BRIDGED_DEVICES_TAB);
    apply_workaround_bsc1204176(BRIDGED_DEVICE_CHECKBOX_UNCHECKED) if (is_sle('>=15-SP4'));
    assert_and_click(BRIDGED_DEVICE_CHECKBOX_UNCHECKED);
}

sub select_continue_in_popup {
    assert_screen(ALREADY_CONFIGURED_DEVICE_POPUP);
    send_key 'alt-o';
}

sub press_next {
    my ($self) = @_;
    $self->SUPER::press_next(BRIDGED_DEVICES_TAB);
}

1;
