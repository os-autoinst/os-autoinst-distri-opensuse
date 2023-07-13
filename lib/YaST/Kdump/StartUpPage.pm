# SUSE's openQA tests
#
# Copyright 2023 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles Kdump StartUp Page.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package YaST::Kdump::StartUpPage;
use parent 'YaST::PageBase';
use strict;
use warnings;
use YaST::Kdump::NavigationPage;

sub init {
    my $self = shift;
    $self->{rbtn_shown} = $self->{app}->radiobutton({id => "\"EnableDisalbeKdump\""});
    $self->{rbtn_enable} = $self->{app}->radiobutton({id => "\"enable_kdump\""});
    $self->{rbtn_firmware} = $self->{app}->radiobutton({id => "\"enable_kdump\""});
    $self->{sect_navigation} = YaST::Kdump::NavigationPage->new();
    return $self;
}

sub get_startup_page {
    my ($self) = @_;
    die 'StartUp Page is not displayed' unless $self->{rbtn_shown}->exist();
    return $self;
}

sub get_navigation {
    my ($self) = @_;
    return $self->get_startup_page()->{sect_navigation};
}

sub enable_kdump {
    my ($self) = @_;
    $self->get_startup_page()->{rbtn_enable}->select('true');
    return $self;
}

1;
