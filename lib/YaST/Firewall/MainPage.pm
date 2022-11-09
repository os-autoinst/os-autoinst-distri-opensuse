# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles Firewall Main Page(Include left view tree menu and bottom button).
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YaST::Firewall::MainPage;
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
    $self->{tre_overview} = $self->{app}->tree({id => "\"Y2Firewall::Widgets::OverviewTree\""});
    $self->{btn_accept} = $self->{app}->button({id => 'next'});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{tre_overview}->exist();
}

sub select_start_up_page {
    my ($self) = @_;
    $self->{tre_overview}->select("Start-Up");
}

sub select_interfaces_page {
    my ($self) = @_;
    $self->{tre_overview}->select("Interfaces");
}

sub select_zones_page {
    my ($self) = @_;
    $self->{tre_overview}->select("Zones");
}

sub press_accept {
    my ($self) = @_;
    $self->{btn_accept}->click();
}

sub select_zone_page {
    my ($self, $zone) = @_;
    $self->{tre_overview}->select("Zones|$zone");
}

1;
