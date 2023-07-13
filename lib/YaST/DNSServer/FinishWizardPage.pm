# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles DNSServer Installation Finish Wizard Page.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package YaST::DNSServer::FinishWizardPage;
use parent 'Installation::Navigation::NavigationBase';
use strict;
use warnings;

sub init {
    my ($self) = @_;
    $self->SUPER::init();
    $self->{cmb_after_configuration} = $self->{app}->combobox({id => "service_widget_action"});
    $self->{cmb_after_reboot} = $self->{app}->combobox({id => "service_widget_autostart"});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{cmb_after_configuration}->exist();
}

sub set_action {
    my ($self, $action) = @_;
    $self->{cmb_after_configuration}->select($action);
}

sub set_autostart {
    my ($self, $autostart) = @_;
    $self->{cmb_after_reboot}->select($autostart);
}

1;
