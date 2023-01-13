# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles Firewall Zones Settings Page.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package YaST::Firewall::ZonesPage;
use strict;
use warnings;

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        app => $args->{app}
    }, $class;
    return $self->init();
}

sub init {
    my $self = shift;
    $self->{tbl_zones} = $self->{app}->table({id => "\"zones_table\""});
    $self->{btn_set_as_default} = $self->{app}->button({id => "\"Y2Firewall::Widgets::DefaultZoneButton\""});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{tbl_zones}->exist();
}

sub get_items {
    my ($self) = @_;
    return $self->{tbl_zones}->items();
}

sub select_zone {
    my ($self, $zone) = @_;
    $self->{tbl_zones}->select(value => $zone);
}

sub set_default_zone {
    my ($self) = @_;
    $self->{btn_set_as_default}->click();
}
1;
