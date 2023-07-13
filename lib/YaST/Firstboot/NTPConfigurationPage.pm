# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for YaST Firstboot
# NTP Configuration page
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package YaST::Firstboot::NTPConfigurationPage;
use parent 'Installation::Navigation::NavigationBase';
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
    my ($self) = @_;
    $self->SUPER::init();
    $self->{rdb_only_manually} = $self->{app}->radiobutton({id => '"never"'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{rdb_only_manually}->exist();
}

1;
