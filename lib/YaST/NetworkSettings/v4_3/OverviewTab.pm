# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for Overview Tab in YaST2
# lan module dialog
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package YaST::NetworkSettings::v4_3::OverviewTab;
use parent 'YaST::NetworkSettings::OverviewTab';
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
    $self->{tbl_devices} = $self->{app}->table({id => '"Y2Network::Widgets::InterfacesTable"'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{tbl_devices}->exist();
}

1;
