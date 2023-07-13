# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces business actions for Network Settings Dialog
# (yast2 lan module), version 4.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package YaST::NetworkSettings::v4::NetworkSettingsController;
use parent 'YaST::NetworkSettings::AbstractNetworkSettingsController';
use strict;
use warnings;
use YaST::NetworkSettings::NetworkCardSetup::DeviceTypeDialog;
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
    $self->{DeviceTypeDialog} = YaST::NetworkSettings::NetworkCardSetup::DeviceTypeDialog->new();
    $self->{BridgedDevicesTabOnAdd} = YaST::NetworkSettings::NetworkCardSetup::BridgedDevicesTab->new({tab_shortcut => 'alt-v', bridged_devices_shortcut => 'alt-i'});
    $self->{BridgedDevicesTabOnEdit} = YaST::NetworkSettings::NetworkCardSetup::BridgedDevicesTab->new({tab_shortcut => 'alt-b', bridged_devices_shortcut => 'alt-i'});
    $self->{BondSlavesTabOnAdd} = YaST::NetworkSettings::NetworkCardSetup::BondSlavesTab->new({tab_shortcut => 'alt-o'});
    $self->{BondSlavesTabOnEdit} = YaST::NetworkSettings::NetworkCardSetup::BondSlavesTab->new({tab_shortcut => 'alt-b'});
    return $self;
}

sub get_device_type_dialog {
    my ($self) = @_;
    return $self->{DeviceTypeDialog};
}

sub get_bridged_devices_tab_on_add {
    my ($self) = @_;
    return $self->{BridgedDevicesTabOnAdd};
}

sub get_bridged_devices_tab_on_edit {
    my ($self) = @_;
    return $self->{BridgedDevicesTabOnEdit};
}

sub get_bond_slaves_tab_on_add {
    my ($self) = @_;
    return $self->{BondSlavesTabOnAdd};
}

sub get_bond_slaves_tab_on_edit {
    my ($self) = @_;
    return $self->{BondSlavesTabOnEdit};
}

sub add_bridged_device {
    my ($self) = @_;
    $self->get_overview_tab()->press_add();
    $self->get_device_type_dialog()->select_device_type('bridge');
    $self->get_device_type_dialog()->press_next();
    $self->get_address_tab()->select_dynamic_address();
    $self->get_bridged_devices_tab_on_add()->select_tab();
    $self->get_bridged_devices_tab_on_add()->select_bridged_device_in_list();
    $self->get_bridged_devices_tab_on_add()->press_next();
    $self->get_bridged_devices_tab_on_add()->select_continue_in_popup();
}

sub add_bond_slave {
    my ($self) = @_;
    $self->get_overview_tab()->press_add();
    $self->get_device_type_dialog()->select_device_type('bond');
    $self->get_device_type_dialog()->press_next();
    $self->get_address_tab()->select_dynamic_address();
    $self->get_bond_slaves_tab_on_add()->select_tab();
    $self->get_bond_slaves_tab_on_add()->select_bond_slave_in_list();
    $self->get_bond_slaves_tab_on_add()->press_next();
    $self->get_bond_slaves_tab_on_add()->select_continue_in_popup();
}

sub add_vlan_device {
    my ($self) = @_;
    $self->get_overview_tab()->press_add();
    $self->get_device_type_dialog()->select_device_type('vlan');
    $self->get_device_type_dialog()->press_next();
    $self->get_vlan_address_tab()->select_dynamic_address();
    $self->get_vlan_address_tab()->fill_in_vlan_id('12');
    $self->get_vlan_address_tab()->press_next();
    $self->get_vlan_address_tab()->decline_vlan_id_warning();
}

sub view_bridged_device_without_editing {
    my ($self) = @_;
    $self->get_overview_tab()->select_device('bridge');
    $self->get_overview_tab()->press_edit();
    $self->get_bridged_devices_tab_on_edit()->select_tab();
    $self->get_bridged_devices_tab_on_edit()->press_next();
}

sub view_bond_slave_without_editing {
    my ($self) = @_;
    $self->get_overview_tab()->select_device('bond');
    $self->get_overview_tab()->press_edit();
    $self->get_bond_slaves_tab_on_edit()->select_tab();
    $self->get_bond_slaves_tab_on_edit()->press_next();
    $self->get_bond_slaves_tab_on_edit()->select_continue_in_popup();
}

1;
