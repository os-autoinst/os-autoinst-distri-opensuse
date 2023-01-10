# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles Kdump Navigation Page.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package YaST::Kdump::NavigationPage;
use parent 'YaST::PageBase';
use strict;
use warnings;

sub init {
    my ($self, $args) = @_;
    $self->{btn_help} = $self->{app}->button({id => 'help'});
    $self->{btn_cancel} = $self->{app}->button({id => 'abort'});
    $self->{btn_ok} = $self->{app}->button({id => 'next'});
    return $self;
}

sub get_navigation_page {
    my ($self) = @_;
    die 'Navigation Page is not displayed' unless $self->{btn_ok}->exist();
    return $self;
}

sub help {
    my ($self) = @_;
    $self->get_navigation_page()->{btn_help}->click();
    return $self;
}

sub cancel {
    my ($self) = @_;
    $self->get_navigation_page()->{btn_cancel}->click();
    return $self;
}

sub ok {
    my ($self) = @_;
    $self->get_navigation_page()->{btn_ok}->click();
    return $self;
}

1;
