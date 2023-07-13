# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles Change Zone Page.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package YaST::Firewall::ChangeZonePage;
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
    $self->{cmb_zone_options} = $self->{app}->combobox({id => "\"Y2Firewall::Widgets::ZoneOptions\""});
    $self->{btn_ok} = $self->{app}->button({id => "ok"});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{cmb_zone_options}->exist();
}

sub set_interface_zone {
    my ($self, $zone) = @_;
    $self->{cmb_zone_options}->select($zone);
    $self->{btn_ok}->click();
}
1;
