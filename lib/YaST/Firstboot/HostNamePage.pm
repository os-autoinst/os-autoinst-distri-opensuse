# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for Host Name page
# in Firstboot Configuration
#
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YaST::Firstboot::HostNamePage;
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
    $self->{tb_static_hostname}      = $self->{app}->textbox({id => '"HOSTNAME"'});
    $self->{cb_dhcp_hostname_method} = $self->{app}->combobox({id => '"DHCP_HOSTNAME"'});
    return $self;
}

sub get_static_hostname {
    my ($self) = @_;
    return $self->{tb_static_hostname}->value();
}

sub get_set_hostname_via_DHCP {
    my ($self) = @_;
    return $self->{cb_dhcp_hostname_method}->value();
}

sub is_shown {
    my ($self) = @_;
    return $self->{tb_static_hostname}->exist();
}

1;
