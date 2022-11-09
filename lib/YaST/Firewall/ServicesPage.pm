# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles Firewall Service Settings Page.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YaST::Firewall::ServicesPage;
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
    $self->{tbl_known_trusted} = $self->{app}->table({id => "\"known:trusted\""});
    $self->{btn_add} = $self->{app}->button({id => "add"});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{tbl_known_trusted}->exist();
}

sub select_service {
    my ($self, $zone, $service) = @_;
    $self->{"tbl_known_$zone"}->select(value => $service);
}

sub add_service {
    my ($self) = @_;
    $self->{btn_add}->click();
}

1;
