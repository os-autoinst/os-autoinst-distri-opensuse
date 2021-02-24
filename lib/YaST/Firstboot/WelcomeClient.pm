# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved. This file is offered as-is,
# without any warranty.    

package YaST::Firstboot::WelcomeClient;
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
    my ($self, $debug_label) = @_;
    $self->{btn_next}            = $self->{app}->button({id => 'next'});
    $self->{client_debug_label} = $self->{app}->debug_label({'debug_label' => 'Not Welcome'});
    return $self;
}

sub assert_client {
    my ($self, $debug_label) = @_;
    return $self->{client_debug_label}->text();    
}

sub press_next {
    my ($self) = @_;
    return $self->{btn_next}->click();
}
    

1;
