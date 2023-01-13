# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles Navigation base
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package YaST::Navigation::NavigationBase;
use strict;
use warnings;

sub new {
    my ($class, $args) = @_;
    my $self = bless {
        app => $args->{app}
    }, $class;
    return $self->init($args);
}

sub init {
    my ($self, $args) = @_;
    $self->{btn_help} = $self->{app}->button({id => 'help'});
    $self->{btn_cancel} = $self->{app}->button({id => 'abort'});
    $self->{btn_apply} = $self->{app}->button({id => "\"apply\""});
    $self->{btn_ok} = $self->{app}->button({id => 'next'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{btn_ok}->exist();
}

sub press_help {
    my ($self) = @_;
    return $self->{btn_help}->click();
}

sub press_cancel {
    my ($self) = @_;
    return $self->{btn_cancel}->click();
}

sub press_apply {
    my ($self) = @_;
    return $self->{btn_apply}->click();
}

sub press_ok {
    my ($self) = @_;
    return $self->{btn_ok}->click();
}

1;
