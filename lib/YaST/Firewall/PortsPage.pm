# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles Firewall Ports Page.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package YaST::Firewall::PortsPage;
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
    $self->{txb_tcp} = $self->{app}->textbox({id => "tcp"});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{txb_tcp}->exist();
}

sub set_tcp_port {
    my ($self, $tcp_port) = @_;
    $self->{txb_tcp}->set($tcp_port);
}

1;
