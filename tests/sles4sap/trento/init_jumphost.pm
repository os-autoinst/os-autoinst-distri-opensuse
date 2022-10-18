# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Initialize the Jumphost for a Trento test
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use Mojo::Base 'publiccloud::basetest';
use base 'consoletest';
use strict;
use testapi;
use serial_terminal 'select_serial_terminal';
use base 'trento';

sub run {
    my ($self) = @_;
    select_serial_terminal;

    # Get the code for the Trento deployment
    $self->get_trento_deployment('/root/test');

    # az login
    die "Only AZURE deployment supported for the moment" unless check_var('PUBLIC_CLOUD_PROVIDER', 'AZURE');
    my $provider = $self->provider_factory();
}

1;
