# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles Firewall Zone Page.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YaST::Firewall::ZonePage;
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
    $self->{tab_services_ports} = $self->{app}->tab({id => "\"CWM::DumbTabPager\""});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{tab_services_ports}->exist();
}

# Using "Ports" instead of "&Ports" as tab select function parameter since YuiRestClient::Widget::Base will
# using sanitize function remove "&" before compare the string
sub switch_ports_tab {
    my ($self) = @_;
    $self->{tab_services_ports}->select("Ports");
}

sub switch_services_tab {
    my ($self) = @_;
    $self->{tab_services_ports}->select("Services");
}

1;
