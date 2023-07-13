# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles DNSServer Installation Zones Page.
# Maintainer: QE YaST and Migration (QE Yam) <qe-yam at suse de>

package YaST::DNSServer::ZonesPage;
use parent 'Installation::Navigation::NavigationBase';
use strict;
use warnings;

sub init {
    my ($self) = @_;
    $self->SUPER::init();
    $self->{tbl_zones} = $self->{app}->table({id => "\"zones_list_table\""});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{tbl_zones}->exist();
}

1;
