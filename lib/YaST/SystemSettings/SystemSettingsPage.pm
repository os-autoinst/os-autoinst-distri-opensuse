# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for YaST module
# System Settings Page.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package YaST::SystemSettings::SystemSettingsPage;
use strict;
use warnings;
use testapi;

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        app => $args->{app}
    }, $class;
    return $self->init();
}

sub init {
    my $self = shift;
    $self->{btn_ok} = $self->{app}->button({id => 'next'});
    $self->{tab_cwm} = $self->{app}->tab({id => '_cwm_tab'});
    return $self;
}

sub press_ok {
    my ($self) = @_;
    $self->{btn_ok}->click();
    return $self;
}

sub switch_tab_kernel {
    my ($self) = @_;
    $self->{tab_cwm}->select("Kernel Settings");
    return $self;
}

1;
