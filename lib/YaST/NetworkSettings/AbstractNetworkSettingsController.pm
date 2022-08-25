# SUSE's openQA tests
#
# Copyright 2019-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The abstract class introduces interface to business actions and
# common actions for all the Network Settings Controllers.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YaST::NetworkSettings::AbstractNetworkSettingsController;
use strict;
use warnings;
use YaST::NetworkSettings::OverviewTab;
use YaST::NetworkSettings::NetworkCardSetup::AddressTab;
use YaST::NetworkSettings::NetworkCardSetup::GeneralTab;
use YaST::NetworkSettings::NetworkCardSetup::VLANAddressTab;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{OverviewTab} = YaST::NetworkSettings::OverviewTab->new();
    $self->{AddressTab} = YaST::NetworkSettings::NetworkCardSetup::AddressTab->new();
    $self->{GeneralTab} = YaST::NetworkSettings::NetworkCardSetup::GeneralTab->new();
    $self->{VLANAddressTab} = YaST::NetworkSettings::NetworkCardSetup::VLANAddressTab->new();
    return $self;
}

sub get_overview_tab {
    my ($self) = @_;
    return $self->{OverviewTab};
}

sub get_address_tab {
    my ($self) = @_;
    return $self->{AddressTab};
}

sub get_general_tab {
    my ($self) = @_;
    return $self->{GeneralTab};
}

sub get_vlan_address_tab {
    my ($self) = @_;
    return $self->{VLANAddressTab};
}

=head2 add_bridged_device

  add_bridged_device();

Add Bridged Device using Network Settings Dialog.

The function just adds the device, but does not save the changes by closing
Network Settings Dialog.

=cut

sub add_bridged_device();

=head2 add_bond_slave

  add_bond_slave();

Add Bond Slave Device using Network Settings Dialog.

The function just adds the device, but does not save the changes by closing
Network Settings Dialog.

=cut

sub add_bond_slave();

=head2 add_vlan_device

  add_vlan_device();

Add VLAN Device using Network Settings Dialog.

The function just adds the device, but does not save the changes by closing
Network Settings Dialog.

=cut

sub add_vlan_device();

=head2 view_bridged_device_without_editing

  view_bridged_device_without_editing();

Open already created Bridged Device for editing, view its settings, do not
change any settings and close the Edit Dialog.

=cut

sub view_bridged_device_without_editing();

=head2 view_bond_slave_without_editing

  view_bond_slave_without_editing();

Open already created Bond Slave Device for editing, view its settings, do not
change any settings and close the Edit Dialog.

=cut

sub view_bond_slave_without_editing();

sub delete_bridged_device {
    my ($self) = @_;
    $self->get_overview_tab()->select_device('bridge');
    $self->get_overview_tab()->press_delete();
}

sub delete_bond_device {
    my ($self) = @_;
    $self->get_overview_tab()->select_device('bond');
    $self->get_overview_tab()->press_delete();
}

sub delete_vlan_device {
    my ($self) = @_;
    $self->get_overview_tab()->select_device('vlan');
    $self->get_overview_tab()->press_delete();
}

sub select_no_link_and_ip_for_ethernet {
    my ($self) = @_;
    $self->get_overview_tab()->select_device('eth');
    $self->get_overview_tab()->press_edit();
    $self->get_address_tab()->select_no_link_and_ip_setup();
    $self->get_address_tab()->press_next();
}

sub select_dynamic_address_for_ethernet {
    my ($self) = @_;
    $self->get_overview_tab()->select_device('eth');
    $self->get_overview_tab()->press_edit();
    $self->get_address_tab()->select_dynamic_address();
    $self->get_address_tab()->press_next();
}

sub view_vlan_device_without_editing {
    my ($self) = @_;
    $self->get_overview_tab()->select_device('vlan');
    $self->get_overview_tab()->press_edit();
    $self->get_vlan_address_tab()->press_next();
}

sub save_changes {
    my ($self) = @_;
    $self->get_overview_tab()->press_ok();
}

1;
