# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles Additional Prodcuts page
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::ProductSelection::AdditionalProductPage;
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
    $self->{btn_add} = $self->{app}->button({id => 'ok'});
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

1;
