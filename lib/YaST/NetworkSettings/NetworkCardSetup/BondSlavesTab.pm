# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for Bond Slaves Tab in
# YaST2 lan module dialog.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YaST::NetworkSettings::NetworkCardSetup::BondSlavesTab;
use strict;
use warnings;
use testapi;
use parent 'YaST::NetworkSettings::NetworkCardSetup::NetworkCardSetupWizard';

use constant {
    NETWORK_CARD_SETUP => 'yast2_lan_network_card_setup',
    BOND_SLAVES_TAB => 'yast2_lan_bond_slave_tab_selected',
    ALREADY_CONFIGURED_DEVICE_POPUP => 'yast2_lan_select_already_configured_device',
    BOND_SLAVE_DEVICE_CHECKBOX_UNCHECKED => 'yast2_lan_checkbox_unchecked'
};

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        tab_shortcut => $args->{tab_shortcut}
    }, $class;
}

sub select_tab {
    my ($self) = @_;
    assert_screen(NETWORK_CARD_SETUP);
    send_key($self->{tab_shortcut});
}

sub select_bond_slave_in_list {
    assert_screen(BOND_SLAVES_TAB);
    record_soft_failure('bsc#1191112 - Resizing window as workaround for YaST content not loading');
    send_key_until_needlematch(BOND_SLAVE_DEVICE_CHECKBOX_UNCHECKED, 'alt-f10', 10, 2);
    assert_and_click(BOND_SLAVE_DEVICE_CHECKBOX_UNCHECKED);
}

sub select_continue_in_popup {
    assert_screen(ALREADY_CONFIGURED_DEVICE_POPUP);
    send_key 'alt-o';
}

sub press_next {
    my ($self) = @_;
    $self->SUPER::press_next(BOND_SLAVES_TAB);
}

1;
