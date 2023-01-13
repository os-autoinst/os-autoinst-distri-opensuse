# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles DNSServer StartUp Page.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package YaST::DNSServer::StartUpPage;
use parent 'YaST::Navigation::NavigationBase';
use strict;
use warnings;

sub init {
    my ($self) = @_;
    $self->SUPER::init();
    $self->{cmb_action} = $self->{app}->combobox({id => "service_widget_action"});
    $self->{cmb_autostart} = $self->{app}->combobox({id => "service_widget_autostart"});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{cmb_action}->exist();
}

sub set_action {
    my ($self, $action) = @_;
    $self->{cmb_action}->select($action);
}

sub set_autostart {
    my ($self, $autostart) = @_;
    $self->{cmb_autostart}->select($autostart);
}

1;
