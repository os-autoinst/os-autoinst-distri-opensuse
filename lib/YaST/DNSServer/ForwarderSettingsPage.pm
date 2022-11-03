# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Handles DNSServer Installation Forwarder Settings Page
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YaST::DNSServer::ForwarderSettingsPage;
use parent 'Installation::Navigation::NavigationBase';
use strict;
use warnings;

sub init {
    my ($self) = @_;
    $self->SUPER::init();
    $self->{cmb_fwsettings} = $self->{app}->combobox({id => "\"forwarder_policy\""});
    return $self;
}

sub is_shown {
    my ($self) = @_;
    return $self->{cmb_fwsettings}->exist();
}

1;
