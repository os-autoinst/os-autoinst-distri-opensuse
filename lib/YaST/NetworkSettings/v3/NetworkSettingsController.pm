# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces business actions for Network Settings Dialog
# (yast2 lan module), version 3.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package YaST::NetworkSettings::v3::NetworkSettingsController;
use parent 'YaST::NetworkSettings::AbstractNetworkSettingsController';
use strict;
use warnings;
use YaST::NetworkSettings::NetworkCardSetup::HardwareDialog;
use YaST::NetworkSettings::NetworkCardSetup::BridgedDevicesTab;
use YaST::NetworkSettings::NetworkCardSetup::BondSlavesTab;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->SUPER::init($args);
    $self->{HardwareDialog} = YaST::NetworkSettings::NetworkCardSetup::HardwareDialog->new();
    $self->{BridgedDevicesTab} = YaST::NetworkSettings::NetworkCardSetup::BridgedDevicesTab->new({tab_shortcut => 'alt-i', bridged_devices_shortcut => 'alt-d'});
    $self->{BondSlavesTab} = YaST::NetworkSettings::NetworkCardSetup::BondSlavesTab->new({tab_shortcut => 'alt-o'});
    return $self;
}

sub get_hardware_dialog {
    my ($self) = @_;
    return $self->{HardwareDialog};
}

sub get_bridged_devices_tab {
    my ($self) = @_;
    return $self->{BridgedDevicesTab};
}

sub get_bond_slaves_tab {
    my ($self) = @_;
    return $self->{BondSlavesTab};
}

sub add_bridged_device {
    my ($self) = @_;
    $self->get_overview_tab()->press_add();
    $self->get_hardware_dialog()->select_device_type('bridge');
    $self->get_hardware_dialog()->press_next();
    $self->get_address_tab()->select_dynamic_address();
    # Bonding Devices tab does not have a shortcut when 'Network Card Setup'
    # Dialog is initialized in v3 (e.g. sle12). It appears after selecting
    # 'General' tab, though. So, apply the workaround here.
    $self->get_general_tab()->select_tab();
    $self->get_bridged_devices_tab()->select_tab();
    $self->get_bridged_devices_tab()->select_bridged_device_in_list();
    $self->get_bridged_devices_tab()->press_next();
    $self->get_bridged_devices_tab()->select_continue_in_popup();
}

sub add_bond_slave {
    my ($self) = @_;
    $self->select_no_link_and_ip_for_ethernet();
    $self->get_overview_tab()->press_add();
    $self->get_hardware_dialog()->select_device_type('bond');
    $self->get_hardware_dialog()->press_next();
    $self->get_address_tab()->select_dynamic_address();
    $self->get_bond_slaves_tab()->select_tab();
    $self->get_bond_slaves_tab()->select_bond_slave_in_list();
    $self->get_bond_slaves_tab()->press_next();
}

sub add_vlan_device {
    my ($self) = @_;
    $self->get_overview_tab()->press_add();
    $self->get_hardware_dialog()->select_device_type('vlan');
    $self->get_hardware_dialog()->press_next();
    $self->get_vlan_address_tab()->select_dynamic_address();
    $self->get_vlan_address_tab()->fill_in_vlan_id('12');
    $self->get_vlan_address_tab()->press_next();
}

sub view_bridged_device_without_editing {
    my ($self) = @_;
    $self->get_overview_tab()->select_device('bridge');
    $self->get_overview_tab()->press_edit();
    # Bridged Devices tab does not have a shortcut when 'Network Card Setup'
    # Dialog is initialized in v3 (e.g. sle12). It appears after selecting
    # 'General' tab, though. So, apply the workaround here.
    $self->get_general_tab()->select_tab();
    $self->get_bridged_devices_tab()->select_tab();
    $self->get_bridged_devices_tab()->press_next();
}

sub view_bond_slave_without_editing {
    my ($self) = @_;
    $self->get_overview_tab()->select_device('bond');
    $self->get_overview_tab()->press_edit();
    $self->get_bond_slaves_tab()->select_tab();
    $self->get_bond_slaves_tab()->press_next();
}

1;
