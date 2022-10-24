# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Install needed tools and compose configuration files in the jumphost, for qe-sap-deployment
# Maintainer: QE-SAP <qe-sap@suse.de>, Michele Pagot <michele.pagot@suse.com>

use strict;
use warnings;
use Mojo::Base 'publiccloud::basetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use qesapdeployment 'qesap_upload_logs';
use base 'trento';

sub run {
    my ($self) = @_;
    select_serial_terminal;

    # Init all the PublicCloud gears (ssh keys)
    my $provider = $self->provider_factory();

    # Setup and configure the qe-sap-deployment
    $self->config_cluster($provider->provider_client->region);

}

sub post_fail_hook {
    my ($self) = shift;
    select_serial_terminal;
    qesap_upload_logs();
    $self->SUPER::post_fail_hook;
}

1;
