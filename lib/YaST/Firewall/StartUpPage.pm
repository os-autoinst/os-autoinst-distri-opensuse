# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles Firewall Startup Page.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YaST::Firewall::StartUpPage;
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
    $self->{lbl_status} = $self->{app}->label({id => 'service_widget_status'});
    $self->{cmb_set_firewall_state} = $self->{app}->combobox({id => 'service_widget_action'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{lbl_status}->exist();
}

sub start_firewall {
    my ($self) = @_;
    $self->{cmb_set_firewall_state}->select("Start");
}

sub stop_firewall {
    my ($self) = @_;
    $self->{cmb_set_firewall_state}->select("Stop");
}

1;
