# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Introduces business actions for Navigation on installation
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Navigation::NavigationController;
use strict;
use warnings;
use YuiRestClient;
use Installation::Navigation::NavigationBase;

sub new {
    my ($class, $args) = @_;
    my $self = bless {}, $class;
    return $self->init();
}

sub init {
    my ($self) = @_;
    $self->{NavigationBase} = Installation::Navigation::NavigationBase->new({app => YuiRestClient::get_app()});
    return $self;
}

sub get_navigation_base {
    my ($self) = @_;
    return $self->{NavigationBase};
}

sub proceed_next_screen {
    my ($self) = @_;
    $self->get_navigation_base()->press_next();
}

1;
