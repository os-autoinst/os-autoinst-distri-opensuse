# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The module provides interface to the Add New ZFCP Device dialog

# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::DiskActivation::AddZFCPDevicePage;
use parent 'Installation::Navigation::NavigationBase';
use strict;
use warnings;

sub init {
    my ($self, $args) = @_;
    $self->SUPER::init($args);
    $self->{cmb_channel} = $self->{app}->combobox({id => 'channel'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{cmb_channel}->exist();
}

sub set_channel {
    my ($self, $channel) = @_;
    return $self->{cmb_channel}->set($channel);
}

1;
