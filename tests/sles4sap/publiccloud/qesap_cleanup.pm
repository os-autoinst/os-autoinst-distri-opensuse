# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Cleanup cloud resources meant to be used with multimodule setup with qe-sap-deployment project.
# https://github.com/SUSE/qe-sap-deployment

use base 'sles4sap_publiccloud_basetest';
use strict;
use warnings FATAL => 'all';
use testapi;


sub run {
    my ($self, $run_args) = @_;
    # Needed to have peering and ansible state propagated in post_fail_hook
    $self->import_context($run_args);

    if (get_var('QESAP_NO_CLEANUP')) {
        record_info('SKIP CLEANUP',
            "Variable 'QESAP_NO_CLEANUP' set to value " . get_var('QESAP_NO_CLEANUP'));
        return 1;
    }
    $self->cleanup($run_args);
    $run_args->{network_peering_present} = $self->{network_peering_present};
    $run_args->{ansible_present} = $self->{ansible_present};
}

1;
