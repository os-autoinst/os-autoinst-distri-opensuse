# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The module provides interface to act with Add-On Product
# Installation dialog
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package Installation::AddOnProductInstallation::AddOnProductInstallationPage;
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
    $self->{tbl_summary} = $self->{app}->table({id => 'summary'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{tbl_summary}->exist();
}

1;
