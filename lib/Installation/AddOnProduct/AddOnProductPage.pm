# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The module provides interface to act with Add On Product
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::AddOnProduct::AddOnProductPage;
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
    $self->{chb_add_addon} = $self->{app}->checkbox({id => 'add_addon'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{chb_add_addon}->exist();
}

1;
