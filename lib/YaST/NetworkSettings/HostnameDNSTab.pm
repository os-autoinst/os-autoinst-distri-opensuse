# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces all accessing methods for Hostname/DNS
# Tab in yast2 lan module dialog.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package YaST::NetworkSettings::HostnameDNSTab;
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
    $self->{cb_set_hostname_via_dhcp} = $self->{app}->combobox({id => '"DHCP_HOSTNAME"'});
    return $self;
}

sub select_option_in_hostname_via_dhcp {
    my ($self, $option) = @_;
    $self->{cb_set_hostname_via_dhcp}->select($option);
}

1;
