# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Cleanup test meant to be used with multimodule setup with qe-sap-deployment project.
# https://github.com/SUSE/qe-sap-deployment

use base 'sles4sap_publiccloud_basetest';
use strict;
use warnings FATAL => 'all';
use testapi;


sub run {
    my ($self, $run_args) = @_;
    $self->{network_peering_present} = 1 if ($run_args->{network_peering_present});
    if (get_var('QESAP_NO_CLEANUP')) {
        delete_network_peering() if ($run_args->{network_peering_present});
        record_info('SKIP CLEANUP',
            "Variable 'QESAP_NO_CLEANUP' set to value " . get_var('QESAP_NO_CLEANUP'));
        return 1;
    }
    $self->cleanup($run_args);
    $run_args->{network_peering_present} = $self->{network_peering_present} = 0;
}

1;
