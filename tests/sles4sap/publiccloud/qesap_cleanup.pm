# SUSE's openQA tests
#
# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
# Maintainer: QE-SAP <qe-sap@suse.de>
# Summary: Cleanup test meant to be used with multimodule setup with qe-sap-deployment project.
# https://github.com/SUSE/qe-sap-deployment

use base 'sles4sap_publiccloud_basetest';
use sles4sap_publiccloud_basetest;
use strict;
use warnings FATAL => 'all';
use testapi;


sub run {
    my ($self, $args) = @_;
    if (get_var('QESAP_NO_CLEANUP')) {
        record_info('SKIP CLEANUP',
            "Variable 'QESAP_NO_CLEANUP' set to value " . get_var('QESAP_NO_CLEANUP'));
        return 1;
    }
    $self->cleanup($args);
}

1;
