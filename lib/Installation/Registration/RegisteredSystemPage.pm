# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The module provides interface to act with Registration page
#
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Registration::RegisteredSystemPage;
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
    $self->{lbl_system_registered} = $self->{app}->label({label => 'The system is already registered.'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{lbl_system_registered}->exist();
}

1;
