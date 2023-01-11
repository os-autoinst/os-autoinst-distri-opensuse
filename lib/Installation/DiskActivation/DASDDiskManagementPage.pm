# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles DASD Disk Management page
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::DiskActivation::DASDDiskManagementPage;
use parent 'Installation::Navigation::NavigationBase';
use strict;
use warnings;

sub init {
    my ($self) = @_;
    $self->SUPER::init();
    $self->{txb_minimum_channel} = $self->{app}->textbox({id => 'min_chan'});
    $self->{txb_maximum_channel} = $self->{app}->textbox({id => 'max_chan'});
    $self->{btn_filter} = $self->{app}->button({id => 'filter'});
    $self->{tbl_devices} = $self->{app}->table({id => 'table'});
    $self->{mnc_operation} = $self->{app}->menucollection({id => 'operation'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{mnc_operation}->exist();
}

sub enter_minimum_channel {
    my ($self, $channel) = @_;
    return $self->{txb_minimum_channel}->set($channel);
}

sub enter_maximum_channel {
    my ($self, $channel) = @_;
    return $self->{txb_maximum_channel}->set($channel);
}

sub press_filter_button {
    my ($self) = @_;
    return $self->{btn_filter}->click();
}

sub get_devices {
    my ($self) = @_;
    return $self->{tbl_devices}->items();
}

sub select_device {
    my ($self, $channel) = @_;
    return $self->{tbl_devices}->select(value => $channel);
}

sub perform_action_activate {
    my ($self) = @_;
    $self->{mnc_operation}->select('Activate');
}

1;
