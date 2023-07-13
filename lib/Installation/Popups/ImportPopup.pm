# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces methods to handle
# a Trust&Import popup.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package Installation::Popups::ImportPopup;
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
    my $self = shift;
    $self->{trust_import} = $self->{app}->button({id => 'import'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    $self->{trust_import}->exist();
}

sub press_import {
    my ($self) = @_;
    $self->{trust_import}->click();
}

sub text {
    my ($self) = @_;
    return $self->{trust_import}->text();
}

1;
