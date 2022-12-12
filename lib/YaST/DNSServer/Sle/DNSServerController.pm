# SUSE's openQA tests
#
# Copyright 2022 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: The class introduces actions for DNS Server Settings Page.
# Maintainer: QE YaST <qa-sle-yast@suse.de>

package YaST::DNSServer::Sle::DNSServerController;
use parent 'YaST::DNSServer::DNSServerController';
use strict;
use warnings;

sub process_reading_configuration {
    my ($self) = @_;
    return $self->get_startup_page();
}

1;
