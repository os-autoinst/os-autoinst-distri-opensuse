# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Summary: Deployment steps for qe-sap-deployment
# Maintainer: QE-SAP <qe-sap@suse.de>

use strict;
use warnings;
use base 'sles4sap_publiccloud_basetest';
use sles4sap_publiccloud;

sub run {
    my ($self, $run_args) = @_;
    $self->import_context($run_args);
    if ($self->{network_peering_present}) {
        delete_network_peering();
        $run_args->{network_peering_present} = $self->{network_peering_present} = 0;
    }
}

1;
