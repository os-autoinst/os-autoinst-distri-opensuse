# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The module provides interface to the Configured ZFCP dialog

# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::DiskActivation::ConfiguredZFCPDevicesPage;
use parent 'Installation::Navigation::NavigationBase';
use strict;
use warnings;

sub init {
    my ($self, $args) = @_;
    $self->SUPER::init($args);
    $self->{btn_filter} = $self->{app}->button({id => 'filter'});
    $self->{btn_add} = $self->{app}->button({id => 'add'});
    $self->{txb_min_chan} = $self->{app}->textbox({id => 'min_chan'});
    $self->{txb_max_chan} = $self->{app}->textbox({id => 'max_chan'});
    $self->{tbl_devices} = $self->{app}->table({id => 'table'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{btn_add}->exist();
}

sub press_add {
    my ($self) = @_;
    return $self->{btn_add}->click();
}

sub get_devices {
    my ($self) = @_;
    return $self->{tbl_devices}->items();
}

1;
